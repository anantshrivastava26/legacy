import crypto from 'crypto';
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { HttpError } from '../middleware/errors';
import { requireAuth } from '../middleware/auth';
import { sendPasswordResetEmail } from '../lib/mailer';
import { config } from '../config';
import {
  issueRefreshToken,
  revokeRefreshToken,
  rotateRefreshToken,
  signAccessToken,
} from '../lib/tokens';

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z.string().min(1).max(100),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({ refreshToken: z.string().min(1) });

const forgotPasswordSchema = z.object({ email: z.string().email() });

const resetPasswordSchema = z.object({
  email: z.string().email(),
  code: z.string().length(6, 'Code must be 6 digits'),
  newPassword: z.string().min(8, 'Password must be at least 8 characters'),
});

function publicUser(user: { id: string; email: string; displayName: string }) {
  return { id: user.id, email: user.email, displayName: user.displayName };
}

function hashResetCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

router.post('/register', async (req, res, next) => {
  try {
    const body = registerSchema.parse(req.body);
    const existing = await prisma.user.findUnique({
      where: { email: body.email.toLowerCase() },
    });
    if (existing) throw new HttpError(409, 'An account with this email already exists');

    const passwordHash = await bcrypt.hash(body.password, 10);
    const user = await prisma.user.create({
      data: {
        email: body.email.toLowerCase(),
        passwordHash,
        displayName: body.displayName,
      },
    });
    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    const refreshToken = await issueRefreshToken(user.id);
    res.status(201).json({ user: publicUser(user), accessToken, refreshToken });
  } catch (err) {
    next(err);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const body = loginSchema.parse(req.body);
    const user = await prisma.user.findUnique({
      where: { email: body.email.toLowerCase() },
    });
    if (!user || !(await bcrypt.compare(body.password, user.passwordHash))) {
      throw new HttpError(401, 'Incorrect email or password');
    }
    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    const refreshToken = await issueRefreshToken(user.id);
    res.json({ user: publicUser(user), accessToken, refreshToken });
  } catch (err) {
    next(err);
  }
});

router.post('/forgot-password', async (req, res, next) => {
  try {
    const body = forgotPasswordSchema.parse(req.body);
    const email = body.email.toLowerCase();
    const genericResponse = {
      message: 'If an account exists for that email, a reset code has been sent.',
    };

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      // Don't reveal whether the account exists.
      return res.json(genericResponse);
    }

    // Basic throttle: don't reissue a code more than once per 60s.
    if (user.resetCodeExpiresAt) {
      const issuedAt = new Date(
        user.resetCodeExpiresAt.getTime() - config.resetCodeTtlMinutes * 60_000
      );
      if (Date.now() - issuedAt.getTime() < 60_000) {
        return res.json(genericResponse);
      }
    }

    const code = crypto.randomInt(100000, 1000000).toString();
    const expiresAt = new Date(Date.now() + config.resetCodeTtlMinutes * 60_000);

    await prisma.user.update({
      where: { id: user.id },
      data: { resetCodeHash: hashResetCode(code), resetCodeExpiresAt: expiresAt },
    });

    try {
      await sendPasswordResetEmail(user.email, code);
    } catch (err) {
      console.error('Failed to send password reset email:', err);
    }

    res.json(genericResponse);
  } catch (err) {
    next(err);
  }
});

router.post('/reset-password', async (req, res, next) => {
  try {
    const body = resetPasswordSchema.parse(req.body);
    const email = body.email.toLowerCase();
    const invalidError = new HttpError(400, 'Invalid or expired code');

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.resetCodeHash || !user.resetCodeExpiresAt) {
      throw invalidError;
    }
    if (user.resetCodeExpiresAt < new Date()) {
      throw invalidError;
    }
    if (user.resetCodeHash !== hashResetCode(body.code)) {
      throw invalidError;
    }

    const passwordHash = await bcrypt.hash(body.newPassword, 10);
    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        resetCodeHash: null,
        resetCodeExpiresAt: null,
      },
    });

    // Reset invalidates any active sessions for safety.
    await prisma.refreshToken.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

router.post('/refresh', async (req, res, next) => {
  try {
    const body = refreshSchema.parse(req.body);
    const rotated = await rotateRefreshToken(body.refreshToken);
    if (!rotated) throw new HttpError(401, 'Invalid or expired refresh token');
    const user = await prisma.user.findUnique({ where: { id: rotated.userId } });
    if (!user) throw new HttpError(401, 'User no longer exists');
    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    res.json({ accessToken, refreshToken: rotated.newToken });
  } catch (err) {
    next(err);
  }
});

router.post('/logout', async (req, res, next) => {
  try {
    const body = refreshSchema.parse(req.body);
    await revokeRefreshToken(body.refreshToken);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.auth!.userId },
    });
    if (!user) throw new HttpError(404, 'User not found');
    res.json({ user: publicUser(user) });
  } catch (err) {
    next(err);
  }
});

export default router;

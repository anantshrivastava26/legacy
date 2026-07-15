import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { HttpError } from '../middleware/errors';
import { requireAuth } from '../middleware/auth';
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

function publicUser(user: { id: string; email: string; displayName: string }) {
  return { id: user.id, email: user.email, displayName: user.displayName };
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

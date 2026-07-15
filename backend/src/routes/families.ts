import { Router } from 'express';
import crypto from 'crypto';
import { z } from 'zod';
import { FamilyRole } from '@prisma/client';
import { prisma } from '../lib/prisma';
import { logActivity } from '../lib/activity';
import { HttpError } from '../middleware/errors';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router();
router.use(requireAuth);

function generateInviteCode(): string {
  // 8 chars, unambiguous (no 0/O/1/I)
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from(crypto.randomBytes(8))
    .map((b) => alphabet[b % alphabet.length])
    .join('');
}

const createFamilySchema = z.object({
  name: z.string().min(1).max(120),
  description: z.string().max(2000).optional(),
  photoUrl: z.string().url().optional(),
});

const updateFamilySchema = createFamilySchema.partial();

const joinSchema = z.object({ inviteCode: z.string().min(4).max(16) });

const roleSchema = z.object({
  role: z.enum(['ADMIN', 'CONTRIBUTOR', 'VIEWER']),
});

// List my families
router.get('/', async (req, res, next) => {
  try {
    const memberships = await prisma.familyMember.findMany({
      where: { userId: req.auth!.userId },
      include: {
        family: {
          include: { _count: { select: { persons: true, members: true } } },
        },
      },
      orderBy: { joinedAt: 'asc' },
    });
    res.json({
      families: memberships.map((m) => ({
        id: m.family.id,
        name: m.family.name,
        description: m.family.description,
        photoUrl: m.family.photoUrl,
        myRole: m.role,
        personCount: m.family._count.persons,
        memberCount: m.family._count.members,
      })),
    });
  } catch (err) {
    next(err);
  }
});

// Create family (creator becomes OWNER)
router.post('/', async (req, res, next) => {
  try {
    const body = createFamilySchema.parse(req.body);
    const family = await prisma.family.create({
      data: {
        ...body,
        inviteCode: generateInviteCode(),
        members: {
          create: { userId: req.auth!.userId, role: FamilyRole.OWNER },
        },
      },
    });
    await logActivity({
      familyId: family.id,
      userId: req.auth!.userId,
      action: 'FAMILY_CREATED',
      summary: `Family "${family.name}" was created`,
    });
    res.status(201).json({ family });
  } catch (err) {
    next(err);
  }
});

// Join family via invite code
router.post('/join', async (req, res, next) => {
  try {
    const body = joinSchema.parse(req.body);
    const family = await prisma.family.findUnique({
      where: { inviteCode: body.inviteCode.toUpperCase() },
    });
    if (!family) throw new HttpError(404, 'Invalid invite code');
    const existing = await prisma.familyMember.findUnique({
      where: {
        familyId_userId: { familyId: family.id, userId: req.auth!.userId },
      },
    });
    if (existing) throw new HttpError(409, 'You are already a member of this family');
    await prisma.familyMember.create({
      data: {
        familyId: family.id,
        userId: req.auth!.userId,
        role: FamilyRole.CONTRIBUTOR,
      },
    });
    const user = await prisma.user.findUnique({
      where: { id: req.auth!.userId },
    });
    await logActivity({
      familyId: family.id,
      userId: req.auth!.userId,
      action: 'MEMBER_JOINED',
      summary: `${user?.displayName ?? 'Someone'} joined the family`,
    });
    res.status(201).json({ family });
  } catch (err) {
    next(err);
  }
});

// Family detail
router.get('/:familyId', requireRole('VIEWER'), async (req, res, next) => {
  try {
    const family = await prisma.family.findUnique({
      where: { id: req.params.familyId },
      include: { _count: { select: { persons: true, members: true } } },
    });
    if (!family) throw new HttpError(404, 'Family not found');
    const showCode =
      req.membership!.role === 'OWNER' || req.membership!.role === 'ADMIN';
    res.json({
      family: {
        id: family.id,
        name: family.name,
        description: family.description,
        photoUrl: family.photoUrl,
        inviteCode: showCode ? family.inviteCode : undefined,
        myRole: req.membership!.role,
        personCount: family._count.persons,
        memberCount: family._count.members,
      },
    });
  } catch (err) {
    next(err);
  }
});

// Update family
router.patch('/:familyId', requireRole('ADMIN'), async (req, res, next) => {
  try {
    const body = updateFamilySchema.parse(req.body);
    const family = await prisma.family.update({
      where: { id: req.params.familyId },
      data: body,
    });
    await logActivity({
      familyId: family.id,
      userId: req.auth!.userId,
      action: 'FAMILY_UPDATED',
      summary: `Family details were updated`,
    });
    res.json({ family });
  } catch (err) {
    next(err);
  }
});

// Delete family (owner only) - confirmation happens client-side
router.delete('/:familyId', requireRole('OWNER'), async (req, res, next) => {
  try {
    await prisma.family.delete({ where: { id: req.params.familyId } });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

// Regenerate invite code
router.post(
  '/:familyId/regenerate-code',
  requireRole('ADMIN'),
  async (req, res, next) => {
    try {
      const family = await prisma.family.update({
        where: { id: req.params.familyId },
        data: { inviteCode: generateInviteCode() },
      });
      res.json({ inviteCode: family.inviteCode });
    } catch (err) {
      next(err);
    }
  }
);

// List members
router.get('/:familyId/members', requireRole('VIEWER'), async (req, res, next) => {
  try {
    const members = await prisma.familyMember.findMany({
      where: { familyId: req.params.familyId },
      include: { user: { select: { id: true, displayName: true, email: true } } },
      orderBy: { joinedAt: 'asc' },
    });
    res.json({
      members: members.map((m) => ({
        userId: m.user.id,
        displayName: m.user.displayName,
        email: m.user.email,
        role: m.role,
        joinedAt: m.joinedAt,
      })),
    });
  } catch (err) {
    next(err);
  }
});

// Change a member's role (owner manages admins; cannot change owner)
router.patch(
  '/:familyId/members/:userId',
  requireRole('OWNER'),
  async (req, res, next) => {
    try {
      const body = roleSchema.parse(req.body);
      const target = await prisma.familyMember.findUnique({
        where: {
          familyId_userId: {
            familyId: req.params.familyId,
            userId: req.params.userId,
          },
        },
        include: { user: { select: { displayName: true } } },
      });
      if (!target) throw new HttpError(404, 'Member not found');
      if (target.role === 'OWNER') {
        throw new HttpError(400, 'The owner role cannot be changed');
      }
      const updated = await prisma.familyMember.update({
        where: { id: target.id },
        data: { role: body.role },
      });
      await logActivity({
        familyId: req.params.familyId,
        userId: req.auth!.userId,
        action: 'MEMBER_ROLE_CHANGED',
        summary: `${target.user.displayName}'s role changed to ${body.role}`,
      });
      res.json({ member: { userId: req.params.userId, role: updated.role } });
    } catch (err) {
      next(err);
    }
  }
);

// Remove a member (admin can remove; cannot remove owner)
router.delete(
  '/:familyId/members/:userId',
  requireRole('ADMIN'),
  async (req, res, next) => {
    try {
      const target = await prisma.familyMember.findUnique({
        where: {
          familyId_userId: {
            familyId: req.params.familyId,
            userId: req.params.userId,
          },
        },
        include: { user: { select: { displayName: true } } },
      });
      if (!target) throw new HttpError(404, 'Member not found');
      if (target.role === 'OWNER') {
        throw new HttpError(400, 'The owner cannot be removed');
      }
      await prisma.familyMember.delete({ where: { id: target.id } });
      await logActivity({
        familyId: req.params.familyId,
        userId: req.auth!.userId,
        action: 'MEMBER_REMOVED',
        summary: `${target.user.displayName} was removed from the family`,
      });
      res.json({ ok: true });
    } catch (err) {
      next(err);
    }
  }
);

// Activity feed
router.get('/:familyId/activity', requireRole('VIEWER'), async (req, res, next) => {
  try {
    const activities = await prisma.activityLog.findMany({
      where: { familyId: req.params.familyId },
      include: { user: { select: { displayName: true } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json({
      activities: activities.map((a) => ({
        id: a.id,
        action: a.action,
        summary: a.summary,
        by: a.user?.displayName ?? null,
        at: a.createdAt,
      })),
    });
  } catch (err) {
    next(err);
  }
});

export default router;

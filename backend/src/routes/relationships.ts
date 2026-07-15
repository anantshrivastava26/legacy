import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { logActivity } from '../lib/activity';
import { validateRelationship } from '../lib/integrity';
import { HttpError } from '../middleware/errors';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router({ mergeParams: true });
router.use(requireAuth);

const createSchema = z.object({
  type: z.enum(['PARENT', 'ADOPTED_PARENT', 'FOSTER_PARENT', 'SPOUSE']),
  fromPersonId: z.string().uuid(),
  toPersonId: z.string().uuid(),
});

const TYPE_LABEL: Record<string, string> = {
  PARENT: 'parent of',
  ADOPTED_PARENT: 'adoptive parent of',
  FOSTER_PARENT: 'foster parent of',
  SPOUSE: 'married to',
};

// List all relationships in family
router.get('/', requireRole('VIEWER'), async (req, res, next) => {
  try {
    const relationships = await prisma.relationship.findMany({
      where: { familyId: req.params.familyId },
    });
    res.json({ relationships });
  } catch (err) {
    next(err);
  }
});

// Create relationship
router.post('/', requireRole('CONTRIBUTOR'), async (req, res, next) => {
  try {
    const body = createSchema.parse(req.body);
    await validateRelationship({ familyId: req.params.familyId, ...body });
    const relationship = await prisma.relationship.create({
      data: {
        ...body,
        familyId: req.params.familyId,
        createdById: req.auth!.userId,
      },
      include: {
        fromPerson: { select: { firstName: true, lastName: true } },
        toPerson: { select: { firstName: true, lastName: true } },
      },
    });
    await logActivity({
      familyId: req.params.familyId,
      userId: req.auth!.userId,
      action: 'RELATIONSHIP_ADDED',
      summary: `${relationship.fromPerson.firstName} ${relationship.fromPerson.lastName} is now ${TYPE_LABEL[body.type]} ${relationship.toPerson.firstName} ${relationship.toPerson.lastName}`,
      meta: { relationshipId: relationship.id },
    });
    res.status(201).json({ relationship });
  } catch (err) {
    next(err);
  }
});

// Remove relationship
router.delete('/:relationshipId', requireRole('ADMIN'), async (req, res, next) => {
  try {
    const existing = await prisma.relationship.findFirst({
      where: { id: req.params.relationshipId, familyId: req.params.familyId },
      include: {
        fromPerson: { select: { firstName: true, lastName: true } },
        toPerson: { select: { firstName: true, lastName: true } },
      },
    });
    if (!existing) throw new HttpError(404, 'Relationship not found');
    await prisma.relationship.delete({ where: { id: existing.id } });
    await logActivity({
      familyId: req.params.familyId,
      userId: req.auth!.userId,
      action: 'RELATIONSHIP_REMOVED',
      summary: `Relationship between ${existing.fromPerson.firstName} and ${existing.toPerson.firstName} was removed`,
    });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

export default router;

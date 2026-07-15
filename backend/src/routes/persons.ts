import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { logActivity } from '../lib/activity';
import { findPossibleDuplicate } from '../lib/integrity';
import { HttpError } from '../middleware/errors';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router({ mergeParams: true });
router.use(requireAuth);

const dateString = z
  .string()
  .refine((s) => !Number.isNaN(Date.parse(s)), 'Invalid date')
  .transform((s) => new Date(s));

const personSchema = z.object({
  firstName: z.string().min(1).max(100),
  lastName: z.string().min(1).max(100),
  middleName: z.string().max(100).optional().nullable(),
  nickname: z.string().max(100).optional().nullable(),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER', 'UNKNOWN']).default('UNKNOWN'),
  dateOfBirth: dateString.optional().nullable(),
  dateOfDeath: dateString.optional().nullable(),
  isLiving: z.boolean().default(true),
  profilePhotoUrl: z.string().url().optional().nullable(),
  birthPlace: z.string().max(200).optional().nullable(),
  currentLocation: z.string().max(200).optional().nullable(),
  occupation: z.string().max(200).optional().nullable(),
  education: z.string().max(200).optional().nullable(),
  biography: z.string().max(10000).optional().nullable(),
  phone: z.string().max(30).optional().nullable(),
  email: z.string().email().optional().nullable(),
  anniversary: dateString.optional().nullable(),
  religion: z.string().max(100).optional().nullable(),
  bloodGroup: z.string().max(10).optional().nullable(),
});

const updatePersonSchema = personSchema.partial();

function assertSaneDates(data: {
  dateOfBirth?: Date | null;
  dateOfDeath?: Date | null;
}) {
  const now = new Date();
  if (data.dateOfBirth && data.dateOfBirth > now) {
    throw new HttpError(400, 'Birth date cannot be in the future');
  }
  if (data.dateOfDeath && data.dateOfDeath > now) {
    throw new HttpError(400, 'Date of death cannot be in the future');
  }
  if (
    data.dateOfBirth &&
    data.dateOfDeath &&
    data.dateOfDeath < data.dateOfBirth
  ) {
    throw new HttpError(400, 'Date of death cannot be before birth date');
  }
}

// List / search persons
router.get('/', requireRole('VIEWER'), async (req, res, next) => {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const persons = await prisma.person.findMany({
      where: {
        familyId: req.params.familyId,
        deletedAt: null,
        ...(q
          ? {
              OR: [
                { firstName: { contains: q, mode: 'insensitive' } },
                { lastName: { contains: q, mode: 'insensitive' } },
                { nickname: { contains: q, mode: 'insensitive' } },
                { currentLocation: { contains: q, mode: 'insensitive' } },
                { birthPlace: { contains: q, mode: 'insensitive' } },
                { occupation: { contains: q, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
    });
    res.json({ persons });
  } catch (err) {
    next(err);
  }
});

// Add person (pass ?force=true to skip duplicate warning)
router.post('/', requireRole('CONTRIBUTOR'), async (req, res, next) => {
  try {
    const body = personSchema.parse(req.body);
    assertSaneDates(body);

    if (req.query.force !== 'true') {
      const duplicate = await findPossibleDuplicate({
        familyId: req.params.familyId,
        firstName: body.firstName,
        lastName: body.lastName,
        dateOfBirth: body.dateOfBirth,
      });
      if (duplicate) {
        return res.status(409).json({
          error: 'A person with the same name may already exist',
          possibleDuplicate: duplicate,
          hint: 'Retry with ?force=true to add anyway',
        });
      }
    }

    const person = await prisma.person.create({
      data: {
        ...body,
        familyId: req.params.familyId,
        createdById: req.auth!.userId,
        updatedById: req.auth!.userId,
      },
    });
    const user = await prisma.user.findUnique({ where: { id: req.auth!.userId } });
    await logActivity({
      familyId: req.params.familyId,
      userId: req.auth!.userId,
      action: 'PERSON_ADDED',
      summary: `${person.firstName} ${person.lastName} added by ${user?.displayName ?? 'someone'}`,
      meta: { personId: person.id },
    });
    res.status(201).json({ person });
  } catch (err) {
    next(err);
  }
});

// Person detail (includes relationships + derived siblings)
router.get('/:personId', requireRole('VIEWER'), async (req, res, next) => {
  try {
    const person = await prisma.person.findFirst({
      where: {
        id: req.params.personId,
        familyId: req.params.familyId,
        deletedAt: null,
      },
      include: {
        relationshipsFrom: { include: { toPerson: true } },
        relationshipsTo: { include: { fromPerson: true } },
      },
    });
    if (!person) throw new HttpError(404, 'Person not found');

    const parentTypes = ['PARENT', 'ADOPTED_PARENT', 'FOSTER_PARENT'];
    const parents = person.relationshipsTo
      .filter((r) => parentTypes.includes(r.type))
      .map((r) => ({ relationshipId: r.id, type: r.type, person: r.fromPerson }));
    const children = person.relationshipsFrom
      .filter((r) => parentTypes.includes(r.type))
      .map((r) => ({ relationshipId: r.id, type: r.type, person: r.toPerson }));
    const spouses = [
      ...person.relationshipsFrom
        .filter((r) => r.type === 'SPOUSE')
        .map((r) => ({ relationshipId: r.id, type: r.type, person: r.toPerson })),
      ...person.relationshipsTo
        .filter((r) => r.type === 'SPOUSE')
        .map((r) => ({ relationshipId: r.id, type: r.type, person: r.fromPerson })),
    ];

    // Derived siblings: other children of this person's parents
    const parentIds = parents.map((p) => p.person.id);
    let siblings: { id: string; firstName: string; lastName: string }[] = [];
    if (parentIds.length > 0) {
      const siblingRels = await prisma.relationship.findMany({
        where: {
          familyId: req.params.familyId,
          type: { in: ['PARENT', 'ADOPTED_PARENT'] },
          fromPersonId: { in: parentIds },
          toPersonId: { not: person.id },
        },
        include: {
          toPerson: { select: { id: true, firstName: true, lastName: true, deletedAt: true } },
        },
      });
      const seen = new Set<string>();
      for (const r of siblingRels) {
        if (r.toPerson.deletedAt) continue;
        if (!seen.has(r.toPerson.id)) {
          seen.add(r.toPerson.id);
          siblings.push({
            id: r.toPerson.id,
            firstName: r.toPerson.firstName,
            lastName: r.toPerson.lastName,
          });
        }
      }
    }

    const { relationshipsFrom, relationshipsTo, ...personData } = person;
    res.json({ person: personData, parents, children, spouses, siblings });
  } catch (err) {
    next(err);
  }
});

// Update person (auto-save friendly: accepts partial updates)
router.patch('/:personId', requireRole('CONTRIBUTOR'), async (req, res, next) => {
  try {
    const body = updatePersonSchema.parse(req.body);
    const existing = await prisma.person.findFirst({
      where: {
        id: req.params.personId,
        familyId: req.params.familyId,
        deletedAt: null,
      },
    });
    if (!existing) throw new HttpError(404, 'Person not found');
    assertSaneDates({
      dateOfBirth: body.dateOfBirth ?? existing.dateOfBirth,
      dateOfDeath: body.dateOfDeath ?? existing.dateOfDeath,
    });
    const person = await prisma.person.update({
      where: { id: existing.id },
      data: { ...body, updatedById: req.auth!.userId },
    });
    const user = await prisma.user.findUnique({ where: { id: req.auth!.userId } });
    await logActivity({
      familyId: req.params.familyId,
      userId: req.auth!.userId,
      action: 'PERSON_UPDATED',
      summary: `${person.firstName} ${person.lastName} updated by ${user?.displayName ?? 'someone'}`,
      meta: { personId: person.id, fields: Object.keys(body) },
    });
    res.json({ person });
  } catch (err) {
    next(err);
  }
});

// Soft delete (undo-able)
router.delete('/:personId', requireRole('ADMIN'), async (req, res, next) => {
  try {
    const existing = await prisma.person.findFirst({
      where: {
        id: req.params.personId,
        familyId: req.params.familyId,
        deletedAt: null,
      },
    });
    if (!existing) throw new HttpError(404, 'Person not found');
    await prisma.person.update({
      where: { id: existing.id },
      data: { deletedAt: new Date() },
    });
    await logActivity({
      familyId: req.params.familyId,
      userId: req.auth!.userId,
      action: 'PERSON_DELETED',
      summary: `${existing.firstName} ${existing.lastName} was deleted`,
      meta: { personId: existing.id },
    });
    res.json({ ok: true, undoHint: `POST /persons/${existing.id}/restore` });
  } catch (err) {
    next(err);
  }
});

// Undo delete
router.post(
  '/:personId/restore',
  requireRole('CONTRIBUTOR'),
  async (req, res, next) => {
    try {
      const existing = await prisma.person.findFirst({
        where: {
          id: req.params.personId,
          familyId: req.params.familyId,
          deletedAt: { not: null },
        },
      });
      if (!existing) throw new HttpError(404, 'Deleted person not found');
      const person = await prisma.person.update({
        where: { id: existing.id },
        data: { deletedAt: null },
      });
      await logActivity({
        familyId: req.params.familyId,
        userId: req.auth!.userId,
        action: 'PERSON_RESTORED',
        summary: `${person.firstName} ${person.lastName} was restored`,
        meta: { personId: person.id },
      });
      res.json({ person });
    } catch (err) {
      next(err);
    }
  }
);

export default router;

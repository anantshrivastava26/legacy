import { RelationshipType } from '@prisma/client';
import { prisma } from './prisma';
import { HttpError } from '../middleware/errors';

const PARENT_TYPES: RelationshipType[] = [
  'PARENT',
  'ADOPTED_PARENT',
  'FOSTER_PARENT',
];

/**
 * Returns the set of all ancestor person ids of `personId` within a family.
 */
async function collectAncestors(
  familyId: string,
  personId: string
): Promise<Set<string>> {
  const rels = await prisma.relationship.findMany({
    where: { familyId, type: { in: PARENT_TYPES } },
    select: { fromPersonId: true, toPersonId: true },
  });
  const parentsOf = new Map<string, string[]>();
  for (const r of rels) {
    const list = parentsOf.get(r.toPersonId) ?? [];
    list.push(r.fromPersonId);
    parentsOf.set(r.toPersonId, list);
  }
  const ancestors = new Set<string>();
  const queue = [...(parentsOf.get(personId) ?? [])];
  while (queue.length > 0) {
    const current = queue.pop()!;
    if (ancestors.has(current)) continue;
    ancestors.add(current);
    queue.push(...(parentsOf.get(current) ?? []));
  }
  return ancestors;
}

/**
 * Validates a new relationship before it is created.
 * Throws HttpError with a friendly message when the relationship is invalid.
 */
export async function validateRelationship(params: {
  familyId: string;
  type: RelationshipType;
  fromPersonId: string;
  toPersonId: string;
}): Promise<void> {
  const { familyId, type, fromPersonId, toPersonId } = params;

  if (fromPersonId === toPersonId) {
    throw new HttpError(400, 'A person cannot be related to themselves');
  }

  const [fromPerson, toPerson] = await Promise.all([
    prisma.person.findFirst({
      where: { id: fromPersonId, familyId, deletedAt: null },
    }),
    prisma.person.findFirst({
      where: { id: toPersonId, familyId, deletedAt: null },
    }),
  ]);
  if (!fromPerson || !toPerson) {
    throw new HttpError(404, 'One or both persons were not found in this family');
  }

  // No duplicate (any direction for spouse)
  const duplicate = await prisma.relationship.findFirst({
    where: {
      familyId,
      type,
      OR: [
        { fromPersonId, toPersonId },
        ...(type === 'SPOUSE'
          ? [{ fromPersonId: toPersonId, toPersonId: fromPersonId }]
          : []),
      ],
    },
  });
  if (duplicate) {
    throw new HttpError(409, 'This relationship already exists');
  }

  if (PARENT_TYPES.includes(type)) {
    // Parent must be born before the child (when both dates are known)
    if (
      fromPerson.dateOfBirth &&
      toPerson.dateOfBirth &&
      fromPerson.dateOfBirth >= toPerson.dateOfBirth
    ) {
      throw new HttpError(
        400,
        'A parent cannot be younger than (or the same age as) their child'
      );
    }

    // Circular ancestry: the child must not already be an ancestor of the parent
    const ancestorsOfParent = await collectAncestors(familyId, fromPersonId);
    if (ancestorsOfParent.has(toPersonId)) {
      throw new HttpError(
        400,
        'This would create an impossible loop in the family tree'
      );
    }

    // At most 2 biological parents
    if (type === 'PARENT') {
      const parentCount = await prisma.relationship.count({
        where: { familyId, type: 'PARENT', toPersonId },
      });
      if (parentCount >= 2) {
        throw new HttpError(
          400,
          'This person already has two biological parents'
        );
      }
    }
  }
}

/**
 * Simple duplicate-person heuristic: same first+last name and same
 * birth year (or both missing DOB).
 */
export async function findPossibleDuplicate(params: {
  familyId: string;
  firstName: string;
  lastName: string;
  dateOfBirth?: Date | null;
}): Promise<{ id: string; firstName: string; lastName: string } | null> {
  const candidates = await prisma.person.findMany({
    where: {
      familyId: params.familyId,
      deletedAt: null,
      firstName: { equals: params.firstName, mode: 'insensitive' },
      lastName: { equals: params.lastName, mode: 'insensitive' },
    },
    select: { id: true, firstName: true, lastName: true, dateOfBirth: true },
  });
  for (const c of candidates) {
    const sameYear =
      params.dateOfBirth && c.dateOfBirth
        ? params.dateOfBirth.getUTCFullYear() === c.dateOfBirth.getUTCFullYear()
        : !params.dateOfBirth && !c.dateOfBirth;
    if (sameYear) return c;
  }
  return null;
}

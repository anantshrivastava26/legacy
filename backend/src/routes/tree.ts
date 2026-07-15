import { Router } from 'express';
import { prisma } from '../lib/prisma';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router({ mergeParams: true });
router.use(requireAuth);

/**
 * Returns the whole tree as nodes + edges, with a generation number per
 * person so clients can lay out the tree easily.
 * Generation 0 = people with no known parents (roots); children are +1, etc.
 */
router.get('/', requireRole('VIEWER'), async (req, res, next) => {
  try {
    const familyId = req.params.familyId;
    const [persons, relationships] = await Promise.all([
      prisma.person.findMany({
        where: { familyId, deletedAt: null },
        select: {
          id: true,
          firstName: true,
          lastName: true,
          nickname: true,
          gender: true,
          dateOfBirth: true,
          dateOfDeath: true,
          isLiving: true,
          profilePhotoUrl: true,
        },
      }),
      prisma.relationship.findMany({
        where: { familyId },
        select: { id: true, type: true, fromPersonId: true, toPersonId: true },
      }),
    ]);

    const alive = new Set(persons.map((p) => p.id));
    const validRels = relationships.filter(
      (r) => alive.has(r.fromPersonId) && alive.has(r.toPersonId)
    );

    const parentTypes = new Set(['PARENT', 'ADOPTED_PARENT', 'FOSTER_PARENT']);
    const childrenOf = new Map<string, string[]>();
    const parentCount = new Map<string, number>();
    for (const r of validRels) {
      if (!parentTypes.has(r.type)) continue;
      const list = childrenOf.get(r.fromPersonId) ?? [];
      list.push(r.toPersonId);
      childrenOf.set(r.fromPersonId, list);
      parentCount.set(r.toPersonId, (parentCount.get(r.toPersonId) ?? 0) + 1);
    }

    // BFS from roots to assign generations
    const generation = new Map<string, number>();
    const queue: string[] = [];
    for (const p of persons) {
      if (!parentCount.get(p.id)) {
        generation.set(p.id, 0);
        queue.push(p.id);
      }
    }
    while (queue.length > 0) {
      const current = queue.shift()!;
      const gen = generation.get(current)!;
      for (const child of childrenOf.get(current) ?? []) {
        const existing = generation.get(child);
        const candidate = gen + 1;
        if (existing === undefined || candidate > existing) {
          generation.set(child, candidate);
          queue.push(child);
        }
      }
    }

    // Spouses share the max generation of the pair
    for (const r of validRels) {
      if (r.type !== 'SPOUSE') continue;
      const a = generation.get(r.fromPersonId) ?? 0;
      const b = generation.get(r.toPersonId) ?? 0;
      const g = Math.max(a, b);
      generation.set(r.fromPersonId, g);
      generation.set(r.toPersonId, g);
    }

    res.json({
      nodes: persons.map((p) => ({
        ...p,
        generation: generation.get(p.id) ?? 0,
      })),
      edges: validRels,
    });
  } catch (err) {
    next(err);
  }
});

export default router;

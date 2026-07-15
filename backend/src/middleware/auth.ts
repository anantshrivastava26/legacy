import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { FamilyRole } from '@prisma/client';
import { config } from '../config';
import { prisma } from '../lib/prisma';
import { HttpError } from './errors';

export interface AuthPayload {
  userId: string;
  email: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      auth?: AuthPayload;
      membership?: { role: FamilyRole; familyId: string };
    }
  }
}

export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next(new HttpError(401, 'Missing access token'));
  }
  try {
    const payload = jwt.verify(
      header.slice(7),
      config.jwtAccessSecret
    ) as AuthPayload;
    req.auth = { userId: payload.userId, email: payload.email };
    next();
  } catch {
    next(new HttpError(401, 'Invalid or expired access token'));
  }
}

const ROLE_RANK: Record<FamilyRole, number> = {
  VIEWER: 0,
  CONTRIBUTOR: 1,
  ADMIN: 2,
  OWNER: 3,
};

/**
 * Loads the caller's membership for req.params.familyId and enforces a
 * minimum role. Attaches membership to the request.
 */
export function requireRole(minRole: FamilyRole) {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const familyId = req.params.familyId;
      if (!req.auth) throw new HttpError(401, 'Not authenticated');
      const membership = await prisma.familyMember.findUnique({
        where: {
          familyId_userId: { familyId, userId: req.auth.userId },
        },
      });
      if (!membership) {
        throw new HttpError(403, 'You are not a member of this family');
      }
      if (ROLE_RANK[membership.role] < ROLE_RANK[minRole]) {
        throw new HttpError(403, 'You do not have permission for this action');
      }
      req.membership = { role: membership.role, familyId };
      next();
    } catch (err) {
      next(err);
    }
  };
}

import { ActivityAction, Prisma } from '@prisma/client';
import { prisma } from './prisma';

export async function logActivity(params: {
  familyId: string;
  userId?: string;
  action: ActivityAction;
  summary: string;
  meta?: Prisma.InputJsonValue;
}): Promise<void> {
  await prisma.activityLog.create({
    data: {
      familyId: params.familyId,
      userId: params.userId,
      action: params.action,
      summary: params.summary,
      meta: params.meta,
    },
  });
}

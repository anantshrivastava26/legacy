-- AlterTable
ALTER TABLE "users" ADD COLUMN     "resetCodeHash" TEXT,
ADD COLUMN     "resetCodeExpiresAt" TIMESTAMP(3);

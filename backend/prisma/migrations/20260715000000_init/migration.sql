-- CreateEnum
CREATE TYPE "FamilyRole" AS ENUM ('OWNER', 'ADMIN', 'CONTRIBUTOR', 'VIEWER');

-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('MALE', 'FEMALE', 'OTHER', 'UNKNOWN');

-- CreateEnum
CREATE TYPE "RelationshipType" AS ENUM ('PARENT', 'ADOPTED_PARENT', 'FOSTER_PARENT', 'SPOUSE');

-- CreateEnum
CREATE TYPE "ActivityAction" AS ENUM ('FAMILY_CREATED', 'FAMILY_UPDATED', 'MEMBER_JOINED', 'MEMBER_ROLE_CHANGED', 'MEMBER_REMOVED', 'PERSON_ADDED', 'PERSON_UPDATED', 'PERSON_DELETED', 'PERSON_RESTORED', 'RELATIONSHIP_ADDED', 'RELATIONSHIP_REMOVED');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "families" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "photoUrl" TEXT,
    "inviteCode" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "families_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_members" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "FamilyRole" NOT NULL DEFAULT 'CONTRIBUTOR',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "family_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "persons" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "middleName" TEXT,
    "nickname" TEXT,
    "gender" "Gender" NOT NULL DEFAULT 'UNKNOWN',
    "dateOfBirth" TIMESTAMP(3),
    "dateOfDeath" TIMESTAMP(3),
    "isLiving" BOOLEAN NOT NULL DEFAULT true,
    "profilePhotoUrl" TEXT,
    "birthPlace" TEXT,
    "currentLocation" TEXT,
    "occupation" TEXT,
    "education" TEXT,
    "biography" TEXT,
    "phone" TEXT,
    "email" TEXT,
    "anniversary" TIMESTAMP(3),
    "religion" TEXT,
    "bloodGroup" TEXT,
    "createdById" TEXT,
    "updatedById" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "persons_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "relationships" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "type" "RelationshipType" NOT NULL,
    "fromPersonId" TEXT NOT NULL,
    "toPersonId" TEXT NOT NULL,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "relationships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "activity_logs" (
    "id" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "userId" TEXT,
    "action" "ActivityAction" NOT NULL,
    "summary" TEXT NOT NULL,
    "meta" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_tokenHash_key" ON "refresh_tokens"("tokenHash");

-- CreateIndex
CREATE INDEX "refresh_tokens_userId_idx" ON "refresh_tokens"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "families_inviteCode_key" ON "families"("inviteCode");

-- CreateIndex
CREATE INDEX "family_members_userId_idx" ON "family_members"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "family_members_familyId_userId_key" ON "family_members"("familyId", "userId");

-- CreateIndex
CREATE INDEX "persons_familyId_idx" ON "persons"("familyId");

-- CreateIndex
CREATE INDEX "persons_familyId_lastName_firstName_idx" ON "persons"("familyId", "lastName", "firstName");

-- CreateIndex
CREATE INDEX "relationships_familyId_idx" ON "relationships"("familyId");

-- CreateIndex
CREATE UNIQUE INDEX "relationships_familyId_type_fromPersonId_toPersonId_key" ON "relationships"("familyId", "type", "fromPersonId", "toPersonId");

-- CreateIndex
CREATE INDEX "activity_logs_familyId_createdAt_idx" ON "activity_logs"("familyId", "createdAt");

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "persons" ADD CONSTRAINT "persons_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "relationships" ADD CONSTRAINT "relationships_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "relationships" ADD CONSTRAINT "relationships_fromPersonId_fkey" FOREIGN KEY ("fromPersonId") REFERENCES "persons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "relationships" ADD CONSTRAINT "relationships_toPersonId_fkey" FOREIGN KEY ("toPersonId") REFERENCES "persons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "activity_logs" ADD CONSTRAINT "activity_logs_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "activity_logs" ADD CONSTRAINT "activity_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

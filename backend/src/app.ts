import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { config } from './config';
import { errorHandler, notFound } from './middleware/errors';
import authRoutes from './routes/auth';
import familyRoutes from './routes/families';
import personRoutes from './routes/persons';
import relationshipRoutes from './routes/relationships';
import treeRoutes from './routes/tree';

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors({ origin: config.corsOrigin }));
  app.use(express.json({ limit: '2mb' }));

  app.get('/health', (_req, res) => res.json({ ok: true }));

  app.use('/api/auth', authRoutes);
  app.use('/api/families', familyRoutes);
  app.use('/api/families/:familyId/persons', personRoutes);
  app.use('/api/families/:familyId/relationships', relationshipRoutes);
  app.use('/api/families/:familyId/tree', treeRoutes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

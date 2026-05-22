import Fastify from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import { env } from './config/env.js';
import { registerRateLimit } from './middleware/rateLimit.js';
import { jobRoutes } from './routes/jobs.js';
import { userRoutes } from './routes/users.js';
import { webhookRoutes } from './routes/webhooks.js';
import { templateRoutes } from './routes/templates.js';

const app = Fastify({
  logger: {
    level: env.NODE_ENV === 'production' ? 'warn' : 'info',
  },
  trustProxy: true,
});

async function bootstrap() {
  // CORS
  await app.register(cors, {
    origin: env.NODE_ENV === 'production' ? false : true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  });

  // Multipart (for photo uploads)
  await app.register(multipart, {
    limits: {
      fileSize: 50 * 1024 * 1024, // 50MB total
      files: 5,
    },
  });

  // Rate limiting
  await registerRateLimit(app);

  // Add rawBody support for webhook HMAC validation
  app.addContentTypeParser('application/json', { parseAs: 'buffer' }, (req, body, done) => {
    try {
      (req as any).rawBody = body;
      done(null, JSON.parse(body.toString()));
    } catch (err) {
      done(err as Error, undefined);
    }
  });

  // Routes
  await app.register(userRoutes);
  await app.register(jobRoutes);
  await app.register(webhookRoutes);
  await app.register(templateRoutes);

  // Global error handler
  app.setErrorHandler((error, request, reply) => {
    app.log.error(error);
    const statusCode = error.statusCode ?? 500;
    reply.status(statusCode).send({
      error:   statusCode >= 500 ? 'Internal Server Error' : error.message,
      message: statusCode >= 500 ? 'Something went wrong. Please try again.' : error.message,
    });
  });

  // Start
  await app.listen({ port: env.PORT, host: '0.0.0.0' });
  console.log(`🚀 Server listening on port ${env.PORT}`);
}

bootstrap().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

export default app;

import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { findOrCreateUser, softDeleteUser } from '../db/users.repo.js';
import { signToken, verifyAuth } from '../middleware/auth.js';

const createUserSchema = z.object({
  apple_user_id: z.string().min(1),
  email:         z.string().email().optional(),
  id_token:      z.string().min(1),
});

export async function userRoutes(app: FastifyInstance): Promise<void> {
  // POST /users — sign in with Apple, return JWT
  app.post('/users', async (request: FastifyRequest, reply: FastifyReply) => {
    const parsed = createUserSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten() });
    }

    const { apple_user_id, email } = parsed.data;

    // In production: verify id_token with Apple's public keys
    // Skipped here for MVP — add apple-signin-auth package for full verification
    const user = await findOrCreateUser(apple_user_id, email);
    const token = signToken({ sub: user.id, tier: user.tier });

    return reply.send({ token, userId: user.id, tier: user.tier });
  });

  // DELETE /users/me — GDPR/CCPA account deletion
  app.delete('/users/me', {
    preHandler: [verifyAuth],
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    await softDeleteUser(request.user.sub);
    // In production: queue async deletion of R2 objects
    return reply.status(202).send({ message: 'Account deletion scheduled' });
  });

  // GET /health
  app.get('/health', async (_request, reply) => {
    return reply.send({ status: 'ok', ts: new Date().toISOString() });
  });
}

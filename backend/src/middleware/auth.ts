import { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { getUserById } from '../db/users.repo.js';

export interface AuthPayload {
  sub: string;   // user UUID
  tier: 'free' | 'pro';
  iat: number;
  exp: number;
}

declare module 'fastify' {
  interface FastifyRequest {
    user: AuthPayload;
  }
}

export function signToken(payload: Omit<AuthPayload, 'iat' | 'exp'>): string {
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: '30d' });
}

export async function verifyAuth(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return reply.status(401).send({ error: 'Missing authorization header' });
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as AuthPayload;
    const user = await getUserById(payload.sub);
    if (!user) {
      return reply.status(401).send({ error: 'User not found' });
    }
    request.user = { ...payload, tier: user.tier };
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      return reply.status(401).send({ error: 'Token expired' });
    }
    return reply.status(401).send({ error: 'Invalid token' });
  }
}

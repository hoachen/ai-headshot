import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { verifyAuth } from '../middleware/auth.js';
import { supabase } from '../db/client.js';

export async function templateRoutes(app: FastifyInstance): Promise<void> {
  app.get('/templates', {
    preHandler: [verifyAuth],
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    const user = request.user;

    const { data, error } = await supabase
      .from('templates')
      .select()
      .eq('active', true)
      .order('sort_order', { ascending: true });

    if (error) {
      return reply.status(500).send({ error: 'Failed to fetch templates' });
    }

    const templates = user.tier === 'pro'
      ? data
      : data?.filter(t => t.tier_required === 'free');

    return reply.send({ templates });
  });
}

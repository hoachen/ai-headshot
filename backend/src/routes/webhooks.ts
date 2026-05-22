import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import crypto from 'crypto';
import { env } from '../config/env.js';
import { setUserTier, upsertSubscription, getSubscriptionByRcCustomerId } from '../db/users.repo.js';
import { sendBillingIssue } from '../services/apns.service.js';

interface RCWebhookBody {
  event: {
    type: string;
    app_user_id: string;
    product_id: string;
    period_type: string;
    purchased_at_ms: number;
    expiration_at_ms: number;
    trial_end_at_ms?: number;
    is_trial_conversion?: boolean;
  };
}

const RC_PLAN_MAP: Record<string, 'monthly' | 'annual'> = {
  'com.aiheadshot.pro.monthly': 'monthly',
  'com.aiheadshot.pro.annual':  'annual',
};

export async function webhookRoutes(app: FastifyInstance): Promise<void> {
  app.post('/webhooks/revenuecat', {
    config: { rawBody: true },
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    // Validate HMAC signature
    const signature = request.headers['x-revenuecat-signature'] as string;
    if (!signature) {
      return reply.status(401).send({ error: 'Missing signature' });
    }

    const rawBody = (request as any).rawBody as Buffer;
    if (!rawBody) {
      return reply.status(400).send({ error: 'Missing raw body' });
    }

    const expected = crypto
      .createHmac('sha256', env.REVENUECAT_WEBHOOK_SECRET)
      .update(rawBody)
      .digest('hex');

    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
      return reply.status(401).send({ error: 'Invalid signature' });
    }

    const body = request.body as RCWebhookBody;
    const event = body?.event;
    if (!event) return reply.status(400).send({ error: 'Invalid event' });

    const rcCustomerId = event.app_user_id;
    const plan: 'monthly' | 'annual' = RC_PLAN_MAP[event.product_id] ?? 'monthly';
    const periodEnd = new Date(event.expiration_at_ms).toISOString();
    const trialEnd  = event.trial_end_at_ms
      ? new Date(event.trial_end_at_ms).toISOString()
      : undefined;

    // Look up internal user ID from subscription table
    const existing = await getSubscriptionByRcCustomerId(rcCustomerId);
    const userId = existing?.user_id;

    switch (event.type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL': {
        if (!userId) break;
        await setUserTier(userId, 'pro');
        await upsertSubscription({
          userId,
          rcCustomerId,
          plan,
          status: 'active',
          currentPeriodEnd: periodEnd,
          trialEnd,
        });
        break;
      }

      case 'CANCELLATION': {
        if (!userId) break;
        // Keep tier as pro until period ends; downgrade handled by a cron or renewal check
        await upsertSubscription({
          userId,
          rcCustomerId,
          plan,
          status: 'cancelled',
          currentPeriodEnd: periodEnd,
          trialEnd,
        });
        break;
      }

      case 'EXPIRATION': {
        if (!userId) break;
        await setUserTier(userId, 'free');
        await upsertSubscription({
          userId,
          rcCustomerId,
          plan,
          status: 'cancelled',
          currentPeriodEnd: periodEnd,
        });
        break;
      }

      case 'BILLING_ISSUE': {
        if (!userId) break;
        await upsertSubscription({
          userId,
          rcCustomerId,
          plan,
          status: 'past_due',
          currentPeriodEnd: periodEnd,
        });
        await sendBillingIssue(userId);
        break;
      }

      default:
        console.log(`Unhandled RevenueCat event: ${event.type}`);
    }

    return reply.status(200).send({ received: true });
  });
}

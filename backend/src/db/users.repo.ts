import { supabase, type Database } from './client.js';

type User = Database['users'];
type Subscription = Database['subscriptions'];

export async function findOrCreateUser(appleUserId: string, email?: string): Promise<User> {
  const { data: existing } = await supabase
    .from('users')
    .select()
    .eq('apple_user_id', appleUserId)
    .is('deleted_at', null)
    .single();

  if (existing) return existing;

  const { data, error } = await supabase
    .from('users')
    .insert({ apple_user_id: appleUserId, email: email ?? null })
    .select()
    .single();

  if (error) throw new Error(`findOrCreateUser: ${error.message}`);
  return data;
}

export async function getUserById(id: string): Promise<User | null> {
  const { data } = await supabase
    .from('users')
    .select()
    .eq('id', id)
    .is('deleted_at', null)
    .single();
  return data;
}

export async function getUserByAppleId(appleUserId: string): Promise<User | null> {
  const { data } = await supabase
    .from('users')
    .select()
    .eq('apple_user_id', appleUserId)
    .is('deleted_at', null)
    .single();
  return data;
}

export async function setUserTier(userId: string, tier: 'free' | 'pro'): Promise<void> {
  const { error } = await supabase
    .from('users')
    .update({ tier })
    .eq('id', userId);

  if (error) throw new Error(`setUserTier: ${error.message}`);
}

export async function softDeleteUser(userId: string): Promise<void> {
  const { error } = await supabase
    .from('users')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', userId);

  if (error) throw new Error(`softDeleteUser: ${error.message}`);
}

export async function upsertSubscription(data: {
  userId: string;
  rcCustomerId: string;
  plan: 'monthly' | 'annual';
  status: 'active' | 'cancelled' | 'past_due' | 'trial';
  currentPeriodEnd: string;
  trialEnd?: string;
}): Promise<void> {
  const { error } = await supabase
    .from('subscriptions')
    .upsert(
      {
        user_id:            data.userId,
        rc_customer_id:     data.rcCustomerId,
        plan:               data.plan,
        status:             data.status,
        current_period_end: data.currentPeriodEnd,
        trial_end:          data.trialEnd ?? null,
      },
      { onConflict: 'user_id' }
    );

  if (error) throw new Error(`upsertSubscription: ${error.message}`);
}

export async function getSubscriptionByRcCustomerId(rcCustomerId: string): Promise<Subscription | null> {
  const { data } = await supabase
    .from('subscriptions')
    .select()
    .eq('rc_customer_id', rcCustomerId)
    .single();
  return data;
}

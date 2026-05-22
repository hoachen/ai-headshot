import { supabase, JobStatus, type Database } from './client.js';

type Job = Database['jobs'];

export async function createJob(data: {
  userId: string;
  tier: 'free' | 'pro';
  industry: string;
  style: string;
}): Promise<Job> {
  const { data: job, error } = await supabase
    .from('jobs')
    .insert({
      user_id:  data.userId,
      tier:     data.tier,
      industry: data.industry,
      style:    data.style,
      status:   'PENDING',
    })
    .select()
    .single();

  if (error) throw new Error(`createJob: ${error.message}`);
  return job;
}

export async function getJob(id: string): Promise<Job | null> {
  const { data, error } = await supabase
    .from('jobs')
    .select()
    .eq('id', id)
    .single();

  if (error) return null;
  return data;
}

export async function getJobForUser(id: string, userId: string): Promise<Job | null> {
  const { data, error } = await supabase
    .from('jobs')
    .select()
    .eq('id', id)
    .eq('user_id', userId)
    .single();

  if (error) return null;
  return data;
}

export async function listUserJobs(userId: string, limit = 20): Promise<Job[]> {
  const { data, error } = await supabase
    .from('jobs')
    .select()
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw new Error(`listUserJobs: ${error.message}`);
  return data ?? [];
}

export async function updateJobStatus(
  id: string,
  status: JobStatus,
  extra?: Partial<Pick<Job, 'error_code' | 'result_urls' | 'completed_at' | 'photos_deleted_at'>>
): Promise<void> {
  const update: Record<string, unknown> = { status };
  if (extra) Object.assign(update, extra);

  const { error } = await supabase
    .from('jobs')
    .update(update)
    .eq('id', id);

  if (error) throw new Error(`updateJobStatus: ${error.message}`);
}

export async function markPhotosDeleted(id: string): Promise<void> {
  await updateJobStatus(id, 'DONE', {
    photos_deleted_at: new Date().toISOString(),
  });
}

export async function deleteJobPhotos(id: string, userId: string): Promise<boolean> {
  const job = await getJobForUser(id, userId);
  if (!job) return false;

  await markPhotosDeleted(id);
  return true;
}

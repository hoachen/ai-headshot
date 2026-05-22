import axios from 'axios';
import { env } from '../config/env.js';

const ONESIGNAL_API = 'https://onesignal.com/api/v1/notifications';

interface PushPayload {
  externalUserId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendPushNotification(payload: PushPayload): Promise<void> {
  try {
    await axios.post(
      ONESIGNAL_API,
      {
        app_id: env.ONESIGNAL_APP_ID,
        include_external_user_ids: [payload.externalUserId],
        channel_for_external_user_ids: 'push',
        headings: { en: payload.title },
        contents: { en: payload.body },
        data: payload.data ?? {},
        ios_sound: 'default',
        priority: 10,
      },
      {
        headers: {
          Authorization: `Basic ${env.ONESIGNAL_API_KEY}`,
          'Content-Type': 'application/json',
        },
        timeout: 10_000,
      }
    );
  } catch (err) {
    console.error('Push notification failed:', (err as Error).message);
    // Non-fatal — don't throw
  }
}

export async function sendGenerationComplete(userId: string, jobId: string): Promise<void> {
  await sendPushNotification({
    externalUserId: userId,
    title: '✨ Your headshots are ready!',
    body: 'Your professional headshots are ready to download.',
    data: { jobId, screen: 'results' },
  });
}

export async function sendBillingIssue(userId: string): Promise<void> {
  await sendPushNotification({
    externalUserId: userId,
    title: 'Payment issue detected',
    body: 'Please update your payment method to keep your Pro subscription.',
    data: { screen: 'settings' },
  });
}

export async function sendReengagement(userId: string): Promise<void> {
  await sendPushNotification({
    externalUserId: userId,
    title: 'Update your LinkedIn photo 📸',
    body: 'New styles are available. Generate fresh headshots today!',
    data: { screen: 'home' },
  });
}

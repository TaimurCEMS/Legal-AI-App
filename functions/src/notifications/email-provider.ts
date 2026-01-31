/**
 * P2 Email provider abstraction – interface + SendGrid (fetch) + NoOp
 * Config: env vars → Firebase config → Google Secret Manager (sendgrid-api-key, sendgrid-from-email)
 */

import * as functions from 'firebase-functions';
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

export interface EmailSendParams {
  to: string;
  subject: string;
  html: string;
  text?: string | null;
  idempotencyKey?: string | null;
}

export interface EmailSendResult {
  ok: boolean;
  error?: string;
}

/** No-op: log and return success (dev / no API key). */
export async function sendEmailNoOp(params: EmailSendParams): Promise<EmailSendResult> {
  functions.logger.info('Email (no-op)', {
    to: params.to,
    subject: params.subject,
    idempotencyKey: params.idempotencyKey ?? undefined,
  });
  return { ok: true };
}

let secretManagerCache: { apiKey: string; fromEmail: string } | null = null;

/**
 * Resolve SendGrid config: 1) env vars 2) Firebase config 3) Secret Manager (sendgrid-api-key, sendgrid-from-email).
 * Secret Manager: create secrets in Google Cloud Console → Security → Secret Manager, then deploy.
 */
async function getSendGridConfig(): Promise<{ apiKey: string; fromEmail: string }> {
  const config = functions.config();
  const apiKey =
    process.env.SENDGRID_API_KEY?.trim() ||
    (typeof config.sendgrid?.api_key === 'string' ? config.sendgrid.api_key : '');
  const fromEmail =
    process.env.SENDGRID_FROM_EMAIL?.trim() ||
    (typeof config.sendgrid?.from_email === 'string' ? config.sendgrid.from_email : '') ||
    '';

  if (apiKey && fromEmail) {
    return { apiKey, fromEmail: fromEmail || 'noreply@example.com' };
  }

  if (secretManagerCache) {
    return secretManagerCache;
  }

  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  if (projectId) {
    try {
      const client = new SecretManagerServiceClient();
      const tasks: Promise<string>[] = [];
      if (!apiKey) {
        tasks.push(
          client
            .accessSecretVersion({
              name: `projects/${projectId}/secrets/sendgrid-api-key/versions/latest`,
            })
            .then(([v]) => (v?.payload?.data ? v.payload.data.toString() : ''))
        );
      } else {
        tasks.push(Promise.resolve(apiKey));
      }
      if (!fromEmail) {
        tasks.push(
          client
            .accessSecretVersion({
              name: `projects/${projectId}/secrets/sendgrid-from-email/versions/latest`,
            })
            .then(([v]) => (v?.payload?.data ? v.payload.data.toString() : ''))
        );
      } else {
        tasks.push(Promise.resolve(fromEmail));
      }
      const [resolvedApiKey, resolvedFromEmail] = await Promise.all(tasks);
      const finalApiKey = apiKey || (resolvedApiKey ?? '');
      const finalFromEmail =
        (fromEmail || resolvedFromEmail || '').trim() || 'Legal AI App <noreply@example.com>';
      if (finalApiKey) {
        secretManagerCache = { apiKey: finalApiKey, fromEmail: finalFromEmail };
        return secretManagerCache;
      }
    } catch (e) {
      functions.logger.debug('SendGrid Secret Manager not available', {
        error: (e as Error).message,
      });
    }
  }

  return { apiKey: apiKey || '', fromEmail: fromEmail || 'noreply@example.com' };
}

/** SendGrid v3 API via fetch. Requires api key and from email (env, config, or Secret Manager). */
export async function sendEmailSendGrid(params: EmailSendParams): Promise<EmailSendResult> {
  const { apiKey, fromEmail: fromStr } = await getSendGridConfig();

  if (!apiKey || apiKey.trim() === '') {
    functions.logger.warn('SendGrid API key not set; skipping send');
    return sendEmailNoOp(params);
  }

  const fromEmail = fromStr.includes('<') ? fromStr.split('<')[1].replace('>', '').trim() : fromStr;
  const fromName = fromStr.includes('<') ? fromStr.split('<')[0].trim() : 'Legal AI';

  const body = {
    personalizations: [{ to: [{ email: params.to }] }],
    from: { email: fromEmail, name: fromName },
    subject: params.subject,
    content: [
      { type: 'text/html', value: params.html },
      ...(params.text ? [{ type: 'text/plain', value: params.text }] : []),
    ],
    ...(params.idempotencyKey
      ? { headers: { 'X-Message-Id': params.idempotencyKey } }
      : {}),
  };

  try {
    const res = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (res.ok) {
      return { ok: true };
    }
    const text = await res.text();
    functions.logger.warn('SendGrid non-OK', { status: res.status, body: text });
    return { ok: false, error: `SendGrid ${res.status}: ${text.slice(0, 200)}` };
  } catch (e) {
    const err = (e as Error).message ?? 'Unknown';
    functions.logger.error('SendGrid request failed', { error: err });
    return { ok: false, error: err };
  }
}

/** Current provider: SendGrid if key set (env, config, or Secret Manager), else NoOp. */
export async function sendEmail(params: EmailSendParams): Promise<EmailSendResult> {
  const { apiKey } = await getSendGridConfig();
  if (apiKey?.trim()) {
    return sendEmailSendGrid(params);
  }
  return sendEmailNoOp(params);
}

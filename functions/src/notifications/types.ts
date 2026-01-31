/**
 * P2 Notification Engine – types and constants
 */

import type * as admin from 'firebase-admin';
type Timestamp = admin.firestore.Timestamp;

export type NotificationChannel = 'in_app' | 'email';
export type NotificationStatus = 'pending' | 'sent' | 'failed' | 'suppressed' | 'read';

export type NotificationCategory =
  | 'matter'
  | 'task'
  | 'document'
  | 'invoice'
  | 'payment'
  | 'comment'
  | 'user'
  | 'client';

export interface NotificationRecord {
  id: string;
  orgId: string;
  recipientUid: string;
  eventId: string;
  channel: NotificationChannel;
  status: NotificationStatus;
  category: NotificationCategory;
  title: string;
  bodyPreview: string;
  deepLink: string;
  templateId?: string | null;
  templateVersion?: number | null;
  readAt?: Timestamp | null;
  sentAt?: Timestamp | null;
  errorMessage?: string | null;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface NotificationPreference {
  orgId: string;
  uid: string;
  category: NotificationCategory;
  inApp: boolean;
  email: boolean;
  updatedAt: Timestamp;
}

export type SuppressionReason = 'bounce' | 'complaint' | 'manual';

export interface SuppressionRecord {
  orgId: string;
  email: string;
  reason: SuppressionReason;
  provider?: string | null;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface NotificationTemplateVersion {
  version: number;
  subject: string;
  html: string;
  text?: string | null;
  variables: string[];
  updatedAt: Timestamp;
}

export interface NotificationTemplateDoc {
  id: string;
  orgId: string;
  eventType: string;
  versions: NotificationTemplateVersion[];
  updatedAt: Timestamp;
}

/** Event types we route to notifications (P1 set + comment later) */
export const ROUTED_EVENT_TYPES = [
  'user.invited',
  'user.joined',
  'matter.created',
  'matter.updated',
  'task.created',
  'task.updated',
  'task.assigned',
  'task.completed',
  'document.uploaded',
  'invoice.created',
  'invoice.sent',
  'payment.received',
  'client.created',
  'comment.added',
  'comment.updated',
  'comment.deleted',
] as const;

export type RoutedEventType = (typeof ROUTED_EVENT_TYPES)[number];

/** Map eventType -> category for preferences */
export function eventTypeToCategory(eventType: string): NotificationCategory {
  if (eventType.startsWith('matter.')) return 'matter';
  if (eventType.startsWith('task.')) return 'task';
  if (eventType.startsWith('document.')) return 'document';
  if (eventType.startsWith('invoice.') || eventType.startsWith('payment.')) return 'invoice';
  if (eventType.startsWith('comment.')) return 'comment';
  if (eventType.startsWith('user.')) return 'user';
  if (eventType.startsWith('client.')) return 'client';
  return 'matter';
}

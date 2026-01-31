/**
 * P2 Notification deep link builder (Flutter route paths).
 * Pure function, no Firebase – safe to unit test.
 */

/** Build deep link path for the entity (must match Flutter route_names and app_router). */
export function buildDeepLink(
  _orgId: string,
  _eventType: string,
  entityType: string,
  entityId: string,
  matterId?: string | null
): string {
  if (entityType === 'comment' && matterId) {
    return `/cases/details?caseId=${matterId}`;
  }
  if (entityType === 'case' || entityType === 'matter') {
    return `/cases/details?caseId=${entityId}`;
  }
  if (entityType === 'task') {
    const q = matterId ? `&caseId=${matterId}` : '';
    return `/tasks/details?taskId=${entityId}${q}`;
  }
  if (entityType === 'document') {
    return `/documents/details/${entityId}`;
  }
  if (entityType === 'client') {
    return `/clients/details?clientId=${entityId}`;
  }
  if (entityType === 'invoice') {
    return '/home';
  }
  return '/home';
}

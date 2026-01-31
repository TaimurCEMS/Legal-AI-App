/**
 * P2 Firestore trigger: on domain_events onCreate run notification routing
 */

import * as functions from 'firebase-functions';
import { runNotificationRouting } from '../notifications/routing';

export const onDomainEventCreated = functions.firestore
  .document('domain_events/{eventId}')
  .onCreate(async (snapshot) => {
    await runNotificationRouting(snapshot);
  });

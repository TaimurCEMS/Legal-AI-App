/**
 * Entitlement Check Helper
 * Performs plan + role + org membership validation
 */

import * as admin from 'firebase-admin';
import { PLAN_FEATURES, PlanTier } from '../constants/entitlements';
import { ROLE_PERMISSIONS, Role } from '../constants/permissions';

const db = admin.firestore();

export interface EntitlementCheckParams {
  uid: string;
  orgId: string;
  requiredFeature?: string;
  requiredPermission?: string;
  objectOrgId?: string;
}

export interface EntitlementCheckResult {
  allowed: boolean;
  reason?: 'ORG_MEMBER' | 'PLAN_LIMIT' | 'ROLE_BLOCKED' | 'ORG_MISMATCH' | 'ORG_REQUIRED';
  plan?: PlanTier;
  role?: Role;
}

/**
 * Check if user is entitled to perform an action
 * @param params - Entitlement check parameters
 * @returns Entitlement check result
 */
export async function checkEntitlement(
  params: EntitlementCheckParams
): Promise<EntitlementCheckResult> {
  const { uid, orgId, requiredFeature, requiredPermission, objectOrgId } = params;

  // 1. Org membership check
  if (!orgId) {
    return { allowed: false, reason: 'ORG_REQUIRED' };
  }

  const memberDoc = await db
    .collection('organizations')
    .doc(orgId)
    .collection('members')
    .doc(uid)
    .get();

  if (!memberDoc.exists) {
    return { allowed: false, reason: 'ORG_MEMBER' };
  }

  const memberData = memberDoc.data()!;
  const role = (memberData.role || 'VIEWER') as Role;

  // Validate role is valid
  if (!ROLE_PERMISSIONS[role]) {
    // Default to VIEWER if invalid role
    const validRole: Role = 'VIEWER';
    return { allowed: false, reason: 'ROLE_BLOCKED', role: validRole };
  }

  // 2. Get org plan
  const orgDoc = await db.collection('organizations').doc(orgId).get();
  if (!orgDoc.exists) {
    return { allowed: false, reason: 'ORG_MEMBER' };
  }

  const plan = (orgDoc.data()!.plan || 'FREE') as PlanTier;

  // Validate plan is valid
  if (!PLAN_FEATURES[plan]) {
    const validPlan: PlanTier = 'FREE';
    return { allowed: false, reason: 'PLAN_LIMIT', plan: validPlan, role };
  }

  // 3. Plan feature check
  if (requiredFeature && !PLAN_FEATURES[plan][requiredFeature as keyof typeof PLAN_FEATURES[typeof plan]]) {
    return { allowed: false, reason: 'PLAN_LIMIT', plan, role };
  }

  // 4. Role permission check
  if (requiredPermission && !ROLE_PERMISSIONS[role][requiredPermission as keyof typeof ROLE_PERMISSIONS[typeof role]]) {
    return { allowed: false, reason: 'ROLE_BLOCKED', plan, role };
  }

  // 5. Org scoping check
  if (objectOrgId && objectOrgId !== orgId) {
    return { allowed: false, reason: 'ORG_MISMATCH' };
  }

  return { allowed: true, plan, role };
}

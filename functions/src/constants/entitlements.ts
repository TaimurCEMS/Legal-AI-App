/**
 * Plan Features Matrix
 * Must match Master Spec Section 4.7 (Entitlements Matrix)
 */

export const PLAN_FEATURES = {
  FREE: {
    CASES: true,
    CLIENTS: true,
    DOCUMENTS: true,
    TEAM_MEMBERS: true, // Enabled for multi-user testing (Slice 2.5)
    TASKS: true, // Enabled for MVP (like TEAM_MEMBERS for Slice 2.5)
    CALENDAR: true, // Enabled for MVP testing (Slice 7)
    NOTES: true, // Enabled for MVP testing (Slice 8)
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: true, // Enabled for testing (Slice 6a)
    AI_RESEARCH: true, // Enabled for testing (Slice 6b)
    AI_DRAFTING: false,
    CONTRACT_ANALYSIS: true, // Enabled for testing (Slice 13)
    DOCUMENT_SUMMARY: true, // Enabled for testing (Slice 14)
    TIME_TRACKING: false,
    EXPORTS: false,
    AUDIT_TRAIL: false,
    NOTIFICATIONS: false,
    ADVANCED_SEARCH: false,
    BILLING_SUBSCRIPTION: true,
    BILLING_INVOICING: false,
    ADMIN_PANEL: false,
  },
  BASIC: {
    CASES: true,
    CLIENTS: true,
    DOCUMENTS: true,
    TEAM_MEMBERS: true,
    TASKS: true,
    CALENDAR: true,
    NOTES: true,
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: true,
    AI_RESEARCH: true,
    AI_DRAFTING: false,
    CONTRACT_ANALYSIS: true,
    DOCUMENT_SUMMARY: true,
    TIME_TRACKING: true,
    EXPORTS: true,
    AUDIT_TRAIL: false,
    NOTIFICATIONS: true,
    ADVANCED_SEARCH: false,
    BILLING_SUBSCRIPTION: true,
    BILLING_INVOICING: true,
    ADMIN_PANEL: true,
  },
  PRO: {
    CASES: true,
    CLIENTS: true,
    DOCUMENTS: true,
    TEAM_MEMBERS: true,
    TASKS: true,
    CALENDAR: true,
    NOTES: true,
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: true,
    AI_RESEARCH: true,
    AI_DRAFTING: true,
    CONTRACT_ANALYSIS: true,
    DOCUMENT_SUMMARY: true,
    TIME_TRACKING: true,
    EXPORTS: true,
    AUDIT_TRAIL: true,
    NOTIFICATIONS: true,
    ADVANCED_SEARCH: true,
    BILLING_SUBSCRIPTION: true,
    BILLING_INVOICING: true,
    ADMIN_PANEL: true,
  },
  ENTERPRISE: {
    CASES: true,
    CLIENTS: true,
    DOCUMENTS: true,
    TEAM_MEMBERS: true,
    TASKS: true,
    CALENDAR: true,
    NOTES: true,
    DOCUMENT_UPLOAD: true,
    OCR_EXTRACTION: true,
    AI_RESEARCH: true,
    AI_DRAFTING: true,
    CONTRACT_ANALYSIS: true,
    DOCUMENT_SUMMARY: true,
    TIME_TRACKING: true,
    EXPORTS: true,
    AUDIT_TRAIL: true,
    NOTIFICATIONS: true,
    ADVANCED_SEARCH: true,
    BILLING_SUBSCRIPTION: true,
    BILLING_INVOICING: true,
    ADMIN_PANEL: true,
  },
} as const;

export type PlanTier = keyof typeof PLAN_FEATURES;
export type FeatureKey = keyof typeof PLAN_FEATURES['FREE'];

/**
 * Error Codes and Messages
 * Must match Master Spec Section 8.3 (Error Response Format)
 */

export enum ErrorCode {
  ORG_REQUIRED = 'ORG_REQUIRED',
  NOT_AUTHORIZED = 'NOT_AUTHORIZED',
  PLAN_LIMIT = 'PLAN_LIMIT',
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  NOT_FOUND = 'NOT_FOUND',
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  RATE_LIMITED = 'RATE_LIMITED',
  CONFLICT = 'CONFLICT',
  SAFETY_ERROR = 'SAFETY_ERROR',
  INVALID_STATUS_TRANSITION = 'INVALID_STATUS_TRANSITION',
  INVALID_DUE_DATE = 'INVALID_DUE_DATE',
  ASSIGNEE_NOT_MEMBER = 'ASSIGNEE_NOT_MEMBER',
  ASSIGNEE_NOT_CASE_PARTICIPANT = 'ASSIGNEE_NOT_CASE_PARTICIPANT',
}

export const ERROR_MESSAGES: Record<ErrorCode, string> = {
  [ErrorCode.ORG_REQUIRED]: 'Organization ID is required to perform this action',
  [ErrorCode.NOT_AUTHORIZED]: 'You do not have permission to perform this action',
  [ErrorCode.PLAN_LIMIT]: 'This feature requires a higher plan. Upgrade to continue.',
  [ErrorCode.VALIDATION_ERROR]: 'Invalid input provided',
  [ErrorCode.NOT_FOUND]: 'Resource not found',
  [ErrorCode.INTERNAL_ERROR]: 'An internal error occurred',
  [ErrorCode.RATE_LIMITED]: 'Too many requests. Please try again later.',
  [ErrorCode.CONFLICT]: 'Operation conflicts with existing data',
  [ErrorCode.SAFETY_ERROR]: 'Safety check failed',
  [ErrorCode.INVALID_STATUS_TRANSITION]: 'Invalid status transition',
  [ErrorCode.INVALID_DUE_DATE]: 'Due date must be today or in the future',
  [ErrorCode.ASSIGNEE_NOT_MEMBER]: 'Assignee must be a member of the organization',
  [ErrorCode.ASSIGNEE_NOT_CASE_PARTICIPANT]:
    'Assignee must be the case creator or a case participant',
};

export function getErrorMessage(code: ErrorCode, customMessage?: string): string {
  return customMessage || ERROR_MESSAGES[code];
}

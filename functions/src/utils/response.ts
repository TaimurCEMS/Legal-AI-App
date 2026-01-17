/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Response Wrapper Utilities
 * Consistent success/error response format per Master Spec Section 8.3
 */

import { ErrorCode, getErrorMessage } from '../constants/errors';

export interface SuccessResponse<T = any> {
  success: true;
  data: T;
}

export interface ErrorResponse {
  success: false;
  error: {
    code: ErrorCode;
    message: string;
    details?: any;
  };
}

export type ApiResponse<T = any> = SuccessResponse<T> | ErrorResponse;

/**
 * Create a success response
 */
export function successResponse<T>(data: T): SuccessResponse<T> {
  return {
    success: true,
    data,
  };
}

/**
 * Create an error response
 */
export function errorResponse(
  code: ErrorCode,
  customMessage?: string,
  details?: any
): ErrorResponse {
  return {
    success: false,
    error: {
      code,
      message: getErrorMessage(code, customMessage),
      ...(details && { details }),
    },
  };
}

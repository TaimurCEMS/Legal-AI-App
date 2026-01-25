/**
 * Text Extraction Service (Slice 6a - Document Text Extraction)
 * 
 * Provides text extraction capabilities for various document types:
 * - PDF: Using pdf-parse library
 * - DOCX: Using mammoth library
 * - TXT/RTF: Direct text reading
 */

import * as functions from 'firebase-functions';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const pdfParse = require('pdf-parse');
import * as mammoth from 'mammoth';

// Maximum text length to store (500KB of text)
const MAX_TEXT_LENGTH = 500000;

// Supported file types for extraction
const EXTRACTABLE_TYPES = ['pdf', 'docx', 'txt', 'rtf'];

export interface ExtractionResult {
  success: boolean;
  text?: string;
  pageCount?: number;
  wordCount?: number;
  error?: string;
  truncated?: boolean;
}

/**
 * Check if a file type is supported for extraction
 */
export function isExtractable(fileType: string): boolean {
  return EXTRACTABLE_TYPES.includes(fileType.toLowerCase());
}

/**
 * Get list of supported file types
 */
export function getSupportedTypes(): string[] {
  return [...EXTRACTABLE_TYPES];
}

/**
 * Count words in text
 */
function countWords(text: string): number {
  if (!text || text.trim().length === 0) return 0;
  // Split on whitespace and filter out empty strings
  return text.trim().split(/\s+/).filter(word => word.length > 0).length;
}

/**
 * Truncate text if it exceeds maximum length
 */
function truncateText(text: string): { text: string; truncated: boolean } {
  if (text.length <= MAX_TEXT_LENGTH) {
    return { text, truncated: false };
  }
  return {
    text: text.substring(0, MAX_TEXT_LENGTH),
    truncated: true,
  };
}

/**
 * Extract text from PDF buffer
 */
async function extractFromPdf(buffer: Buffer): Promise<ExtractionResult> {
  try {
    const data = await pdfParse(buffer);
    
    const { text, truncated } = truncateText(data.text || '');
    const wordCount = countWords(text);
    const pageCount = data.numpages || undefined;
    
    return {
      success: true,
      text,
      pageCount,
      wordCount,
      truncated,
    };
  } catch (error) {
    functions.logger.error('PDF extraction error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to extract text from PDF',
    };
  }
}

/**
 * Extract text from DOCX buffer
 */
async function extractFromDocx(buffer: Buffer): Promise<ExtractionResult> {
  try {
    const result = await mammoth.extractRawText({ buffer });
    
    const { text, truncated } = truncateText(result.value || '');
    const wordCount = countWords(text);
    
    // DOCX doesn't have a direct page count, estimate based on ~500 words per page
    const estimatedPageCount = Math.max(1, Math.ceil(wordCount / 500));
    
    return {
      success: true,
      text,
      pageCount: estimatedPageCount,
      wordCount,
      truncated,
    };
  } catch (error) {
    functions.logger.error('DOCX extraction error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to extract text from DOCX',
    };
  }
}

/**
 * Extract text from plain text buffer (TXT, RTF basic)
 */
function extractFromText(buffer: Buffer): ExtractionResult {
  try {
    // Try UTF-8 first, fall back to latin1
    let rawText: string;
    try {
      rawText = buffer.toString('utf-8');
    } catch {
      rawText = buffer.toString('latin1');
    }
    
    // For RTF, try to strip RTF control codes (basic cleanup)
    // Full RTF parsing would require a dedicated library
    let cleanText = rawText;
    if (rawText.startsWith('{\\rtf')) {
      // Basic RTF cleanup - remove control words and groups
      cleanText = rawText
        .replace(/\{\\[^{}]*\}/g, '') // Remove control groups
        .replace(/\\[a-z]+\d* ?/gi, '') // Remove control words
        .replace(/[{}]/g, '') // Remove remaining braces
        .replace(/\r\n/g, '\n') // Normalize line endings
        .trim();
    }
    
    const { text, truncated } = truncateText(cleanText);
    const wordCount = countWords(text);
    
    // Estimate page count based on ~3000 characters per page
    const estimatedPageCount = Math.max(1, Math.ceil(text.length / 3000));
    
    return {
      success: true,
      text,
      pageCount: estimatedPageCount,
      wordCount,
      truncated,
    };
  } catch (error) {
    functions.logger.error('Text extraction error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to extract text from file',
    };
  }
}

/**
 * Main extraction function - routes to appropriate extractor based on file type
 */
export async function extractText(
  buffer: Buffer,
  fileType: string
): Promise<ExtractionResult> {
  const type = fileType.toLowerCase();
  
  if (!isExtractable(type)) {
    return {
      success: false,
      error: `Unsupported file type: ${fileType}. Supported types: ${EXTRACTABLE_TYPES.join(', ')}`,
    };
  }
  
  functions.logger.info(`Extracting text from ${type} file (${buffer.length} bytes)`);
  
  switch (type) {
    case 'pdf':
      return extractFromPdf(buffer);
    
    case 'docx':
      return extractFromDocx(buffer);
    
    case 'txt':
    case 'rtf':
      return extractFromText(buffer);
    
    default:
      return {
        success: false,
        error: `Unsupported file type: ${fileType}`,
      };
  }
}

/**
 * Extract text with timeout protection
 */
export async function extractTextWithTimeout(
  buffer: Buffer,
  fileType: string,
  timeoutMs: number = 60000
): Promise<ExtractionResult> {
  return Promise.race([
    extractText(buffer, fileType),
    new Promise<ExtractionResult>((_, reject) => 
      setTimeout(() => reject(new Error('Extraction timed out')), timeoutMs)
    ),
  ]).catch((error) => ({
    success: false,
    error: error instanceof Error ? error.message : 'Extraction failed',
  }));
}

/**
 * AI Service (Slice 6b - AI Chat/Research)
 * 
 * Provides OpenAI integration for legal research chat.
 * Builds context from case documents and manages chat completions.
 */

import * as functions from 'firebase-functions';
import OpenAI from 'openai';

// Initialize OpenAI client
// The API key is stored in Firebase config: openai.key  
let openaiClient: OpenAI | null = null;

function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    // Try environment variable first (for secrets), then fall back to config
    const apiKey = process.env.OPENAI_API_KEY || functions.config().openai?.key;
    if (!apiKey) {
      throw new Error('OpenAI API key is not configured. Set OPENAI_API_KEY or openai.key config.');
    }
    openaiClient = new OpenAI({ apiKey });
  }
  return openaiClient;
}

// Types
export interface DocumentInfo {
  documentId: string;
  name: string;
  extractedText?: string | null;
  pageCount?: number | null;
}

export interface Citation {
  documentId: string;
  documentName: string;
  excerpt: string;
  pageNumber?: number;
}

export interface ChatCompletionResult {
  content: string;
  tokensUsed: number;
  model: string;
  processingTimeMs: number;
}

// System prompt for legal research assistant
const BASE_SYSTEM_PROMPT = `You are an expert legal AI assistant helping lawyers and legal professionals. You have comprehensive knowledge of legal principles, procedures, and practices across multiple jurisdictions.

YOUR CAPABILITIES:
1. **Document Analysis**: Analyze provided case documents, extract key information, and cite sources
2. **Legal Research**: Provide legal research, case law references, and statutory analysis
3. **Legal Opinions**: Offer preliminary legal opinions and analysis based on the facts provided
4. **Practice Guidance**: Suggest legal strategies, procedural requirements, and best practices
5. **Drafting Assistance**: Help with legal document structure and language

IMPORTANT RULES:
1. When documents are provided, prioritize information from those documents and cite them explicitly
2. Clearly distinguish between:
   - Information from provided documents (cite the document name)
   - General legal principles and knowledge
   - Your analysis and opinions
3. Always note when legal advice should be verified with local counsel
4. Be precise and factual - this is for legal work
5. Highlight risks, potential issues, and considerations
6. When uncertain, acknowledge limitations and suggest further research

RESPONSE FORMAT:
- Structure responses clearly with headings when appropriate
- Use bullet points for lists of factors, elements, or considerations
- Cite document sources inline: (Source: [Document Name])
- Flag jurisdictional variations when relevant

Remember: Your responses will be reviewed by legal professionals. Accuracy and clarity are critical.`;

/**
 * Build jurisdiction-aware system prompt
 */
export function buildSystemPrompt(options?: {
  jurisdiction?: {
    country?: string;
    state?: string;
    region?: string;
  };
}): string {
  let prompt = BASE_SYSTEM_PROMPT;
  
  if (options?.jurisdiction) {
    const { country, state, region } = options.jurisdiction;
    const jurisdictionParts: string[] = [];
    
    if (state) jurisdictionParts.push(state);
    if (region) jurisdictionParts.push(region);
    if (country) jurisdictionParts.push(country);
    
    if (jurisdictionParts.length > 0) {
      const jurisdictionStr = jurisdictionParts.join(', ');
      prompt += `\n\nJURISDICTION CONTEXT:
The user is working within the jurisdiction of: ${jurisdictionStr}

When providing legal analysis:
- Prioritize laws, regulations, and procedures specific to ${jurisdictionStr}
- Note when federal/national law differs from local law
- Highlight any jurisdiction-specific requirements or deadlines
- Reference relevant courts and regulatory bodies for this jurisdiction
- Flag if a question may involve multiple jurisdictions`;
    }
  }
  
  return prompt;
}

// Maximum context length (characters) - roughly 100K tokens
const MAX_CONTEXT_CHARS = 400000;

// Maximum text per document (characters)
const MAX_DOC_CHARS = 50000;

/**
 * Build context string from case documents
 */
export function buildCaseContext(documents: DocumentInfo[]): {
  context: string;
  includedDocs: DocumentInfo[];
} {
  let context = '';
  const includedDocs: DocumentInfo[] = [];
  
  // Filter documents with extracted text
  const docsWithText = documents.filter(d => d.extractedText && d.extractedText.length > 0);
  
  if (docsWithText.length === 0) {
    return {
      context: '[No documents with extracted text available for this case]',
      includedDocs: [],
    };
  }
  
  for (const doc of docsWithText) {
    const docText = doc.extractedText!;
    
    // Truncate document if too long
    const truncatedText = docText.length > MAX_DOC_CHARS 
      ? docText.substring(0, MAX_DOC_CHARS) + '\n...[document truncated]'
      : docText;
    
    const docSection = `\n--- Document: ${doc.name} ---\n${truncatedText}\n--- End of ${doc.name} ---\n`;
    
    // Check if adding this document would exceed limit
    if (context.length + docSection.length > MAX_CONTEXT_CHARS) {
      // Try to add a truncated version
      const remaining = MAX_CONTEXT_CHARS - context.length - 200;
      if (remaining > 2000) {
        context += `\n--- Document: ${doc.name} ---\n${truncatedText.substring(0, remaining)}\n...[remaining content truncated]\n--- End of ${doc.name} ---\n`;
        includedDocs.push(doc);
      }
      break;
    }
    
    context += docSection;
    includedDocs.push(doc);
  }
  
  return { context, includedDocs };
}

/**
 * Send chat completion request to OpenAI
 */
export async function sendChatCompletion(
  messages: { role: 'user' | 'assistant' | 'system'; content: string }[],
  documentContext: string,
  options?: {
    model?: 'gpt-4o-mini' | 'gpt-4o';
    jurisdiction?: {
      country?: string;
      state?: string;
      region?: string;
    };
  }
): Promise<ChatCompletionResult> {
  const startTime = Date.now();
  const model = options?.model || 'gpt-4o-mini';
  
  const client = getOpenAIClient();
  
  // Build system prompt with jurisdiction context
  const systemPrompt = buildSystemPrompt({
    jurisdiction: options?.jurisdiction,
  });
  
  // Build document context section
  const documentSection = documentContext && documentContext !== '[No documents with extracted text available for this case]'
    ? `\n\nCASE DOCUMENTS:\n${documentContext}`
    : '\n\n[No case documents available. Responding based on general legal knowledge.]';
  
  // Build messages array with system prompt and context
  const fullMessages: OpenAI.Chat.ChatCompletionMessageParam[] = [
    {
      role: 'system',
      content: `${systemPrompt}${documentSection}`,
    },
    ...messages.map(m => ({
      role: m.role as 'user' | 'assistant' | 'system',
      content: m.content,
    })),
  ];
  
  try {
    const response = await client.chat.completions.create({
      model,
      messages: fullMessages,
      max_tokens: 4096,
      temperature: 0.3, // Lower temperature for more factual responses
    });
    
    const content = response.choices[0]?.message?.content || '';
    const tokensUsed = response.usage?.total_tokens || 0;
    const processingTimeMs = Date.now() - startTime;
    
    functions.logger.info(`OpenAI completion: ${tokensUsed} tokens, ${processingTimeMs}ms`, {
      model,
      tokensUsed,
      processingTimeMs,
    });
    
    return {
      content,
      tokensUsed,
      model,
      processingTimeMs,
    };
  } catch (error) {
    functions.logger.error('OpenAI API error:', error);
    
    if (error instanceof OpenAI.APIError) {
      if (error.status === 429) {
        throw new Error('AI service is temporarily overloaded. Please try again in a moment.');
      }
      if (error.status === 401) {
        throw new Error('AI service configuration error. Please contact support.');
      }
    }
    
    throw new Error('Failed to get AI response. Please try again.');
  }
}

/**
 * Extract citations from AI response by matching document names
 */
export function extractCitations(
  response: string,
  documents: DocumentInfo[]
): Citation[] {
  const citations: Citation[] = [];
  const addedDocIds = new Set<string>();
  
  for (const doc of documents) {
    // Skip if already added
    if (addedDocIds.has(doc.documentId)) continue;
    
    // Check if document is referenced in response
    const docNameLower = doc.name.toLowerCase();
    const responseLower = response.toLowerCase();
    
    if (responseLower.includes(docNameLower)) {
      // Find excerpt from the response that references this document
      const excerpt = findExcerpt(response, doc.name);
      
      citations.push({
        documentId: doc.documentId,
        documentName: doc.name,
        excerpt,
        // pageNumber could be added with page detection in future
      });
      
      addedDocIds.add(doc.documentId);
    }
  }
  
  return citations;
}

/**
 * Find an excerpt from the response that references the document
 */
function findExcerpt(response: string, documentName: string): string {
  const responseLower = response.toLowerCase();
  const docNameLower = documentName.toLowerCase();
  
  const index = responseLower.indexOf(docNameLower);
  if (index === -1) return '';
  
  // Get surrounding context (100 chars before and after)
  const start = Math.max(0, index - 100);
  const end = Math.min(response.length, index + documentName.length + 100);
  
  let excerpt = response.substring(start, end);
  
  // Clean up excerpt
  if (start > 0) excerpt = '...' + excerpt;
  if (end < response.length) excerpt = excerpt + '...';
  
  return excerpt.trim();
}

/**
 * Generate a title for a chat thread based on the first message
 */
export function generateThreadTitle(firstMessage: string): string {
  // Take first 50 chars or first sentence
  const cleaned = firstMessage.trim();
  
  // Find first sentence end
  const sentenceEnd = cleaned.search(/[.!?]/);
  if (sentenceEnd > 0 && sentenceEnd < 50) {
    return cleaned.substring(0, sentenceEnd + 1);
  }
  
  // Otherwise, take first 50 chars
  if (cleaned.length <= 50) return cleaned;
  return cleaned.substring(0, 47) + '...';
}

/**
 * Add legal disclaimer to AI response (if not already present)
 */
export function addDisclaimer(response: string): string {
  // NOTE: Keep this ASCII-only so downstream exports (e.g. PDF standard fonts) don't fail.
  const disclaimer = '\n\n---\nAI-generated content. Review before use in legal matters.';
  // Don't add if already present
  if (response.includes('AI-generated content')) {
    return response;
  }
  return response + disclaimer;
}

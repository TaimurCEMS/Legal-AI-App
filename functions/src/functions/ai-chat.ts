/**
 * AI Chat Functions (Slice 6b - AI Chat/Research)
 * 
 * Provides AI-powered legal research chat functionality.
 * Users can chat with their case documents using OpenAI.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { successResponse, errorResponse } from '../utils/response';
import { ErrorCode } from '../constants/errors';
import { checkEntitlement } from '../utils/entitlements';
import { canUserAccessCase } from '../utils/case-access';
import { createAuditEvent } from '../utils/audit';
import {
  buildCaseContext,
  sendChatCompletion,
  extractCitations,
  generateThreadTitle,
  addDisclaimer,
  DocumentInfo,
  Citation,
} from '../services/ai-service';

const db = admin.firestore();

type FirestoreTimestamp = admin.firestore.Timestamp;

// Types
interface JurisdictionContext {
  country?: string;
  state?: string;
  region?: string;
}

interface ChatThread {
  threadId: string;
  caseId: string;
  orgId: string;
  title: string;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  createdBy: string;
  messageCount: number;
  lastMessageAt: FirestoreTimestamp;
  status: 'active' | 'archived';
  deletedAt?: FirestoreTimestamp | null;
  jurisdiction?: JurisdictionContext | null;  // Persisted jurisdiction for this thread
}

interface ChatMessage {
  messageId: string;
  threadId: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  citations?: Citation[];
  metadata?: {
    model: string;
    tokensUsed?: number;
    processingTimeMs?: number;
  };
  createdAt: FirestoreTimestamp;
  createdBy: string;
}

interface DocumentWithText {
  id: string;
  name: string;
  extractedText?: string | null;
  pageCount?: number | null;
  deletedAt?: FirestoreTimestamp | null;
}

function toIso(ts: FirestoreTimestamp): string {
  return ts.toDate().toISOString();
}

/**
 * Create a new chat thread for a case
 * Function Name (Export): aiChatCreate
 */
export const aiChatCreate = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const uid = context.auth.uid;
    const { orgId, caseId, title, jurisdiction } = data || {};

    // Validate required fields
    if (!orgId || typeof orgId !== 'string') {
      return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
    }

    if (!caseId || typeof caseId !== 'string') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Case ID is required');
    }

    // Parse jurisdiction context if provided
    const jurisdictionContext: JurisdictionContext | null = jurisdiction ? {
      ...(jurisdiction.country && { country: jurisdiction.country }),
      ...(jurisdiction.state && { state: jurisdiction.state }),
      ...(jurisdiction.region && { region: jurisdiction.region }),
    } : null;

    // Check entitlement - AI_RESEARCH feature required
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'AI_RESEARCH',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'ORG_MEMBER') {
        return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You are not a member of this organization');
      }
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(ErrorCode.PLAN_LIMIT, 'AI Research requires a BASIC plan or higher. Please upgrade to continue.');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
    }

    // Verify user can access the case
    const caseAccess = await canUserAccessCase(orgId, caseId, uid);
    if (!caseAccess.allowed) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, caseAccess.reason || 'You do not have access to this case');
    }

    // Create thread
    const threadRef = db
      .collection('organizations').doc(orgId)
      .collection('cases').doc(caseId)
      .collection('chatThreads').doc();
    
    const now = admin.firestore.Timestamp.now();
    const threadTitle = title?.trim() || 'New Research Chat';

    const threadData: ChatThread = {
      threadId: threadRef.id,
      caseId,
      orgId,
      title: threadTitle,
      createdAt: now,
      updatedAt: now,
      createdBy: uid,
      messageCount: 0,
      lastMessageAt: now,
      status: 'active',
      deletedAt: null,  // Explicitly set for query compatibility
      ...(jurisdictionContext && Object.keys(jurisdictionContext).length > 0 && { jurisdiction: jurisdictionContext }),
    };

    await threadRef.set(threadData);

    // Create audit event
    await createAuditEvent({
      orgId,
      actorUid: uid,
      action: 'ai.chat.thread_created',
      entityType: 'chat_thread',
      entityId: threadRef.id,
      metadata: { caseId, title: threadTitle },
    });

    functions.logger.info(`Created AI chat thread: ${threadRef.id} for case ${caseId}`);

    return successResponse({
      threadId: threadRef.id,
      caseId,
      title: threadTitle,
      createdAt: toIso(now),
      updatedAt: toIso(now),
      createdBy: uid,
      messageCount: 0,
      lastMessageAt: toIso(now),
      status: 'active',
      ...(jurisdictionContext && Object.keys(jurisdictionContext).length > 0 && { jurisdiction: jurisdictionContext }),
    });
  });

/**
 * Send a message and get AI response
 * Function Name (Export): aiChatSend
 */
export const aiChatSend = functions
  .runWith({ 
    timeoutSeconds: 120,  // Allow more time for AI response
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const uid = context.auth.uid;
    const { orgId, caseId, threadId, message, options, jurisdiction } = data || {};
    
    // Jurisdiction context for legal opinions
    const jurisdictionContext = jurisdiction as {
      country?: string;
      state?: string;
      region?: string;
    } | undefined;

    // Validate required fields
    if (!orgId || typeof orgId !== 'string') {
      return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
    }

    if (!caseId || typeof caseId !== 'string') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Case ID is required');
    }

    if (!threadId || typeof threadId !== 'string') {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Thread ID is required');
    }

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Message is required');
    }

    if (message.length > 10000) {
      return errorResponse(ErrorCode.VALIDATION_ERROR, 'Message is too long (max 10000 characters)');
    }

    // Check entitlement
    const entitlement = await checkEntitlement({
      uid,
      orgId,
      requiredFeature: 'AI_RESEARCH',
    });

    if (!entitlement.allowed) {
      if (entitlement.reason === 'PLAN_LIMIT') {
        return errorResponse(ErrorCode.PLAN_LIMIT, 'AI Research requires a BASIC plan or higher. Please upgrade to continue.');
      }
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
    }

    // Verify case access
    const caseAccess = await canUserAccessCase(orgId, caseId, uid);
    if (!caseAccess.allowed) {
      return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have access to this case');
    }

    // Verify thread exists
    const threadRef = db
      .collection('organizations').doc(orgId)
      .collection('cases').doc(caseId)
      .collection('chatThreads').doc(threadId);
    
    const threadSnap = await threadRef.get();
    if (!threadSnap.exists) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Chat thread not found');
    }

    const threadData = threadSnap.data() as ChatThread;
    if (threadData.deletedAt) {
      return errorResponse(ErrorCode.NOT_FOUND, 'Chat thread has been deleted');
    }

    // Use provided jurisdiction or fall back to thread's stored jurisdiction
    const effectiveJurisdiction = jurisdictionContext || threadData.jurisdiction || undefined;

    const now = admin.firestore.Timestamp.now();
    const messagesRef = threadRef.collection('messages');

    // Save user message
    const userMsgRef = messagesRef.doc();
    const userMessage: ChatMessage = {
      messageId: userMsgRef.id,
      threadId,
      role: 'user',
      content: message.trim(),
      createdAt: now,
      createdBy: uid,
    };
    await userMsgRef.set(userMessage);

    // Get previous messages for context (last 10)
    const prevMessagesSnap = await messagesRef
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    const previousMessages = prevMessagesSnap.docs
      .map(d => d.data() as ChatMessage)
      .reverse()
      .slice(0, -1) // Exclude the message we just added
      .map(m => ({
        role: m.role as 'user' | 'assistant' | 'system',
        content: m.content,
      }));

    // Load case documents with extracted text
    const documentsSnap = await db
      .collection('organizations').doc(orgId)
      .collection('documents')
      .where('caseId', '==', caseId)
      .where('deletedAt', '==', null)
      .get();

    const documents: DocumentInfo[] = documentsSnap.docs
      .map(d => {
        const data = d.data() as DocumentWithText;
        return {
          documentId: d.id,
          name: data.name,
          extractedText: data.extractedText,
          pageCount: data.pageCount,
        };
      })
      .filter(d => d.extractedText); // Only include documents with extracted text

    // Build context
    const { context: documentContext, includedDocs } = buildCaseContext(documents);

    functions.logger.info(`AI chat: ${includedDocs.length} documents in context, ${documentContext.length} chars`);

    // Add current message to history
    const fullHistory = [
      ...previousMessages,
      { role: 'user' as const, content: message.trim() },
    ];

    try {
      // Get AI response with jurisdiction context (use effective jurisdiction)
      const model = options?.model || 'gpt-4o-mini';
      const aiResult = await sendChatCompletion(fullHistory, documentContext, { 
        model,
        jurisdiction: effectiveJurisdiction,
      });

      // Extract citations
      const citations = extractCitations(aiResult.content, includedDocs);

      // Add disclaimer to response
      const contentWithDisclaimer = addDisclaimer(aiResult.content);

      // Save assistant message
      const assistantMsgRef = messagesRef.doc();
      const assistantNow = admin.firestore.Timestamp.now();
      const assistantMessage: ChatMessage = {
        messageId: assistantMsgRef.id,
        threadId,
        role: 'assistant',
        content: contentWithDisclaimer,
        ...(citations.length > 0 && { citations }),
        metadata: {
          model: aiResult.model,
          tokensUsed: aiResult.tokensUsed,
          processingTimeMs: aiResult.processingTimeMs,
        },
        createdAt: assistantNow,
        createdBy: 'ai',
      };
      await assistantMsgRef.set(assistantMessage);

      // Update thread metadata
      const newMessageCount = threadData.messageCount + 2;
      const threadUpdate: Record<string, unknown> = {
        messageCount: newMessageCount,
        lastMessageAt: assistantNow,
        updatedAt: assistantNow,
      };
      
      // Update title if this is the first message
      if (threadData.messageCount === 0) {
        threadUpdate.title = generateThreadTitle(message.trim());
      }
      
      // Update jurisdiction if provided and different from stored
      if (jurisdictionContext && Object.keys(jurisdictionContext).length > 0) {
        threadUpdate.jurisdiction = jurisdictionContext;
      }
      
      await threadRef.update(threadUpdate);

      // Create audit events
      await createAuditEvent({
        orgId,
        actorUid: uid,
        action: 'ai.chat.message_sent',
        entityType: 'chat_message',
        entityId: userMsgRef.id,
        metadata: { threadId, caseId },
      });

      await createAuditEvent({
        orgId,
        actorUid: uid,
        action: 'ai.chat.response_received',
        entityType: 'chat_message',
        entityId: assistantMsgRef.id,
        metadata: {
          threadId,
          caseId,
          model: aiResult.model,
          tokensUsed: aiResult.tokensUsed,
          citationCount: citations.length,
        },
      });

      return successResponse({
        userMessage: {
          messageId: userMessage.messageId,
          threadId: userMessage.threadId,
          role: userMessage.role,
          content: userMessage.content,
          createdAt: toIso(userMessage.createdAt),
          createdBy: userMessage.createdBy,
        },
        assistantMessage: {
          messageId: assistantMessage.messageId,
          threadId: assistantMessage.threadId,
          role: assistantMessage.role,
          content: assistantMessage.content,
          ...(assistantMessage.citations && { citations: assistantMessage.citations }),
          metadata: assistantMessage.metadata,
          createdAt: toIso(assistantNow),
          createdBy: assistantMessage.createdBy,
        },
      });

    } catch (error) {
      functions.logger.error('AI chat error:', error);
      
      // Delete the user message since we couldn't get a response
      await userMsgRef.delete();
      
      const errorMessage = error instanceof Error ? error.message : 'AI response failed';
      return errorResponse(ErrorCode.INTERNAL_ERROR, errorMessage);
    }
  });

/**
 * List chat threads for a case
 * Function Name (Export): aiChatList
 */
export const aiChatList = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, limit = 20, offset = 0 } = data || {};

  // Validate
  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Case ID is required');
  }

  // Check entitlement (just org membership for list)
  const entitlement = await checkEntitlement({ uid, orgId });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  // Verify case access
  const caseAccess = await canUserAccessCase(orgId, caseId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have access to this case');
  }

  // Query threads (use status='active' instead of deletedAt for better compatibility)
  const threadsRef = db
    .collection('organizations').doc(orgId)
    .collection('cases').doc(caseId)
    .collection('chatThreads');

  const snapshot = await threadsRef
    .where('status', '==', 'active')
    .orderBy('lastMessageAt', 'desc')
    .get();

  const allThreads = snapshot.docs.map(d => {
    const data = d.data() as ChatThread;
    return {
      threadId: data.threadId,
      caseId: data.caseId,
      title: data.title,
      createdAt: toIso(data.createdAt),
      updatedAt: toIso(data.updatedAt),
      createdBy: data.createdBy,
      messageCount: data.messageCount,
      lastMessageAt: toIso(data.lastMessageAt),
      status: data.status,
      ...(data.jurisdiction && { jurisdiction: data.jurisdiction }),
    };
  });

  // Apply pagination
  const parsedLimit = Math.min(Math.max(1, limit), 50);
  const parsedOffset = Math.max(0, offset);
  const paged = allThreads.slice(parsedOffset, parsedOffset + parsedLimit);
  const hasMore = parsedOffset + parsedLimit < allThreads.length;

  return successResponse({
    threads: paged,
    total: allThreads.length,
    hasMore,
  });
});

/**
 * Get messages for a thread
 * Function Name (Export): aiChatGetMessages
 */
export const aiChatGetMessages = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, threadId, limit = 50, offset = 0 } = data || {};

  // Validate
  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Case ID is required');
  }

  if (!threadId || typeof threadId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Thread ID is required');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({ uid, orgId });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  // Verify case access
  const caseAccess = await canUserAccessCase(orgId, caseId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have access to this case');
  }

  // Verify thread exists
  const threadRef = db
    .collection('organizations').doc(orgId)
    .collection('cases').doc(caseId)
    .collection('chatThreads').doc(threadId);
  
  const threadSnap = await threadRef.get();
  if (!threadSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Chat thread not found');
  }

  const threadData = threadSnap.data() as ChatThread;
  if (threadData.deletedAt) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Chat thread has been deleted');
  }

  // Query messages
  const messagesRef = threadRef.collection('messages');
  const snapshot = await messagesRef
    .orderBy('createdAt', 'asc')
    .get();

  const allMessages = snapshot.docs.map(d => {
    const data = d.data() as ChatMessage;
    return {
      messageId: data.messageId,
      threadId: data.threadId,
      role: data.role,
      content: data.content,
      citations: data.citations,
      metadata: data.metadata,
      createdAt: toIso(data.createdAt),
      createdBy: data.createdBy,
    };
  });

  // Apply pagination
  const parsedLimit = Math.min(Math.max(1, limit), 100);
  const parsedOffset = Math.max(0, offset);
  const paged = allMessages.slice(parsedOffset, parsedOffset + parsedLimit);
  const hasMore = parsedOffset + parsedLimit < allMessages.length;

  return successResponse({
    messages: paged,
    total: allMessages.length,
    hasMore,
  });
});

/**
 * Delete a chat thread
 * Function Name (Export): aiChatDelete
 */
export const aiChatDelete = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  const { orgId, caseId, threadId } = data || {};

  // Validate
  if (!orgId || typeof orgId !== 'string') {
    return errorResponse(ErrorCode.ORG_REQUIRED, 'Organization ID is required');
  }

  if (!caseId || typeof caseId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Case ID is required');
  }

  if (!threadId || typeof threadId !== 'string') {
    return errorResponse(ErrorCode.VALIDATION_ERROR, 'Thread ID is required');
  }

  // Check entitlement
  const entitlement = await checkEntitlement({ uid, orgId });
  if (!entitlement.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Not authorized');
  }

  // Verify case access
  const caseAccess = await canUserAccessCase(orgId, caseId, uid);
  if (!caseAccess.allowed) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'You do not have access to this case');
  }

  // Get thread
  const threadRef = db
    .collection('organizations').doc(orgId)
    .collection('cases').doc(caseId)
    .collection('chatThreads').doc(threadId);
  
  const threadSnap = await threadRef.get();
  if (!threadSnap.exists) {
    // Idempotent - already deleted
    return successResponse({ deleted: true });
  }

  const threadData = threadSnap.data() as ChatThread;
  
  // Only thread creator or ADMIN can delete
  const memberSnap = await db
    .collection('organizations').doc(orgId)
    .collection('members').doc(uid)
    .get();
  
  const memberRole = memberSnap.data()?.role;
  const isAdmin = memberRole === 'ADMIN';
  const isCreator = threadData.createdBy === uid;

  if (!isAdmin && !isCreator) {
    return errorResponse(ErrorCode.NOT_AUTHORIZED, 'Only the thread creator or an admin can delete this thread');
  }

  // Soft delete the thread
  const now = admin.firestore.Timestamp.now();
  await threadRef.update({
    deletedAt: now,
    updatedAt: now,
    status: 'archived',
  });

  // Create audit event
  await createAuditEvent({
    orgId,
    actorUid: uid,
    action: 'ai.chat.thread_deleted',
    entityType: 'chat_thread',
    entityId: threadId,
    metadata: { caseId },
  });

  functions.logger.info(`Deleted AI chat thread: ${threadId}`);

  return successResponse({ deleted: true });
});

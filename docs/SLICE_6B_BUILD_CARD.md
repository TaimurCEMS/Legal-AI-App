# SLICE 6B: AI Chat/Research - Build Card

**Last Updated:** January 24, 2026  
**Status:** 🔄 IN PROGRESS  
**Owner:** Taimur (CEMS)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅, Slice 2 ✅, Slice 4 ✅, Slice 6a ✅

---

## 1) Purpose

Enable AI-powered legal research by allowing users to chat with their case documents using OpenAI. The AI uses extracted text from documents (from Slice 6a) to provide contextual answers with citations to source documents.

---

## 2) Scope In ✅

### Backend (Cloud Functions):
- `aiChatCreate` - Create new chat thread for a case
- `aiChatSend` - Send message and receive AI response with citations
- `aiChatList` - List chat threads for a case
- `aiChatGetMessages` - Get message history for a thread
- `aiChatDelete` - Delete a chat thread
- OpenAI integration service
- Context building from extracted document text
- Citation extraction and linking
- Entitlement checks (`AI_RESEARCH` feature)
- Audit logging for AI interactions

### Frontend (Flutter):
- Chat thread list screen (per case)
- Chat conversation screen
- Message display (user/AI differentiated)
- Citation display with document links
- Loading states during AI response
- Error handling
- Legal disclaimer display

### Data Model:
- Chat threads belong to cases
- Messages belong to threads
- Citations link to source documents
- Timestamps and audit fields

---

## 3) Scope Out ❌

- Embeddings/vector search (future - for large doc sets)
- Streaming responses (future)
- Multi-model support (Claude, Gemini)
- Chat export to PDF
- Prompt templates
- Token usage tracking/limits
- Real-time collaborative chat

---

## 4) Dependencies

**External Services:**
- Firebase Authentication (required) - from Slice 0
- Firestore Database (required) - from Slice 0
- Cloud Functions (required) - from Slice 0
- OpenAI API (required) - NEW

**NPM Packages:**
- `openai` - Already installed in Slice 6a

**Dependencies on Other Slices:**
- ✅ **Slice 0**: Required (org, membership, entitlements)
- ✅ **Slice 1**: Required (Flutter UI shell)
- ✅ **Slice 2**: Required (cases)
- ✅ **Slice 4**: Required (documents)
- ✅ **Slice 6a**: Required (extracted text from documents)

**No Dependencies on:** Slice 5 (Tasks), Slice 7+ (Calendar, Notes, etc.)

---

## 5) Backend Endpoints (Cloud Functions) — Slice 4 style

### 5.1 `aiChatCreate` (Callable Function)

**Function Name (Export):** `aiChatCreate`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `AI_RESEARCH` (BASIC+ plans)  
**Required Permission:** `case.read`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "title": "string (optional, auto-generated from first message if not provided)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "threadId": "string",
    "caseId": "string",
    "title": "string",
    "createdAt": "ISO 8601",
    "createdBy": "string (uid)"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or caseId
- `NOT_AUTHORIZED` (403): User not org member or lacks AI_RESEARCH/case.read
- `NOT_FOUND` (404): Case not found or soft-deleted
- `NOT_AUTHORIZED` (403): User does not have case access (PRIVATE case)
- `INTERNAL_ERROR` (500): Firestore write failure

**Implementation Flow:**
1. Validate auth token; validate orgId, caseId (required)
2. Check entitlement: AI_RESEARCH feature + case.read permission
3. Verify case access: canUserAccessCase(orgId, caseId, uid) must allow
4. Create thread in organizations/{orgId}/cases/{caseId}/chatThreads/{threadId} (title, createdAt, updatedAt, createdBy, messageCount 0, lastMessageAt, status active)
5. Create audit event ai.chat.thread_created
6. Return successResponse with threadId, caseId, title, createdAt, createdBy

---

### 5.2 `aiChatSend` (Callable Function)

**Function Name (Export):** `aiChatSend`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Feature:** `AI_RESEARCH`  
**Required Permission:** `case.read`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "threadId": "string (required)",
  "message": "string (required)",
  "options": {
    "model": "string (optional, 'gpt-4o-mini' | 'gpt-4o')",
    "documentIds": "string[] (optional, specific docs; empty = all case docs)"
  }
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "userMessage": {
      "messageId": "string",
      "role": "user",
      "content": "string",
      "createdAt": "ISO 8601"
    },
    "assistantMessage": {
      "messageId": "string",
      "role": "assistant",
      "content": "string",
      "citations": [ { "documentId": "string", "documentName": "string", "excerpt": "string", "pageNumber": "number | null" } ],
      "metadata": { "model": "string", "tokensUsed": "number", "processingTimeMs": "number" },
      "createdAt": "ISO 8601"
    }
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId, caseId, threadId, or message
- `NOT_AUTHORIZED` (403): User not org member or no case/thread access
- `NOT_FOUND` (404): Case or thread not found
- `INTERNAL_ERROR` (500): OpenAI or Firestore failure

**Implementation Flow:**
1. Validate auth; validate orgId, caseId, threadId, message (required)
2. Check entitlement: AI_RESEARCH + case.read
3. Verify case access: canUserAccessCase(orgId, caseId, uid); load thread, verify exists
4. Save user message to thread messages subcollection (messageId, role user, content, createdAt, createdBy)
5. Build document context from case documents (extracted text); optionally filter by options.documentIds
6. Call OpenAI (sendChatCompletion) with system prompt + document context + user message
7. Extract citations from response (extractCitations); add disclaimer if configured
8. Save assistant message (role assistant, content, citations, metadata: model, tokensUsed, processingTimeMs)
9. Update thread: lastMessageAt, messageCount++; create audit event
10. Return successResponse with userMessage and assistantMessage

---

### 5.3 `aiChatList` (Callable Function)

**Function Name (Export):** `aiChatList`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `case.read`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "limit": "number (optional, default 20, max 100)",
  "offset": "number (optional, default 0)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "threads": [ { "threadId": "string", "caseId": "string", "title": "string", "createdAt": "ISO 8601", "updatedAt": "ISO 8601", "createdBy": "string", "messageCount": "number", "lastMessageAt": "ISO 8601", "status": "string" } ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId or caseId
- `NOT_AUTHORIZED` (403): User not org member or no case access
- `NOT_FOUND` (404): Case not found
- `INTERNAL_ERROR` (500): Firestore read failure

**Implementation Flow:**
1. Validate auth, orgId, caseId; parse limit (default 20, max 100), offset (default 0)
2. Check entitlement: case.read; canUserAccessCase(orgId, caseId, uid) must allow
3. Query organizations/{orgId}/cases/{caseId}/chatThreads orderBy lastMessageAt desc, limit(+1), offset
4. Return threads array, total, hasMore

---

### 5.4 `aiChatGetMessages` (Callable Function)

**Function Name (Export):** `aiChatGetMessages`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `case.read`

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "threadId": "string (required)",
  "limit": "number (optional, default 50)",
  "offset": "number (optional, default 0)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "messages": [ { "messageId": "string", "threadId": "string", "role": "string", "content": "string", "citations": [], "metadata": {}, "createdAt": "ISO 8601", "createdBy": "string" } ],
    "total": "number",
    "hasMore": "boolean"
  }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId, caseId, or threadId
- `NOT_AUTHORIZED` (403): User not org member or no case/thread access
- `NOT_FOUND` (404): Case or thread not found
- `INTERNAL_ERROR` (500): Firestore read failure

**Implementation Flow:**
1. Validate auth, orgId, caseId, threadId; parse limit (default 50), offset
2. Check entitlement: case.read; canUserAccessCase(orgId, caseId, uid); verify thread exists
3. Query thread messages subcollection orderBy createdAt asc, limit(+1), offset
4. Return messages array, total, hasMore

---

### 5.5 `aiChatDelete` (Callable Function)

**Function Name (Export):** `aiChatDelete`  
**Type:** Firebase Callable Function  
**Auth Requirement:** Valid Firebase Auth token  
**Required Permission:** `case.read`; only thread creator or org ADMIN can delete

**Request Payload:**
```json
{
  "orgId": "string (required)",
  "caseId": "string (required)",
  "threadId": "string (required)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": { "deleted": true }
}
```

**Error Responses:**
- `VALIDATION_ERROR` (400): Missing orgId, caseId, or threadId
- `NOT_AUTHORIZED` (403): User not org member, no case access, or not thread creator/ADMIN
- `NOT_FOUND` (404): Case or thread not found
- `INTERNAL_ERROR` (500): Firestore delete failure

**Implementation Flow:**
1. Validate auth, orgId, caseId, threadId (required)
2. Check entitlement: case.read; canUserAccessCase(orgId, caseId, uid)
3. Load thread; verify createdBy === uid or user role is ADMIN
4. Delete thread document (and messages subcollection or cascade delete as implemented)
5. Create audit event ai.chat.thread_deleted
6. Return successResponse({ deleted: true })

---

## 6) Data Model

### 6.1 Chat Thread

**Path:** `organizations/{orgId}/cases/{caseId}/chatThreads/{threadId}`

```typescript
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
}
```

### 6.2 Chat Message

**Path:** `organizations/{orgId}/cases/{caseId}/chatThreads/{threadId}/messages/{messageId}`

```typescript
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
```

---

## 7) AI Service

### 7.1 System Prompt

```
You are a legal research assistant helping lawyers analyze case documents.

IMPORTANT RULES:
1. Base your answers ONLY on the provided documents
2. Always cite your sources using [Document Name] format
3. If information is not in the documents, say "I could not find this information in the provided documents"
4. Be precise and factual - this is for legal work
5. Highlight any contradictions or gaps you notice

Documents for this case:
{document_context}
```

### 7.2 Context Building

```typescript
function buildCaseContext(documents: DocumentWithText[]): string {
  const MAX_CHARS = 400000;  // ~100K tokens for gpt-4o-mini
  let context = "";
  
  for (const doc of documents) {
    if (!doc.extractedText) continue;
    
    const docSection = `\n--- ${doc.name} (ID: ${doc.documentId}) ---\n${doc.extractedText}\n`;
    
    if (context.length + docSection.length > MAX_CHARS) {
      // Truncate this document to fit
      const remaining = MAX_CHARS - context.length - 100;
      if (remaining > 1000) {
        context += `\n--- ${doc.name} (ID: ${doc.documentId}) ---\n${doc.extractedText.substring(0, remaining)}...[truncated]\n`;
      }
      break;
    }
    
    context += docSection;
  }
  
  return context;
}
```

### 7.3 Citation Extraction

Extract citations by matching document names/IDs mentioned in the AI response:

```typescript
function extractCitations(
  response: string,
  documents: DocumentInfo[]
): Citation[] {
  const citations: Citation[] = [];
  
  for (const doc of documents) {
    // Check if document is referenced in response
    if (response.includes(doc.name) || response.includes(doc.documentId)) {
      citations.push({
        documentId: doc.documentId,
        documentName: doc.name,
        excerpt: findRelevantExcerpt(response, doc.name),
      });
    }
  }
  
  return citations;
}
```

---

## 8) Frontend Changes

### 8.1 New Models

**ChatThreadModel** (`lib/core/models/chat_thread_model.dart`):
```dart
class ChatThreadModel {
  final String threadId;
  final String caseId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final int messageCount;
  final DateTime lastMessageAt;
  final String status;
}
```

**ChatMessageModel** (`lib/core/models/chat_message_model.dart`):
```dart
class ChatMessageModel {
  final String messageId;
  final String threadId;
  final String role;
  final String content;
  final List<CitationModel>? citations;
  final ChatMetadata? metadata;
  final DateTime createdAt;
  final String createdBy;
}

class CitationModel {
  final String documentId;
  final String documentName;
  final String excerpt;
  final int? pageNumber;
}
```

### 8.2 New Service

**AIChatService** (`lib/core/services/ai_chat_service.dart`):
```dart
class AIChatService {
  Future<ChatThreadModel> createThread(OrgModel org, String caseId, {String? title});
  Future<SendMessageResult> sendMessage(OrgModel org, String caseId, String threadId, String message);
  Future<List<ChatThreadModel>> listThreads(OrgModel org, String caseId);
  Future<List<ChatMessageModel>> getMessages(OrgModel org, String caseId, String threadId);
  Future<void> deleteThread(OrgModel org, String caseId, String threadId);
}
```

### 8.3 New Screens

**CaseAIChatScreen** (`lib/features/ai_chat/screens/case_ai_chat_screen.dart`):
- List of chat threads for current case
- "New Chat" FAB
- Thread preview (title, last message, time)
- Swipe to delete

**ChatThreadScreen** (`lib/features/ai_chat/screens/chat_thread_screen.dart`):
- Message list (scrollable)
- User messages: right-aligned, blue bubble
- AI messages: left-aligned, gray bubble, citations below
- Input field at bottom with send button
- Loading indicator during AI response
- Legal disclaimer banner at top

### 8.4 UI Components

**ChatBubble**: Message display with role-based styling
**CitationCard**: Expandable card showing document reference
**AIDisclaimer**: Warning banner about AI-generated content

---

## 9) Entitlements

### Feature: `AI_RESEARCH`

| Plan | Enabled |
|------|---------|
| FREE | ❌ |
| BASIC | ✅ |
| PRO | ✅ |
| ENTERPRISE | ✅ |

### Permission: `ai.chat`

All roles can use AI chat if plan allows (no role restriction).

---

## 10) Legal Compliance

### Disclaimer Text
Every chat screen must display:
```
⚠️ AI-generated content. Review before use in legal matters.
```

### Audit Events
- `ai.chat.thread_created` - Thread created
- `ai.chat.message_sent` - User sent message
- `ai.chat.response_received` - AI responded
- `ai.chat.thread_deleted` - Thread deleted

---

## 11) Implementation Order

1. ✅ Create build card (this document)
2. Store OpenAI API key as Firebase secret
3. Create `ai-service.ts` with OpenAI integration
4. Create `ai-chat.ts` Cloud Functions
5. Export functions in `index.ts`
6. Create Flutter models (ChatThreadModel, ChatMessageModel)
7. Create AIChatService
8. Create AIChatProvider
9. Create CaseAIChatScreen
10. Create ChatThreadScreen
11. Integrate with CaseDetailsScreen
12. Deploy and test

---

## 12) Testing Checklist

### Backend
- [ ] `aiChatCreate` creates thread successfully
- [ ] `aiChatCreate` fails for FREE plan users
- [ ] `aiChatSend` returns AI response with citations
- [ ] `aiChatSend` handles empty document context
- [ ] `aiChatSend` respects token limits
- [ ] `aiChatList` returns threads sorted by last message
- [ ] `aiChatGetMessages` returns messages in order
- [ ] `aiChatDelete` removes thread and messages
- [ ] OpenAI errors are handled gracefully

### Frontend
- [ ] Thread list shows all case threads
- [ ] New thread creation works
- [ ] Messages display correctly (user vs AI)
- [ ] Citations are clickable and link to documents
- [ ] Loading state shown during AI response
- [ ] Error messages displayed properly
- [ ] Legal disclaimer always visible

---

## 13) Files to Create/Modify

### Create
- `functions/src/services/ai-service.ts`
- `functions/src/functions/ai-chat.ts`
- `legal_ai_app/lib/core/models/chat_thread_model.dart`
- `legal_ai_app/lib/core/models/chat_message_model.dart`
- `legal_ai_app/lib/core/services/ai_chat_service.dart`
- `legal_ai_app/lib/features/ai_chat/providers/ai_chat_provider.dart`
- `legal_ai_app/lib/features/ai_chat/screens/case_ai_chat_screen.dart`
- `legal_ai_app/lib/features/ai_chat/screens/chat_thread_screen.dart`
- `docs/SLICE_6B_BUILD_CARD.md`

### Modify
- `functions/src/index.ts` - Export AI chat functions
- `functions/src/constants/entitlements.ts` - Enable AI_RESEARCH for BASIC+
- `legal_ai_app/lib/features/cases/screens/case_details_screen.dart` - Add AI Chat button

---

## 14) Cost Estimate

### OpenAI Pricing (gpt-4o-mini)
- Input: $0.15 per 1M tokens
- Output: $0.60 per 1M tokens

### Typical Query
- Context: ~20,000 tokens (5 documents × 4K each)
- Query: ~100 tokens
- Response: ~500 tokens
- **Cost per query: ~$0.003** (less than 1 cent)

### Monthly Estimate (per org)
- 100 queries/month: ~$0.30
- 1000 queries/month: ~$3.00

---

**End of Slice 6B Build Card**

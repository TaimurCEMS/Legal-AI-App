# Slice 17 Build Card: Two-Factor Authentication (2FA)

**Status:** 🟡 NOT STARTED  
**Priority:** High (required for world-class launch per MASTER_SPEC_V2.0 §8)  
**Dependencies:** Slice 0 ✅, Slice 1 ✅  
**Date Created:** 2026-01-30  
**Spec Reference:** MASTER_SPEC_V2.0.md §8 (Launch Criteria)

---

## 📋 Overview

Slice 17 adds **Two-Factor Authentication (2FA)** so firm accounts can enforce a second factor at login. No platform (P1/P2) dependency; can be implemented in parallel with P1/P2.

**Key Features:**
1. **Enable 2FA** – User enrolls TOTP (authenticator app); backend stores enrollment state; emit `auth.2fa.enabled` for audit/events.
2. **Disable 2FA** – User turns off 2FA (with re-auth and optional backup code).
3. **Login flow** – After email/password success, if 2FA enabled, prompt for TOTP code; validate and complete sign-in.
4. **Recovery** – Backup codes (generate on enable, one-time use); optional "forgot device" flow.

**Out of Scope (MVP):**
- SMS 2FA (TOTP only for MVP).
- Enforcing 2FA at org level (future: org setting "require 2FA for all members").

---

## 🎯 Success Criteria

### Backend
- **2FA enrollment:** Generate TOTP secret, store in user document or Auth custom claims; return QR/secret for authenticator app; mark user as 2FA enabled.
- **2FA verification at login:** After Firebase Auth email/password sign-in, custom token or session check: if 2FA enabled, require second-factor verification before issuing effective session (e.g. custom token only after TOTP verified).
- **2FA disable:** Require current password or re-auth; clear 2FA secret; emit audit event.
- **Backup codes:** Generate N one-time codes on enable; store hashed; consume on use; allow re-generate (invalidates previous).

### Frontend
- **Settings → Security:** "Enable 2FA" flow (show QR + manual secret, "I've added this" → verify with first code).
- **Settings → Security:** "Disable 2FA", "Regenerate backup codes".
- **Login:** After email/password success, if 2FA enabled, show TOTP code input screen; on success, complete sign-in; optional "Use backup code" path.

### Testing
- Backend: TOTP verify logic; backup code generation and consumption.
- Frontend: Enable 2FA, login with TOTP, login with backup code, disable 2FA.
- Security: 2FA state not bypassable from client.

---

## 🏗️ Technical Architecture

### Backend (Cloud Functions / Firebase Auth)

#### Option A: Firebase Auth + Custom Backend Verification
- Firebase Auth does not natively support TOTP. Flow:
  1. User signs in with email/password → getIdToken returns token with custom claim `mfaPending: true` if 2FA enabled (set via Admin SDK after sign-in check).
  2. Callable **`mfaVerifyTOTP`** with `{ idToken, code }` – verify TOTP, then set custom claims to clear `mfaPending` and set `mfaVerified: true` (or issue new custom token with full claims).
  3. Client uses new token for subsequent requests.

#### Option B: Separate 2FA Verification Before Full Sign-In
- After email/password, do not treat session as complete. Call **`authChallenge2FA`** with credentials or temporary token; backend verifies TOTP, then returns custom token or session cookie for full access.

**Callables (typical):**
- **`mfaSetupStart`** – Generate TOTP secret, store server-side keyed by uid, return QR URL and secret for manual entry.
- **`mfaSetupVerify`** – User submits first TOTP code; verify; persist 2FA enabled in Firestore (`users/{uid}/mfa` or custom claims); generate backup codes; return backup codes once.
- **`mfaVerify`** – Called at login with current idToken + TOTP code; verify code; return new custom token (or refresh token) with 2FA satisfied.
- **`mfaDisable`** – Re-auth required; clear 2FA data; emit audit.
- **`mfaBackupCodeUse`** – Consume one backup code (hash match); invalidate that code; grant 2FA satisfaction for this session.
- **`mfaBackupCodesRegenerate`** – Re-auth; generate new set; invalidate old set; return new codes once.

### Data Model

```typescript
// Firestore: users/{uid}/private/mfa (or organizations not used for 2FA - 2FA is user-level)
interface MfaDocument {
  enabled: boolean;
  totpSecretEncrypted: string;   // encrypted at rest
  backupCodeHashes: string[];   // hashed, one-time
  enabledAt: Timestamp;
  lastVerifiedAt?: Timestamp;
}
```

### Frontend (Flutter)

- **MfaSetupScreen** – Step 1: Show QR + secret. Step 2: Input code to verify. Step 3: Show backup codes (copy/download).
- **MfaVerifyScreen** – Shown after email/password when 2FA enabled; TOTP input; "Use backup code" link → backup code input.
- **SecuritySettingsSection** – Enable 2FA, Disable 2FA, Regenerate backup codes (with re-auth dialog).
- **Login flow** – After `signInWithEmailAndPassword`, check response or get token; if 2FA required, navigate to MfaVerifyScreen; on success, proceed to app.

---

## 🔐 Security & Permissions

- TOTP secret and backup codes stored encrypted/hashed; never log codes.
- Only the user (uid) can enable/disable their own 2FA.
- Re-auth (password or recent login) required for disable and backup code regeneration.
- Emit audit event `auth.2fa.enabled` / `auth.2fa.disabled` for compliance.

---

## 📝 Backend Endpoints (Summary)

| Function | Request | Success | Errors |
|----------|---------|---------|--------|
| mfaSetupStart | (auth) | { qrUrl, secret } | ALREADY_ENABLED |
| mfaSetupVerify | { code } | { backupCodes } | INVALID_CODE, ALREADY_ENABLED |
| mfaVerify | { idToken, code? } or { idToken, backupCode? } | { customToken } or { verified: true } | INVALID_CODE, MFA_REQUIRED |
| mfaDisable | { password } or re-auth | { success } | REAUTH_REQUIRED, INVALID_PASSWORD |
| mfaBackupCodesRegenerate | re-auth | { backupCodes } | REAUTH_REQUIRED |

---

## 🧪 Testing Strategy

- Unit: TOTP generation and verification (known secret, known time).
- Integration: Full enable → login with TOTP → disable; backup code use and invalidation.
- Security: Attempt to bypass 2FA with stolen password only.

---

## 📚 References

- MASTER_SPEC_V2.0.md §8 (Launch criteria: 2FA enabled for firm accounts)
- Firebase Auth: Custom tokens, custom claims
- TOTP: RFC 6238; library e.g. `otplib` (Node)

---

**Last Updated:** 2026-01-30

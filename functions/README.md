# Legal AI App - Cloud Functions

## Slice 0: Foundation (Auth + Org + Entitlements Engine) ✅ LOCKED

**Status:** ✅ Complete & Locked  
**Tests:** ✅ All passing (3/3)

This directory contains the Cloud Functions implementation for Slice 0.

> ⚠️ **Slice 0 is LOCKED** - Business logic should not be modified without approval.

## Structure

```
functions/
├── src/
│   ├── constants/          # PLAN_FEATURES, ROLE_PERMISSIONS, Error codes
│   ├── utils/              # Response wrappers, entitlement checks, audit logging
│   ├── functions/          # Callable functions (org, member)
│   ├── __tests__/          # Unit tests
│   └── index.ts            # Entry point
├── package.json
├── tsconfig.json
└── jest.config.js
```

## Setup

1. Install dependencies:
```bash
cd functions
npm install
```

2. Build TypeScript:
```bash
npm run build
```

3. Run tests:
```bash
# Run Slice 0 terminal tests (recommended)
npm run test:slice0

# Or run Jest tests (if configured)
npm test
```

## Functions

### `org.create`
Creates a new organization and sets the creator as ADMIN.

### `org.join`
Joins an existing organization with idempotent behavior and transaction protection.

### `member.getMyMembership`
Retrieves the current user's membership information for an organization.

## Constants

- **PLAN_FEATURES**: Defines which features are enabled per plan tier
- **ROLE_PERMISSIONS**: Defines which permissions each role has
- **ErrorCode**: Standardized error codes

## Security

All sensitive writes (create, update, delete) must go through Cloud Functions. Firestore security rules deny client writes to protected collections.

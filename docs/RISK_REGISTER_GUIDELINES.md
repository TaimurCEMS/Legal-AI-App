# Risk Register: Guidelines & Maintenance Process

**Version:** 1.0  
**Created:** 2026-01-26  
**Owner:** Taimur (Product Owner)  
**Status:** MANDATORY — All builds must follow this process

---

## 1. Purpose

This document defines the mandatory Risk Register maintenance process for the Legal AI Application. The Risk Register tracks technical, security, scalability, and business risks throughout the project lifecycle.

**Key Principles:**
- Maintain risks with **minimal effort** from the Product Owner
- Update after **every slice completion** (Definition of Done requirement)
- Output in **Markdown table format** for easy copy-paste to ChatGPT
- ChatGPT maintains the **master Excel Risk Register** externally
- **Never delete risks** — close them with notes instead
- **Stable Risk IDs** — IDs never change or get reused

---

## 2. Strict Policy & Rules

### 2.1 Risk ID System (NON-NEGOTIABLE)

| Rule | Description |
|------|-------------|
| **Permanent IDs** | Every risk has a unique ID: `R-001`, `R-002`, etc. |
| **Never Change** | IDs must NEVER change even if risk title/description changes |
| **Never Reuse** | Never reuse an ID even if risk is closed |
| **Sequential** | New risks get the next available number |

### 2.2 Never Delete Risks (NON-NEGOTIABLE)

| Rule | Description |
|------|-------------|
| **No Deletions** | Risks must NEVER be removed from the register |
| **Close Instead** | If risk is no longer relevant, set Status = `Closed` or `Accepted` |
| **Document Closure** | Add closure notes and update Last Updated date |
| **History Preserved** | Full risk history is maintained for audit purposes |

### 2.3 Mandatory Slice Updates (NON-NEGOTIABLE)

After **every slice completion**, the following MUST occur:

1. **Add New Risks** — Minimum 2 new risks if slice introduces new complexity
2. **Review Top 5 Risks** — Adjust Likelihood, Impact, Status as needed
3. **Update Mitigations** — Document what was done in that slice
4. **Update Dates** — Set Last Updated to current date (YYYY-MM-DD)
5. **Close Resolved Risks** — Mark as Closed/Accepted with notes (never delete)

### 2.4 Risk Quality Rules (NON-NEGOTIABLE)

Each risk MUST be **specific and testable**, not generic.

| Quality | Example |
|---------|---------|
| ❌ BAD | "Security risk" |
| ✅ GOOD | "No rate limiting on callable functions may allow abuse/spam causing cost spikes" |
| ❌ BAD | "Performance issues" |
| ✅ GOOD | "In-memory search scans all records (O(n)), causing 2-3s delays at 500+ documents" |

### 2.5 Ownership Rules (NON-NEGOTIABLE)

| Rule | Description |
|------|-------------|
| **Required for Open/In Progress** | Every Open or In Progress risk MUST have an Owner |
| **Valid Owners** | Backend Dev, Frontend Dev, QA, Product, Taimur |
| **Accountability** | Owner is responsible for mitigation progress |

### 2.6 Severity Consistency Rules (NON-NEGOTIABLE)

Severity must be logically consistent with Likelihood + Impact:

| Rule | Constraint |
|------|------------|
| **Critical Impact** | If Impact = Critical, Severity cannot be Low |
| **High + High** | If Likelihood = High AND Impact = High/Critical, Severity must be High/Critical |
| **Low + Low** | If Likelihood = Low AND Impact = Low, Severity should be Low |

**Severity Matrix (Reference):**

| Likelihood ↓ / Impact → | Low | Medium | High | Critical |
|-------------------------|-----|--------|------|----------|
| **Low** | Low | Low | Medium | High |
| **Medium** | Low | Medium | High | High |
| **High** | Medium | High | High | Critical |

---

## 3. Controlled Vocabularies

All fields with controlled values MUST use these exact options:

### 3.1 Category
| Value | Use When |
|-------|----------|
| `Technical` | Code bugs, architecture issues, integration problems |
| `Security` | Authentication, authorization, data protection, vulnerabilities |
| `Scalability` | Performance at scale, pagination, search, caching |
| `UX` | User experience issues, UI bugs, usability problems |
| `Operations` | Deployment, monitoring, infrastructure, DevOps |
| `Compliance` | Legal requirements, data retention, GDPR, audit |
| `Business` | Timeline, resources, budget, stakeholder risks |
| `Delivery` | Scope creep, dependencies, blockers |

### 3.2 Likelihood
| Value | Description |
|-------|-------------|
| `Low` | Unlikely to occur (<25% chance) |
| `Medium` | May occur (25-75% chance) |
| `High` | Likely to occur (>75% chance) |

### 3.3 Impact
| Value | Description |
|-------|-------------|
| `Low` | Minor inconvenience, easy workaround |
| `Medium` | Noticeable degradation, requires attention |
| `High` | Significant impact on functionality or users |
| `Critical` | System failure, data loss, security breach, legal liability |

### 3.4 Severity
| Value | Description |
|-------|-------------|
| `Low` | Monitor, address when convenient |
| `Medium` | Plan mitigation, address in upcoming work |
| `High` | Prioritize mitigation, address soon |
| `Critical` | Immediate action required, potential blocker |

### 3.5 Status
| Value | Description |
|-------|-------------|
| `Open` | Risk identified, not yet addressed |
| `In Progress` | Mitigation work underway |
| `Mitigated` | Controls in place, risk reduced to acceptable level |
| `Accepted` | Risk acknowledged, decided not to mitigate (documented reason) |
| `Closed` | Risk no longer relevant (documented reason) |

---

## 4. Markdown Risk Register Template

Use this **exact column order** for all Risk Register outputs:

```markdown
| Risk ID | Risk Title | Description | Category | Slice/Module | Likelihood | Impact | Severity | Status | Owner | Mitigation / Controls | Trigger / Early Warning | Last Updated | Notes |
|---------|------------|-------------|----------|--------------|------------|--------|----------|--------|-------|----------------------|------------------------|--------------|-------|
| R-001 | [Short title] | [Specific, testable description] | [Category] | [Slice X] | [L/M/H] | [L/M/H/C] | [L/M/H/C] | [Status] | [Owner] | [What's been done / planned] | [How we'll know it's happening] | YYYY-MM-DD | [Additional context] |
```

### Column Definitions

| Column | Description | Required |
|--------|-------------|----------|
| **Risk ID** | Permanent unique ID (R-001, R-002, etc.) | Yes |
| **Risk Title** | Short descriptive title (5-10 words) | Yes |
| **Description** | Specific, testable description of the risk | Yes |
| **Category** | One of: Technical, Security, Scalability, UX, Operations, Compliance, Business, Delivery | Yes |
| **Slice/Module** | Which slice introduced or is affected by this risk | Yes |
| **Likelihood** | Low, Medium, High | Yes |
| **Impact** | Low, Medium, High, Critical | Yes |
| **Severity** | Low, Medium, High, Critical (must be consistent with L+I) | Yes |
| **Status** | Open, In Progress, Mitigated, Accepted, Closed | Yes |
| **Owner** | Backend Dev, Frontend Dev, QA, Product, Taimur | Yes (if Open/In Progress) |
| **Mitigation / Controls** | What's been done or planned to address the risk | Yes |
| **Trigger / Early Warning** | How we'll detect if risk is materializing | Recommended |
| **Last Updated** | Date of last update (YYYY-MM-DD) | Yes |
| **Notes** | Additional context, closure reasons, history | Optional |

---

## 5. Slice Closure Checklist (Definition of Done)

Every slice MUST complete the following before being marked as COMPLETE:

### Slice Closure Checklist

```markdown
## Slice [X] Closure Checklist

### Code & Testing
- [ ] All acceptance criteria met
- [ ] All tests passing (unit, integration)
- [ ] No critical linter errors
- [ ] Code reviewed and approved

### Documentation
- [ ] Build card updated with completion status
- [ ] SLICE_STATUS.md updated
- [ ] Any new learnings added to DEVELOPMENT_LEARNINGS.md

### Deployment
- [ ] Functions deployed successfully
- [ ] Firestore indexes deployed (if any)
- [ ] Security rules updated (if any)

### Risk Register (MANDATORY)
- [ ] **New risks added** (minimum 2 if new complexity introduced)
- [ ] **Top 5 risks reviewed** and updated (Likelihood, Impact, Status)
- [ ] **Mitigations updated** with work done in this slice
- [ ] **Last Updated dates** set to today
- [ ] **Risk Register Markdown** output and ready for ChatGPT paste
- [ ] **No risks deleted** — only closed with notes

### Sign-Off
- [ ] Slice marked COMPLETE in SLICE_STATUS.md
- [ ] Product Owner notified
```

---

## 6. Slice Update Instructions (MANDATORY)

After every slice completion, perform these steps and output the **full updated Risk Register table**:

### Step 1: Add New Risks
- Review the slice for new complexity, dependencies, or issues
- Add minimum 2 new risks if new complexity was introduced
- Assign sequential Risk IDs (never reuse)
- Ensure each risk is specific and testable

### Step 2: Review Top 5 Risks
- Identify the top 5 risks by Severity
- For each, evaluate:
  - Has Likelihood changed based on new information?
  - Has Impact changed based on new understanding?
  - Should Status be updated?

### Step 3: Update Mitigations
- Document what was done in this slice to address risks
- Add specific controls, code changes, or decisions
- Reference relevant commits or files if applicable

### Step 4: Update Dates
- Set Last Updated to today's date (YYYY-MM-DD) for all modified risks

### Step 5: Close Resolved Risks
- If a risk is no longer relevant, set Status = Closed or Accepted
- Add closure reason in Notes column
- **NEVER delete the row**

### Step 6: Output Full Table
- Output the complete Risk Register as a Markdown table
- Use exact column order specified in Section 4
- Ready for copy-paste to ChatGPT for Excel master update

---

## 7. Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      SLICE COMPLETION                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. Complete Slice Closure Checklist (Code, Tests, Docs, Deploy)│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Update Risk Register (Add new, Review top 5, Update dates)  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Output Risk Register as Markdown Table                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Taimur: Copy Markdown → Paste to ChatGPT                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. ChatGPT: Update Master Excel Risk Register                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  6. Slice marked COMPLETE                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Enforcement

This Risk Register process is **MANDATORY** and enforced as follows:

1. **MASTER_SPEC Requirement** — Added to official project governance
2. **Definition of Done** — Risk Register update is a required closure step
3. **Slice Status** — Cannot mark slice COMPLETE without Risk Register update
4. **Audit Trail** — Risk Register is version controlled with full history

**Non-compliance will result in:**
- Slice not being marked as COMPLETE
- Potential quality issues being missed
- Technical debt accumulating without visibility

---

## 9. Quick Reference Card

### When Adding a New Risk
```
1. Get next Risk ID (R-XXX)
2. Write specific, testable title and description
3. Assign Category, Likelihood, Impact
4. Calculate Severity (must be consistent)
5. Set Status = Open
6. Assign Owner
7. Document initial mitigation plan
8. Set Last Updated = today
```

### When Closing a Risk
```
1. Set Status = Closed or Accepted
2. Add closure reason in Notes
3. Set Last Updated = today
4. NEVER delete the row
```

### When Updating After Slice
```
1. Add new risks (min 2 if new complexity)
2. Review top 5 by severity
3. Update mitigations with slice work
4. Update all Last Updated dates
5. Output full Markdown table
6. Paste to ChatGPT for Excel update
```

---

**Document Version History:**

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-26 | Initial creation |

---

*This document is referenced by MASTER_SPEC and is mandatory for all development work.*

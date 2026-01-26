# Legal AI App — Risk Register

**Version:** 1.0  
**Last Updated:** 2026-01-26  
**Last Slice Completed:** Slice 6b (AI Chat/Research Enhanced)  
**Next Review:** After Slice 7 completion

---

## Risk Register Table

| Risk ID | Risk Title | Description | Category | Slice/Module | Likelihood | Impact | Severity | Status | Owner | Mitigation / Controls | Trigger / Early Warning | Last Updated | Notes |
|---------|------------|-------------|----------|--------------|------------|--------|----------|--------|-------|----------------------|------------------------|--------------|-------|
| R-001 | Document loading race condition on first navigation | On first navigation after login, documents may not load and require manual refresh due to timing issues between navigation and provider state initialization | UX | Slice 4, 5 | High | Medium | High | Open | Frontend Dev | Documented as known issue; deferred to future polish slice | Users report blank document lists after login | 2026-01-26 | Documented in SLICE_STATUS.md as Known Non-Blocking UX Issue |
| R-002 | In-memory search breaks at scale | Search loads up to 1000 records into memory then filters with O(n) scan; will miss results and slow down significantly beyond 500-1000 records | Scalability | Slice 2, 3, 4 | Medium | High | High | Accepted | Backend Dev | Documented limitation; plan to implement Algolia/Elasticsearch post-MVP | Query response times exceed 2 seconds; users report missing search results | 2026-01-26 | MVP tradeoff; acceptable for <500 records per org |
| R-003 | Offset pagination inefficient at scale | Offset-based pagination gets slower as offset increases; Firestore reads all skipped documents; hard limit of 1000 records | Scalability | Slice 2, 3, 4, 5 | Medium | High | High | Accepted | Backend Dev | Documented limitation; plan cursor-based pagination post-MVP | Page load times increase noticeably; users can't access records beyond 1000 | 2026-01-26 | MVP tradeoff; will address before reaching 500 records/org |
| R-004 | No rate limiting on Cloud Functions | Callable functions have no rate limiting; malicious or buggy clients could cause cost spikes or denial of service | Security | Slice 0 | Low | Critical | High | Open | Backend Dev | Firebase quotas provide some protection; plan App Check + rate limiting before public launch | Unusual cost spikes in Firebase billing; high function invocation counts | 2026-01-26 | Not critical for private beta; must address before public launch |
| R-005 | No caching layer increases latency and cost | Every request hits Firestore directly; no caching for frequently accessed data (orgs, members); increases latency and read costs | Scalability | All | Medium | Medium | Medium | Accepted | Backend Dev | Acceptable for MVP scale; plan Redis caching when costs exceed $100/month | Firestore read costs become significant; users notice delays on common operations | 2026-01-26 | MVP tradeoff; monitor costs monthly |
| R-006 | Lists not real-time; require manual refresh | Case, document, task lists use request-driven loading, not Firestore snapshot listeners; changes by other users not visible until refresh | UX | Slice 2, 4, 5 | High | Low | Medium | Accepted | Frontend Dev | Documented behavior; acceptable for MVP; plan real-time listeners for v2 | Users confused when collaborator changes not visible | 2026-01-26 | MVP tradeoff; most users work solo initially |
| R-007 | AI responses not streamed; feels slow | AI chat waits for complete response before displaying; users see loading spinner for 5-15 seconds with no feedback | UX | Slice 6b | High | Medium | High | Open | Backend Dev | Documented as UX enhancement; plan streaming implementation | Users abandon AI chat due to perceived slowness | 2026-01-26 | High priority UX improvement; affects perceived AI quality |
| R-008 | OpenAI API key in .env file on server | API key stored in functions/.env; secure for Firebase deployment but requires careful handling; rotation not automated | Security | Slice 6b | Low | High | Medium | Mitigated | Backend Dev | Key stored in .env (gitignored); Firebase loads automatically on deploy; documented in setup guides | Key exposed in logs or commits | 2026-01-26 | Standard practice; consider Secret Manager for production |
| R-009 | No legal disclaimer enforcement in AI responses | Legal disclaimer appended to AI responses but no technical enforcement; could be removed or bypassed | Compliance | Slice 6b | Low | High | Medium | Mitigated | Backend Dev | Backend always appends disclaimer; duplicate prevention implemented; cannot be disabled by frontend | Legal complaint about AI advice | 2026-01-26 | Current implementation is acceptable; legal review recommended |
| R-010 | Soft-deleted data not automatically purged | Soft delete pattern preserves data indefinitely; no automated cleanup after retention period; storage costs accumulate | Operations | All | Low | Low | Low | Accepted | Backend Dev | Acceptable for MVP; plan scheduled cleanup function for post-launch | Storage costs increase unexpectedly | 2026-01-26 | Add cleanup function when storage exceeds reasonable threshold |
| R-011 | No audit trail UI for compliance visibility | Comprehensive audit logging exists in backend but no UI to view/search/export audit logs | Compliance | Slice 0 | Medium | Medium | Medium | Open | Frontend Dev | Backend foundation complete; UI planned for Slice 12 | Compliance audit request cannot be fulfilled easily | 2026-01-26 | Can export via Firebase Console manually if needed before Slice 12 |
| R-012 | Two-query merge for case visibility adds latency | Case list runs separate queries for ORG_WIDE and PRIVATE cases, merges in memory; doubles read cost and latency | Scalability | Slice 2, 5.5 | Medium | Medium | Medium | Accepted | Backend Dev | Acceptable for MVP; consider composite index optimization if latency becomes noticeable | Case list load times exceed 2 seconds | 2026-01-26 | MVP tradeoff; works well for current scale |
| R-013 | Complex provider state tracking causes race conditions | Providers use multiple tracking variables (_lastLoadedOrgId, _lastLoadedCaseId, etc.) creating complex state that can cause race conditions | Technical | Slice 2, 3, 4, 5 | Medium | Medium | Medium | In Progress | Frontend Dev | Documented in DEVELOPMENT_LEARNINGS.md; listener pattern adopted; ongoing refinement | Intermittent bugs with data not loading or loading wrong data | 2026-01-26 | Improving with each slice; monitor for new issues |
| R-014 | No conflict of interest check on new cases | No automated check for conflicts when creating cases/clients; required by legal ethics rules | Compliance | Slice 3 | Low | High | Medium | Open | Backend Dev | Planned for Slice 19; manual checks required until then | Ethical violation due to missed conflict | 2026-01-26 | Lower priority; most solo practitioners manage manually |
| R-015 | Calendar and deadline tracking not implemented | No calendar, court dates, or deadline tracking; lawyers depend heavily on deadline management | Business | Not started | High | High | High | Open | Product | Planned for Slice 7 (next slice); critical for adoption | Users choose competitor for deadline tracking | 2026-01-26 | Priority 1 feature; blocking wider adoption |
| R-016 | Time tracking and billing not implemented | No time tracking or billing features; core revenue feature for law firms | Business | Not started | High | High | High | Open | Product | Planned for Slices 10-11; important for revenue generation | Users need separate billing software | 2026-01-26 | Priority 2 feature; important for firm adoption |

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Risks** | 16 |
| **Open** | 7 |
| **In Progress** | 1 |
| **Mitigated** | 2 |
| **Accepted** | 6 |
| **Closed** | 0 |
| **Critical Severity** | 0 |
| **High Severity** | 6 |
| **Medium Severity** | 8 |
| **Low Severity** | 2 |

---

## Risk Distribution by Category

| Category | Count | High/Critical |
|----------|-------|---------------|
| Scalability | 4 | 2 |
| UX | 3 | 2 |
| Security | 2 | 1 |
| Compliance | 3 | 0 |
| Technical | 1 | 0 |
| Operations | 1 | 0 |
| Business | 2 | 2 |

---

## Top 5 Risks by Severity

1. **R-001** (High) — Document loading race condition on first navigation
2. **R-002** (High) — In-memory search breaks at scale
3. **R-003** (High) — Offset pagination inefficient at scale
4. **R-004** (High) — No rate limiting on Cloud Functions
5. **R-007** (High) — AI responses not streamed; feels slow
6. **R-015** (High) — Calendar and deadline tracking not implemented
7. **R-016** (High) — Time tracking and billing not implemented

*(Note: 7 risks tied at High severity)*

---

## Version History

| Version | Date | Slice | Changes |
|---------|------|-------|---------|
| 1.0 | 2026-01-26 | Post-6b | Initial risk register created with 16 risks from architecture assessment and known issues |

---

## Next Update

**After Slice 7 (Calendar & Court Dates) completion:**
- Add new risks discovered during calendar implementation
- Review and update R-015 status
- Update mitigation progress for UX risks
- Assess if R-007 (streaming) should be addressed

---

*Copy this entire document and paste to ChatGPT to update the master Excel Risk Register.*

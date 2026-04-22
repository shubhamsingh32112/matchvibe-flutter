# Frontend Capacity Comparative Verification (2026-04-22)

## Objective

Verify, by code inspection, whether the Flutter frontend is now truly aligned with the capacity target:

- 1000 daily active users
- 200 creators
- ~50 users + ~50 creators online simultaneously

and compare the current state against prior frontend documents.

---

## Documents Compared

Primary frontend docs:

1. `frontend/docs/FLUTTER_FRONTEND_CAPACITY_ASSESSMENT_1000_DAU.md`
2. `frontend/docs/FRONTEND_REMEDIATION_IMPLEMENTATION_VERIFICATION.md`
3. `frontend/docs/FRONTEND_UI_AUDIT_REPORT.md`

Supporting platform/system docs reviewed for consistency:

- `docs/VIDEO_CALL_GO_LIVE_READINESS_DEEP_DIVE.md`
- `docs/VIDEO_CALL_200_USERS_200_CREATORS_ANALYSIS.md`

---

## Verification Method

Code-focused checks were performed on the exact capacity-sensitive paths:

- feed data loading and ordering:
  - `frontend/lib/features/home/providers/home_provider.dart`
  - `backend/src/modules/creator/creator.controller.ts`
- realtime availability update behavior:
  - `frontend/lib/features/home/providers/availability_provider.dart`
  - `frontend/lib/app/widgets/stream_chat_wrapper.dart`
- modal/lifecycle orchestration:
  - `frontend/lib/features/home/screens/home_screen.dart`
  - `frontend/lib/app/widgets/app_lifecycle_wrapper.dart`
  - `frontend/lib/features/chat/screens/chat_screen.dart`
- affected consumer screens:
  - `frontend/lib/features/home/screens/favorite_creators_screen.dart`
  - `frontend/lib/features/chat/screens/chat_list_screen.dart`
- regression tests:
  - `frontend/test/home_provider_pagination_test.dart`
  - `frontend/test/modal_coordinator_service_test.dart`
  - `frontend/test/onboarding_flow_service_test.dart`

Validation commands executed:

- `flutter test test/home_provider_pagination_test.dart test/modal_coordinator_service_test.dart test/onboarding_flow_service_test.dart` -> passed
- `flutter analyze` on key capacity files -> no blocking errors, informational warnings only

---

## Comparison Outcome (Previous Docs vs Current Code)

## Closed Since Previous Reports

The major gaps identified in `FRONTEND_UI_AUDIT_REPORT.md` and `FRONTEND_REMEDIATION_IMPLEMENTATION_VERIFICATION.md` are now materially addressed:

1. **Backend pagination integration is implemented**
   - Frontend now uses paged async notifiers (`CreatorFeedNotifier`, `UserFeedNotifier`) with `loadMore` + `refresh`.
   - Backend `GET /creator` now supports `page`/`limit` and returns `pagination` when queried.

2. **Full-list reshuffle dependency is reduced**
   - `home_provider.dart` now contains incremental ordering state (`CreatorOrderNotifier`) instead of calling full-list shuffle on each event.

3. **Feedback modal completion semantics improved**
   - `HomeScreen` now awaits feedback dialog completion in modal request presentation path.

4. **Build-phase side effects have been moved to listeners**
   - `HomeScreen`, `ChatScreen`, and `AppLifecycleWrapper` now rely on stable `listenManual` subscriptions rather than repeating build-trigger side effects in critical paths.

5. **Performance probes and regression tests were added**
   - Reorder timing, availability events/sec, and frame-jank sampling logs are present.
   - New tests cover pagination extension and modal queue blocking behavior.

---

## Remaining Gaps Found (Important)

These are the items still left after thorough code cross-check:

### 1) Presence hydration scope is now limited by pagination (High)

- In `stream_chat_wrapper.dart`, initial availability hydration still reads:
  - `await ref.read(creatorsProvider.future)`
  - `await ref.read(usersProvider.future)`
- Since these providers are paginated, this now hydrates only the first page (default 20), not the full active population.
- Impact:
  - Status fidelity can degrade for creators/users outside first page until explicit updates arrive.
  - Risk increases under your 200 creator population.

### 2) Favorite creators view can be incomplete under paged source (High)

- `favorite_creators_screen.dart` filters favorites from the currently loaded `creatorsProvider` data only.
- With pagination, favorites beyond loaded pages are invisible unless explicitly loaded.
- Impact:
  - User-facing correctness issue (favorites appear missing).

### 3) Creator online users tab has no pagination growth path (Medium)

- `chat_list_screen.dart` (`_OnlineUsersTab`) reads `usersProvider` and filters online users, but does not load additional pages on scroll.
- Impact:
  - Creator can see only online users in loaded pages; discoverability degrades as user base grows.

### 4) Ordering rebuild heuristic may miss same-length feed changes (Medium)

- `CreatorOrderNotifier.syncCreators(...)` rebuilds only when user changes or creator count changes.
- If creator identities change while count remains same (block/unblock, replacement, or stale cache scenarios), ordering state may be stale.
- Impact:
  - Potential subtle ordering inconsistency.

### 5) Stress/integration coverage still thin (Medium)

- Current tests are strong unit checks, but there is still no real widget/integration stress test for:
  - rapid availability churn during scroll,
  - modal collision under runtime event interleaving,
  - concurrent lifecycle + chat/call transition pressure.

### 6) Profile-mode SLO validation is still pending (Medium)

- Capacity assessment checklist still leaves profile-mode benchmark gate unchecked.
- Instrumentation exists, but measured evidence is not yet documented.

---

## Current Readiness for Your Target

## Verdict

For your target (**1000 DAU / 200 creators / ~100 online simultaneous**):

- **Frontend architecture is now significantly stronger than earlier audits.**
- **Likely workable in production with moderate confidence**, assuming backend and infra remain healthy.
- **Not yet "fully closed" as production-hardened** until the remaining pagination-linked correctness issues and profile/stress verification are completed.

## Practical Risk Level

- Core call/chat/home flows: **Low-to-Moderate risk**
- Presence correctness and list completeness at scale: **Moderate risk**
- Regression confidence under bursty runtime conditions: **Moderate risk**

---

## What To Fix Next (Priority)

### P0 (Do immediately)

1. **Decouple presence hydration from paged feed providers**
   - Use dedicated lightweight ID-fetch endpoints or batched cursor sweep for hydration.
2. **Fix favorites source correctness**
   - Load favorites from dedicated backend endpoint or paginate until all favorites are represented.
3. **Add user list pagination UX for creators in online-users tab**
   - Scroll-triggered `loadMore` + deduped online filtering.

### P1

4. **Strengthen ordering invalidation logic**
   - Rebuild when creator ID set changes, not only list length.
5. **Add at least one widget/integration stress test**
   - Simulate availability event bursts while scrolling home feed.
6. **Run profile-mode benchmark pass and document numbers**
   - Capture P95 reorder cost, frame timings, and fetch latency against current SLO draft.

## Implementation Closure Update (Post-plan execution)

The P0/P1 closure items above are now implemented in code:

- Presence hydration now uses a bounded paginated ID sweep and chunked socket hydration instead of relying only on first-page providers.
- Favorites now have a dedicated paginated backend endpoint (`GET /api/v1/user/favorites/creators`) and frontend provider-backed screen.
- Creator online users tab now supports scroll-triggered pagination with dedupe before online filtering.
- Creator ordering invalidation now rebuilds on creator ID-set fingerprint changes, not only list length.
- A widget stress test was added for bursty availability updates while scrolling paginated home feed.
- API latency probes were added for `creator_page`, `user_page`, and `favorites_page` fetches.

## Profile-mode benchmark workflow

Run this pass on representative low/mid/high devices in **profile mode**:

1. Start backend and ensure `/metrics` is available if backend metrics capture is enabled.
2. Launch Flutter in profile mode and navigate through:
   - Home feed scroll (trigger loadMore repeatedly)
   - Favorites screen pagination
   - Creator online-users tab pagination
3. Capture logs for:
   - `📈 [HOME PERF] reorder=...`
   - `📈 [HOME PERF] frameJank worstFrameUs=...`
   - `📈 [API PERF] category=... latencyMs=...`
4. Compute P95 for:
   - reorder microseconds
   - frame total span microseconds
   - fetch latency milliseconds by category
5. Compare to SLO draft in `FLUTTER_FRONTEND_CAPACITY_ASSESSMENT_1000_DAU.md` and mark pass/fail.

Use companion results doc:

- `frontend/docs/FRONTEND_PROFILE_BENCHMARK_RESULTS_2026-04-22.md`

---

## Final Summary

Compared with previous docs, the major architecture blockers were genuinely resolved (pagination integration, incremental ordering, modal completion, listener-based side effects, baseline testing and instrumentation).  

What is left is mostly the second-order impact of that refactor (paginated data now being reused by flows that expected full datasets) plus missing runtime evidence.  

Once those targeted gaps are closed and profile measurements are recorded, your Flutter app will be in a much safer position to reliably sustain:

- 1000 users/day
- 200 creators
- ~50 users + ~50 creators online concurrently.


# Flutter Frontend Capacity Assessment (1000 DAU / 200 Creators / 100 Concurrent)

Date: 2026-04-22  
Scope: Static code audit of Flutter frontend runtime behavior and scalability characteristics.

## Implementation Update (2026-04-22)

The priority hardening items from this report have now been implemented in the codebase:

- Home data providers moved from full-list `FutureProvider`s to paged async notifiers with `loadMore()` and `refresh()` behavior.
- Backend pagination contract is now active for both `GET /user/list` and `GET /creator` when `page`/`limit` are provided.
- Home feed ordering is now maintained through an incremental ordering engine (online + busy partitions) instead of full-list reshuffle on each availability event.
- Post-call feedback modal now remains coordinator-owned until dialog dismissal (queue completion aligns with true lifecycle completion).
- Build-time side effects were moved to stable listeners in `HomeScreen`, `ChatScreen`, and `AppLifecycleWrapper`.
- Added performance probes for feed reorder timing, availability event throughput, and home frame jank sampling.
- Added regression tests for pagination behavior, incremental ordering behavior, and modal queue serialization.

This keeps the original audit findings for historical context while documenting the applied remediation.

## Workload Profile Evaluated

- Daily active users: ~1000 users/day
- Creator pool: ~200 creators total
- Peak online concurrently: ~50 users + ~50 creators (~100 simultaneous online clients)
- Key hot paths: home feed, realtime availability updates, modal orchestration, chat/call entry, active call billing overlays

## Executive Verdict

The Flutter frontend is **good and likely workable** for the stated load, but it is **not “perfect” yet** for production confidence at this scale.

Current implementation should handle the target numbers on typical devices, but there are still architectural gaps (especially feed pagination and list recomputation strategy) that can cause avoidable UI churn and performance volatility during realtime spikes.

## What Is Already Strong

1. Realtime architecture exists and is reasonably robust:
   - Socket reconnect + replay behavior is implemented (`SocketService`).
   - Billing has HTTP fallback when socket is unavailable.
2. Core UI hardening work is present:
   - Modal coordinator and queueing foundation are implemented.
   - Selector-based card availability (`creatorStatusProvider`) reduces per-item rebuild fan-out.
3. Startup and call paths are improved:
   - Non-dependent startup tasks are parallelized (`Future.wait` in `main.dart` / `stream_chat_wrapper.dart`).
   - Call duration watchdog is now one-shot timer based instead of high-frequency polling.
4. Media pressure has meaningful safeguards:
   - `cacheWidth` / `cacheHeight` are widely applied to network images.
   - Billing overlay cadence is 1-second and isolated by `RepaintBoundary`.

## Capacity Risks Found (Important)

### 1) No real backend pagination on home feed (High)

**Observed**
- `creatorsProvider` fetches `GET /creator` and `usersProvider` fetches `GET /user/list` as full lists.
- Home “pagination” is client-side slicing (`take(visibleCount)`), not server cursor/page loading.

**Why it matters at your target**
- For 200 creators this is manageable, but it scales poorly and increases initial payload + parse + memory on every refresh.
- Under concurrent users, backend/network pressure rises because clients repeatedly re-fetch full lists.

**Code paths**
- `lib/features/home/providers/home_provider.dart`

### 2) Full-list reorder/recompute on availability map changes (High)

**Observed**
- `homeFeedProvider` watches full `creatorAvailabilityProvider` map.
- Every availability update can trigger full `sortAndShuffleCreatorsByAvailability(...)`.
- Sorting/shuffling touches entire creator list and allocates new lists.

**Why it matters**
- With 200 creators and frequent status churn, repeated recomputation can produce frame-time spikes on low/mid devices.
- This is the biggest frontend-side scaling bottleneck in your current target scenario.

**Code paths**
- `lib/features/home/providers/home_provider.dart`
- `lib/features/home/utils/creator_shuffle_utils.dart`

### 3) Availability state updates clone full maps per event (Medium)

**Observed**
- `updateSingle` and `updateBatch` create new `Map<String, CreatorAvailability>` states.
- This is fine functionally, but event bursts increase allocation churn.

**Why it matters**
- At 200 creators this is still likely acceptable, but sustained high-frequency status storms can increase GC pressure.

**Code path**
- `lib/features/home/providers/availability_provider.dart`

### 4) Modal flow still has a coordinator completion gap in feedback path (Medium)

**Observed**
- Feedback prompt is enqueued through modal coordinator, but presenter calls `_showPostCallFeedbackDialog(...)` and returns immediately.
- Coordinator marks request complete before actual dialog dismissal.

**Why it matters**
- Can reintroduce modal collision timing edge cases under busy usage (post-call + other queued prompts).

**Code path**
- `lib/features/home/screens/home_screen.dart`

### 5) Build-phase side effects still exist in hot screens (Medium)

**Observed**
- `HomeScreen.build` and other screens still schedule side effects via `addPostFrameCallback` based on watched state.
- This pattern is controlled but can still duplicate UI intents under rebuild churn if state transitions race.

**Why it matters**
- Not a guaranteed failure, but this pattern is sensitive under high event frequency and is harder to reason about.

**Code paths**
- `lib/features/home/screens/home_screen.dart`
- `lib/app/widgets/app_lifecycle_wrapper.dart`
- `lib/features/chat/screens/chat_screen.dart` (similar post-frame state reset pattern)

### 6) Regression safety coverage is still thin for scale scenarios (Medium)

**Observed**
- Test suite currently includes modal coordinator unit tests and onboarding flow unit tests.
- Missing integration/perf smoke tests for feed churn, modal collision under stress, and call/chat concurrency.

**Why it matters**
- Without automation around load-like scenarios, production regressions are harder to catch before release.

**Code paths**
- `test/modal_coordinator_service_test.dart`
- `test/onboarding_flow_service_test.dart`

## Suitability for Your Target Load

### For 1000 users/day
Likely **yes**, assuming backend is healthy and devices are mostly modern.

### For 200 creators total
Likely **yes**, but you are already near the range where full-list fetch + full-list reorders should be replaced by real pagination/incremental strategies.

### For ~50 users and ~50 creators online concurrently
Likely **mostly yes**, with **moderate risk** of occasional UI jank during high availability event churn (not guaranteed failure, but avoidable).

## Final Readiness Rating

- Current readiness: **7/10**
- Can it run your target? **Probably yes**
- Is it “perfect” for that target? **No**
- Primary blockers to “perfect”:  
  1) real backend pagination,  
  2) reduced full-list recomputation on availability events,  
  3) modal completion consistency + stress tests.

## Priority Fix Plan (Before Calling It Production-Hardened)

### P0 (Do first)
1. Implement API-backed pagination for creators/users (`loadInitial`, `loadMore`, cursor/page model).
2. Refactor feed computation:
   - Keep stable base list provider.
   - Move to incremental/affected-entry reorder logic for availability updates.
3. Make post-call feedback dialog coordinator-aware end-to-end (complete only after actual dismissal).

### P1
1. Add perf instrumentation:
   - feed recompute duration histogram
   - availability events/sec
   - frame timing sampling on home screen
2. Add integration smoke tests:
   - modal collision sequences
   - availability churn with scrolling
   - post-call feedback + coin popup race scenarios

### P2
1. Reduce build-side effect patterns where feasible (move orchestration to listeners/services with explicit transitions).
2. Add documented SLO thresholds (example: P95 home feed build/recompute budget in profile mode).

## Release Gate Checklist (Recommended)

Do not call this “perfect for target scale” until all pass:

- [x] Home feed uses backend pagination (not just client slicing)
- [x] Availability updates no longer depend on full-list reshuffle each event
- [x] Modal feedback completion is coordinator-consistent with dialog dismissal
- [x] Chat and call entry remain responsive under concurrent notification + lifecycle events (build-side effect listeners migrated)
- [x] Automated regression tests exist for pagination + modal queue serialization + ordering updates
- [ ] Profile-mode run captured and validated against budgets on representative low/mid/high devices

## Performance Budgets (SLO Draft)

These thresholds are now explicitly defined as release targets for the home experience:

- Home feed incremental reorder: P95 <= 6ms in profile mode on mid-tier devices.
- Availability event processing: sustained 20 events/sec without dropped interaction responsiveness.
- Home screen frame budget: P95 frame total span <= 16.6ms under synthetic availability churn while scrolling.
- Pagination fetch latency (home feed): P95 <= 400ms on stable network; timeout/error rate <= 2% per 5-minute window in profile testing.

## Assessment Method Notes

- This is a static code-based capacity analysis.
- No live load test or runtime profiling data was executed as part of this report.
- Final production confidence should include profile-mode measurements on representative low/mid/high devices.


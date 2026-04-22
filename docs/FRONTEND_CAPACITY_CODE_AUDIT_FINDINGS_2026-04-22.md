# Frontend Capacity Code Audit Findings (2026-04-22)

## Scope and target

This audit compares:

- `frontend/docs/FRONTEND_CAPACITY_COMPARATIVE_VERIFICATION_2026-04-22.md`
- `frontend/docs/FLUTTER_FRONTEND_CAPACITY_ASSESSMENT_1000_DAU.md`

against current implementation in frontend and backend capacity-sensitive paths for the target:

- 1000 daily active users
- 200 creators
- ~50 users + ~50 creators online simultaneously

## Executive verdict

The current codebase is materially improved and appears operationally suitable for the target with moderate confidence, but it is not fully production-closed until profile-mode benchmark numbers are captured and reviewed against SLO thresholds.

Current status:

- Architecture and correctness gaps from the prior audit are largely implemented.
- Pagination, presence hydration behavior, favorites correctness source, online-users discoverability, and ordering invalidation have all been strengthened.
- There is still no measured benchmark evidence in the docs (results template exists, but is unfilled).

## Document-to-code comparison

### 1) Comparative verification doc consistency

`frontend/docs/FRONTEND_CAPACITY_COMPARATIVE_VERIFICATION_2026-04-22.md` currently contains two conflicting states:

- A historical "Remaining Gaps Found" section that says gaps are unresolved.
- A later "Implementation Closure Update" section that says those items were implemented.

Code review confirms the closure update is the accurate current state, while the earlier "Remaining Gaps" section is now stale context.

### 2) Capacity assessment doc alignment

`frontend/docs/FLUTTER_FRONTEND_CAPACITY_ASSESSMENT_1000_DAU.md` is mostly aligned directionally, but some older risk statements are now partially outdated due to recent fixes already present in code (especially favorites correctness source and online-users pagination behavior).

## Code findings by planned closure item

### P0-1 Presence hydration decoupled from first-page providers

Verified in:

- `frontend/lib/features/home/services/presence_hydration_service.dart`
- `frontend/lib/app/widgets/stream_chat_wrapper.dart`

What is implemented:

- Bounded paginated sweep for creator/user Firebase UIDs.
- Chunked socket hydration dispatch to avoid oversized payloads.
- Fallback to first-page provider hydration if sweep fails.

Assessment:

- Improvement is real and directly addresses prior first-page-only hydration behavior.
- Guardrails are present (`max pages`, `batch size`, fallback path).
- Remaining concern: cap-based sweep can still miss very large catalogs beyond cap, though this is acceptable for current target scale.

### P0-2 Favorites source correctness moved to dedicated endpoint

Verified in:

- `backend/src/modules/user/user.controller.ts`
- `backend/src/modules/user/user.routes.ts`
- `frontend/lib/features/home/providers/favorite_creators_provider.dart`
- `frontend/lib/features/home/screens/favorite_creators_screen.dart`

What is implemented:

- New endpoint: `GET /api/v1/user/favorites/creators`.
- Frontend favorites screen now consumes dedicated paginated favorites provider.
- Availability seeding still occurs from response data.

Assessment:

- Correctness issue from filtering only loaded creator pages is resolved.
- UX now supports incremental loading and refresh behavior.
- Endpoint uses user favorites as source of truth, which is the right contract for this use case.

### P0-3 Online users tab pagination and dedupe

Verified in:

- `frontend/lib/features/chat/screens/chat_list_screen.dart`

What is implemented:

- Scroll controller in `_OnlineUsersTabState`.
- Near-end trigger calls `usersProvider.loadMore()` with pagination meta checks.
- Deduplication before online filtering.

Assessment:

- Discoverability and list growth behavior for creator online-users tab is improved.
- This is aligned with capacity needs for larger user lists.

### P1-4 Ordering invalidation strengthened

Verified in:

- `frontend/lib/features/home/providers/home_provider.dart`

What is implemented:

- `CreatorOrderNotifier.syncCreators(...)` now uses creator ID fingerprint + user ID checks instead of count-only invalidation.

Assessment:

- Same-length identity swap stale-order risk is reduced.
- Behavior is materially safer under replacement and cache-change scenarios.

### P1-5 Stress test coverage added

Verified in:

- `frontend/test/home_feed_availability_stress_widget_test.dart`

What is implemented:

- Burst availability updates while scrolling paginated feed.
- Assertions on uniqueness and pagination completion.

Assessment:

- Better than previous unit-only posture.
- Still widget-level, not full device integration; acceptable as incremental hardening.

### P1-6 Profile benchmark instrumentation and workflow

Verified in:

- `frontend/lib/core/api/api_client.dart`
- `frontend/docs/FRONTEND_CAPACITY_COMPARATIVE_VERIFICATION_2026-04-22.md`
- `frontend/docs/FRONTEND_PROFILE_BENCHMARK_RESULTS_2026-04-22.md`

What is implemented:

- API latency probe logs categorized for creator/user/favorites paging paths.
- Benchmark workflow documented.
- Results template created.

Assessment:

- Instrumentation and process are in place.
- Hard evidence is still missing because results are not populated yet.

## Validation status observed

Previously reported and consistent with current state:

- Frontend targeted tests pass, including new stress test.
- Backend tests pass.
- `flutter analyze` still reports non-blocking info-level issues across repo; no blocking regressions found in changed paths.

## Readiness for your target workload

For your stated requirement:

- 1000 users/day
- 200 creators
- 50 users + 50 creators online simultaneously

Practical readiness:

- Likely workable now for production with moderate confidence.
- Main blocker to "fully closed/hardened" status is missing benchmark evidence, not missing core architecture fixes.

## Remaining risks

1. Evidence gap:
   - Profile-mode numbers are not yet captured in `FRONTEND_PROFILE_BENCHMARK_RESULTS_2026-04-22.md`.

2. Startup hydration tradeoff:
   - Bounded sweep is safer than full sweep, but could under-hydrate if future catalog size materially exceeds current assumptions.

3. Test scope:
   - Stress testing improved, but there is still no end-to-end integration harness validating full runtime interactions on real devices.

## Recommended next steps (to close confidently)

1. Run profile benchmark passes on low/mid/high devices and fill:
   - `reorder_p95_us`
   - `frame_total_p95_us`
   - `creator_page/user_page/favorites_page latency p95`

2. Explicitly mark pass/fail versus SLO thresholds in:
   - `frontend/docs/FRONTEND_PROFILE_BENCHMARK_RESULTS_2026-04-22.md`

3. Clean up document drift in:
   - `frontend/docs/FRONTEND_CAPACITY_COMPARATIVE_VERIFICATION_2026-04-22.md`
   by clearly separating historical findings from current state to avoid contradictory reads.

## Final conclusion

Compared to the earlier state, the core frontend/backend capacity hardening tasks are now implemented and materially improve correctness and scalability behavior at your target profile.

The app is close to production-hardened for your target, but final confidence should come from completed profile benchmark evidence rather than static code inspection alone.

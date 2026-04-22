# Frontend Profile Benchmark Results (2026-04-22)

## Scope

- Build mode: `profile`
- Targets:
  - Home feed reorder performance
  - Home frame timing under availability churn while scrolling
  - Pagination fetch latency for creator/user/favorites paths

## Device Matrix

- Low-tier device: `TODO`
- Mid-tier device: `TODO`
- High-tier device: `TODO`

## Run Notes

- Backend environment: `TODO`
- Network conditions: `TODO`
- Data volume used: `TODO`
- Test duration per run: `TODO`

## Raw Log Keys

- Reorder: `📈 [HOME PERF] reorder=...`
- Frame timing: `📈 [HOME PERF] frameJank worstFrameUs=...`
- API latency: `📈 [API PERF] category=... latencyMs=...`

## Aggregated Metrics (Fill after run)

- `reorder_p95_us`: `TODO`
- `frame_total_p95_us`: `TODO`
- `creator_page_latency_p95_ms`: `TODO`
- `user_page_latency_p95_ms`: `TODO`
- `favorites_page_latency_p95_ms`: `TODO`

## SLO Comparison

- Reorder P95 <= 6ms (6000us): `TODO PASS/FAIL`
- Frame P95 <= 16.6ms (16666us): `TODO PASS/FAIL`
- Pagination fetch latency P95 <= 400ms: `TODO PASS/FAIL`

## Conclusion

- Overall benchmark gate: `TODO PASS/FAIL`
- Remaining bottlenecks: `TODO`
- Follow-up actions: `TODO`

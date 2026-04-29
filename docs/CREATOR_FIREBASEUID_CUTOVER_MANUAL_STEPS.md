# Creator `firebaseUid` Cutover — Manual Steps Before Deploying

This is the operator runbook for safely eliminating the hidden fallback join (Creator → User) and making creator presence + incoming-call lookup fully O(1) on `Creator.firebaseUid`.

It assumes the code changes are already merged/built and you are preparing **staging → production** rollout.

Related docs:

- Implementation overview: [CREATOR_FEED_PERF_REFACTOR_IMPLEMENTATION.md](CREATOR_FEED_PERF_REFACTOR_IMPLEMENTATION.md)
- End-to-end “how it works”: [CREATOR_FEED_PERF_REFACTOR_HOW_EVERYTHING_WORKS.md](CREATOR_FEED_PERF_REFACTOR_HOW_EVERYTHING_WORKS.md)
- Existing ops checklist (gallery backfill + disable repair): [CREATOR_FEED_PERF_REFACTOR_MANUAL_CHECKLIST.md](CREATOR_FEED_PERF_REFACTOR_MANUAL_CHECKLIST.md)

---

## What you are trying to achieve

- **Shadow period (24–48h)**: keep the fallback join available, but log every time it would be used.
- **Cutover**: disable the fallback join via an env switch (no code change required).
- **Safety**: detect drift early and repair quickly without reintroducing hidden latency.

---

## Required environment variables (for this cutover)

### 1) Fallback join switch (the cutover lever)

- **Shadow period ON** (fallback join enabled):

```bash
ENABLE_CREATOR_UID_FALLBACK_JOIN=true
```

- **Cutover ON** (fallback join disabled):
  - unset the variable, or set it to anything other than the string `true`.

### 2) Optional (not required for the uid cutover, but often paired)

- If you already ran gallery URL backfill and want to skip repair-on-read:

```bash
DISABLE_GALLERY_REPAIR_ON_READ=true
```

- If you want server-side eventual thumbnail persistence on profile reads:

```bash
ENABLE_GALLERY_THUMB_LAZY_FILL=true
```

---

## Step-by-step rollout (do staging first)

## A) Staging rollout (do this end-to-end first)

### A1) Deploy API to staging with shadow period enabled

1. Set staging env:

```bash
ENABLE_CREATOR_UID_FALLBACK_JOIN=true
```

2. Deploy/restart staging API.

### A2) Run the Creator.firebaseUid backfill (staging)

From `backend/`:

```bash
npx tsx src/scripts/backfill-creator-firebase-uids.ts
```

### A3) Verify “0 missing” in Mongo (staging)

Run all of these and require **0**:

```js
db.creators.countDocuments({ firebaseUid: { $exists: false } })
db.creators.countDocuments({ firebaseUid: null })
db.creators.countDocuments({ firebaseUid: "" })
db.creators.countDocuments({ firebaseUid: { $not: { $type: "string" } } })
db.creators.countDocuments({ firebaseUid: { $regex: /^\s*$/ } })
db.creators.countDocuments({
  $or: [
    { firebaseUid: { $exists: false } },
    { firebaseUid: null },
    { firebaseUid: "" }
  ]
})
```

If any are non-zero:
- re-run the backfill script
- investigate which write path is producing creator docs without a UID

### A4) Exercise staging traffic and check logs

During normal QA flows (home feed load, profile open, presence dots, incoming call simulation):

- Confirm you see `creator.feed.timing` and `creator.uids.timing` logs.
- Confirm `feed.query.count` logs look reasonable (Mongo 1 on miss, 0 when served from cache).
- Confirm you do **not** see repeated or sustained:
  - `creator.uid.fallback.used`

### A5) Cutover in staging (disable join)

1. Unset or change the env var:

```bash
# Either remove it, or set to not-true
ENABLE_CREATOR_UID_FALLBACK_JOIN=false
```

2. Restart staging API.
3. Re-run the same QA flows and ensure:
   - no errors
   - presence still hydrates (`/creator/uids`)
   - incoming call lookup works (`/creator/by-firebase-uid/:uid`)

---

## B) Production rollout (shadow → cutover)

### B1) Deploy API to production with shadow period enabled

1. Set production env:

```bash
ENABLE_CREATOR_UID_FALLBACK_JOIN=true
```

2. Deploy/restart production API.

### B2) Run Creator.firebaseUid backfill (production)

From `backend/`:

```bash
npx tsx src/scripts/backfill-creator-firebase-uids.ts
```

### B3) Verify “0 missing” in Mongo (production)

Run the same “0 missing” queries (must all be 0). See section A3.

### B4) Shadow period monitoring (24–48 hours)

For 24–48 hours **before cutover**, monitor:

- **Hard requirement**: `creator.uid.fallback.used` should remain **0**.

If you see any:
- Run the quick repair command (backfill again).
- Identify how the creator doc was created/modified without `firebaseUid`.
- Extend the shadow window until it stays at 0 for the full period.

### B5) Cutover in production (disable join)

1. Disable fallback join:

```bash
ENABLE_CREATOR_UID_FALLBACK_JOIN=false
```

2. Restart production API.

3. Monitor for the next hour:
   - `creator.uid.fallback.used` should be **0** (it will still log if missing UIDs exist, but it won’t run the join when disabled).
   - `missingCreatorFirebaseUidCount` in `creator.feed.timing` should be **0**.
   - `creator.uids.timing` count should be stable.

---

## Post-cutover invariant (treat violations as data corruption)

**Invariant:** Every `Creator` document must have a **non-empty string** `firebaseUid`.

- If violated, do not reintroduce joins.
- Repair data + fix write path.

### Quick repair command (safe to re-run)

```bash
cd backend
npx tsx src/scripts/backfill-creator-firebase-uids.ts
```

---

## Rollback guidance (if something goes wrong)

If you see issues after cutover (presence bugs, missing incoming-call matches, feed regressions):

1. **Do not** restore the join long-term.
2. Immediate safe mitigation options:
   - Temporarily re-enable fallback join:

```bash
ENABLE_CREATOR_UID_FALLBACK_JOIN=true
```

   - Run quick repair (backfill).
3. Root-cause:
   - find the write path creating creators without `firebaseUid`
   - add/strengthen enforcement (fail fast / error log) in that path

---

## What “done” looks like

- All Mongo verification counts are **0** in production.
- Shadow period shows **0** fallback usage for **24–48h**.
- After cutover (join disabled):
  - `missingCreatorFirebaseUidCount` remains **0**
  - incoming-call lookup works via `/creator/by-firebase-uid/:uid`
  - presence hydration works via `/creator/uids`
  - no `User.find({ _id: { $in: ... }})` patterns appear in slow query logs for feed/uids paths


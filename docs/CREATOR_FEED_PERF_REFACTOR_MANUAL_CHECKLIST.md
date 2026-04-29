# Creator Feed Performance Refactor — Manual Checklist

Use this checklist **outside the repo** (staging → production): database backfill, env vars, Firebase console, monitoring, and release coordination. Implementation details live in [CREATOR_FEED_PERF_REFACTOR_IMPLEMENTATION.md](CREATOR_FEED_PERF_REFACTOR_IMPLEMENTATION.md).

---

## 1. Pre-flight (before touching production)

- [ ] **Confirm app version in stores** (or forced update policy) so **no old clients** still call `GET /creator/` without handling **410** — or accept transient 410s until minimum version catches up.
- [ ] **Confirm Redis** is available in the target environment (`REDIS_URL` / `REDIS_PUBLIC_URL` or `REDISHOST`, etc.). Caching degrades gracefully without Redis, but you lose feed/uids/detail cache benefits.
- [ ] **Backup MongoDB** (or ensure point-in-time recovery) before running destructive or wide write scripts (backfill updates many `Creator` documents).

---

## 2. Gallery URL backfill (production-safe sequence)

Legacy gallery rows may store URLs **without** `token=`; the feed no longer repairs them at read time. Repair them **once** in the database so clients and `GET /creator/:id` do not depend on Storage repair-on-read.

1. [ ] **Staging first**: from [backend](../../backend) with staging `MONGO_URI` (and Firebase admin credentials matching that project):

   ```bash
   cd backend
   npm run backfill:gallery-urls
   ```

2. [ ] **Review logs**: note any per-creator errors (missing objects, permission issues). Fix data or IAM before repeating on production.

3. [ ] **Production**: run the same command against production `MONGO_URI` during a low-traffic window if the script touches many documents.

4. [ ] **Spot-check**: pick a few creators in Mongo; confirm `galleryImages[].url` values include `token=` where expected.

**Script location**: [backend/src/scripts/backfill-gallery-urls.ts](../../backend/src/scripts/backfill-gallery-urls.ts)

---

## 3. Disable gallery repair-on-read (after backfill)

When (and only when) you are confident URLs are persisted:

- [ ] Set on the **API server** environment:

  ```bash
  DISABLE_GALLERY_REPAIR_ON_READ=true
  ```

- [ ] **Redeploy** or restart the Node process so `process.env` picks it up.

- [ ] **Smoke-test** `GET /creator/:id` with a valid Bearer token: gallery images still load; new uploads still go through **`commitGalleryImage`** (which uses Storage at write time).

**Rollback**: remove the variable or set to anything other than the string `true` to re-enable repair-on-read for emergencies.

---

## 4. Firebase Resize Images extension (optional but recommended)

Thumbnails reduce bandwidth and improve perceived profile speed.

- [ ] In **Firebase Console → Extensions**, install **Resize Images** (or your team’s equivalent pipeline).
- [ ] Configure paths and sizes per [FIREBASE_RESIZE_IMAGES.md](FIREBASE_RESIZE_IMAGES.md) (e.g. `100x100`, `400x400` suffixes aligned with `buildResizedStoragePath` in the backend).
- [ ] **Upload a test gallery image**, wait for the extension to generate resized objects, then **commit again** or open profile — `thumbnailUrl` may populate on next commit once the resized file exists.

---

## 5. Monitoring and validation

- [ ] **Logs**: watch for `creator.feed.timing`, `creator.uids.timing`, `creator.detail.timing` after deploy; confirm `cacheHit: true` appears under steady traffic when Redis is on.
- [ ] **Redis counters** (optional): `GET creator:feed:metrics:hits` and `GET creator:feed:metrics:misses` to sanity-check cache effectiveness.
- [ ] **Flutter debug** (dev builds): `📈 [API PERF] category=creator_feed|creator_uids|creator_detail` lines when exercising home + profile + login.
- [ ] **Load smoke** (optional): e.g. `autocannon` against `/creator/feed?page=1&limit=20` with a real `Authorization: Bearer <firebase-id-token>` header — see notes in [PERF_HOME_AND_CREATOR_PROFILE_LOADING.md](PERF_HOME_AND_CREATOR_PROFILE_LOADING.md).

---

## 6. Automated tests (CI or local)

Run after any backend/frontend change touching these paths:

- [ ] Backend: `cd backend && npm test` (includes `creator-feed.contract.test.ts`).
- [ ] Frontend examples:

  ```bash
  cd frontend
  flutter test test/home_provider_pagination_test.dart
  flutter test test/presence_hydration_service_test.dart
  flutter test test/home_feed_availability_stress_widget_test.dart
  ```

---

## 7. Documentation hygiene (optional)

- [ ] Update any **internal runbooks** or **API client docs** that still reference `GET /creator?page=` as the home catalog — replace with **`GET /creator/feed`**.
- [ ] If you maintain **OpenAPI / Postman collections**, add `feed`, `uids`, and document **410** on `GET /creator/`.

---

## 8. Rollback plan (if something goes wrong)

| Symptom | Action |
|---------|--------|
| 410 from old clients | Ship updated app faster, or temporarily restore a compatibility proxy (not in repo by default). |
| Broken gallery images after `DISABLE_GALLERY_REPAIR_ON_READ` | Unset env var; verify backfill completeness; re-run backfill for failed ids. |
| Stale catalog in UI | Lower TTL is code-level; operationally **`invalidateCreatorCatalogCaches`** runs on mutations — check admin/creator flows still hit update endpoints. |
| Redis down | App should still function; caches skipped — scale Redis or fix connectivity. |

---

## Quick “done” summary

| Step | Done when |
|------|-----------|
| Backfill | `npm run backfill:gallery-urls` clean on staging + prod |
| Env | `DISABLE_GALLERY_REPAIR_ON_READ=true` only after backfill verified |
| Firebase | Resize extension configured (optional) |
| Verify | Home load, profile open, presence dots, incoming call avatar all OK |

When all boxes are checked for your environment, the manual rollout for this refactor is complete.

# Performance Deep Dive: Slow Home Loading + Slow Creator Profile Loading

This document explains **why the user homepage feed** and **creator profile modal/page** can feel slow, based on the current frontend/backend code paths.

## TL;DR (Root Causes)

- **Backend `GET /creator` is heavy**: it resolves creator gallery image URLs by calling Firebase Storage APIs (exists/metadata) for gallery images missing a tokenized URL. This adds significant latency per creator and per image.
- **Frontend presence hydration amplifies load**: after login, the app may fetch up to **8 pages** of `/creator` (limit 50) to collect Firebase UIDs for presence—*in addition to* the home feed’s initial `/creator?page=1&limit=20`.
- **Home UI blocks on `creatorsProvider`**: skeleton grid is shown until the first `/creator` response completes.
- **Creator profile “loading” is often image-bound**: profile page itself doesn’t fetch more API data; it loads avatar + gallery images via `Image.network` with spinners.
- **Creator-facing `/user/list` has extra DB work**: includes a debug query `User.find({}).limit(10)` on every request.
- **Client API overhead**: `SharedPreferences.getInstance()` is called on every request to attach auth headers, which adds overhead during request bursts.

## Symptoms and What They Usually Mean

- **Home page takes long to show creators**: usually **slow `GET /creator?page=1&limit=20`** (backend latency or network contention).
- **Creator profile page opens but shows spinners for a long time**: usually **image CDN / Firebase Storage URL issues**, large images, or cold cache.
- **Creator home (viewing users) is slow**: often **slow `GET /user/list`**, plus any concurrent presence hydration.

---

## Architecture Overview (What Loads When)

### Home feed: data flow

- Frontend uses `creatorsProvider` (for regular users/admin-in-user-view) to fetch creators from:
  - `GET /creator?page={page}&limit={homeFeedPageSize}` (`homeFeedPageSize = 20`)
- Home screen shows a skeleton grid until `creatorsProvider` leaves loading state.

### Creator profile: data flow

- Profile UI (`_CreatorProfilePage`) is opened using the **same `CreatorModel`** already present in the home feed list.
- It does **not** fetch a separate “creator detail” endpoint by default.
- Perceived slowness is usually:
  - `Image.network(creator.photo)` and gallery thumbnails loading slowly
  - broken/unsigned Firebase Storage URLs returning 403 (spinner + error states)

### Presence hydration: extra traffic after login

- After auth, the app sweeps pages of `/creator` or `/user/list` to collect Firebase UIDs so it can request presence availability from Socket.IO in batches.
- This can create a burst of requests right when the user lands on Home.

---

## 1) Backend: Why `GET /creator` Can Be Slow (Primary Bottleneck)

### What happens today

The `GET /creator` handler:

- Loads creators from Mongo (`Creator.find`)
- Builds a **userId → firebaseUid** map via an additional query on `User`
- For every creator, it calls `resolveGalleryImageUrlsForApi(creator.galleryImages)`
  - which may call `buildPublicGalleryDownloadUrl(storagePath)`
  - which hits Firebase Storage: **`exists()` + `getMetadata()`**, plus token work
- Batch-queries Redis availability afterwards

### Why it’s expensive

If a page contains:

- \(N\) creators
- each with \(G\) gallery images lacking `token=`

Then Storage operations are roughly \(N \times G\) and each Storage call adds network round trips and rate/latency variability.

### Key code references

**Creator list endpoint performs gallery URL resolution per creator:**

```119:180:d:\zztherapy\backend\src\modules\creator\creator.controller.ts
    // Resolve gallery URLs for response only (no write-on-read in hot feed endpoint).
    const creatorsWithUserIds = await Promise.all(
      creators.map(async (creator) => {
        const { galleryImages } = await resolveGalleryImageUrlsForApi(creator.galleryImages);
        return {
          id: creator._id.toString(),
          userId: creator.userId ? creator.userId.toString() : null,
          firebaseUid: creator.userId ? (firebaseUidByUserId.get(creator.userId.toString()) ?? null) : null,
          name: creator.name,
          about: creator.about,
          photo: creator.photo,
          galleryImages,
          // ...
        };
      })
    );
```

**Gallery resolve calls Storage token/url resolution when URLs aren’t tokenized:**

```23:55:d:\zztherapy\backend\src\modules\creator\creator-gallery-resolve.ts
export async function resolveGalleryImageUrlsForApi(
  galleryImages: Parameters<typeof normalizeGalleryImages>[0],
): Promise<{ galleryImages: ReturnType<typeof normalizeGalleryImages>; urlsChanged: boolean }> {
  const normalized = normalizeGalleryImages(galleryImages);
  let urlsChanged = false;
  const resolved = await Promise.all(
    normalized.map(async (img) => {
      if (!img.storagePath || img.url.includes('token=')) {
        return img;
      }
      try {
        const url = await buildPublicGalleryDownloadUrl(img.storagePath);
        if (url !== img.url) urlsChanged = true;
        return { ...img, url };
      } catch (e) {
        // ...
        return img;
      }
    }),
  );
  return { galleryImages: normalizeGalleryImages(resolved), urlsChanged };
}
```

**Storage calls in the hot path:**

```87:100:d:\zztherapy\backend\src\modules\creator\creator-gallery.storage.ts
export async function buildPublicGalleryDownloadUrl(storagePath: string): Promise<string> {
  const bucketName = getStorageBucketName();
  const file = getBucket().file(storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new Error(`Gallery object not found: ${storagePath}`);
  }

  const [meta] = await file.getMetadata();
  const existingRaw = meta.metadata?.firebaseStorageDownloadTokens;
  // ...
}
```

---

## 2) Frontend: Presence Hydration Causes a Request Burst (Amplifier)

### What happens today

For regular users/admin-in-user-view, after auth the app:

- Calls `collectCreatorFirebaseUids()` which sweeps up to **8 pages** of `/creator` with limit 50
- Then requests Socket.IO availability in batches of 100 UIDs

### Key code references

**Presence hydration page sweep config:**

```1:78:d:\zztherapy\frontend\lib\features\home\services\presence_hydration_service.dart
const int _presenceHydrationPageSize = 50;
const int _presenceHydrationMaxPages = 8;
```

**Presence hydration hits `/creator?page=...&limit=...` repeatedly:**

```16:33:d:\zztherapy\frontend\lib\features\home\services\presence_hydration_service.dart
  Future<List<String>> collectCreatorFirebaseUids() async {
    return _collectFirebaseUids(
      pathBuilder: (page) =>
          '/creator?page=$page&limit=$_presenceHydrationPageSize',
      listSelector: (data) => data['creators'] as List? ?? const [],
    );
  }
```

**Stream wrapper bootstraps hydration after fetching auth token:**

```129:176:d:\zztherapy\frontend\lib\app\widgets\stream_chat_wrapper.dart
    if (role != 'creator') {
      Future<void>(() async {
        try {
          final ids = await ref
              .read(presenceHydrationServiceProvider)
              .collectCreatorFirebaseUids();
          if (!mounted) return;
          _requestCreatorAvailabilityInChunks(ids);
        } catch (e) {
          // fallback...
        }
      });
    }
```

### Why it makes Home feel slower

Even if the home feed only needs the first page of creators, the backend is simultaneously processing multiple additional `/creator` requests for hydration. Since `/creator` is heavy (gallery URL resolution), this burst can:

- increase backend CPU + I/O contention
- increase Firebase Storage API load
- increase p95/p99 latency for the *first* page the UI needs

---

## 3) UI: Home “Loading” is Waiting on `creatorsProvider`

Home shows a skeleton grid while `creatorsProvider` is loading.

```1422:1444:d:\zztherapy\frontend\lib\features\home\screens\home_screen.dart
  Widget _buildHomeFeedContent(
    List<dynamic> items,
    ColorScheme scheme,
    bool isCreator,
  ) {
    // Show loading state while creators are being fetched
    final creatorsAsync = ref.watch(creatorsProvider);
    final isLoading = creatorsAsync.isLoading;

    if (isLoading) {
      return GridView.builder(
        // skeleton tiles...
      );
    }
    // ...
  }
```

So any delay in the first `/creator` request maps directly to “Home loading slow”.

---

## 4) Creator Profile Page: “Slow” Usually Means Slow Images

The creator profile page uses `Image.network` for:

- the creator avatar
- the gallery image thumbnails

If the image URLs are large, cold-cache, invalid, or subject to high-latency, the UI shows spinners.

**Avatar network image:**

```606:641:d:\zztherapy\frontend\lib\features\home\widgets\home_user_grid_card.dart
                          child: Image.network(
                            creator.photo,
                            fit: BoxFit.cover,
                            cacheWidth:
                                (100 * MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                            cacheHeight:
                                (100 * MediaQuery.of(context).devicePixelRatio)
                                    .round(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return ColoredBox(
                                color: scheme.surfaceContainerHigh,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
```

**Gallery grid thumbnails:**

```731:770:d:\zztherapy\frontend\lib\features\home\widgets\home_user_grid_card.dart
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  cacheWidth: (140 * MediaQuery.of(context).devicePixelRatio).round(),
                                  cacheHeight: (180 * MediaQuery.of(context).devicePixelRatio).round(),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return ColoredBox(
                                      color: scheme.surfaceContainerHigh,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: scheme.surfaceContainerHigh,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
```

---

## 5) Creator-facing `/user/list` Has Avoidable DB Work

The `GET /user/list` handler runs a debug query and logs it every request.

```1055:1060:d:\zztherapy\backend\src\modules\user\user.controller.ts
    // Debug: Check all users in database
    const allUsersDebug = await User.find({}).select('firebaseUid role username').limit(10);
    console.log(`🔍 [USER] Debug - All users in DB (first 10):`);
    allUsersDebug.forEach((u) => {
      console.log(`   - ${u.firebaseUid}: role=${u.role}, username=${u.username || 'N/A'}`);
    });
```

This is not needed for normal operation and adds latency to creator home loads.

---

## 6) Client API Overhead: `SharedPreferences` Read per Request

The API client loads `SharedPreferences.getInstance()` on every request to fetch the token.

```60:76:d:\zztherapy\frontend\lib\core\api\api_client.dart
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.keyAuthToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
```

During presence hydration bursts, this adds extra work and can contribute to perceived slowness.

---

## Measurement Plan (Confirm the Real Bottleneck)

### Server-side

- **Measure latency distribution** (p50/p95/p99) for:
  - `GET /creator?page=1&limit=20`
  - `GET /creator?page=1&limit=50` (presence hydration)
- Add timing breakdowns (even temporary) around:
  - Mongo fetch
  - gallery URL resolution (`resolveGalleryImageUrlsForApi`)
  - Redis availability batch (`getBatchAvailability`)

### Client-side

- Capture a timeline after login:
  - concurrent requests count
  - time to first feed render
  - image loading timings (avatar + thumbnails)
- Use Flutter DevTools Network:
  - confirm whether “slow profile” is API-bound (should not be) or image-bound

---

## Recommended Fixes (Prioritized)

### P0: Remove Firebase Storage calls from hot list endpoints

Goal: make `GET /creator` fast and predictable.

Options:

- **Stop resolving gallery URLs on `GET /creator`** (return stored URLs as-is; resolve only on creator-detail or dedicated gallery endpoint).
- **Return only the first 0–1 gallery images** (or none) in the list endpoint; load full gallery on demand.
- **Cache resolved URLs** (server-side) so Storage calls happen once per image, not on every list request.

### P0: Reduce duplicate catalog fetch during presence hydration

Goal: avoid hammering `/creator` right at login.

Options:

- Use UIDs already returned from the first feed page to seed presence, then progressively hydrate as user scrolls.
- Add a backend endpoint that returns **only firebaseUids** (no gallery resolution, no extra data) for presence hydration.

### P1: Remove debug DB query from `/user/list`

Goal: reduce creator-home load latency and DB pressure.

### P1: Cache auth token in memory in the API client

Goal: avoid `SharedPreferences.getInstance()` per request.

Implementation idea:

- Read token once on startup / on auth refresh
- Keep in an in-memory variable and update it when token changes

### P2: Improve image loading UX/perf on profile

Goal: make “profile slow” less noticeable and reduce bandwidth.

Options:

- Ensure creator `photo` and gallery URLs point to **resized/compressed** variants.
- Use stronger caching (e.g., a caching image provider package) if acceptable.
- Consider showing the profile layout immediately with placeholders, and lazy-load gallery grid below the fold.

---

## Quick Checklist for Debugging a Specific Slow Session

- Does the server log show many **`/creator/feed`** or legacy catalog requests right after login? Presence hydration should now hit **`/creator/uids` once** (not a page sweep).
- Is **`GET /creator/feed?page=1&limit=20`** slow in isolation? If yes, check Mongo + Redis availability batch; list path must **not** call Firebase Storage.
- Does the profile open instantly but images spin? If yes, focus on image URLs, **CachedNetworkImage** disk cache, and optional **Resize Images** thumbnails ([FIREBASE_RESIZE_IMAGES.md](FIREBASE_RESIZE_IMAGES.md)).
- Are creators/admin-in-creator-view seeing slow user lists? The **`/user/list`** debug `User.find({})` query was removed — re-profile if still slow.

---

## Post-refactor observability (implemented)

- **Backend**: structured `logInfo` lines `creator.feed.timing`, `creator.uids.timing`, `creator.detail.timing` (includes `cacheHit`, `mongoMs`, `availabilityMs`, `totalMs` where applicable).
- **Redis metrics**: `INCR creator:feed:metrics:hits` / `creator:feed:metrics:misses` (best-effort when Redis is configured).
- **Flutter**: `ApiClient` debug logs `category=creator_feed|creator_uids|creator_detail` for latency breakdown.
- **Backfill**: `npm run backfill:gallery-urls` then set **`DISABLE_GALLERY_REPAIR_ON_READ=true`** on the API to skip Storage repair in `GET /creator/:id`.
- **Load smoke** (optional): e.g. `npx autocannon -c 10 -d 30 http://HOST/creator/feed?page=1&limit=20` with a valid `Authorization` header.

**See also:** full implementation write-up [CREATOR_FEED_PERF_REFACTOR_IMPLEMENTATION.md](CREATOR_FEED_PERF_REFACTOR_IMPLEMENTATION.md) and operator checklist [CREATOR_FEED_PERF_REFACTOR_MANUAL_CHECKLIST.md](CREATOR_FEED_PERF_REFACTOR_MANUAL_CHECKLIST.md).


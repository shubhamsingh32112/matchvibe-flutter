# Firebase Resize Images (creator avatars + gallery)

Use the official **Firebase Extension: Resize Images** so clients receive small thumbnails without downloading originals.

## Configure the extension

1. In Firebase Console → **Extensions** → install **Resize Images**.
2. Set **Cloud Storage path for images** to include creator gallery uploads, e.g.:
   - `creators/{creatorId}/gallery/{imageId}.jpg` (match your upload paths).
3. Set **Sizes** to at least:
   - `100x100` — feed / avatar tiles  
   - `400x400` — profile gallery thumbnails  
4. Use a **suffix** before the extension (extension default), e.g. `_{width}x{height}` so files become:
   - `…/image_100x100.jpg`
   - `…/image_400x400.jpg`

The backend builds these paths via `buildResizedStoragePath()` in `creator-gallery.storage.ts` and stores `thumbnailUrl` on commit when the resized object already exists in Storage.

## Behaviour

- **Immediately after upload**: the resized object may not exist yet; `thumbnailUrl` may be `null`. The app falls back to the full `url`.
- **After the extension runs**: the next gallery commit or a profile refresh can persist `thumbnailUrl`; until then, **CachedNetworkImage** still caches the full image locally.

## Optional env

On the API server, after running `npm run backfill:gallery-urls` and verifying all gallery URLs include `token=`, set:

```bash
DISABLE_GALLERY_REPAIR_ON_READ=true
```

so `GET /creator/:id` skips Storage repair-on-read (see performance doc).

/// Decorative frame overlays for [AppAvatar].
enum AvatarDecoration {
  none,
  vip,
  creator,
  verified,
  premium,
}

/// Asset paths per decoration. Add one line when introducing a new frame.
const Map<AvatarDecoration, String?> kAvatarDecorationAssets = {
  AvatarDecoration.none: null,
  AvatarDecoration.vip: null,
  AvatarDecoration.creator: null,
  AvatarDecoration.verified: null,
  AvatarDecoration.premium: null,
};

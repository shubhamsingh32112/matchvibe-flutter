final _hashtagPattern = RegExp(r'#\w+');

/// Returns all hashtags in [caption].
List<String> extractHashtags(String? caption) {
  if (caption == null || caption.isEmpty) return const [];
  return _hashtagPattern.allMatches(caption).map((m) => m.group(0)!).toList();
}

/// Returns the first hashtag in [caption], or null if none.
String? extractFirstHashtag(String? caption) {
  if (caption == null || caption.isEmpty) return null;
  final match = _hashtagPattern.firstMatch(caption);
  return match?.group(0);
}

/// Caption text with hashtags stripped for display.
String captionWithoutHashtags(String? caption) {
  if (caption == null || caption.isEmpty) return '';
  return caption.replaceAll(_hashtagPattern, '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

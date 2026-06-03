class PlaybackRefreshException implements Exception {
  PlaybackRefreshException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isDenied => statusCode == 403 || code == 'PLAYBACK_DENIED';
  bool get isDegraded =>
      statusCode == 503 ||
      code == 'PLAYBACK_SIGNING_UNAVAILABLE' ||
      code == 'CLOUDFLARE_STREAM_UNAVAILABLE';

  @override
  String toString() => 'PlaybackRefreshException($message, status=$statusCode, code=$code)';
}

class PlaybackRefreshResult {
  const PlaybackRefreshResult({
    required this.playbackUrl,
    required this.expiresAtMs,
  });

  final String playbackUrl;
  final int expiresAtMs;
}

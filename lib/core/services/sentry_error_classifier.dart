import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:stream_chat/stream_chat.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../features/chat/exceptions/chat_send_exceptions.dart';

/// How [SentryService] should treat a captured error.
enum SentryErrorDisposition {
  report,
  drop,
  breadcrumbOnly,
  sample,
}

/// Layered error classification — type-first, string fallback for opaque SDK blobs.
class SentryErrorClassifier {
  SentryErrorClassifier._();

  static const sampleRateDnsAllowlist = 0.02;
  static const sampleRateIceTrickle = 0.08;

  static const _ignoredDnsHostFragments = {
    'chat.stream-io-api.com',
    'stream-io-video.com',
    'fonts.gstatic.com',
  };

  static final _quotedHostPattern = RegExp(
    r'''failed host lookup:\s*['"]?([a-zA-Z0-9.\-_]+)''',
    caseSensitive: false,
  );

  static final _hostInParensPattern = RegExp(
    r"host lookup:\s*([a-zA-Z0-9.\-_]+)",
    caseSensitive: false,
  );

  static SentryErrorDisposition classifyError(Object error) {
    // Layer 1 — app typed exceptions
    if (error is RestrictedContentException ||
        error is MediaAttachmentBlockedException) {
      return SentryErrorDisposition.drop;
    }

    // Layer 2 — known third-party types
    if (error is PlayerInterruptedException) {
      return SentryErrorDisposition.drop;
    }

    if (error is SocketException) {
      return _classifySocketException(error);
    }

    // Layer 3 — Stream / websocket typed errors
    final streamDisposition = _classifyStreamError(error);
    if (streamDisposition != null) {
      return streamDisposition;
    }

    if (error is WebSocketChannelException) {
      return _classifyWebSocketChannelException(error);
    }

    // Layer 4 — opaque SDK string fallback only
    return _classifyByOpaqueMessage(error);
  }

  static String buildSampleFingerprint(Object error, {String? host}) {
    final typeName = error.runtimeType.toString();
    final hostPart = host ?? tryExtractHost(error) ?? 'unknown';
    return '$typeName|$hostPart';
  }

  static bool shouldSample(String fingerprint, double rate) {
    if (rate >= 1.0) return true;
    if (rate <= 0.0) return false;
    final bucket = fingerprint.hashCode.abs() % 100;
    return bucket < (rate * 100).round();
  }

  static double sampleRateFor(Object error) {
    final disposition = classifyError(error);
    if (disposition != SentryErrorDisposition.sample) return 1.0;

    final text = error.toString().toLowerCase();
    if (text.contains('icetrickle') || text.contains('twirperror')) {
      return sampleRateIceTrickle;
    }
    return sampleRateDnsAllowlist;
  }

  static String? tryExtractHost(Object error) {
    if (error is SocketException) {
      return extractHostFromSocketMessage(error.message);
    }
    if (error is WebSocketChannelException) {
      final message = error.message;
      if (message != null && message.isNotEmpty) {
        return extractHostFromSocketMessage(message);
      }
    }
    return extractHostFromSocketMessage(error.toString());
  }

  @visibleForTesting
  static String? extractHostFromSocketMessage(String message) {
    if (message.trim().isEmpty) return null;

    final quoted = _quotedHostPattern.firstMatch(message);
    if (quoted != null && quoted.groupCount >= 1) {
      final host = quoted.group(1)?.trim();
      if (host != null && host.isNotEmpty) return host.toLowerCase();
    }

    final plain = _hostInParensPattern.firstMatch(message);
    if (plain != null && plain.groupCount >= 1) {
      final host = plain.group(1)?.trim();
      if (host != null && host.isNotEmpty) return host.toLowerCase();
    }

    return null;
  }

  static String breadcrumbCategoryFor(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('icetrickle') ||
        text.contains('twirperror') ||
        text.contains('stream-io-video')) {
      return 'call.network';
    }
    if (error is StreamChatNetworkError ||
        error is StreamWebSocketError ||
        text.contains('streamchat')) {
      return 'stream.chat.connectivity';
    }
    if (tryExtractHost(error) != null) {
      return 'connectivity.dns';
    }
    return 'connectivity';
  }

  static bool hostMatchesAllowlist(String host) {
    final lower = host.toLowerCase();
    return _ignoredDnsHostFragments.any(lower.contains);
  }

  static SentryErrorDisposition? _classifyStreamError(Object error) {
    if (error is StreamWebSocketError) {
      return SentryErrorDisposition.breadcrumbOnly;
    }

    if (error is StreamChatNetworkError) {
      final msg = error.message.toLowerCase();
      if (error.code == -1 ||
          msg.contains('connecttimeout') ||
          msg.contains('connection took longer')) {
        return SentryErrorDisposition.breadcrumbOnly;
      }
    }

    return null;
  }

  static SentryErrorDisposition _classifyWebSocketChannelException(
    WebSocketChannelException error,
  ) {
    final inner = error.inner;
    if (inner is SocketException) {
      return _classifySocketException(inner);
    }
    final message = error.message;
    if (message == null || message.isEmpty) {
      return SentryErrorDisposition.report;
    }
    final host = extractHostFromSocketMessage(message);
    if (host == null || host.isEmpty) {
      return SentryErrorDisposition.report;
    }
    if (hostMatchesAllowlist(host)) {
      return SentryErrorDisposition.sample;
    }
    return SentryErrorDisposition.report;
  }

  static SentryErrorDisposition _classifySocketException(SocketException error) {
    final msg = error.message.toLowerCase();
    if (!msg.contains('failed host lookup')) {
      return SentryErrorDisposition.report;
    }

    final host = extractHostFromSocketMessage(error.message);
    if (host == null || host.isEmpty) {
      return SentryErrorDisposition.report;
    }

    if (hostMatchesAllowlist(host)) {
      return SentryErrorDisposition.sample;
    }
    return SentryErrorDisposition.report;
  }

  static SentryErrorDisposition _classifyByOpaqueMessage(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('message contains restricted content') ||
        text.contains('only creators can send media attachments')) {
      return SentryErrorDisposition.drop;
    }

    if (text.contains('failed to load font') ||
        text.contains('fonts.gstatic.com')) {
      return SentryErrorDisposition.drop;
    }

    if (text.contains('playerinterruptedexception') ||
        (text.contains('connection aborted') && text.contains('just_audio'))) {
      return SentryErrorDisposition.drop;
    }

    if (text.contains('twirperror') &&
        text.contains('icetrickle') &&
        text.contains('connection abort')) {
      return SentryErrorDisposition.sample;
    }

    if (text.contains('streamchatnetworkerror') &&
        (text.contains('connecttimeout') || text.contains('code: -1'))) {
      return SentryErrorDisposition.breadcrumbOnly;
    }

    if (text.contains('streamwebsocketerror') ||
        text.contains('websocketchannelexception')) {
      final host = tryExtractHost(error);
      if (host != null && hostMatchesAllowlist(host)) {
        return SentryErrorDisposition.sample;
      }
      if (host == null) {
        return SentryErrorDisposition.breadcrumbOnly;
      }
      return SentryErrorDisposition.report;
    }

    if (text.contains('failed host lookup')) {
      final host = tryExtractHost(error);
      if (host == null || host.isEmpty) {
        return SentryErrorDisposition.report;
      }
      if (hostMatchesAllowlist(host)) {
        return SentryErrorDisposition.sample;
      }
      return SentryErrorDisposition.report;
    }

    return SentryErrorDisposition.report;
  }

  /// Returns true when the event should be suppressed (not sent to Sentry).
  static bool shouldSuppressEvent(Object error) {
    switch (classifyError(error)) {
      case SentryErrorDisposition.drop:
      case SentryErrorDisposition.breadcrumbOnly:
        return true;
      case SentryErrorDisposition.sample:
        final fp = buildSampleFingerprint(error, host: tryExtractHost(error));
        return !shouldSample(fp, sampleRateFor(error));
      case SentryErrorDisposition.report:
        return false;
    }
  }

  static bool shouldReportCapture(Object error) {
    return !shouldSuppressEvent(error);
  }
}

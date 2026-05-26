/// Non-reportable chat send guard exceptions (Sentry layer 1 classification).
class RestrictedContentException implements Exception {
  const RestrictedContentException();

  @override
  String toString() => 'Message contains restricted content';
}

class MediaAttachmentBlockedException implements Exception {
  const MediaAttachmentBlockedException();

  @override
  String toString() => 'Only creators can send media attachments';
}

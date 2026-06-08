/// Formats view counts like 12.4K for creator home media grid.
String formatViewCount(int count) {
  if (count >= 1000000) {
    final m = count / 1000000;
    return m >= 10 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    final k = count / 1000;
    return k >= 10 ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
  }
  return count.toString();
}

String formatCreatorOnlineMinutes(int seconds) {
  final minutes = seconds ~/ 60;
  return '$minutes min';
}

String formatRelativeStoryTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dateTime.day}/${dateTime.month}';
}

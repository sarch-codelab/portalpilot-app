String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'hace s';
  if (diff.inMinutes < 60) return 'hace m';
  if (diff.inHours < 24) return 'hace h';
  if (diff.inDays < 7) return 'hace d';
  return '//';
}

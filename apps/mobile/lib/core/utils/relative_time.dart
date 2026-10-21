String formatRelativeTime(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final current = now ?? DateTime.now();
  final local = date.toLocal();
  var seconds = current.difference(local).inSeconds;
  if (seconds < 0) seconds = 0;
  if (seconds < 60) return 'now';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h';
  final days = hours ~/ 24;
  if (days < 7) return '${days}d';
  final weeks = days ~/ 7;
  if (weeks < 5) return '${weeks}w';
  final months = days ~/ 30;
  if (months < 12) return '${months}mo';
  final years = days ~/ 365;
  return '${years}y';
}

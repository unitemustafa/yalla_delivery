/// Formats a [DateTime] as a human-readable Arabic relative-time string
/// such as "منذ 5 دقائق" or "منذ ساعتين".
class AppTimeAgo {
  AppTimeAgo._();

  /// Returns a relative-time string comparing [dateTime] to [DateTime.now].
  ///
  /// Examples: "الآن", "منذ 3 دقائق", "منذ ساعة", "منذ يومين".
  static String format(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'الآن';
    }

    if (difference.inMinutes < 60) {
      return _formatMinutes(difference.inMinutes);
    }

    if (difference.inHours < 24) {
      return _formatHours(difference.inHours);
    }

    return _formatDays(difference.inDays);
  }

  static String _formatMinutes(int minutes) {
    if (minutes == 1) return 'منذ دقيقة';
    if (minutes == 2) return 'منذ دقيقتين';
    if (minutes <= 10) return 'منذ $minutes دقائق';
    return 'منذ $minutes دقيقة';
  }

  static String _formatHours(int hours) {
    if (hours == 1) return 'منذ ساعة';
    if (hours == 2) return 'منذ ساعتين';
    if (hours <= 10) return 'منذ $hours ساعات';
    return 'منذ $hours ساعة';
  }

  static String _formatDays(int days) {
    if (days == 1) return 'منذ يوم';
    if (days == 2) return 'منذ يومين';
    if (days <= 10) return 'منذ $days أيام';
    return 'منذ $days يوم';
  }
}

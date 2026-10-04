import '../texts/app_texts.dart';

/// Formats a [DateTime] as a relative-time string from [TimeTexts].
class AppTimeAgo {
  AppTimeAgo._();

  /// Returns a relative-time string comparing [dateTime] to [DateTime.now].
  static String format(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 60) {
      return TimeTexts.now;
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
    if (minutes == 1) return TimeTexts.oneMinuteAgo;
    if (minutes == 2) return TimeTexts.twoMinutesAgo;
    if (minutes <= 10) return TimeTexts.minutesAgo(minutes);
    return TimeTexts.minutesAgoSingular(minutes);
  }

  static String _formatHours(int hours) {
    if (hours == 1) return TimeTexts.oneHourAgo;
    if (hours == 2) return TimeTexts.twoHoursAgo;
    if (hours <= 10) return TimeTexts.hoursAgo(hours);
    return TimeTexts.hoursAgoSingular(hours);
  }

  static String _formatDays(int days) {
    if (days == 1) return TimeTexts.oneDayAgo;
    if (days == 2) return TimeTexts.twoDaysAgo;
    if (days <= 10) return TimeTexts.daysAgo(days);
    return TimeTexts.daysAgoSingular(days);
  }
}

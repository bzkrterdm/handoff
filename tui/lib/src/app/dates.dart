import 'strings.dart';

/// Short, human dates, worded like the desktop app: "Today 11:00",
/// "Yesterday 17:40", "28 Sep", "3 Jan 2025".
abstract class DateText {
  static String relative(DateTime value, Strings strings, {DateTime? now}) {
    final local = value.toLocal();
    final today = _day(now ?? DateTime.now());
    final day = _day(local);
    final time = _time(local);

    if (day == today) return '${strings('date_today')} $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return '${strings('date_yesterday')} $time';
    }
    final month = _month(local.month, strings);
    if (day.year == today.year) return '${local.day} $month';

    return '${local.day} $month ${local.year}';
  }

  /// "29 Sep 2026, 11:00" for the details.
  static String full(DateTime value, Strings strings) {
    final local = value.toLocal();

    return '${local.day} ${_month(local.month, strings)} ${local.year}, '
        '${_time(local)}';
  }

  // Helpers
  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _time(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _month(int month, Strings strings) {
    final names = strings.months;

    return names.length == 12 ? names[month - 1] : '$month';
  }

  // - Helpers
}

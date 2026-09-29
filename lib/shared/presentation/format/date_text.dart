import '../../../stack/core/localization/translate.dart';

/// Short, human dates for lists: "Bugün 11:00", "Dün 17:40", "28 Eyl",
/// "3 Oca 2025". Month names come from the translation file so no locale
/// data needs initialising.
abstract class DateText {
  static String relative(DateTime value, {DateTime? now}) {
    final local = value.toLocal();
    final today = _day(now ?? DateTime.now());
    final day = _day(local);
    final time = _time(local);

    if (day == today) return '${trt('date_today')} $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return '${trt('date_yesterday')} $time';
    }
    final month = _month(local.month);
    if (day.year == today.year) return '${local.day} $month';

    return '${local.day} $month ${local.year}';
  }

  /// "29 Eyl 2026, 11:00" for detail views.
  static String full(DateTime value) {
    final local = value.toLocal();

    return '${local.day} ${_month(local.month)} ${local.year}, ${_time(local)}';
  }

  // Helpers
  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _time(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}';

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _month(int month) {
    final names = trt('months_short').split(',');

    return names.length == 12 ? names[month - 1] : '$month';
  }

  // - Helpers
}

class AppDateFormatters {
  static const _months = [
    'janv',
    'févr',
    'mars',
    'avr',
    'mai',
    'juin',
    'juil',
    'août',
    'sept',
    'oct',
    'nov',
    'déc',
  ];

  static String formatShortDate(DateTime date) {
    final month = _months[date.month - 1];
    return '${date.day} $month ${date.year}';
  }

  static String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatDateTimeLabel(DateTime date) {
    return '${formatShortDate(date)} à ${formatTime(date)}';
  }

  static bool isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) {
    return isSameCalendarDay(date, DateTime.now());
  }

  static bool isTomorrow(DateTime date) {
    return isSameCalendarDay(
      date,
      DateTime.now().add(const Duration(days: 1)),
    );
  }

  static bool isPastDay(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return normalized.isBefore(normalizedToday);
  }

  static bool isFutureDay(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return normalized.isAfter(normalizedToday);
  }
}
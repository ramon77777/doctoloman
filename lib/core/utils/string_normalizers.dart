class StringNormalizers {
  static String normalizeLoose(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String collapseSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String normalizePhoneCi(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';

    if (raw.startsWith('+')) {
      final digits = digitsOnly(raw.substring(1));

      if (digits.startsWith('225') && digits.length == 13) {
        return '+$digits';
      }

      if (digits.length == 10) {
        return '+225$digits';
      }

      return '+$digits';
    }

    final digits = digitsOnly(raw);

    if (digits.startsWith('225') && digits.length == 13) {
      return '+$digits';
    }

    if (digits.length == 10) {
      return '+225$digits';
    }

    if (digits.startsWith('0') && digits.length == 11) {
      return '+225${digits.substring(1)}';
    }

    return '+$digits';
  }

  static bool isValidCiPhone(String input) {
    final normalized = normalizePhoneCi(input);
    return RegExp(r'^\+225\d{10}$').hasMatch(normalized);
  }
}
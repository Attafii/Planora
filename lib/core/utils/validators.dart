class Validators {
  static String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
  static String? email(String? value) =>
      value == null ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? 'Enter a valid email address.'
      : null;
  static String? password(String? value) => value == null || value.length < 10
      ? 'Use at least 10 characters.'
      : value.length > 128
      ? 'Use at most 128 characters.'
      : null;
  static String? minutes(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n < 1 || n > 1440 ? 'Enter 1–1440 minutes.' : null;
  }

  static String? date(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final d = DateTime.tryParse(value);
    return !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
            d == null ||
            d.toIso8601String().substring(0, 10) != value
        ? 'Use a real date: YYYY-MM-DD.'
        : null;
  }
}

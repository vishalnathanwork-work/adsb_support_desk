class PasswordValidator {
  /// Minimum length for new passwords.
  static const int minLength = 6;

  /// Returns null if valid, otherwise an error message.
  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// 0..4 strength score — kept for the visual bar.
  static int strength(String value) {
    if (value.isEmpty) return 0;
    int score = 0;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    return score.clamp(0, 4);
  }
}
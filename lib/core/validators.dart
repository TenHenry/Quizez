/// Form validators. Each returns an error message, or null when the value is valid.
class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static final _nickname = RegExp(r'^[A-Za-z0-9_.]+$');

  static const minPasswordLength = 8;

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your e-mail address';
    if (!_email.hasMatch(v)) return 'Enter a valid e-mail address';
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return 'Enter a password';
    if (value.length < minPasswordLength) return 'Use at least $minPasswordLength characters';
    if (!value.contains(RegExp(r'[A-Za-z]')) || !value.contains(RegExp(r'[0-9]'))) {
      return 'Use letters and digits';
    }
    return null;
  }

  static String? confirmPassword(String value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? nickname(String value) {
    final v = value.trim();
    if (v.length < 3 || v.length > 20) return 'Use 3-20 characters';
    if (!_nickname.hasMatch(v)) return 'Use only letters, digits, "_" and "."';
    return null;
  }
}

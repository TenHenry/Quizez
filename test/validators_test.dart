import 'package:flutter_test/flutter_test.dart';
import 'package:quizez/core/validators.dart';

void main() {
  group('email', () {
    test('accepts a normal address', () => expect(Validators.email('a.b@domain.com'), isNull));
    test('rejects empty and malformed values', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
  });

  group('password', () {
    test('accepts letters and digits, 8+ characters', () => expect(Validators.password('abcd1234'), isNull));
    test('rejects short passwords', () => expect(Validators.password('ab12'), isNotNull));
    test('rejects passwords without digits or letters', () {
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
    });
  });

  test('confirmPassword compares both values', () {
    expect(Validators.confirmPassword('x', 'x'), isNull);
    expect(Validators.confirmPassword('x', 'y'), isNotNull);
  });

  group('nickname', () {
    test('accepts 3-20 safe characters', () => expect(Validators.nickname('Marcin_01'), isNull));
    test('rejects too short, too long and special characters', () {
      expect(Validators.nickname('ab'), isNotNull);
      expect(Validators.nickname('a' * 21), isNotNull);
      expect(Validators.nickname('bad name!'), isNotNull);
    });
  });
}

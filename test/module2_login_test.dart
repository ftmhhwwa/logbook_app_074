import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_074/features/auth/login_controller.dart';

void main() {
  Object actual, expected;

  group('Module 2 - LoginController Test', () {
    late LoginController controller;

    setUp(() {
      controller = LoginController();
    });

    test('TC01: login should return true for valid credentials', () {
      actual = controller.login('admin', '123');
      expected = true;

      expect(
        actual,
        expected,
        reason: 'Expected login to succeed for admin/123',
      );
    });

    test('TC02: login should return false for invalid password', () {
      actual = controller.login('admin', 'salah_password');
      expected = false;

      expect(
        actual,
        expected,
        reason: 'Expected login to fail for wrong password',
      );
    });

    test('TC03: login should return false for unregistered user', () {
      actual = controller.login('user_gelap', '123');
      expected = false;

      expect(
        actual,
        expected,
        reason: 'Expected login to fail for unknown user',
      );
    });

    test('TC04: getUserRole should return Ketua for admin', () {
      actual = controller.getUserRole('admin');
      expected = 'Ketua';

      expect(actual, expected, reason: 'Expected role to be Ketua for admin');
    });

    test(
      'TC05: getUserRole should return default Anggota for unknown user',
      () {
        actual = controller.getUserRole('user_gelap');
        expected = 'Anggota';

        expect(
          actual,
          expected,
          reason: 'Expected default role Anggota for unknown user',
        );
      },
    );
  });
}

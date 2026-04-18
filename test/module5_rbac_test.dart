import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/services/access_control_service.dart';

void main() {
  bool actual, expected;

  group('Module 5 - Access Control (RBAC) Test', () {
    test('TC01: Ketua can delete any log (even if not owner)', () {
      actual = AccessControlService.canPerform(
        'Ketua',
        'delete',
        isOwner: false,
      );
      expected = true;

      expect(
        actual,
        expected,
        reason: 'Role Ketua harusnya memiliki izin bypass untuk delete',
      );
    });

    test('TC02: Anggota cannot delete non-owned log', () {
      actual = AccessControlService.canPerform(
        'Anggota',
        'delete',
        isOwner: false,
      );
      expected = false;

      expect(
        actual,
        expected,
        reason: 'Role Anggota tidak boleh menghapus data milik orang lain',
      );
    });

    test('TC03: Anggota can update their own log', () {
      actual = AccessControlService.canPerform(
        'Anggota',
        'update',
        isOwner: true,
      );
      expected = true;

      expect(
        actual,
        expected,
        reason: 'Role Anggota harusnya boleh mengedit datanya sendiri',
      );
    });

    test('TC04: Asisten cannot perform create action', () {
      actual = AccessControlService.canPerform('Asisten', 'create');
      expected = false;

      expect(
        actual,
        expected,
        reason: 'Role Asisten hanya untuk Read/Update, tidak boleh Create',
      );
    });
  });
}

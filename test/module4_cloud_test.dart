import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_074/features/logbook/models/log_model.dart';
import 'package:logbook_app_074/services/mongo_service.dart';

void main() {
  bool actual, expected;

  group('Module 4 - Cloud Data Access Rules Test (MongoService)', () {
    test('TC01: isLogVisibleToUser should return true for log owner', () {
      final dummyLog = LogModel(
        title: 'Laporan Rahasia',
        description: 'Test',
        date: '2026-04-03',
        authorId: 'fatim',
        teamId: 'TIM_A',
        isPublic: false,
      );

      actual = MongoService.isLogVisibleToUser(
        dummyLog,
        currentUserId: 'fatim',
        currentUserTeamId: 'TIM_A',
      );
      expected = true;

      expect(
        actual,
        expected,
        reason: 'Pemilik (author) harus selalu bisa melihat log-nya sendiri',
      );
    });

    test(
      'TC02: isLogVisibleToUser should return true for public log in same team',
      () {
        final dummyLog = LogModel(
          title: 'Laporan Publik',
          description: 'Test',
          date: '2026-04-03',
          authorId: 'budi',
          teamId: 'TIM_A',
          isPublic: true,
        );

        actual = MongoService.isLogVisibleToUser(
          dummyLog,
          currentUserId: 'fatim',
          currentUserTeamId: 'TIM_A',
        );
        expected = true;

        expect(
          actual,
          expected,
          reason:
              'Anggota dari tim yang sama harus bisa melihat log publik temannya',
        );
      },
    );

    test(
      'TC03: isLogVisibleToUser should return false for private log of other user',
      () {
        final dummyLog = LogModel(
          title: 'Rahasia Budi',
          description: 'Test',
          date: '2026-04-03',
          authorId: 'budi',
          teamId: 'TIM_A',
          isPublic: false,
        );

        actual = MongoService.isLogVisibleToUser(
          dummyLog,
          currentUserId: 'fatim',
          currentUserTeamId: 'TIM_A',
        );
        expected = false;

        expect(
          actual,
          expected,
          reason:
              'Log private orang lain tidak boleh terlihat, meskipun satu tim',
        );
      },
    );

    test(
      'TC04: isLogVisibleToUser should return false for public log from different team',
      () {
        final dummyLog = LogModel(
          title: 'Laporan Publik Tim Lain',
          description: 'Test',
          date: '2026-04-03',
          authorId: 'agus',
          teamId: 'TIM_B',
          isPublic: true,
        );

        actual = MongoService.isLogVisibleToUser(
          dummyLog,
          currentUserId: 'fatim',
          currentUserTeamId: 'TIM_A',
        );
        expected = false;

        expect(
          actual,
          expected,
          reason:
              'Log publik hanya boleh terlihat oleh tim yang sama, beda tim harus false',
        );
      },
    );
  });
}

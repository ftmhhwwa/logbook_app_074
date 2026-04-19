import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_074/features/logbook/models/log_model.dart';
import 'package:logbook_app_074/services/mongo_service.dart';

void main() {
  test(
    'RBAC Security Check: Private logs should NOT be visible to teammates',
    () {
      // 1. Setup Data:
      // User A memiliki 2 catatan: 1 Private dan 1 Public pada tim yang sama.
      final logsFromFetch = <LogModel>[
        LogModel(
          id: 'log-private-a',
          title: 'Private A',
          date: '2026-03-28T10:00:00.000Z',
          description: 'Hanya owner yang boleh lihat',
          authorId: 'user-a',
          teamId: 'team-01',
          isPublic: false,
          isSynced: true,
        ),
        LogModel(
          id: 'log-public-a',
          title: 'Public A',
          date: '2026-03-28T11:00:00.000Z',
          description: 'Bisa terlihat oleh rekan satu tim',
          authorId: 'user-a',
          teamId: 'team-01',
          isPublic: true,
          isSynced: true,
        ),
      ];

      // 2. Action:
      // User B (rekan satu tim User A) melakukan fetchLogs.
      final visibleToUserB = MongoService.filterVisibleLogsForUser(
        logsFromFetch,
        currentUserId: 'user-b',
        currentUserTeamId: 'team-01',
      );

      // 3. Assert (Validasi):
      // Hanya log Public yang boleh terlihat.
      expect(visibleToUserB.length, 1);
      expect(visibleToUserB.first.id, 'log-public-a');
      expect(visibleToUserB.first.isPublic, isTrue);
      expect(visibleToUserB.any((log) => log.id == 'log-private-a'), isFalse);
    },
  );
}

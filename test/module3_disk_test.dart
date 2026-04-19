import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_074/features/logbook/models/log_model.dart';

void main() {
  var actual, expected;

  group('Module 3 - Save Data to Disk Test (SharedPreferences)', () {
    const storageKey = 'user_logs_data';
    late SharedPreferences prefs;

    Future<void> simulateSaveToDisk(List<LogModel> currentLogs) async {
      final String encodedData = jsonEncode(
        currentLogs.map((log) => log.toMap()).toList(),
      );
      await prefs.setString(storageKey, encodedData);
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('TC01: saveToDisk should store logs as JSON string', () async {
      final dummyLog = LogModel(
        title: 'Rapat Pertama',
        description: 'Bahas UI',
        date: '2026-04-03',
        authorId: 'admin',
        teamId: 'MEKTRA_KLP_01',
      );

      await simulateSaveToDisk([dummyLog]);
      actual = prefs.getString(storageKey);

      expect(actual != null, true, reason: 'Disk tidak boleh kosong');
      expect(
        actual.contains('Rapat Pertama'),
        true,
        reason: 'Harus mengandung judul log',
      );
    });

    test(
      'TC02: saveToDisk should store empty array when logs are empty',
      () async {
        final List<LogModel> emptyLogs = [];

        await simulateSaveToDisk(emptyLogs);
        actual = prefs.getString(storageKey);
        expected = '[]';

        expect(actual, expected, reason: 'Expected empty JSON array string []');
      },
    );

    test('TC03: saveToDisk should overwrite old data with new data', () async {
      final log1 = LogModel(
        title: 'Data 1',
        description: 'Desc 1',
        date: '2026-04-03',
        authorId: 'admin',
        teamId: 'MEKTRA',
      );
      final log2 = LogModel(
        title: 'Data 2',
        description: 'Desc 2',
        date: '2026-04-03',
        authorId: 'admin',
        teamId: 'MEKTRA',
      );

      await simulateSaveToDisk([log1]);

      await simulateSaveToDisk([log1, log2]);
      actual = prefs.getString(storageKey);

      List<dynamic> decodedList = jsonDecode(actual);

      expect(
        decodedList.length,
        2,
        reason: 'Expected disk to contain 2 items after overwrite',
      );
      expect(
        actual.contains('Data 2'),
        true,
        reason: 'Data baru harus ada di disk',
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_001/features/logbook/counter_controller.dart';

void main() {
  var actual, expected;

  group('Module 1 - CounterController Test', () {
    late CounterController controller;
    const username = "admin";

    setUp(() async {
      // (1) setup (arrange, build) - Dijalankan sebelum setiap test
      // Inisialisasi mock storage agar SharedPreferences bisa jalan tanpa error
      SharedPreferences.setMockInitialValues({});
    });

    test('TC04: increment should increase counter based on step', () async {
      // (1) setup (arrange, build)
      controller = CounterController(username: username);
      await controller.load();
      controller.setStep(2);

      // (2) exercise (act, operate)
      controller.increment();
      actual = controller.value;
      expected = 2;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('TC05: decrement should decrease counter based on step', () async {
      // (1) setup (arrange, build)
      controller = CounterController(username: username);
      await controller.load();
      controller.setStep(2);
      controller.increment(); // counter menjadi 2

      // (2) exercise (act, operate)
      bool status = controller.decrement();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(status, true, reason: 'Expected decrement to return true');
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('TC06: decrement should not go below zero', () async {
      // (1) setup (arrange, build)
      controller = CounterController(username: username);
      await controller.load();
      controller.setStep(5); // counter awal 0

      // (2) exercise (act, operate)
      bool status = controller.decrement();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(status, false, reason: 'Expected decrement to return false');
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('TC07: reset should set counter to zero', () async {
      // (1) setup (arrange, build)
      controller = CounterController(username: username);
      await controller.load();
      controller.increment(); // counter terisi (tidak nol)

      // (2) exercise (act, operate)
      controller.reset();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('TC08: history should record actions', () async {
      // (1) setup (arrange, build)
      controller = CounterController(username: username);
      await controller.load();

      // (2) exercise (act, operate)
      controller.increment();
      actual = controller.history;

      // (3) verify (assert, check)
      expect(actual.isNotEmpty, true, reason: 'History should not be empty');
      expect(actual.first.contains("menambah"), true, reason: 'History should contain kata menambah');
    });

    test('TC09: history should not exceed 5 items', () async {
      // (1) setup (arrange, build)
      controller = CounterController(username: username);
      await controller.load();

      // (2) exercise (act, operate)
      for (int i = 0; i < 6; i++) {
        controller.increment();
      }
      actual = controller.history.length;
      expected = 5;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('TC10: counter should persist using SharedPreferences', () async {
      // (1) setup (arrange, build)
      controller = CounterController(username: username);
      await controller.load();
      controller.increment(); // step default 1, counter jadi 1
      
      // Jeda sangat singkat untuk memastikan penulisan storage sinkronus selesai
      await Future.delayed(const Duration(milliseconds: 50)); 

      // (2) exercise (act, operate)
      final newController = CounterController(username: username); // Simulasi restart
      await newController.load();
      actual = newController.value;
      expected = 1;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });
  });
}
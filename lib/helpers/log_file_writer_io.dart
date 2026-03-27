import 'dart:io';

import 'package:intl/intl.dart';

Future<void> appendLogLine(String line) async {
  final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
  final logsDir = Directory('logs');
  if (!await logsDir.exists()) {
    await logsDir.create(recursive: true);
  }

  final file = File('${logsDir.path}/$date.log');
  await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
}

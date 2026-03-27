import 'log_file_writer_stub.dart'
    if (dart.library.io) 'log_file_writer_io.dart'
    as impl;

Future<void> appendLogLine(String line) => impl.appendLogLine(line);

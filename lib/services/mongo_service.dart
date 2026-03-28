import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();

  Db? _db;
  DbCollection? _collection;

  final String _source = "mongo_service.dart";

  factory MongoService() => _instance;
  MongoService._internal();

  void _assertLogAccess(
    LogModel log, {
    required String currentUserId,
    required String currentUserRole,
    required String currentUserTeamId,
  }) {
    final hasAccess =
        log.authorId == currentUserId ||
        log.teamId == currentUserTeamId ||
        currentUserRole == 'Ketua';

    if (!hasAccess) {
      throw Exception("Security Breach: Anda tidak memiliki akses!");
    }
  }

  Future<DbCollection> _getSafeCollection() async {
    if (_db == null || !_db!.isConnected || _collection == null) {
      await LogHelper.writeLog(
        "INFO: Koleksi belum siap, mencoba rekoneksi...",
        source: _source,
        level: 3,
      );
      await connect();
    }
    return _collection!;
  }

  Future<void> connect() async {
    try {
      final dbUri = dotenv.env['MONGODB_URI'];
      if (dbUri == null) throw Exception("MONGODB_URI tidak ditemukan di .env");

      _db = await Db.create(dbUri);

      await _db!.open().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
            "Koneksi Timeout. Cek IP Whitelist (0.0.0.0/0) atau Sinyal HP.",
          );
        },
      );

      _collection = _db!.collection('logs');

      await LogHelper.writeLog(
        "DATABASE: Terhubung & Koleksi Siap",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Gagal Koneksi - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// READ: Mengambil data dari Cloud
  Future<List<LogModel>> getLogs(String teamId) async {
    try {
      final collection = await _getSafeCollection(); // Gunakan jalur aman

      await LogHelper.writeLog(
        "INFO: Fetching data for Team: $teamId",
        source: _source,
        level: 3,
      );

      final List<Map<String, dynamic>> data = await collection
          .find(where.eq('teamId', teamId))
          .toList();
      return data.map((json) => LogModel.fromMap(json)).toList();
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Fetch Failed - $e",
        source: _source,
        level: 1,
      );
      return [];
    }
  }

  Future<void> insertLog(LogModel log) async {
    try {
      await LogHelper.writeLog(
        "CRUD CREATE: Menyimpan '${log.title}'...",
        source: _source,
        level: 3,
      );

      final collection = await _getSafeCollection();
      await collection.insertOne(log.toMap());

      await LogHelper.writeLog(
        "SUCCESS: Data '${log.title}' Saved to Cloud",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Insert Failed - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<void> updateLog(
    LogModel log, {
    required String currentUserId,
    required String currentUserRole,
    required String currentUserTeamId,
  }) async {
    try {
      _assertLogAccess(
        log,
        currentUserId: currentUserId,
        currentUserRole: currentUserRole,
        currentUserTeamId: currentUserTeamId,
      );

      await LogHelper.writeLog(
        "CRUD UPDATE: Memperbarui '${log.title}'...",
        source: _source,
        level: 3,
      );

      final collection = await _getSafeCollection();
      if (log.id == null) {
        throw Exception("ID Log tidak ditemukan untuk update");
      }

      await collection.replaceOne(
        where.id(ObjectId.fromHexString(log.id!)),
        log.toMap(),
      );

      await LogHelper.writeLog(
        "DATABASE: Update '${log.title}' Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Update Gagal - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<void> deleteLog(
    LogModel log, {
    required String currentUserId,
    required String currentUserRole,
    required String currentUserTeamId,
  }) async {
    try {
      _assertLogAccess(
        log,
        currentUserId: currentUserId,
        currentUserRole: currentUserRole,
        currentUserTeamId: currentUserTeamId,
      );

      if (log.id == null) {
        throw Exception("ID Log tidak ditemukan untuk delete");
      }

      await LogHelper.writeLog(
        "CRUD DELETE: Menghapus dokumen ID ${log.id}...",
        source: _source,
        level: 3,
      );

      final collection = await _getSafeCollection();
      await collection.remove(where.id(ObjectId.fromHexString(log.id!)));

      await LogHelper.writeLog(
        "DATABASE: Hapus ID ${log.id} Berhasil",
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "DATABASE: Hapus Gagal - $e",
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      await LogHelper.writeLog(
        "DATABASE: Koneksi ditutup",
        source: _source,
        level: 2,
      );
    }
  }
}

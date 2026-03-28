import 'dart:convert'; // Wajib ditambahkan untuk jsonEncode & jsonDecode
import 'package:flutter/material.dart';
import 'package:hive/hive.dart' as hive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logbook_app_001/helpers/access_policy.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier =
      ValueNotifier<List<LogModel>>([]);
  final hive.Box<LogModel> hiveBox = hive.Hive.box<LogModel>('offline_logs');
  final String userTeamId;
  final String currentUserId;
  final String userRole;

  // Kunci unik untuk penyimpanan lokal di Shared Preferences
  static const String _storageKey = 'user_logs_data';

  // Getter untuk mempermudah akses list data saat ini
  List<LogModel> get logs => logsNotifier.value;

  // --- BARU: KONSTRUKTOR ---
  // Saat Controller dibuat, ia otomatis mencoba mengambil data lama
  LogController({
    this.userTeamId = 'MEKTRA_KLP_01',
    required this.currentUserId,
    this.userRole = 'Anggota',
  }) {
    loadLogs(userTeamId);
  }

  hive.Box<LogModel> get _myBox => hiveBox;

  bool _canEdit(LogModel log) {
    bool canEdit = AccessPolicy.canPerform(
      userRole,
      'update',
      isOwner: log.authorId == currentUserId,
    );
    return canEdit;
  }

  void _assertLogAccess(LogModel log) {
    final hasAccess =
        log.authorId == currentUserId ||
        log.teamId == userTeamId ||
        userRole == 'Ketua';

    if (!hasAccess) {
      throw Exception("Security Breach: Anda tidak memiliki akses!");
    }
  }

  /// 1. LOAD DATA (Offline-First Strategy)
  Future<void> loadLogs(String teamId) async {
    // Langkah 1: Ambil data dari Hive (Sangat Cepat/Instan)
    logsNotifier.value = _myBox.values.toList();

    // Langkah 2: Sync dari Cloud (Background)
    try {
      final cloudData = await MongoService().getLogs(teamId);

      // Jika cloud kosong saat cache lokal tersedia, pertahankan cache lokal.
      if (cloudData.isEmpty && _myBox.isNotEmpty) {
        await LogHelper.writeLog(
          "OFFLINE: Menggunakan data cache lokal",
          source: "log_controller.dart",
          level: 2,
        );
        return;
      }

      // Update Hive dengan data terbaru dari Cloud agar sinkron
      await _myBox.clear();
      await _myBox.addAll(cloudData);

      // Update UI dengan data Cloud
      logsNotifier.value = cloudData;

      await LogHelper.writeLog(
        "SYNC: Data berhasil diperbarui dari Atlas",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "OFFLINE: Menggunakan data cache lokal",
        source: "log_controller.dart",
        level: 2,
      );
    }
  }

  /// 2. ADD DATA (Instant Local + Background Cloud)
  Future<void> addLog(
    String title,
    String desc,
    String authorId,
    String teamId,
  ) async {
    if (!AccessPolicy.canPerform(userRole, 'create')) {
      await LogHelper.writeLog(
        "AUTH: Tidak punya izin menambah log",
        source: "log_controller.dart",
        level: 2,
      );
      return;
    }

    final newLog = LogModel(
      id: ObjectId().oid,
      title: title,
      description: desc,
      date: DateTime.now().toString(),
      authorId: authorId,
      teamId: teamId,
    );

    // ACTION 1: Simpan ke Hive (Instan)
    await _myBox.add(newLog);
    logsNotifier.value = [...logsNotifier.value, newLog];

    // ACTION 2: Kirim ke MongoDB Atlas (Background)
    try {
      await MongoService().insertLog(newLog);
      await LogHelper.writeLog(
        "SUCCESS: Data tersinkron ke Cloud",
        source: "log_controller.dart",
      );
    } catch (e) {
      await LogHelper.writeLog(
        "WARNING: Data tersimpan lokal, akan sinkron saat online",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  Future<void> syncLog(LogModel log) async {
    await hiveBox.add(log); // Simpan lokal dulu (Instant!)
    try {
      await MongoService().insertLog(log); // Coba kirim ke Cloud
      await LogHelper.writeLog("Sync Success", source: "SyncManager");
    } catch (e) {
      await LogHelper.writeLog(
        "Offline Mode: Data saved locally",
        source: "SyncManager",
        level: 3,
      );
    }
  }

  // 2. Memperbarui data di Cloud (HOTS: Sinkronisasi Terjamin)
  Future<void> updateLog(
    int index,
    String newTitle,
    String newDesc,
    String newCategory,
  ) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];
    _assertLogAccess(oldLog);
    if (!_canEdit(oldLog)) {
      await LogHelper.writeLog(
        "AUTH: Tidak punya izin edit log '${oldLog.title}'",
        source: "log_controller.dart",
        level: 2,
      );
      return;
    }

    final updatedLog = LogModel(
      id: oldLog.id, // ID harus tetap sama agar MongoDB mengenali dokumen ini
      title: newTitle,
      description: newDesc,
      category: newCategory,
      date: DateTime.now().toString(),
      teamId: oldLog.teamId,
      authorId: oldLog.authorId,
    );

    try {
      // 1. Jalankan update di MongoService (Tunggu konfirmasi Cloud)
      await MongoService().updateLog(
        updatedLog,
        currentUserId: currentUserId,
        currentUserRole: userRole,
        currentUserTeamId: userTeamId,
      );

      // 2. Jika sukses, baru perbarui state lokal
      currentLogs[index] = updatedLog;
      logsNotifier.value = currentLogs;

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Update - $e",
        source: "log_controller.dart",
        level: 1,
      );
      // Data di UI tidak berubah jika proses di Cloud gagal
    }
  }

  // 3. Menghapus data dari Cloud (HOTS: Sinkronisasi Terjamin)
  Future<void> removeLog(int index) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];

    if (!AccessPolicy.canPerform(
      userRole,
      'delete',
      isOwner: targetLog.authorId == currentUserId,
    )) {
      await LogHelper.writeLog(
        "SECURITY BREACH: Unauthorized delete attempt",
        source: "log_controller.dart",
        level: 1,
      );
      return; // Hentikan proses jika tidak punya izin
    }

    _assertLogAccess(targetLog);

    try {
      if (targetLog.id == null) {
        throw Exception(
          "ID Log tidak ditemukan, tidak bisa menghapus di Cloud.",
        );
      }

      // 1. Hapus data di MongoDB Atlas (Tunggu konfirmasi Cloud)
      await MongoService().deleteLog(
        targetLog,
        currentUserId: currentUserId,
        currentUserRole: userRole,
        currentUserTeamId: userTeamId,
      );

      // 2. Jika sukses, baru hapus dari state lokal
      currentLogs.removeAt(index);
      logsNotifier.value = currentLogs;

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${targetLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        "ERROR: Gagal sinkronisasi Hapus - $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  // --- BARU: FUNGSI PERSISTENCE (SINKRONISASI JSON) ---

  // Fungsi untuk menyimpan seluruh List ke penyimpanan lokal
  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    // Mengubah List of Object -> List of Map -> String JSON
    final String encodedData = jsonEncode(
      logsNotifier.value.map((log) => log.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  // Ganti pemanggilan SharedPreferences menjadi MongoService
  Future<void> loadFromDisk() async {
    await loadLogs(userTeamId);
  }
}

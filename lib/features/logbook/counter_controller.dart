import 'package:shared_preferences/shared_preferences.dart';

class CounterController {
  CounterController({required this.username});

  final String username;
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // Variabel private untuk langkah increment/decrement

  int get value => _counter; // Getter untuk akses data
  int get step => _step; // Getter untuk akses langkah

  final List<String> _history = []; // List untuk menyimpan riwayat perubahan

  static const int _historyLimit = 5;
  static const String _lastValueKeyPrefix = 'last_counter_';
  static const String _historyKeyPrefix = 'counter_history_';

  List<String> get history =>
      List.unmodifiable(_history); // Getter untuk riwayat

  void setStep(int newValue) {
    _step = newValue; // Setter untuk mengubah langkah increment/decrement
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _counter = prefs.getInt(_lastValueKey) ?? 0;
    final storedHistory = prefs.getStringList(_historyKey) ?? <String>[];
    _history
      ..clear()
      ..addAll(storedHistory);
  }

  void increment() {
    _counter += _step; // Increment counter dengan langkah yang ditentukan
    _addLog(
      "User $username menambah +$_step pada jam ${_getTime()}",
    ); // Simpan riwayat
  }

  bool decrement() {
    if (_counter >= _step) {
      _counter -= _step;
      _addLog(
        "User $username mengurangi -$_step pada jam ${_getTime()}",
      ); // Simpan riwayat
      return true;
    } else {
      _addLog(
        "User $username mencoba mengurangi -$_step pada jam ${_getTime()} tetapi operasi gagal karena nilai counter akan menjadi minus",
      ); // Simpan riwayat
      return false;
    }
  }

  void reset() {
    _counter = 0;
    _addLog(
      "User $username mereset counter menjadi 0 pada jam ${_getTime()}",
    ); // Simpan riwayat
  }

  void clearHistory() {
    _history.clear(); // Menghapus isi List
    _addLog("User $username menghapus riwayat pada jam ${_getTime()}");
  }

  String _getTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _addLog(String action) {
    _history.insert(0, action); // Tambahkan log ke riwayat

    if (_history.length > _historyLimit) {
      _history.removeLast(); // Batasi riwayat hanya 5 entri terakhir
    }

    _saveState();
  }

  String get _lastValueKey => "$_lastValueKeyPrefix$username";
  String get _historyKey => "$_historyKeyPrefix$username";

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastValueKey, _counter);
    await prefs.setStringList(_historyKey, List<String>.from(_history));
  }
}

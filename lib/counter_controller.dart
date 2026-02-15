class CounterController {
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // Variabel private untuk langkah increment/decrement

  int get value => _counter; // Getter untuk akses data
  int get step => _step; // Getter untuk akses langkah

  final List<String> _history = []; // List untuk menyimpan riwayat perubahan
  
  List<String> get history => List.unmodifiable(_history); // Getter untuk riwayat

  void setStep(int newValue) {
    _step = newValue; // Setter untuk mengubah langkah increment/decrement
  }

  void increment() {
    _counter += _step; // Increment counter dengan langkah yang ditentukan
    _addLog("User menambah nilai sebesar $_step pada jam ${_getTime()} sehingga counter menunjukkan angka $_counter"); // Simpan riwayat
  }

  void decrement() { 
    if (_counter >= _step) {
      _counter -= _step;
      _addLog("User mengurangi nilai sebesar $_step pada jam ${_getTime()} sehingga counter menunjukkan angka $_counter"); // Simpan riwayat
    } else {
        _counter = 0;
        _addLog("Counter direset menjadi 0 pada jam ${_getTime()}"); // Simpan riwayat
    }
  }
    void reset() {
      _counter = 0;
      _addLog("Counter direset menjadi 0 pada jam ${_getTime()}"); // Simpan riwayat
    }

  String _getTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _addLog(String action) {
    _history.insert(0, action); // Tambahkan log ke riwayat
    
    if (_history.length > 5) {
      _history.removeLast(); // Batasi riwayat hanya 5 entri terakhir
    
    }
  }
}
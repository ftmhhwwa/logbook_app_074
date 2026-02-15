class CounterController {
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // Variabel private untuk langkah increment/decrement

  int get value => _counter; // Getter untuk akses data
  int get step => _step; // Getter untuk akses langkah

  void setStep(int newValue) {
    _step = newValue; // Setter untuk mengubah langkah increment/decrement
  }

  void increment() => _counter += _step;
  void decrement() { if (_counter > 0) _counter -= _step; else _counter = 0; }
  
  void reset() => _counter = 0;
}

import 'package:flutter/material.dart';
import 'counter_controller.dart';

class CounterView extends StatefulWidget {
  const CounterView({super.key});
  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  final CounterController _controller = CounterController();

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Reset"),
          content: const Text(
            "Apakah Anda yakin ingin menghapus seluruh hitungan?",
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context), // Menutup dialog tanpa reset
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _controller.reset(); // Memanggil logika reset di controller
                });
                Navigator.pop(context); // Menutup dialog
                _showSuccessSnackBar(); // Memanggil SnackBar sukses
              },
              child: const Text(
                "Ya, Hapus",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Hapus Data"),

          content: const Text(
            "Apakah Anda yakin ingin menghapus seluruh riwayat?",
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context), // Menutup dialog tanpa reset
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _controller.reset(); // Memanggil logika reset di controller
                });
                Navigator.pop(context); // Menutup dialog
                _showDeleteSnackBar(); // Memanggil SnackBar sukses
              },
              child: const Text(
                "Ya, Hapus",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Data berhasil di-reset!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

    void  _showDeleteSnackBar() {
      setState(() {
        _controller.clearHistory();
      });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Riwayat berhasil dihapus!"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fatim's Counter App"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Bagian Display Angka Utama
          const Text(
            "Counter:",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          Text(
            '${_controller.value}',
            style: const TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: Color(0xFF008080),
            ),
          ),

          //Input Step
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            child: Column(
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Set Increment/Decrement step',
                    labelText: "Masukkan Step",
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF008080)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF008080),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                  ),
                  onChanged: (value) =>
                      _controller.setStep(int.tryParse(value) ?? 1),
                ),
                  const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tombol Minus (Merah)
                    ElevatedButton.icon(
                      onPressed: () {
                        bool isSuccess = _controller.decrement();
                        if (isSuccess) {
                          setState(() {});
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Gagal: Nilai tidak boleh kurang dari 0!",
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.remove, color: Colors.white),
                      label: const Text(
                        "Minus",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // Tombol Reset (Oranye)
                    ElevatedButton.icon(
                      onPressed: _showResetConfirmation,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        "Reset",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // Tombol Tambah (Hijau)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _controller.increment()),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        "Add",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Riwayat Aktivitas (5 Terakhir)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: _showDeleteConfirmation,
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  tooltip: "Hapus Riwayat",
                ),
              ],
            ),
          ),

          // Daftar Riwayat (5 Terbaru) [cite: 33, 95, 356]
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _controller.history.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(
                    Icons.access_time,
                    color: Colors.blueGrey,
                  ),
                  title: Text(
                    _controller.history[index],
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Text(
                    "Total: ${_controller.value}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

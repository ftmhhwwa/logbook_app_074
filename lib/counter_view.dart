import 'package:flutter/material.dart';
import 'counter_controller.dart';

class CounterView extends StatefulWidget {
  const CounterView({super.key});
  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {

void _showResetConfirmation() {
showDialog(
  context: context,
  builder: (BuildContext context) {
    return AlertDialog(
      title: const Text("Konfirmasi Reset"),
      content: const Text("Apakah Anda yakin ingin menghapus seluruh hitungan?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Menutup dialog tanpa reset
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
          child: const Text("Ya, Hapus", style: TextStyle(color: Colors.red)),
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

  final CounterController _controller = CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LogBook: Versi Task 1")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //Input Step
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Masukkan Step"),
                onChanged: (value) =>
                    _controller.setStep(int.tryParse(value) ?? 1),
              ),
            ),
            const Text("Total Hitungan:"),
            Text('${_controller.value}', style: const TextStyle(fontSize: 40)),            
            Expanded(
              child: ListView.builder(
                shrinkWrap: true, // Agar list tidak mengambil semua ruang jika data sedikit
                itemCount: _controller.history.length, // Mengambil jumlah data dari controller
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(_controller.history[index]), // Menampilkan teks riwayat
                  );
                },
              ),
            )
          ],
        ),
      ),
      //tombol tambah dan kurang
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              // Cek hasil fungsi decrement dari controller
              bool isSuccess = _controller.decrement();
              
              if (isSuccess) {
                // Jika berhasil, perbarui tampilan
                setState(() {});
              } else {
                // Jika gagal (hasil akan minus), tampilkan SnackBar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Gagal: Nilai tidak boleh kurang dari 0!"),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Icon(Icons.remove),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: () => setState(() => _controller.increment()),
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: _showResetConfirmation,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _controller.resetHistory(); // Memanggil fungsi reset khusus riwayat
              });
              // Tambahkan SnackBar sesuai standar UX Modul 1 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Riwayat dibersihkan!")),
              );
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
    );
  }
}

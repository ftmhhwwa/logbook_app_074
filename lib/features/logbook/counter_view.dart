import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/logbook/counter_controller.dart';
import 'package:logbook_app_001/features/onboarding/onboarding_view.dart';

class CounterView extends StatefulWidget {
  final String username; // Menambahkan parameter untuk menerima username

  const CounterView({super.key, required this.username});

  @override
  State<CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<CounterView> {
  late final CounterController _controller;
  final TextEditingController _stepController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _controller = CounterController(username: widget.username);
    _loadState();
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    await _controller.load();
    if (mounted) {
      setState(() {});
    }
  }

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

  void _showDeleteSnackBar() {
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
        title: Text("Logbook: ${widget.username}"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Kita siapkan tombol logout di sini untuk Fase 3 nanti
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Konfirmasi Logout"),
                    content: const Text(
                      "Apakah Anda yakin? Data yang belum disimpan mungkin akan hilang.",
                    ),
                    actions: [
                      // Tombol Batal
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context), // Menutup dialog saja
                        child: const Text("Batal"),
                      ),
                      // Tombol Ya, Logout
                      TextButton(
                        onPressed: () {
                          // Menutup dialog
                          Navigator.pop(context);

                          // 2. Navigasi kembali ke Onboarding (Membersihkan Stack)
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingView(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Ya, Keluar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text("Selamat Datang, ${widget.username}!"),
            const SizedBox(height: 10),
            const Text("Angka Terakhir:"),
            Text(
              '${_controller.value}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _stepController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Set Increment/Decrement step',
                  labelText: 'Masukkan Step',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF008080)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
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
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
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
                ElevatedButton.icon(
                  onPressed: () => setState(() => _controller.increment()),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Tambah",
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Riwayat Aktivitas"),
                  IconButton(
                    onPressed: _showDeleteConfirmation,
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    tooltip: "Hapus Riwayat",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _controller.history.isEmpty
                  ? const Center(child: Text("Belum ada aktivitas"))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _controller.history.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text(_controller.history[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

//       ),
//       body: Column(
//         children: [
//           const SizedBox(height: 20),
//           // Bagian Display Angka Utama
//           const Text(
//             "Counter:",
//             style: TextStyle(fontSize: 18, color: Colors.grey),
//           ),
//           Text(
//             '${_controller.value}',
//             style: const TextStyle(
//               fontSize: 80,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF008080),
//             ),
//           ),

//           //Input Step
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
//             child: Column(
//               children: [
//                 TextField(
//                   keyboardType: TextInputType.number,
//                   decoration: InputDecoration(
//                     hintText: 'Set Increment/Decrement step',
//                     labelText: "Masukkan Step",
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide(color: Color(0xFF008080)),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: BorderSide(
//                         color: Color(0xFF008080),
//                         width: 2,
//                       ),
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 15,
//                       vertical: 15,
//                     ),
//                   ),
//                   onChanged: (value) =>
//                       _controller.setStep(int.tryParse(value) ?? 1),
//                 ),
//                   const SizedBox(height: 20),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     // Tombol Minus (Merah)
//                     ElevatedButton.icon(
//                       onPressed: () {
//                         bool isSuccess = _controller.decrement();
//                         if (isSuccess) {
//                           setState(() {});
//                         } else {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(
//                               content: Text(
//                                 "Gagal: Nilai tidak boleh kurang dari 0!",
//                               ),
//                               backgroundColor: Colors.red,
//                             ),
//                           );
//                         }
//                       },
//                       icon: const Icon(Icons.remove, color: Colors.white),
//                       label: const Text(
//                         "Minus",
//                         style: TextStyle(color: Colors.white),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.red,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),

//                     // Tombol Reset (Oranye)
//                     ElevatedButton.icon(
//                       onPressed: _showResetConfirmation,
//                       icon: const Icon(Icons.refresh, color: Colors.white),
//                       label: const Text(
//                         "Reset",
//                         style: TextStyle(color: Colors.white),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.orange,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),

//                     // Tombol Tambah (Hijau)
//                     ElevatedButton.icon(
//                       onPressed: () => setState(() => _controller.increment()),
//                       icon: const Icon(Icons.add, color: Colors.white),
//                       label: const Text(
//                         "Add",
//                         style: TextStyle(color: Colors.white),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   "Riwayat Aktivitas (5 Terakhir)",
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                 ),
//                 IconButton(
//                   onPressed: _showDeleteConfirmation,
//                   icon: const Icon(Icons.delete_outline, color: Colors.grey),
//                   tooltip: "Hapus Riwayat",
//                 ),
//               ],
//             ),
//           ),

//           // Daftar Riwayat (5 Terbaru) [cite: 33, 95, 356]
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.symmetric(horizontal: 10),
//               itemCount: _controller.history.length,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   leading: const Icon(
//                     Icons.access_time,
//                     color: Colors.blueGrey,
//                   ),
//                   title: Text(
//                     _controller.history[index],
//                     style: const TextStyle(fontSize: 13),
//                   ),
//                   trailing: Text(
//                     "Total: ${_controller.value}",
//                     style: const TextStyle(
//                       color: Colors.green,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

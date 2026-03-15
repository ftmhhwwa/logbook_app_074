import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final LogController _controller = LogController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logbook Catatan Harian")),
      body: ValueListenableBuilder<List<LogModel>>(
        valueListenable: _controller.logsNotifier,
        builder: (context, currentLogs, child) {
          if (currentLogs.isEmpty) return const Center(child: Text("Belum ada catatan."));
          return ListView.builder(
            itemCount: currentLogs.length,
            itemBuilder: (context, index) {
              final log = currentLogs[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.note),
                  title: Text(log.title),
                  subtitle: Text(log.description),
                  trailing: Wrap(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditLogDialog(index, log), // Fungsi edit
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _controller.removeLog(index));
                      },
                    ),
                  ],
                )
              )
            );
          },
        );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLogDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
// 1. Tambahkan Controller untuk menangkap input di dalam State
final TextEditingController _titleController = TextEditingController();
final TextEditingController _contentController = TextEditingController();

void _showAddLogDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Tambah Catatan Baru"),
      content: Column(
        mainAxisSize: MainAxisSize.min, // Agar dialog tidak memenuhi layar
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: "Judul Catatan"),
          ),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(hintText: "Isi Deskripsi"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Tutup tanpa simpan
          child: const Text("Batal"),
        ),
        ElevatedButton(
          onPressed: () {
            // Jalankan fungsi tambah di Controller
            _controller.addLog(
              _titleController.text, 
              _contentController.text
            );
            
            // Trigger UI Refresh
            setState(() {}); 
            
            // Bersihkan input dan tutup dialog
            _titleController.clear();
            _contentController.clear();
            Navigator.pop(context);
          },
          child: const Text("Simpan"),
        ),
      ],
    ),
  );
}

void _showEditLogDialog(int index, LogModel log) {
  _titleController.text = log.title;
  _contentController.text = log.description;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit Catatan"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleController),
          TextField(controller: _contentController),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        ElevatedButton(
          onPressed: () {
            _controller.updateLog(index, _titleController.text, _contentController.text);
            _titleController.clear();
            _contentController.clear();
            Navigator.pop(context);
          },
          child: const Text("Update"),
        ),
      ],
    ),
  );
}
}
// body: ValueListenableBuilder<List<LogModel>>(
//   valueListenable: _controller.logsNotifier,
//   builder: (context, currentLogs, child) {
//     if (currentLogs.isEmpty) return const Center(child: Text("Belum ada catatan."));
//     return ListView.builder(
//       itemCount: currentLogs.length,
//       itemBuilder: (context, index) {
//         final log = currentLogs[index];
//         return Card(
//           child: ListTile(
//             leading: const Icon(Icons.note),
//             title: Text(log.title),
//             subtitle: Text(log.description),
//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 IconButton(icon: const Icon(Icons.edit, color: Colors.blue), 
//                   onPressed: () => _showEditLogDialog(index, log)),
//                 IconButton(icon: const Icon(Icons.delete, color: Colors.red), 
//                   onPressed: () => _controller.removeLog(index)),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   },
// ),

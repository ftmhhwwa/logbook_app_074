import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/mongo_service.dart';

class LogView extends StatefulWidget {
  final String username;
  const LogView({super.key, required this.username});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final MongoService _mongoService = MongoService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  late Future<List<LogModel>> _logsFuture;

  final List<String> _categories = [
    'Akademik',
    'Pekerjaan',
    'Pribadi',
    'Urgent',
  ];

  @override
  void initState() {
    super.initState();
    _logsFuture = _mongoService.getLogs();
  }

  void _refreshLogs() {
    if (!mounted) return;
    setState(() {
      _logsFuture = _mongoService.getLogs();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logbook Catatan Harian")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => _searchQuery.value = value,
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchQuery,
              builder: (context, query, child) {
                return FutureBuilder<List<LogModel>>(
                  future: _logsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Menghubungkan ke MongoDB Atlas..."),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('Gagal memuat data: ${snapshot.error}'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _refreshLogs,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      );
                    }

                    final currentLogs = snapshot.data ?? [];
                    final filteredLogs = currentLogs.where((log) {
                      return log.title.toLowerCase().contains(
                            query.toLowerCase(),
                          ) ||
                          log.description.toLowerCase().contains(
                            query.toLowerCase(),
                          );
                    }).toList();

                    if (currentLogs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text("Data Kosong"),
                            ElevatedButton(
                              onPressed: _showAddLogDialog,
                              child: const Text("Buat Catatan Pertama"),
                            ),
                          ],
                        ),
                      );
                    }

                    if (filteredLogs.isEmpty) {
                      return const Center(
                        child: Text("Catatan tidak ditemukan."),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => _refreshLogs(),
                      child: ListView.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];

                          Color cardColor;
                          switch (log.category) {
                            case 'Akademik':
                              cardColor = Colors.purple.shade50;
                              break;
                            case 'Pekerjaan':
                              cardColor = Colors.blue.shade50;
                              break;
                            case 'Urgent':
                              cardColor = Colors.red.shade50;
                              break;
                            case 'Pribadi':
                            default:
                              cardColor = Colors.green.shade50;
                              break;
                          }

                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.note,
                                color: Colors.blueGrey.shade700,
                              ),
                              title: Text(
                                log.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(log.description),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white60,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          log.category,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "Waktu: ${log.date.split('.').first}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _showEditLogDialog(log),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      if (log.id == null) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'ID log tidak ditemukan.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      await _mongoService.deleteLog(log.id!);
                                      _refreshLogs();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLogDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddLogDialog() {
    _titleController.clear();
    _contentController.clear();
    String selectedCategory = _categories.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          title: const Text("Tambah Catatan Baru"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: "Judul Catatan"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(hintText: "Isi Deskripsi"),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setStateDialog(() => selectedCategory = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newLog = LogModel(
                  title: _titleController.text,
                  description: _contentController.text,
                  date: DateTime.now().toIso8601String(),
                  category: selectedCategory,
                );

                await _mongoService.insertLog(newLog);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _refreshLogs();
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLogDialog(LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;

    // Pastikan kategori yang tersimpan ada dalam list, jika tidak gunakan default
    String selectedCategory = _categories.contains(log.category)
        ? log.category
        : _categories.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          title: const Text("Edit Catatan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Judul Catatan"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: "Isi Deskripsi"),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setStateDialog(() => selectedCategory = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedLog = LogModel(
                  id: log.id,
                  title: _titleController.text,
                  description: _contentController.text,
                  date: DateTime.now().toIso8601String(),
                  category: selectedCategory,
                );

                await _mongoService.updateLog(updatedLog);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _refreshLogs();
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }
}

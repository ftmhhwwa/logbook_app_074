import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logbook_app_001/features/auth/login_view.dart';
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
    _logsFuture = _fetchLogs();
  }

  Future<List<LogModel>> _fetchLogs() async {
    await initializeDateFormatting('id_ID');
    return _mongoService.getLogs();
  }

  void _refreshLogs() {
    if (!mounted) return;
    setState(() {
      _logsFuture = _fetchLogs();
    });
  }

  Future<void> _pullToRefresh() async {
    _refreshLogs();
    try {
      await _logsFuture;
    } catch (_) {
      // Error ditampilkan lewat FutureBuilder.
    }
  }

  String _friendlyConnectionMessage(Object? error) {
    final message = (error ?? '').toString().toLowerCase();
    if (message.contains('socket') ||
        message.contains('timeout') ||
        message.contains('network') ||
        message.contains('failed host lookup')) {
      return 'Offline Mode Warning: Koneksi internet terputus. Periksa jaringan, lalu coba lagi.';
    }

    return 'Offline Mode Warning: Gagal menghubungi MongoDB Atlas. Silakan coba beberapa saat lagi.';
  }

  String _formatLogTimestamp(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;

    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit yang lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam yang lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari yang lalu';

    return DateFormat('d MMM yyyy', 'id_ID').format(parsed);
  }

  Color _categoryTint(ColorScheme colorScheme, String category) {
    switch (category) {
      case 'Akademik':
        return Colors.indigo.withValues(alpha: 0.14);
      case 'Pekerjaan':
        return Colors.teal.withValues(alpha: 0.14);
      case 'Urgent':
        return colorScheme.error.withValues(alpha: 0.14);
      case 'Pribadi':
      default:
        return colorScheme.primary.withValues(alpha: 0.14);
    }
  }

  Color _categoryForeground(ColorScheme colorScheme, String category) {
    switch (category) {
      case 'Akademik':
        return Colors.indigo.shade800;
      case 'Pekerjaan':
        return Colors.teal.shade800;
      case 'Urgent':
        return colorScheme.error;
      case 'Pribadi':
      default:
        return colorScheme.primary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Akademik':
        return Icons.school_outlined;
      case 'Pekerjaan':
        return Icons.work_outline;
      case 'Urgent':
        return Icons.priority_high_rounded;
      case 'Pribadi':
      default:
        return Icons.person_outline_rounded;
    }
  }

  InputDecoration _dialogInputDecoration(
    BuildContext context, {
    required String label,
    IconData? icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await _mongoService.close();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFEEDCC6),
      appBar: AppBar(
        title: const Text("Logbook Catatan Harian"),
        elevation: 0,
        backgroundColor: const Color(0xFF4E342E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFEEDCC6),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x19000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.18,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, ${widget.username}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Tarik ke bawah untuk sinkronisasi cloud',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Cari catatan...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: colorScheme.surface.withValues(alpha: 0.92),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
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
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Menghubungkan ke MongoDB Atlas...',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(
                                alpha: 0.94,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  color: colorScheme.error,
                                  size: 42,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Offline Mode Warning',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _friendlyConnectionMessage(snapshot.error),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _refreshLogs,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
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
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(
                                alpha: 0.94,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 56,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Data Kosong',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mulai catat aktivitas pertamamu hari ini.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _showAddLogDialog,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Buat Catatan Pertama'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (filteredLogs.isEmpty) {
                        return Center(
                          child: Text(
                            'Catatan tidak ditemukan.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _pullToRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            final categoryBg = _categoryTint(
                              colorScheme,
                              log.category,
                            );
                            final categoryFg = _categoryForeground(
                              colorScheme,
                              log.category,
                            );

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withValues(
                                  alpha: 0.94,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  8,
                                  10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: categoryBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _categoryIcon(log.category),
                                        color: categoryFg,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.title,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            log.description,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: categoryBg,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  log.category,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: categoryFg,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatLogTimestamp(log.date),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(
                                            Icons.edit_rounded,
                                            color: colorScheme.primary,
                                          ),
                                          onPressed: () =>
                                              _showEditLogDialog(log),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: colorScheme.error,
                                          ),
                                          onPressed: () async {
                                            final shouldDelete =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogContext) =>
                                                      AlertDialog(
                                                        title: const Text(
                                                          'Hapus Catatan',
                                                        ),
                                                        content: const Text(
                                                          'Yakin ingin menghapus catatan ini?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  dialogContext,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Batal',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  dialogContext,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'Hapus',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );

                                            if (shouldDelete != true) {
                                              return;
                                            }

                                            if (log.id == null) {
                                              if (!context.mounted) return;
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

                                            try {
                                              await _mongoService.deleteLog(
                                                log.id!,
                                              );
                                              _refreshLogs();
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    _friendlyConnectionMessage(
                                                      e,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLogDialog,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add_rounded),
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
        builder: (dialogContext, setStateDialog) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;

          return AlertDialog(
            backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
                  child: Icon(
                    Icons.note_add_rounded,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Tambah Catatan Baru',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: _dialogInputDecoration(
                    dialogContext,
                    label: 'Judul Catatan',
                    icon: Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contentController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: _dialogInputDecoration(
                    dialogContext,
                    label: 'Isi Deskripsi',
                    icon: Icons.subject_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: _dialogInputDecoration(
                    dialogContext,
                    label: 'Kategori',
                    icon: Icons.category_outlined,
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newLog = LogModel(
                    title: _titleController.text,
                    description: _contentController.text,
                    date: DateTime.now().toIso8601String(),
                    category: selectedCategory,
                  );

                  try {
                    await _mongoService.insertLog(newLog);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    _refreshLogs();
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(_friendlyConnectionMessage(e))),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Simpan'),
              ),
            ],
          );
        },
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
        builder: (dialogContext, setStateDialog) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;

          return AlertDialog(
            backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Edit Catatan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: _dialogInputDecoration(
                    dialogContext,
                    label: 'Judul Catatan',
                    icon: Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contentController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: _dialogInputDecoration(
                    dialogContext,
                    label: 'Isi Deskripsi',
                    icon: Icons.subject_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: _dialogInputDecoration(
                    dialogContext,
                    label: 'Kategori',
                    icon: Icons.category_outlined,
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final updatedLog = LogModel(
                    id: log.id,
                    title: _titleController.text,
                    description: _contentController.text,
                    date: DateTime.now().toIso8601String(),
                    category: selectedCategory,
                  );

                  try {
                    await _mongoService.updateLog(updatedLog);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    _refreshLogs();
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(_friendlyConnectionMessage(e))),
                    );
                  }
                },
                icon: const Icon(Icons.save_as_rounded, size: 18),
                label: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }
}

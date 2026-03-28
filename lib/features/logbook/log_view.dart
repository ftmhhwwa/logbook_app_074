import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logbook_app_001/features/auth/login_view.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/logbook/log_editor_page.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/access_policy.dart';
import 'package:logbook_app_001/services/mongo_service.dart';

class LogView extends StatefulWidget {
  final String username;
  final String userTeamId;
  final String currentUserId;
  final String userRole;

  const LogView({
    super.key,
    required this.username,
    this.userTeamId = 'MEKTRA_KLP_01',
    required this.currentUserId,
    this.userRole = 'Anggota',
  });

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final MongoService _mongoService = MongoService();
  late final LogController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _controller = LogController(
      userTeamId: widget.userTeamId,
      currentUserId: widget.currentUserId,
      userRole: widget.userRole,
    );
    _initConnectivityStatus();
    initializeDateFormatting('id_ID');
  }

  Future<void> _initConnectivityStatus() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;

    final initialOffline = _isConnectivityOffline(connectivityResult);

    setState(() {
      _isOffline = initialOffline;
    });

    // Jika app dibuka saat online, langsung coba sinkronkan data pending.
    if (!initialOffline) {
      await _controller.syncPendingLogs();
      _refreshLogs();
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      final wasOffline = _isOffline;
      final isOfflineNow = _isConnectivityOffline(result);
      if (!mounted) return;
      if (_isOffline == isOfflineNow) return;

      setState(() {
        _isOffline = isOfflineNow;
      });

      // Saat koneksi kembali online, sinkronkan data pending ke cloud.
      if (wasOffline && !isOfflineNow) {
        _controller.syncPendingLogs().then((_) {
          if (!mounted) return;
          _refreshLogs();
        });
      }
    });
  }

  bool _isConnectivityOffline(List<ConnectivityResult> connectivityResults) {
    if (connectivityResults.isEmpty) {
      return true;
    }
    return connectivityResults.every(
      (result) => result == ConnectivityResult.none,
    );
  }

  void _refreshLogs() {
    _controller.loadLogs(widget.userTeamId);
  }

  Future<void> _goToEditor({required LogModel log, int? index}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUserId: widget.currentUserId,
          currentUserRole: widget.userRole,
          currentUserTeamId: widget.userTeamId,
        ),
      ),
    );
  }

  Future<void> _pullToRefresh() async {
    await _controller.loadLogs(widget.userTeamId);
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
    _connectivitySubscription?.cancel();
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
            onPressed: null,
            icon: Icon(
              _isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
            ),
            tooltip: _isOffline ? 'Offline' : 'Online',
          ),
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
                  return ValueListenableBuilder<List<LogModel>>(
                    valueListenable: _controller.logsNotifier,
                    builder: (context, currentLogs, _) {
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
                                  onPressed: () => _goToEditor(
                                    log: LogModel(
                                      id: '',
                                      title: '',
                                      description: '',
                                      date: '',
                                      authorId: widget.currentUserId,
                                      teamId: widget.userTeamId,
                                      isPublic: false,
                                    ),
                                  ),
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
                            final isOwner =
                                log.authorId == widget.currentUserId;
                            final canUpdate = AccessPolicy.canPerform(
                              widget.userRole,
                              'update',
                              isOwner: isOwner,
                            );
                            final canDelete = AccessPolicy.canPerform(
                              widget.userRole,
                              'delete',
                              isOwner: isOwner,
                            );
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
                                          MarkdownBody(
                                            data: log.description,
                                            shrinkWrap: true,
                                            styleSheet:
                                                MarkdownStyleSheet.fromTheme(
                                                  theme,
                                                ).copyWith(
                                                  p: theme.textTheme.bodyMedium,
                                                ),
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
                                              Icon(
                                                log.isPublic
                                                    ? Icons.public_rounded
                                                    : Icons.lock_rounded,
                                                size: 15,
                                                color: log.isPublic
                                                    ? Colors.blueGrey
                                                    : colorScheme.primary,
                                              ),
                                              Text(
                                                log.isPublic
                                                    ? 'Public'
                                                    : 'Private',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                              Icon(
                                                log.isSynced
                                                    ? Icons.cloud_done_rounded
                                                    : Icons
                                                          .cloud_upload_rounded,
                                                size: 16,
                                                color: log.isSynced
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        if (canUpdate)
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: Icon(
                                              Icons.edit_rounded,
                                              color: colorScheme.primary,
                                            ),
                                            onPressed: () {
                                              final originalIndex = currentLogs
                                                  .indexWhere(
                                                    (item) =>
                                                        item.id == log.id &&
                                                        item.title ==
                                                            log.title &&
                                                        item.date == log.date,
                                                  );
                                              _goToEditor(
                                                log: log,
                                                index: originalIndex == -1
                                                    ? null
                                                    : originalIndex,
                                              );
                                            },
                                          ),
                                        if (canDelete)
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
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

                                              final originalIndex = currentLogs
                                                  .indexWhere(
                                                    (item) =>
                                                        item.id == log.id &&
                                                        item.title ==
                                                            log.title &&
                                                        item.date == log.date,
                                                  );
                                              if (originalIndex == -1) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Data log tidak ditemukan di daftar.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              try {
                                                await _controller.removeLog(
                                                  originalIndex,
                                                );
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(content: Text('$e')),
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
        onPressed: () => _goToEditor(
          log: LogModel(
            id: '',
            title: '',
            description: '',
            date: '',
            authorId: widget.currentUserId,
            teamId: widget.userTeamId,
            isPublic: false,
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

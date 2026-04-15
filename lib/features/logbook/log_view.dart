import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:logbook_app_001/features/auth/login_view.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/logbook/log_editor_page.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/access_policy.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_001/features/vision/vision_view.dart';
import 'package:logbook_app_001/features/vision/vision_controller.dart';

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
  static const String _technicalFilterPrefsKey = 'log_view_technical_filter_v1';
  static const List<String> _technicalCategories = [
    'Mechanical',
    'Electronic',
    'Software',
  ];

  static const String _emptyStateSvg = '''
<svg width="220" height="180" viewBox="0 0 220 180" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFF8EF"/>
      <stop offset="1" stop-color="#F1E4D5"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="212" height="172" rx="22" fill="url(#g1)"/>
  <circle cx="48" cy="42" r="10" fill="#26A69A" fill-opacity="0.20"/>
  <circle cx="178" cy="32" r="8" fill="#4E342E" fill-opacity="0.20"/>
  <rect x="30" y="48" width="160" height="96" rx="14" fill="#FFFFFF"/>
  <rect x="44" y="66" width="90" height="10" rx="5" fill="#D7CCC8"/>
  <rect x="44" y="84" width="124" height="8" rx="4" fill="#EFEBE9"/>
  <rect x="44" y="98" width="116" height="8" rx="4" fill="#EFEBE9"/>
  <rect x="44" y="112" width="80" height="8" rx="4" fill="#EFEBE9"/>
  <circle cx="164" cy="116" r="12" fill="#26A69A"/>
  <path d="M159 116.5L163 120.5L170 111" stroke="white" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  final MongoService _mongoService = MongoService();
  late final LogController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  final ValueNotifier<String?> _technicalFilter = ValueNotifier<String?>(null);
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
    unawaited(_restoreTechnicalFilter());
    _initConnectivityStatus();
    initializeDateFormatting('id_ID');
  }

  Future<void> _restoreTechnicalFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilter = prefs.getString(_technicalFilterPrefsKey);
    if (savedFilter == null || !_technicalCategories.contains(savedFilter)) {
      _technicalFilter.value = null;
      return;
    }
    _technicalFilter.value = savedFilter;
  }

  Future<void> _setTechnicalFilter(String? value) async {
    _technicalFilter.value = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_technicalFilterPrefsKey);
      return;
    }
    await prefs.setString(_technicalFilterPrefsKey, value);
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

  Color _technicalTint(String technicalCategory) {
    switch (technicalCategory) {
      case 'Mechanical':
        return Colors.green.withValues(alpha: 0.18);
      case 'Electronic':
        return Colors.blue.withValues(alpha: 0.18);
      case 'Software':
        return Colors.deepPurple.withValues(alpha: 0.18);
      default:
        return Colors.blueGrey.withValues(alpha: 0.14);
    }
  }

  Color _technicalForeground(String technicalCategory) {
    switch (technicalCategory) {
      case 'Mechanical':
        return Colors.green.shade800;
      case 'Electronic':
        return Colors.blue.shade800;
      case 'Software':
        return Colors.deepPurple.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  IconData _technicalIcon(String technicalCategory) {
    switch (technicalCategory) {
      case 'Mechanical':
        return Icons.precision_manufacturing_rounded;
      case 'Electronic':
        return Icons.memory_rounded;
      case 'Software':
        return Icons.code_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _technicalFilterBackground(String? technicalCategory, bool selected) {
    if (technicalCategory == null) {
      return selected ? const Color(0xFFF1DCA7) : const Color(0xFFF5EAD0);
    }
    final base = _technicalTint(technicalCategory);
    return selected
        ? base.withValues(alpha: 0.35)
        : base.withValues(alpha: 0.16);
  }

  Color _technicalFilterForeground(String? technicalCategory) {
    if (technicalCategory == null) {
      return const Color(0xFF6D5200);
    }
    return _technicalForeground(technicalCategory);
  }

  Widget _buildInformativeEmptyState(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(_emptyStateSvg, width: 220, height: 180),
            const SizedBox(height: 12),
            Text(
              'Belum ada aktivitas hari ini?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Mulai catat kemajuan proyek Anda!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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

  Widget _buildSearchEmptyState(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String query,
  ) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'Catatan tidak ditemukan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Tidak ada hasil untuk "$query". Coba kata kunci lain atau kosongkan pencarian.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                _searchQuery.value = '';
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset Pencarian'),
            ),
          ],
        ),
      ),
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
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    _searchQuery.dispose();
    _technicalFilter.dispose();
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
          IconButton(onPressed: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const VisionView())
            ), 
            icon: const Icon(Icons.camera_alt_rounded))
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ValueListenableBuilder<String?>(
                valueListenable: _technicalFilter,
                builder: (context, selectedTechnical, _) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Semua Teknis'),
                          selected: selectedTechnical == null,
                          backgroundColor: _technicalFilterBackground(
                            null,
                            false,
                          ),
                          selectedColor: _technicalFilterBackground(null, true),
                          checkmarkColor: _technicalFilterForeground(null),
                          labelStyle: TextStyle(
                            color: _technicalFilterForeground(null),
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: _technicalFilterBackground(null, true),
                          ),
                          onSelected: (_) {
                            unawaited(_setTechnicalFilter(null));
                          },
                        ),
                        const SizedBox(width: 8),
                        ..._technicalCategories.map(
                          (technical) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(technical),
                              selected: selectedTechnical == technical,
                              backgroundColor: _technicalFilterBackground(
                                technical,
                                false,
                              ),
                              selectedColor: _technicalFilterBackground(
                                technical,
                                true,
                              ),
                              checkmarkColor: _technicalFilterForeground(
                                technical,
                              ),
                              labelStyle: TextStyle(
                                color: _technicalFilterForeground(technical),
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: _technicalFilterBackground(
                                  technical,
                                  true,
                                ),
                              ),
                              onSelected: (isSelected) {
                                unawaited(
                                  _setTechnicalFilter(
                                    isSelected ? technical : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _searchQuery,
                builder: (context, query, child) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: _technicalFilter,
                    builder: (context, selectedTechnical, child) {
                      return ValueListenableBuilder<List<LogModel>>(
                        valueListenable: _controller.logsNotifier,
                        builder: (context, currentLogs, _) {
                          final normalizedQuery = query.toLowerCase();
                          final filteredLogs = currentLogs.where((log) {
                            final matchesSearch =
                                log.title.toLowerCase().contains(
                                  normalizedQuery,
                                ) ||
                                log.description.toLowerCase().contains(
                                  normalizedQuery,
                                );
                            final matchesTechnical =
                                selectedTechnical == null ||
                                log.technicalCategory == selectedTechnical;
                            return matchesSearch && matchesTechnical;
                          }).toList();

                          if (currentLogs.isEmpty) {
                            return _buildInformativeEmptyState(
                              context,
                              theme,
                              colorScheme,
                            );
                          }

                          if (filteredLogs.isEmpty) {
                            return _buildSearchEmptyState(
                              context,
                              theme,
                              colorScheme,
                              query.trim(),
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
                                final technicalBg = _technicalTint(
                                  log.technicalCategory,
                                );
                                final technicalFg = _technicalForeground(
                                  log.technicalCategory,
                                );

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: technicalBg,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            _technicalIcon(
                                              log.technicalCategory,
                                            ),
                                            color: technicalFg,
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
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                      p: theme
                                                          .textTheme
                                                          .bodyMedium,
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
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          _categoryIcon(
                                                            log.category,
                                                          ),
                                                          size: 12,
                                                          color: categoryFg,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          log.category,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: categoryFg,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: technicalBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      log.technicalCategory,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: technicalFg,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  Text(
                                                    _formatLogTimestamp(
                                                      log.date,
                                                    ),
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                  Icon(
                                                    log.isSynced
                                                        ? Icons
                                                              .cloud_done_rounded
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
                                                  final originalIndex =
                                                      currentLogs.indexWhere(
                                                        (item) =>
                                                            item.id == log.id &&
                                                            item.title ==
                                                                log.title &&
                                                            item.date ==
                                                                log.date,
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
                                                  final shouldDelete = await showDialog<bool>(
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
                                                    if (!context.mounted) {
                                                      return;
                                                    }
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

                                                  final originalIndex =
                                                      currentLogs.indexWhere(
                                                        (item) =>
                                                            item.id == log.id &&
                                                            item.title ==
                                                                log.title &&
                                                            item.date ==
                                                                log.date,
                                                      );
                                                  if (originalIndex == -1) {
                                                    if (!context.mounted) {
                                                      return;
                                                    }
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
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text('$e'),
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

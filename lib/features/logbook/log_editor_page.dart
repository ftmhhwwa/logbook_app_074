import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/access_policy.dart';

class LogEditorPage extends StatefulWidget {
  final LogModel log;
  final int? index;
  final LogController controller;
  final String currentUserId;
  final String currentUserRole;
  final String currentUserTeamId;

  const LogEditorPage({
    super.key,
    required this.log,
    this.index,
    required this.controller,
    required this.currentUserId,
    required this.currentUserRole,
    required this.currentUserTeamId,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final List<String> _categories = [
    'Akademik',
    'Pekerjaan',
    'Pribadi',
    'Urgent',
  ];
  final List<String> _technicalCategories = [
    'Mechanical',
    'Electronic',
    'Software',
  ];
  late String _selectedCategory;
  late String _selectedTechnicalCategory;
  late bool _isPublic;

  bool get _isAddMode => widget.log.id == null || widget.log.id!.isEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log.title);
    _descController = TextEditingController(text: widget.log.description);
    _selectedCategory = _categories.contains(widget.log.category)
        ? widget.log.category
        : _categories.first;
    _selectedTechnicalCategory =
        _technicalCategories.contains(widget.log.technicalCategory)
        ? widget.log.technicalCategory
        : _technicalCategories.first;
    _isPublic = widget.log.isPublic;

    _descController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _save() async {
    if (_isAddMode &&
        !AccessPolicy.canPerform(widget.currentUserRole, 'create')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak memiliki izin menambah data.'),
        ),
      );
      return;
    }

    if (!_isAddMode) {
      final isOwner = widget.log.authorId == widget.currentUserId;
      if (!AccessPolicy.canPerform(
        widget.currentUserRole,
        'update',
        isOwner: isOwner,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda tidak memiliki izin mengubah data.'),
          ),
        );
        return;
      }
    }

    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan deskripsi wajib diisi.')),
      );
      return;
    }

    try {
      if (_isAddMode) {
        await widget.controller.addLog(
          _titleController.text.trim(),
          _descController.text.trim(),
          widget.currentUserId,
          widget.currentUserTeamId,
          _isPublic,
          _selectedTechnicalCategory,
        );
      } else {
        if (widget.index == null) {
          throw Exception('Index log tidak ditemukan untuk update.');
        }

        await widget.controller.updateLog(
          widget.index!,
          _titleController.text.trim(),
          _descController.text.trim(),
          _selectedCategory,
          _isPublic,
          _selectedTechnicalCategory,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan data: $e')));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _descController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  void _insertMarkdownTemplate(String template) {
    final current = _descController.text;
    final updated = current.isEmpty ? template : '$current\n$template';
    _descController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  Widget _buildEditorHeader(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEBDCC8), Color(0xFFF7EFE4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF7A5A00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Color(0xFF7A5A00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAddMode ? 'Buat Catatan Baru' : 'Perbarui Catatan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tuliskan progres harian tim dengan format markdown.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownTools() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            label: const Text('H1'),
            onPressed: () => _insertMarkdownTemplate('# Judul Utama'),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('H2'),
            onPressed: () => _insertMarkdownTemplate('## Subjudul'),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Bold'),
            onPressed: () => _insertMarkdownTemplate('**teks penting**'),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Checklist'),
            onPressed: () => _insertMarkdownTemplate('- [ ] Tugas baru'),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Code'),
            onPressed: () =>
                _insertMarkdownTemplate('```\nprint("debug")\n```'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2E8DA),
        appBar: AppBar(
          title: Text(_isAddMode ? "Catatan Baru" : "Edit Catatan"),
          backgroundColor: const Color(0xFFF2E8DA),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Editor"),
              Tab(text: "Pratinjau"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Editor
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditorHeader(colorScheme, theme),
                  const SizedBox(height: 14),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Judul',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                              prefixIcon: Icon(Icons.label_outline_rounded),
                            ),
                            items: _categories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTechnicalCategory,
                            decoration: const InputDecoration(
                              labelText: 'Kategori Teknis',
                              prefixIcon: Icon(
                                Icons.precision_manufacturing_outlined,
                              ),
                            ),
                            items: _technicalCategories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedTechnicalCategory = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Visibilitas Publik'),
                            subtitle: Text(
                              _isPublic
                                  ? 'Public: terlihat oleh anggota tim & ketua'
                                  : 'Private: hanya Anda yang bisa melihat',
                            ),
                            value: _isPublic,
                            onChanged: (value) {
                              setState(() {
                                _isPublic = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Template Cepat Markdown',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMarkdownTools(),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _descController,
                            minLines: 6,
                            maxLines: 10,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText:
                                  'Tulis laporan dengan format Markdown...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${_descController.text.length} karakter',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$_wordCount kata',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Simpan Catatan'),
                    ),
                  ),
                ],
              ),
            ),
            // Tab 2: Markdown Preview
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _descController.text.trim().isEmpty
                      ? Text(
                          'Pratinjau akan muncul setelah Anda menulis isi catatan.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : MarkdownBody(data: _descController.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

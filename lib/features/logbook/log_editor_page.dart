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
  late String _selectedCategory;
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isAddMode ? "Catatan Baru" : "Edit Catatan"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Editor"),
              Tab(text: "Pratinjau"),
            ],
          ),
          actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Editor
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "Judul"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori'),
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
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _descController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: "Tulis laporan dengan format Markdown...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab 2: Markdown Preview
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MarkdownBody(data: _descController.text),
            ),
          ],
        ),
      ),
    );
  }
}

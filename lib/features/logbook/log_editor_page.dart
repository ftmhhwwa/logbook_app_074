import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/access_policy.dart';
import 'package:logbook_app_001/services/mongo_service.dart';

class LogEditorPage extends StatefulWidget {
  final LogModel log;
  final String currentUserId;
  final String currentUserRole;
  final String currentUserTeamId;

  const LogEditorPage({
    super.key,
    required this.log,
    required this.currentUserId,
    required this.currentUserRole,
    required this.currentUserTeamId,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  final MongoService _mongoService = MongoService();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final List<String> _categories = [
    'Akademik',
    'Pekerjaan',
    'Pribadi',
    'Urgent',
  ];
  late String _selectedCategory;

  bool get _isAddMode => widget.log.id == null || widget.log.id!.isEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log.title);
    _descController = TextEditingController(text: widget.log.description);
    _selectedCategory = _categories.contains(widget.log.category)
        ? widget.log.category
        : _categories.first;

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
        final newLog = LogModel(
          id: null,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          date: DateTime.now().toIso8601String(),
          category: _selectedCategory,
          authorId: widget.currentUserId,
          teamId: widget.currentUserTeamId,
        );
        await _mongoService.insertLog(newLog);
      } else {
        final updatedLog = LogModel(
          id: widget.log.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          date: DateTime.now().toIso8601String(),
          category: _selectedCategory,
          authorId: widget.log.authorId,
          teamId: widget.log.teamId,
        );
        await _mongoService.updateLog(
          updatedLog,
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
          currentUserTeamId: widget.currentUserTeamId,
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
                    value: _selectedCategory,
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
            Markdown(data: _descController.text),
          ],
        ),
      ),
    );
  }
}

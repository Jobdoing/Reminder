import 'package:flutter/material.dart';

import '../models/memory_record.dart';
import '../services/photo_store.dart';
import '../widgets/big_button.dart';
import 'photo_view_screen.dart';

class RecordDetailScreen extends StatefulWidget {
  const RecordDetailScreen({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final MemoryRecord record;
  final Future<void> Function(String newText) onEdit;
  final Future<void> Function() onDelete;

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  bool _editing = false;
  bool _busy = false;
  late final TextEditingController _controller = TextEditingController(
    text: widget.record.text,
  );

  Future<void> _saveEdit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入記錄內容')));
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onEdit(text);
      if (!mounted) return;
      setState(() => _editing = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('修改沒有儲存，原本內容保持不變')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除這筆記錄？'),
        content: const Text('照片、文字和這筆提醒都會刪除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.onDelete();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('刪除失敗，記錄仍然保留')));
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.record.photoPath.isEmpty
        ? null
        : PhotoStore.file(widget.record.photoPath);
    return Scaffold(
      appBar: AppBar(title: const Text('記錄', style: TextStyle(fontSize: 28))),
      body: SafeArea(
        child: Column(
          children: [
            if (photo?.existsSync() == true)
              GestureDetector(
                key: const Key('detailPhoto'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PhotoViewScreen(photoPath: widget.record.photoPath),
                  ),
                ),
                child: Container(
                  height: 280,
                  width: double.infinity,
                  color: Colors.black,
                  child: Image.file(photo!, fit: BoxFit.contain),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _editing
                    ? TextField(
                        controller: _controller,
                        maxLines: null,
                        style: const TextStyle(fontSize: 28),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      )
                    : Text(
                        widget.record.text,
                        style: const TextStyle(fontSize: 30),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _editing
                        ? BigButton(
                            label: '存',
                            icon: Icons.check,
                            onPressed: _busy ? null : _saveEdit,
                          )
                        : BigButton(
                            label: '修改文字',
                            icon: Icons.edit,
                            onPressed: _busy
                                ? null
                                : () => setState(() => _editing = true),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: BigButton(
                      label: '刪除',
                      icon: Icons.delete,
                      color: Colors.red,
                      onPressed: _busy ? null : _confirmDelete,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

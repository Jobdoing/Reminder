import 'package:flutter/material.dart';

import '../models/memory_record.dart';
import '../services/photo_store.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.records, required this.onTap});

  final List<MemoryRecord> records;
  final void Function(MemoryRecord) onTap;

  @override
  Widget build(BuildContext context) {
    final reminders =
        (records.where((r) => r.isReminder).toList()..sort(
              (a, b) => (a.reminderAt ?? a.createdAt).compareTo(
                b.reminderAt ?? b.createdAt,
              ),
            ))
            .toList();
    final others = records.where((r) => !r.isReminder).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('記錄', style: TextStyle(fontSize: 28))),
      body: records.isEmpty
          ? const Center(child: Text('還沒有記錄', style: TextStyle(fontSize: 28)))
          : _buildList(reminders, others),
    );
  }

  Widget _buildList(List<MemoryRecord> reminders, List<MemoryRecord> others) {
    // Build a flat item list: optional pinned header + reminder tiles + other tiles.
    final items = <Widget>[
      if (reminders.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '提醒',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        ...reminders.map((r) => _tile(r)),
        const Divider(height: 1),
      ],
      ...others.map((r) => _tile(r)),
    ];

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _tile(MemoryRecord r) {
    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: _thumb(r.photoPath),
      title: Text(
        r.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 26),
      ),
      subtitle: Text(
        _formatDate(r.createdAt),
        style: const TextStyle(fontSize: 20),
      ),
      onTap: () => onTap(r),
    );
  }

  Widget _thumb(String path) {
    if (path.isEmpty) return const Icon(Icons.photo, size: 48);
    final file = PhotoStore.file(path);
    if (file.existsSync()) {
      return SizedBox(
        width: 64,
        height: 64,
        child: Image.file(file, fit: BoxFit.cover),
      );
    }
    return const Icon(Icons.photo, size: 48);
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
}

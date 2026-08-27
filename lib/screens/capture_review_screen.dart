import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/memory_record.dart';
import '../semantic/note_analysis.dart' as na;
import '../semantic/note_analyzer.dart';
import '../services/contact_store.dart';
import '../services/part_of_day_store.dart';
import '../services/stt/stt_service.dart';
import '../widgets/big_button.dart';

class CaptureReviewScreen extends StatefulWidget {
  const CaptureReviewScreen({
    super.key,
    required this.photoPath,
    required this.stt,
    required this.onSave,
    required this.onRetake,
    this.analyzer = const NoteAnalyzer(),
    this.now,
  });

  final String photoPath;
  final SttService stt;
  final Future<void> Function(MemoryRecord) onSave;
  final VoidCallback onRetake;

  // Injectable for deterministic tests; defaults to DateTime.now() at analysis time.
  final NoteAnalyzer analyzer;
  final DateTime? now;

  @override
  State<CaptureReviewScreen> createState() => _CaptureReviewScreenState();
}

class _CaptureReviewScreenState extends State<CaptureReviewScreen> {
  static const _uuid = Uuid();
  bool _listening = true;
  String _partial = '';
  final _controller = TextEditingController();
  StreamSubscription<String>? _sub;
  na.NoteAnalysis? _analysis;
  // The reminder time actually used for saving: a concrete detected time, a
  // default/learned part-of-day time, or the current time on a resolved future
  // date. May be adjusted by the user via the time picker.
  DateTime? _reminderAt;
  // null = follow detection; set once the user flips the "要提醒我" switch.
  bool? _reminderOverride;
  bool _saving = false;

  bool get _reminderOn => _reminderOverride ?? (_analysis?.isReminder ?? false);

  // Concrete time if present; otherwise use the part-of-day default or the
  // current hour/minute on the resolved date. A reminder without a date remains
  // unresolved.
  DateTime? _effectiveReminderAt(na.NoteAnalysis a) {
    if (a.reminderAt != null) return a.reminderAt;
    final day = a.dayBase;
    if (day == null) return null;
    final part = a.vaguePart;
    if (part != null) {
      final (h, m) = PartOfDayStore.timeFor(part);
      return DateTime(day.year, day.month, day.day, h, m);
    }
    final now = widget.now ?? DateTime.now();
    return DateTime(day.year, day.month, day.day, now.hour, now.minute);
  }

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  Future<void> _startListening() async {
    try {
      await widget.stt.init();
      if (!mounted) return;
      final stream = await widget.stt.start();
      if (!mounted) {
        await widget.stt.stop();
        return;
      }
      _sub = stream.listen((text) {
        if (mounted) setState(() => _partial = text);
      }, onError: _showSpeechFallback);
    } catch (error) {
      _showSpeechFallback(error);
    }
  }

  void _showSpeechFallback(Object? error) {
    if (!mounted || !_listening) return;
    unawaited(_sub?.cancel());
    _sub = null;
    final analysis = widget.analyzer.analyze(
      '',
      now: widget.now ?? DateTime.now(),
      contacts: ContactStore.names(),
    );
    setState(() {
      _listening = false;
      _analysis = analysis;
      _reminderAt = _effectiveReminderAt(analysis);
    });
    var message = '無法使用麥克風，請直接打字';
    if (error is PlatformException) {
      if (error.code == 'MODEL_DOWNLOAD_SCHEDULED') {
        message = '離線中文語音正在下載，完成後請按「重講」';
      } else if (error.code == 'MODEL_DOWNLOAD_FAILED' ||
          error.code == 'UNAVAILABLE') {
        message = '尚未安裝離線中文語音，請連上網路後再試';
      }
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finishListening() async {
    final full = await widget.stt.stop();
    if (!mounted) return;
    final text = full.isNotEmpty ? full : _partial;
    final analysis = widget.analyzer.analyze(
      text,
      now: widget.now ?? DateTime.now(),
      contacts: ContactStore.names(),
    );
    setState(() {
      _listening = false;
      _controller.text = analysis.correctedText;
      _analysis = analysis;
      _reminderAt = _effectiveReminderAt(analysis);
    });
  }

  // Let the user confirm/adjust the reminder time. If the time came from a vague
  // part-of-day, remember the chosen time so that part defaults to it next time.
  Future<void> _pickTime() async {
    final now = widget.now ?? DateTime.now();
    final day = _analysis?.dayBase;
    final base =
        _reminderAt ??
        (day == null
            ? now
            : DateTime(day.year, day.month, day.day, now.hour, now.minute));
    var selected = base;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '選擇時間',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 216,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: base,
                    use24hFormat: true,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('取消', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: const Text('確定', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    selected = DateTime(
      base.year,
      base.month,
      base.day,
      picked.hour,
      picked.minute,
    );
    if (mounted) {
      setState(() => _reminderAt = selected);
    }
    final part = _analysis?.vaguePart;
    if (part != null) {
      await PartOfDayStore.setTimeFor(part, picked.hour, picked.minute);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final on = _reminderOn;
    final analysis = _analysis;
    final reminderAt = _reminderAt;
    if (on &&
        reminderAt != null &&
        !reminderAt.isAfter(widget.now ?? DateTime.now())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提醒時間已經過了，請重新說明日期或關閉提醒')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        MemoryRecord(
          id: _uuid.v4(),
          photoPath: widget.photoPath,
          text: _controller.text,
          createdAt: DateTime.now(),
          isReminder: on,
          reminderAt: on ? reminderAt : null,
          intent: analysis?.intent.name ?? 'record',
          mentionedContacts: analysis?.mentionedContacts ?? const [],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_listening) unawaited(widget.stt.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _listening ? _buildListening() : _buildReview()),
    );
  }

  Widget _buildListening() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('正在聽… 請說話', style: TextStyle(fontSize: 32)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_partial, style: const TextStyle(fontSize: 28)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: BigButton(
            label: '說完了',
            icon: Icons.check,
            onPressed: _finishListening,
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final analysis = _analysis;
    return Column(
      children: [
        if (analysis != null) _buildReminderRow(),
        if (analysis != null) _buildIntentChip(analysis.intent),
        if (File(widget.photoPath).existsSync())
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Image.file(File(widget.photoPath), fit: BoxFit.contain),
            ),
          ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 28),
              decoration: const InputDecoration(
                hintText: '在這裡打字，或之後再改',
                hintStyle: TextStyle(fontSize: 24, color: Colors.black38),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              // Re-analyze live so the reminder banner reflects edits/corrections
              // to the recognised text (elderly users often fix STT mistakes).
              onChanged: (v) => setState(() {
                final analysis = widget.analyzer.analyze(
                  v,
                  now: widget.now ?? DateTime.now(),
                  contacts: ContactStore.names(),
                );
                _analysis = analysis;
                _reminderAt = _effectiveReminderAt(analysis);
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: BigButton(
                  label: '存起來',
                  icon: Icons.check,
                  onPressed: _saving ? null : _save,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: BigButton(
                  label: '重講',
                  icon: Icons.refresh,
                  color: Colors.grey,
                  onPressed: widget.onRetake,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntentChip(na.Intent intent) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(
          _intentLabel(intent),
          style: TextStyle(fontSize: 22, color: Colors.blue.shade900),
        ),
      ),
    );
  }

  // "要提醒我" switch (defaults to detection, user can flip) plus the resolved
  // time. This lets the user fix a wrong auto-detection instead of the app
  // deciding for them. The time is always shown and tappable to adjust, and we
  // ask "這個時間可以嗎？" so nothing is scheduled silently.
  Widget _buildReminderRow() {
    final on = _reminderOn;
    final at = _reminderAt;
    return Container(
      width: double.infinity,
      color: on ? Colors.amber.shade100 : Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('要提醒我', style: TextStyle(fontSize: 22)),
              const Spacer(),
              Switch(
                value: on,
                onChanged: (v) => setState(() => _reminderOverride = v),
              ),
            ],
          ),
          if (on && at != null) _buildTimeConfirm(at),
          if (on && at == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                '沒有抓到時間，時間到不會響',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeConfirm(DateTime at) {
    final t =
        '${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '這個時間可以嗎？',
            style: TextStyle(fontSize: 18, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade400, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, size: 20, color: Colors.black54),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Maps Intent enum to a short Chinese display label.
  static String _intentLabel(na.Intent intent) {
    switch (intent) {
      case na.Intent.call:
        return '📞 電話';
      case na.Intent.visit:
        return '🏥 就醫';
      case na.Intent.medication:
        return '💊 吃藥';
      case na.Intent.shopping:
        return '🛒 購物';
      case na.Intent.meal:
        return '🍽 用餐／聚餐';
      case na.Intent.classSession:
        return '📚 上課';
      case na.Intent.exercise:
        return '🏃 運動';
      case na.Intent.investment:
        return '📈 投資';
      case na.Intent.date:
        return '💜 約會';
      case na.Intent.visitor:
        return '👤 訪客／拜訪';
      case na.Intent.social:
        return '🎉 社交';
      case na.Intent.work:
        return '💼 工作';
      case na.Intent.travel:
        return '✈️ 旅遊';
      case na.Intent.birthday:
        return '🎂 生日';
      case na.Intent.family:
        return '👨‍👩‍👧 家人';
      case na.Intent.reminder:
        return '⏰ 提醒';
      case na.Intent.record:
        return '📝 記錄';
    }
  }
}

import 'package:flutter/material.dart';
import '../services/contact_importer.dart';
import '../services/contact_store.dart';
import '../services/notification_service.dart';
import 'privacy_policy_screen.dart';

/// Child-facing settings screen: import device contacts (one tap) and/or
/// manually enter the elderly person's common contact names (one per line).
/// These feed the name-correction feature.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ContactStore.names().join('\n'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final names = _controller.text.split('\n');
    await ContactStore.setNames(names);
    if (!mounted) return;
    final count = ContactStore.names().length;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已儲存 $count 位聯絡人')));
  }

  Future<void> _importFromDevice() async {
    final count = await ContactImporter.importFromDevice();
    if (!mounted) return;
    if (count == -1) {
      await _showContactPermissionHelp();
      return;
    }
    setState(() => _controller.text = ContactStore.names().join('\n'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已匯入，共 $count 位聯絡人')));
  }

  Future<void> _showContactPermissionHelp() async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要聯絡人權限'),
        content: const Text('請在下一頁開啟「聯絡人」，再回到 App 重新匯入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('開啟系統設定'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await ContactImporter.openSettings();
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除聯絡人？'),
        content: const Text('只會清除 App 內的名單，不會刪除手機聯絡人。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ContactStore.setNames(const []);
    if (!mounted) return;
    setState(_controller.clear);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除 App 內的聯絡人')));
  }

  Future<void> _openNotificationSettings() async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isAndroid =
            Theme.of(dialogContext).platform == TargetPlatform.android;
        final guidance = isAndroid
            ? '請在下一頁開啟通知、聲音和鎖定畫面。若仍無聲，也請確認手機不是震動模式。'
            : '請在下一頁開啟允許通知、聲音、鎖定畫面和橫幅。若仍無聲，也請確認手機不是靜音模式。';
        return AlertDialog(
          title: const Text('檢查提醒設定'),
          content: Text(guidance),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('開啟系統設定'),
            ),
          ],
        );
      },
    );
    if (openSettings != true) return;

    final opened = await NotificationService.openNotificationSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('無法開啟系統設定')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定', style: TextStyle(fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
            child: const Text('隱私政策', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '常用聯絡人（一行一個名字）\n用來自動校正說錯的人名',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              '若允許同步聯絡人的名字，可以比對口述的人名。語音辨識可能使用手機系統的線上服務；照片、聯絡人與記錄不會由本 App 上傳。',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('設定提醒顯示與聲音', style: TextStyle(fontSize: 22)),
              ),
              onPressed: _openNotificationSettings,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.contacts, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('載入手機聯絡人', style: TextStyle(fontSize: 22)),
              ),
              onPressed: _importFromDevice,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 26),
                decoration: const InputDecoration(
                  hintText: '王小明\n陳美玲\n李醫師',
                  hintStyle: TextStyle(fontSize: 22, color: Colors.black38),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('儲存', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('清除', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

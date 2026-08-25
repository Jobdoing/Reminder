import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隱私政策', style: TextStyle(fontSize: 24))),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Text('生效日期：2026 年 8 月 25 日', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            _PolicySection(
              title: '永遠免費與開放原始碼',
              body:
                  '「銀髮記憶」官方版本永遠免費，原始碼以 Apache License 2.0 公開於：\nhttps://github.com/Jobdoing/Reminder',
            ),
            _PolicySection(
              title: '資料如何使用',
              body:
                  '「銀髮記憶」不需要帳號，也沒有廣告、分析或追蹤。拍攝的照片、記錄文字、提醒時間和匯入的聯絡人名稱儲存在 App 的本機空間，不會上傳到本 App 開發者的伺服器。手機作業系統仍可能依使用者的備份或換機設定處理 App 資料；開發者無法存取這些系統備份。',
            ),
            _PolicySection(
              title: '手機權限',
              body:
                  '相機用於拍照記錄；麥克風和語音辨識用於把口述轉成文字；聯絡人權限只用於匯入名稱以校正人名；通知和鬧鐘權限用於準時提醒。使用者可以在手機設定中隨時取消權限。',
            ),
            _PolicySection(
              title: '語音辨識',
              body:
                  '語音辨識由手機系統提供。依手機型號、已下載的語音模型和系統設定，語音可能在手機內處理，也可能暫時送到 Apple、Google 或手機的語音服務供應商轉成文字。本 App 的開發者不會收到或保留這些語音資料。',
            ),
            _PolicySection(
              title: '刪除與保留',
              body:
                  '使用者可以在 App 內刪除單筆記錄與照片，並在設定中清除已匯入的聯絡人名單。移除 App 會刪除手機內的 App 資料；若手機系統另有備份，保留與刪除方式依使用者的 Apple 或 Google 帳號設定。本 App 沒有雲端帳號或開發者伺服器副本。',
            ),
            _PolicySection(
              title: '聯絡方式',
              body:
                  '若對隱私政策有疑問，請透過開源專案的 Issues 聯絡：\nhttps://github.com/Jobdoing/Reminder/issues',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 20, height: 1.5)),
        ],
      ),
    );
  }
}

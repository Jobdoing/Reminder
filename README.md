# Reminder（中文產品名稱：「銀髮記憶」）

「銀髮記憶」是一個幫助記憶的手機記錄與提醒 App。使用者可以拍下眼前的事物、說出要記得的事，再確認文字與提醒時間。

這個 App 是為了自家長輩開發，也分享給有需要的人使用。官方版本永遠免費，原始碼公開供大家檢視。

## 特點

- 大按鈕與大字體，操作步驟簡短。
- 拍照後使用手機系統語音辨識轉成文字。
- 可辨識「明天早上」、「下禮拜三」、「一分鐘後」等自然時間說法。
- 提醒時間一定顯示給使用者確認，也可手動調整。
- 照片、記錄與聯絡人名稱儲存在手機本機。
- 支援 iPhone 與 Android 手機。

## 開發環境

- Flutter 3.41.9
- Dart 3.11.5
- iOS 13.0 以上
- Android 7.0（API 24）以上

```bash
flutter pub get
flutter test
flutter run
```

Android 正式版需要開發者自行準備 upload keystore 與 `android/key.properties`。簽章檔案與密碼不應加入 Git。
正式上架前，應把 upload keystore 與密碼分開備份到安全位置；遺失後可能無法發布更新。

## 隱私

請見 [PRIVACY.md](PRIVACY.md)。

## 授權

本專案使用 [Apache License 2.0](LICENSE)。

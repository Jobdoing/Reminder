# 銀髮記憶：商店資料草稿（繁體中文）

## 共用資料

- App 名稱：銀髮記憶
- iOS Bundle ID：`com.pyramius.reminder`
- Android application ID：`com.pyramius.reminder`
- 隱私政策：https://github.com/Jobdoing/Reminder/blob/main/PRIVACY.md
- 支援網址：https://github.com/Jobdoing/Reminder/issues
- 帳號：不需要
- 廣告：沒有
- 付費功能：沒有
- 定位：不使用
- 用戶追蹤：沒有
- 目標對象：高齡使用者與協助他們的家人；不是兒童 App
- 支援裝置：iPhone 與 Android 手機；首版不支援 iPad
- 產品定位：幫助記憶的生活記錄與提醒工具，不是醫療器材，不提供診斷或治療建議

## App Store

- 副標題（30 字內）：拍下眼前的事，說出要記得的事
- 建議主類別：工具程式
- 建議次類別：生活風格
- 關鍵字：銀髮,提醒,記憶,語音,拍照,聯絡人,回診,行程,長輩

### 宣傳文字

用拍照和口述留下當下的事，確認時間後由手機準時提醒。

### 完整描述

「銀髮記憶」讓記錄事情只需要三個步驟：拍照、說話、確認。

對著眼前的人或物拍一張照片，再說出「明天早上去回診」、「下禮拜三看醫生」或「一分鐘後通知我」。App 會顯示辨識的文字和提醒時間，讓使用者確認或調整後才儲存。

主要功能：

- 大字與大按鈕。
- 拍照加語音記錄。
- 自然時間說法的提醒。
- 可調整並學習早上、中午、下午、傍晚和晚上的常用時間。
- 可匯入聯絡人名稱，幫助校正口述人名。
- 提醒有「停止」按鈕，開啟 App 也會停止正在響的提醒。

照片、記錄和聯絡人名稱儲存在手機本機。本 App 沒有帳號、廣告、分析或追蹤，官方版本永遠免費並開放原始碼。

### App Review 備註

App 不需要帳號。開啟後允許相機，拍照後再允許麥克風與語音辨識。說出「設定一分鐘後通知我」，確認時間並儲存，即可驗證本機通知。聯絡人匯入是選用功能。

### App Privacy 草稿

- 資料收集：選「否，我們不會從此 App 收集資料」。照片、文字、提醒時間與聯絡人名稱只留在 App 本機；開發者與第三方套件沒有伺服器接收這些資料。
- 語音辨識：iOS 系統可能把語音送到 Apple 即時辨識；隱私政策已揭露。依 Apple 定義，開發者不用申報 Apple 自己收集的資料，但送審時仍應以 Xcode 產生的 Privacy Report 再核對一次。
- 隱私政策網址：使用上方公開網址。
- 年齡分級：在 App Store Connect 回答 2026 年新版年齡分級問題；本 App 不含暴力、色情、賭博、付費或醫療診斷內容。
- 加密：`ITSAppUsesNonExemptEncryption` 已設為 `false`。

## Google Play

- 應用類別：生產力工具
- 簡短說明（80 字內）：拍照並說出要記得的事，確認時間後由手機準時提醒。
- 完整說明：使用上方 App Store 完整描述。

### Data Safety 草稿

- 帳號、廣告、分析、追蹤：無。
- 照片、記錄文字、聯絡人名稱：只由 App 在裝置上處理，不宣告為開發者收集；作業系統備份不由開發者存取。
- 語音資料：使用者主動開啟；系統語音服務可能離開裝置做即時辨識。保守填報為 Audio，選用、App functionality、ephemeral processing、不用於追蹤，不與其他第三方分享。
- 資料傳輸加密：由手機系統語音服務處理；送審前在 Play Console 依實際系統服務再確認。
- 刪除方式：App 內刪除單筆記錄、清除聯絡人名單，或移除 App 刪除所有本機資料。

### 權限申報草稿

- 精準提醒使用 `SCHEDULE_EXACT_ALARM`，由使用者在系統設定中明確開啟；沒有使用受限的 `USE_EXACT_ALARM`。
- 核心用途：使用者指定時間的生活提醒。審查操作可使用「設定一分鐘後通知我」。
- 相機、麥克風、聯絡人與通知只在使用者啟動相對應功能時請求。
- 最終 Android manifest 不含舊式 `READ_EXTERNAL_STORAGE` 或 `WRITE_EXTERNAL_STORAGE`。
- Target API：36；Min API：24。

## 尚未完成的商店項目

- Play App Signing 設定；本機 Android upload keystore 已建立。
- App Store Connect 與 Play Console 的法律聯絡資料。
- App Store 新版年齡分級問卷與 Xcode Privacy Report 最終核對。
- Play Console 的 Data Safety 與精準提醒用途申報。

## 已完成的送審材料

- iPhone 與 Android 商店截圖；只含示範資料，不含真實聯絡人或個人記錄。
- Release 建置後的 iPhone 與 Android 實機安裝及啟動驗收。

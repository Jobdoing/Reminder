# 手機端繁體中文人名位置模型研究

日期：2026-08-27

## 結論

要限制聯絡人名稱的替換位置，應使用能輸出 `PERSON` 範圍的 NER，不是只判斷名詞與動詞的 POS。

現成模型中，**CKIP ALBERT Tiny NER** 是最小且官方明確定位為繁體中文、可輸出 `PERSON` 的候選：4M 參數，官方 FP32 權重為 16,037,849 bytes（約 15.3 MiB）。技術上可嘗試匯出 ONNX，再用 ONNX Runtime Mobile 於 Android/iOS 執行。

但它現在還不能直接進入已發行 App：

- 模型授權為 GPL-3.0，需先確認與 App 發行方式是否相容。
- 官方權重是 PyTorch，沒有可直接集成的 Android/iOS 成品。
- 官方 NER F1 為 71.17%，而且訓練資料與本 App 的短口語句型不同，不能未測試就當成可發行功能。

因此最小可行的下一步是：**只對 CKIP ALBERT Tiny NER 做離線 PoC，不先改 App**。它若能穩定找出實際 STT 文字中的 `PERSON` 範圍，且授權可接受，才進入手機端轉換。

## POS 為什麼不夠

POS 可分辨普通名詞、動詞、形容詞等詞性，但「飯」、「水果」、「醫院」也都是名詞。即使 POS 有專有名詞標記，也不等於完整的人名範圍。

「主詞」也不是正確限制：

- `李佩瑜明天來` 中，人名可能是主詞。
- `明天跟李佩瑜吃飯` 中，人名不是主詞。
- `請李佩瑜提醒我` 中，人名是動作的受詞。

依賴主詞、動詞或前綴都會漏掉合法句型。NER 則直接回答「哪一段是人名」。

## 候選比較

| 方案 | 模型與大小 | 繁體中文 | 輸出 | 手機端 | 維護與授權 | 判斷 |
| --- | --- | --- | --- | --- | --- | --- |
| CKIP ALBERT Tiny NER | 4M 參數；PyTorch 權重 16,037,849 bytes | 官方定位為繁中模型，並以繁中測試集評估；NER 訓練集是 OntoNotes，官方未單獨說明其字體轉換過程 | `B/I/E/S-PERSON` 及其他 NER 類型；不同時輸出 POS | 可研究轉 ONNX；Android/iOS 均可用 ONNX Runtime Mobile，但尚未實際轉換 | 模型 2022-05-10 更新；repo 最後 push 2023-04-21；GPL-3.0 | **最佳技術 PoC 候選**，未過授權與手機驗證前不可發行 |
| CKIP BERT Tiny NER | 12M 參數；PyTorch 權重 45,891,063 bytes | 同上 | `PERSON` NER | 同樣需自行轉換 | 同一 repo 與 GPL-3.0 | NER F1 74.21%，只比 ALBERT Tiny 高 3.04 點，大小約 2.9 倍；不是最小解 |
| Baidu LAC Lite | `model.nb` 1,932,895 bytes；加字典約 2.05 MB | 官方未宣稱繁中訓練；2020 行動模型字典有 `请/里/台`，但未找到 `請/裡/臺/與` | 單一模型同時輸出 WS、POS、`PER/LOC/ORG/TIME` | 有官方 Android NDK/Paddle Lite 範例；LAC 文件只指向通用 iOS Paddle Lite demo | LAC repo 最後 push 2021-05-25；Apache-2.0 | **檔案最小**，但不可直接視為繁中方案；加 OpenCC 又會增加轉換與位置對應複雜度 |
| Apple Natural Language `NLTagger` | 系統提供，App 不攜帶模型 | API 定義 `.traditionalChinese`，但每個系統/語言可用標記不同 | API 有 `lexicalClass`、`nameType`、`personalName` | 僅 Apple 平台；必須在目標裝置查 `availableTagSchemes` | Apple 系統 API | 不能作 Android/iOS 共用基礎；本機 macOS 26.6.2 實測 zh-Hant 沒有 POS/NER scheme |
| Android `TextClassifier` | 系統提供 | 系統實作而定 | 只公開地址、日期、Email、電話、URL 等類型，沒有 person | Android 原生 | Android API | 不適用 |
| Google ML Kit Entity Extraction | 需下載語言模型 | 官方列出簡中與繁中 | 地址、日期、Email、金額、電話、URL 等，沒有 person | Android/iOS | Beta，官方明言沒有 SLA 或不相容變更保證 | 不適用 |

## 建議的最小處理流程

1. 只跑一個 NER 模型，不另外載入 WS 或 POS 模型。
2. 只將 NER 輸出的 `PERSON` 文字範圍交給現有拼音聯絡人比對。
3. 只有最佳聯絡人明顯優於第二名時才自動替換。
4. NER 沒有找到 `PERSON` 時不自動改，保留人工確認。

這個流程不依賴「跟、叫、請、陪」等前綴，也不假設人名必須是主詞。

已知天花板：NER 可能漏掉生僻姓名或被 STT 破壞得太嚴重的姓名。若將 NER 當成必須通過的門檻，它會降低誤改，但也可能降低校正成功率。此取捨必須用實際 STT 語料測量，不可只看官方 F1。

## PoC 應回答的問題

在任何 App 整合前，使用固定、不因結果修改的實際 STT 文字集比較：

- 句首直接是人名。
- 前面是「叫、請、陪、跟」及其他未列舉句型。
- 人名是主詞、受詞或介詞片語中的名詞。
- 無人名的一般名詞句子。
- 多個高度近音聯絡人。
- 二到多字姓名，不以字數寫死。

要分開記錄：`PERSON` 範圍命中率、有人名時的校正成功率、無人名時的誤改數，以及手機上的模型大小、峰值 RAM 與延遲。

## 實證與來源

- CKIP 官方列出 ALBERT Tiny/BERT Tiny 的參數、繁中訓練資料與 NER 成績：<https://github.com/ckiplab/ckip-transformers#model-performance>
- CKIP ALBERT Tiny NER 官方模型卡與 GPL-3.0 授權：<https://huggingface.co/ckiplab/albert-tiny-chinese-ner>
- CKIP ALBERT Tiny NER 官方模型 API（含檔案大小與更新時間）：<https://huggingface.co/api/models/ckiplab/albert-tiny-chinese-ner?blobs=true>
- CKIP ALBERT Tiny NER `config.json`（含 `PERSON` 標記）：<https://huggingface.co/ckiplab/albert-tiny-chinese-ner/raw/main/config.json>
- CKIP BERT Tiny NER 官方模型 API：<https://huggingface.co/api/models/ckiplab/bert-tiny-chinese-ner?blobs=true>
- CKIP 官方 repo 提交紀錄：<https://github.com/ckiplab/ckip-transformers/commits/master/>
- Baidu LAC 官方功能、PER/POS 標記、2 MB 行動模型與 Apache-2.0：<https://github.com/baidu/lac#工具介绍>
- Baidu LAC 官方 Android/Paddle Lite 整合：<https://github.com/baidu/lac/blob/master/Android/README.md>
- Baidu LAC v2.0 官方行動模型檔：<https://github.com/baidu/lac/releases/tag/v2.0.0>
- Baidu LAC 官方 repo 提交紀錄：<https://github.com/baidu/lac/commits/master/>
- ONNX Runtime Mobile 官方 Android/iOS 支援、量化與 runtime 縮減說明：<https://onnxruntime.ai/docs/tutorials/mobile/>
- Hugging Face 官方 ONNX 匯出與驗證 API：<https://huggingface.co/docs/optimum-onnx/en/onnx/package_reference/export>
- Apple `NLTagger` 可用標記查詢：<https://developer.apple.com/documentation/naturallanguage/nltagger/availabletagschemes(for:language:)>
- Apple `nameTypeOrLexicalClass` 與 `personalName`：<https://developer.apple.com/documentation/naturallanguage/nltagscheme/2976612-nametypeorlexicalclass> 、<https://developer.apple.com/documentation/naturallanguage/nltag/personalname>
- Android `TextClassifier` 公開實體類型：<https://developer.android.com/reference/android/view/textclassifier/TextClassifier>
- Google ML Kit Entity Extraction 支援語言與實體類型：<https://developers.google.com/ml-kit/language/entity-extraction>

### 可重複的本機查核

2026-08-27 於 macOS 26.6.2 / Xcode 26.3 執行：

```swift
import NaturalLanguage

print(
  NLTagger.availableTagSchemes(
    for: .word,
    language: .traditionalChinese
  ).map(\.rawValue).sorted()
)
```

輸出只有 `Language`、`Script`、`TokenType`，沒有 `LexicalClass` 或 `NameType`。這不能代表所有 iOS 版本，但證明 App 不可假設繁中 POS/NER 在每台 Apple 裝置都存在；必須用官方 API 在目標裝置查詢。

LAC v2.0 `models_android.zip` 中的實際檔案與字典可用下列命令從官方發行檔重複查核：

```sh
curl -fsSL https://github.com/baidu/lac/releases/download/v2.0.0/models_android.zip \
  | bsdtar -tvf -

curl -fsSL https://github.com/baidu/lac/releases/download/v2.0.0/models_android.zip \
  | bsdtar -xOf - models_android/laclite_model/word.dic
```

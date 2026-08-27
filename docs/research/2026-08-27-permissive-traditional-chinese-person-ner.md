# 寬鬆授權的手機端繁體中文 PERSON NER 查核

日期：2026-08-27

## 結論

截至本次查核，**沒有找到同時符合以下條件的現成模型**：

- Apache-2.0、MIT、BSD 或 CC-BY 等可商用寬鬆授權。
- 官方明確支援繁體中文。
- 已有可輸出 `PERSON`／`PER` 的 NER head，不只是 base encoder。
- 小到適合離線放進 Android 與 iOS App，並有可行的手機推論格式。

因此不應把 CKIP GPL 模型放進正式 App，也不應用一個只支援簡中的模型假裝已解決繁中姓名位置。現在最值得做的下一個小實驗是 **Baidu LAC Lite**；它符合授權、`PER` 與 Android 體積要求，但官方沒有宣稱繁體中文，必須先用固定繁中語料驗證，不能直接採用。

## 排名

| 排名 | 候選 | 授權與輸出 | 大小／手機條件 | 繁體中文證據 | 判斷 |
| --- | --- | --- | --- | --- | --- |
| 1 | Baidu LAC Lite | 官方 repo 為 Apache-2.0；輸出含 `PER` | 官方稱行動模型約 2 MB、主流手機單執行緒 200 QPS，並提供 Android NDK 範例 | **沒有官方繁中聲明** | 只適合下一個隔離 PoC；通過固定繁中案例後才可考慮整合 |
| 2 | `p988744/eland-ner-zh` | 模型卡為 Apache-2.0；`BertForTokenClassification`，含 `PER` | 以 `hfl/chinese-roberta-wwm-ext` BERT base 微調，不是 tiny；沒有手機成品證據 | 模型卡明確寫 Traditional Chinese，例子含「賴清德、魏哲家」 | 語言符合但太大，不能作最小手機方案 |
| 3 | `TomatoMTL/bert-mini-finetuned-ner-chinese-onnx` | Apache-2.0；config 有 `B-PER/I-PER` | INT8 ONNX 12,606,755 bytes | 上游模型卡稱訓練資料 unknown，也未聲明繁中 | **排除**：本機固定繁中 11 例只得 NER 3/11，六種「李佩瑜」位置全部漏掉 |

## 排除項目

- `hfl/minirbt-h288`、MacBERT、Chinese RoBERTa 等只有 base encoder 的模型：沒有姓名 NER head，不能直接輸出姓名位置。
- 只以 CLUENER、MSRA、People's Daily 等簡中資料訓練，且沒有繁中聲明或本機驗證的 NER：不把「中文」等同「繁體中文」。
- `AdapterHub/bert-base-multilingual-cased_wikiann_ner_zh_pfeiffer`：雖有 Apache-2.0 NER adapter 與 prediction head，但仍需完整 multilingual BERT base；不是獨立小模型，也沒有繁中短口語證據。
- CKIP ALBERT Tiny NER：技術 PoC 已成功，但模型卡是 GPL-3.0；依目前決策不採用。

## Baidu LAC Lite 的最小 PoC 門檻

只做隔離測試，不先改 App：

1. 使用現有固定 11 句，另加入常見繁體字與台灣姓名。
2. 分開記錄 `PER` 範圍命中、無姓名誤判及「NER＋通訊錄 Pinyin」最終結果。
3. 若需要 OpenCC 轉簡體才能推論，必須驗證轉換前後的字元位置映射；做不到就淘汰。
4. Android 實機測量模型加 runtime 後的 APK 增量、峰值 RAM 與單句延遲。
5. 未達到既有 CKIP 混合原型的 11/11，不進正式 App。

這條路與終極目標的關係是：它仍以 NER 找姓名位置，再由通訊錄決定要換成誰；只替換模型來源，不退回前綴窮舉。距離正式採用還差繁中準確率與 Android 實機兩道證據。

## 第一手來源與可重複查核

- Baidu LAC 官方 repo：功能含 `PER`、行動模型約 2 MB、Android 入口與 Apache-2.0：<https://github.com/baidu/lac>
- Baidu LAC 官方 Android NDK 整合說明：<https://github.com/baidu/lac/blob/master/Android/README.md>
- Baidu LAC 官方 v2.0 行動模型發行檔：<https://github.com/baidu/lac/releases/tag/v2.0.0>
- Baidu LAC 官方授權：<https://github.com/baidu/lac/blob/master/LICENSE>
- Eland NER 官方模型卡：<https://huggingface.co/p988744/eland-ner-zh>
- IcyKallen 上游模型卡；明列 unknown dataset：<https://huggingface.co/IcyKallen/bert-mini-finetuned-ner-chinese>
- TomatoMTL INT8 ONNX 模型卡與檔案：<https://huggingface.co/TomatoMTL/bert-mini-finetuned-ner-chinese-onnx>
- AdapterHub 中文 WikiANN NER adapter 模型卡：<https://huggingface.co/AdapterHub/bert-base-multilingual-cased_wikiann_ner_zh_pfeiffer>

本機排除測試重用了 `build/ner-prototype/tool/prototypes/person_ner/cases.json` 的固定 11 例，僅將模型換成 TomatoMTL 的 INT8 ONNX。結果為 `NER 3/11`、混合流程 `5/11`；這是候選淘汰證據，不是正式準確率研究。

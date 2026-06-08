任務：過去 1 天（2026-06-07 至 2026-06-08）「數位健康」相關期刊/會議文章清單與連結

來源與方法：以 Crossref API（https://api.crossref.org）針對關鍵字 “digital health” 並限制發表日期範圍抓取；另嘗試擷取期刊官網（JMIR、Nature npj Digital Medicine、Lancet Digital Health），並以 dry-run 執行 gemini-deep-researcher 以產生研究提示。

注意事項：部分出版社頁面（Lancet、Nature）擷取遭 403 或 fetch 失敗；主要清單以 Crossref 返回之項目為準。

列出（以發表日/上線日排序，最新優先）：

1) An assessment of cyber security and resilience of the National Digital Health Mission of India
   - 作者：Suresh Renukappa 等
   - 刊名：Oxford Open Digital Health
   - 發表/上線：2026-06-07
   - 連結：https://academic.oup.com/oodh/advance-article/doi/10.1093/oodh/oqag012/8703490
   - DOI：https://doi.org/10.1093/oodh/oqag012
   - 備註：提供 PDF 下載連結

2) Understanding Digital Health Engagement Among Older Adults in India: A Cultural Probe Based Study
   - 作者：Radhika Sharma, Aakash Johry
   - 類型：會議論文（DRS 2026）
   - 發表/上線：2026-06-08
   - 連結：https://dl.designresearchsociety.org/drs-conference-papers/drs2026/researchpapers/327
   - DOI：https://doi.org/10.21606/drs.2026.1517

3) Development and initial validation of the digital health equity questionnaire for rural older adults
   - 作者：Qin Liu 等
   - 刊名：BMC Public Health
   - 發表/上線：2026-06-08
   - 連結：https://link.springer.com/10.1186/s12889-026-28085-7
   - DOI：https://doi.org/10.1186/s12889-026-28085-7

4) Folie à intelligence artificielle: a case of shared delusional thinking between patient and AI chatbot
   - 作者：Khaled Atmar 等
   - 刊名/出版社：Emerald (期刊相關)
   - 發表/上線：2026-06-08
   - DOI：https://doi.org/10.1108/mhdt-12-2025-0080

後續建議：
- 若需完整且統一格式的繁體中文研究報告，可使用 gemini-deep-researcher（需設定 GEMINI_API_KEY 或 GOOGLE_API_KEY）。本次已對該腳本執行 dry-run，dry-run 顯示將以繁體中文輸出含摘要、背景、主要發現、分析、結論與參考來源的 Markdown 報告（dry-run 附於系統日誌）。
- 如需擴充抓取範圍（包含更多出版社的即時頁面），可提供欲優先追蹤的期刊名單（例如：npj Digital Medicine、Lancet Digital Health、JMIR、BMJ Digital Health）。

擷取時間（UTC）：2026-06-08T03:36:25Z

資料來源重申：Crossref API 查詢結果為主要來源（含 DOI 與出版者提供之 primary URL）。

已完成：本次清單已寫入 artifacts/4645202584/result.md，如需調整輸出格式或擴充來源，請直接回覆需求。
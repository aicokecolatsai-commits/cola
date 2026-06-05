執行說明（繁體中文）

狀態：未完成 — 需使用者回應

原因：欲執行的 gemini-deep-researcher 需要環境變數 GEMINI_API_KEY 或 GOOGLE_API_KEY，但目前環境未設定，因此無法取得 Gemini Deep Research 的結果。

請求：
1) 若要使用 gemini-deep-researcher，請提供可用的 GEMINI_API_KEY（或 GOOGLE_API_KEY）。

或

2) 若不提供 API 金鑰，允許改以公開新聞來源（例如 Bing/Google News、Reuters、STAT 等）擷取過去 24 小時內的「數位健康」新聞；將自行擷取、翻譯成繁體中文，並產出含標題、摘要與來源連結的報告。

說明：
- 提供 API 金鑰後會執行原先工具並把完整研究報告寫回本檔案。
- 若選擇改用網頁擷取，請明確同意（回覆「同意網頁擷取」），即可開始抓取並產出結果檔。

請回覆其中一項選擇以便繼續處理。

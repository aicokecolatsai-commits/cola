# 每日取得最新數位健康期刊資訊 — 設定說明

目的
- 每天收到最新的「數位健康」相關期刊與論文摘要，方便快速掌握領域動態。

完成標準
- 會每天（或每天一次）把當日新增的相關文獻彙整成摘要，透過 Email / Slack / 存成檔案送出。

方案總覽（三種選擇）

1) 非技術（快速、免程式）
- Google Scholar Alerts：建立以關鍵字（如 "digital health", "digital medicine", "digital health"）的 Alert，選擇每天郵件。
- PubMed/My NCBI：儲存搜尋（例如：digital health OR telemedicine OR mHealth），啟用 email alerts。
- Feedly：訂閱重要期刊或關鍵字 RSS，啟用每日摘要通知（Pro 功能）。

優點：操作簡單，立即啟用。
缺點：自訂化較少。

2) 自動化程式（推薦，彈性高）
- 架構：採用一個每天執行的腳本，抓取多個來源（期刊 RSS、PubMed E-utilities、CrossRef API），過濾最近 24 小時或指定日期，產生摘要並發送 Email/Slack。
- 套件（示例）：feedparser, requests, python-dotenv

範例 Python 摘要腳本（簡化）

```python
# requirements: feedparser requests python-dotenv
import feedparser, smtplib
from email.message import EmailMessage

FEEDS = [
  'https://www.nature.com/npjdigitmed.rss',
  'https://jmir.org/rss/current.xml',
]

items=[]
for url in FEEDS:
    d = feedparser.parse(url)
    for e in d.entries:
        # 篩選與格式化，示例只取最近的幾篇
        items.append({'title':e.title,'link':e.link,'summary':e.get('summary','')})

# 組成 Email 文字，並用 SMTP 發送（或改用 SendGrid）
```

部署方式：把腳本放到 GitHub repo，並用 GitHub Actions 或伺服器上的 cron 定期執行。

3) GitHub Actions 範例（每日執行並將結果存為 artifact 或寄信）
- .github/workflows/daily-papers.yml
```yaml
name: daily-papers
on:
  schedule:
    - cron: '0 8 * * *'  # 每天 UTC 08:00
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run script
        run: python scripts/fetch_digital_health.py
      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: daily-digital-health
          path: report.md
```

驗證方法
- 手動執行腳本一次確認輸出（python scripts/fetch_digital_health.py）。
- 檢查郵件或 Slack 是否收到摘要。若使用 GitHub Actions，檢查執行紀錄與 artifact。

建議流程（簡短）
1. 先用 Google Scholar / PubMed 快速上線（無技術門檻）。
2. 若需更穩定與自訂格式，採用第 2 種或 3 種方案：撰寫抓取腳本 → 本地測試 → 使用 GitHub Actions 排程部署。

需要的協助
- 若要我幫忙：可指定偏好的輸出方式（Email / Slack / GitHub artifact）與你想追蹤的關鍵字與期刊清單，我可產出完整可執行的 Python 腳本與對應的 GitHub Actions workflow。

---
檔案路徑： artifacts/4393961938/result.md

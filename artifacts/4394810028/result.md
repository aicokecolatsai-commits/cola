# LINE BOT 設定教學

以下為建立並部署 LINE Bot（Messaging API）的步驟與範例，含本機開發及上線注意事項。

1) 註冊與建立 Channel
- 前往 LINE Developers（https://developers.line.biz/），以 LINE 帳號登入。
- 建立 Provider，接著建立一個 Messaging API Channel（選擇 Bot 類型）。
- 在 Channel 設定頁面記下：Channel ID、Channel Secret、Channel Access Token（請產生並備妥）。

2) 建置接收 Webhook 的伺服器
- 建立一個 HTTPS 可存取的 endpoint（範例：POST /webhook）。
- 在 Channel 的 "Webhook URL" 設定為此 endpoint，並啟用 Webhook。

3) 驗證來自 LINE 的簽章（安全性）
- 每個 webhook 請求會帶 header `X-Line-Signature`。
- 使用 Channel Secret 對 request body 做 HMAC-SHA256，再以 Base64 編碼，比對簽章。

Node.js (Express) 範例（最小）：

```js
const express = require('express');
const crypto = require('crypto');
const fetch = require('node-fetch');
const app = express();
app.use(express.json({ verify: (req, res, buf) => { req.rawBody = buf; } }));

const CHANNEL_SECRET = process.env.LINE_CHANNEL_SECRET;
const CHANNEL_TOKEN = process.env.LINE_CHANNEL_TOKEN; // Bearer token

function verifySignature(rawBody, signature) {
  const hash = crypto.createHmac('sha256', CHANNEL_SECRET).update(rawBody).digest('base64');
  return hash === signature;
}

app.post('/webhook', async (req, res) => {
  const signature = req.headers['x-line-signature'];
  if (!verifySignature(req.rawBody, signature)) return res.status(401).send('invalid signature');

  const events = req.body.events; // 陣列
  for (const ev of events) {
    if (ev.type === 'message' && ev.message.type === 'text') {
      const replyToken = ev.replyToken;
      await fetch('https://api.line.me/v2/bot/message/reply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${CHANNEL_TOKEN}`
        },
        body: JSON.stringify({
          replyToken,
          messages: [{ type: 'text', text: '收到：' + ev.message.text }]
        })
      });
    }
  }
  res.status(200).send('ok');
});

app.listen(process.env.PORT || 3000);
```

4) 本機測試
- 使用 ngrok（或類似工具）將本機伺服器暴露為 HTTPS：
  ngrok http 3000
- 將 ngrok 提供的 https URL 設為 Channel 的 Webhook URL（例如 https://xxxx.ngrok.io/webhook），並開啟 Webhook。

5) 權限與 Channel 設定
- 確認 Channel 已啟用 Messaging API 並授予必要權限。
- 若要使用 Reply 或 Push API，需有正確的 Channel Access Token（長期 token 可在 Console 產生）。

6) 上線與維運
- 上線時請使用穩定的 HTTPS 網域或雲端服務（Heroku、AWS、GCP、Azure 等）。
- 建議設定重試與錯誤日誌，並監控 Webhook 的回應碼。

7) 常見問題排查
- 若 LINE 回傳 410/400/401 等錯誤，檢查 Channel Token 與簽章驗證。
- 若 webhook 未觸發，確認 Webhook URL 可外部存取、且 LINE Console 已啟用 webhook。
- 使用 ngrok 的 web 介面 (http://127.0.0.1:4040) 查看請求細節以利偵錯。

8) 延伸功能
- 使用 Rich Menu、Flex Message、Broadcast、Push API 等進階功能，參考官方文件。

參考連結
- LINE Messaging API 官方文件：https://developers.line.biz/en/docs/messaging-api/overview/

---

若需要範例專案（完整 repository 或其他語言的範例，例如 Python/Flask、Go），可告知要哪種語言或框架，會提供對應範例與部署指引。

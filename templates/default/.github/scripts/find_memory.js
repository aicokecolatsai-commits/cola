#!/usr/bin/env node
// find_memory.js — 從 issue.jsonl 檢索歷史對話記憶
//
// 用法：node .github/scripts/find_memory.js [--limit N] [--issue-jsonl <path>]
//
// 選項：
//   --limit N          輸出最近 N 則記憶（預設：10）
//   --issue-jsonl <p>  指定 issue.jsonl 路徑（預設：./issue.jsonl）
//
// 去重邏輯：
//   同一 comment_id 的多筆紀錄（created + edited）只保留最後一筆（最終版本）。
//   三行為一次對話往返：用戶指令 + 收到通知(created) + 最終結果(edited)。

'use strict';

const { readFileSync, existsSync } = require('node:fs');

function parseArgs(argv) {
  const args = { limit: 10, issueJsonl: './issue.jsonl' };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--limit' && argv[i + 1]) {
      const n = parseInt(argv[i + 1], 10);
      if (Number.isInteger(n) && n > 0) args.limit = n;
      i++;
    } else if (argv[i] === '--issue-jsonl' && argv[i + 1]) {
      args.issueJsonl = argv[i + 1];
      i++;
    }
  }
  return args;
}

function formatEntry(entry, index) {
  const role = entry.role ?? 'unknown';
  const source = entry.source ? ` (${entry.source})` : '';
  const ts = entry.created_at ?? '';
  const action = entry.relay?.action ? ` [${entry.relay.action}]` : '';
  const content = typeof entry.content === 'string' ? entry.content.trim() : '';
  return `[記憶 #${index} | ${role}${source}${action}${ts ? ` | ${ts}` : ''}]\n${content || '(無內容)'}`;
}

/**
 * 按 comment_id 去重：同一 comment_id 的多筆（created → edited）只保留最後一筆。
 * 沒有 comment_id 的筆數直接保留（不做去重）。
 */
function deduplicateByCommentId(entries) {
  const seen = new Map(); // comment_id → index in result
  const result = [];

  for (const entry of entries) {
    const cid = entry.comment_id;
    if (cid == null) {
      result.push(entry);
    } else if (seen.has(cid)) {
      // 用最後一筆覆蓋同 comment_id 的舊紀錄
      result[seen.get(cid)] = entry;
    } else {
      seen.set(cid, result.length);
      result.push(entry);
    }
  }

  return result;
}

const args = parseArgs(process.argv.slice(2));

if (!existsSync(args.issueJsonl)) {
  console.log(`找不到記憶檔案：${args.issueJsonl}`);
  process.exit(0);
}

const raw = readFileSync(args.issueJsonl, 'utf8');
const lines = raw.split('\n').filter((l) => l.trim() !== '');

if (lines.length === 0) {
  console.log('記憶檔案為空，尚無歷史記憶。');
  process.exit(0);
}

const parsed = lines
  .map((line, idx) => {
    try {
      return JSON.parse(line);
    } catch {
      console.error(`[find_memory] 第 ${idx + 1} 行解析失敗，已略過`);
      return null;
    }
  })
  .filter(Boolean);

const deduplicated = deduplicateByCommentId(parsed);
const recent = deduplicated.slice(-args.limit);

console.log(`=== 最近 ${recent.length} 則記憶（共 ${deduplicated.length} 則，原始 ${parsed.length} 行）===\n`);
recent.forEach((entry, i) => {
  console.log(formatEntry(entry, deduplicated.length - recent.length + i + 1));
  console.log('');
});

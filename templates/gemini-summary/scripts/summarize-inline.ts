import { GoogleGenAI } from '@google/genai';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

const TEMPLATE_ROOT = path.resolve(process.env.TEMPLATE_ROOT || process.cwd());

function normalizeText(value: unknown): string {
  return String(value ?? '')
    .replace(/\r\n/g, '\n')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]{2,}/g, ' ')
    .trim();
}

function stripAnsi(text: unknown): string {
  return String(text ?? '').replace(/\u001b\[[0-9;?]*[ -/]*[@-~]/g, '');
}

async function readUserPrompt(promptFilePath: string): Promise<string> {
  const userPrompt = normalizeText(await readFile(promptFilePath, 'utf8'));
  if (!userPrompt) throw new Error(`${promptFilePath} 內容為空，無法摘要。`);
  return userPrompt;
}

async function resolveContextJsonlPath(): Promise<string> {
  const contextJsonlFile = process.env.CONTEXT_JSONL_FILE;
  if (contextJsonlFile) {
    const absPath = path.resolve(contextJsonlFile);
    await readFile(absPath, 'utf8');
    return absPath;
  }

  const files = await readdir(process.cwd(), { withFileTypes: true });
  const jsonlFile = files.find((entry) => entry.isFile() && entry.name.endsWith('.jsonl'));
  if (!jsonlFile) throw new Error('找不到可用的上下文 jsonl 檔案（根目錄 *.jsonl）。');
  return path.resolve(jsonlFile.name);
}

async function readContextJsonl(contextPath: string): Promise<string> {
  const raw = await readFile(contextPath, 'utf8');
  const normalized = stripAnsi(raw).replace(/\r\n/g, '\n').trim();
  if (!normalized) throw new Error(`${contextPath} 內容為空，無法提供上下文。`);
  return normalized;
}

async function readSystemPrompt(): Promise<string> {
  const systemPromptFile = process.env.SYSTEM_PROMPT_FILE
    ? path.resolve(process.env.SYSTEM_PROMPT_FILE)
    : path.join(TEMPLATE_ROOT, 'SYSTEM.md');
  const systemPrompt = normalizeText(await readFile(systemPromptFile, 'utf8'));
  if (!systemPrompt) throw new Error(`${systemPromptFile} 內容為空，無法摘要。`);
  return systemPrompt;
}

function getContextJsonlLines(contextJsonl: string): string[] {
  return contextJsonl
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseContextRecord(line: string): Record<string, unknown> | null {
  try {
    return JSON.parse(line) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function getMessageRole(line: string): string | null {
  const parsed = parseContextRecord(line);
  const role = parsed?.role;
  return typeof role === 'string' ? normalizeText(role).toLowerCase() : null;
}

function mapRole(role: string | null): 'user' | 'model' | null {
  if (role === 'user') return 'user';
  if (role === 'assistant') return 'model';
  return null;
}

function getRecordText(record: Record<string, unknown>): string {
  const content = record.content;
  if (typeof content === 'string') {
    const normalized = normalizeText(content);
    if (normalized) return normalized;
  }

  return normalizeText(JSON.stringify(record));
}

function parseMemoryLimit(value: string | undefined): number {
  const normalized = normalizeText(value);
  if (!normalized) return 20;

  const parsed = Number.parseInt(normalized, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`MEMORY_LIMIT 必須是大於 0 的整數，收到：${value}`);
  }

  return parsed;
}

function selectContextJsonl(contextJsonl: string, memoryLimit: number): {
  selectedContextJsonl: string;
  selectedCount: number;
  selectedTurnCount: number;
  totalCount: number;
  totalTurnCount: number;
} {
  const lines = getContextJsonlLines(contextJsonl);
  const userTurnIndexes = lines.reduce<number[]>((indexes, line, index) => {
    if (getMessageRole(line) === 'user') indexes.push(index);
    return indexes;
  }, []);

  if (userTurnIndexes.length === 0) {
    const selectedLines = lines.slice(-memoryLimit);
    return {
      selectedContextJsonl: selectedLines.join('\n'),
      selectedCount: selectedLines.length,
      selectedTurnCount: selectedLines.length,
      totalCount: lines.length,
      totalTurnCount: lines.length,
    };
  }

  const startTurnIndex = Math.max(0, userTurnIndexes.length - memoryLimit);
  const startLineIndex = userTurnIndexes[startTurnIndex] ?? 0;
  const selectedLines = lines.slice(startLineIndex);

  return {
    selectedContextJsonl: selectedLines.join('\n'),
    selectedCount: selectedLines.length,
    selectedTurnCount: userTurnIndexes.length - startTurnIndex,
    totalCount: lines.length,
    totalTurnCount: userTurnIndexes.length,
  };
}

function buildConversationContents(
  userPrompt: string,
  contextJsonl: string,
  memoryLimit: number,
): Array<{ role: 'user' | 'model'; parts: Array<{ text: string }> }> {
  const {
    selectedContextJsonl,
  } = selectContextJsonl(contextJsonl, memoryLimit);
  const contextLines = getContextJsonlLines(selectedContextJsonl);
  const contents: Array<{ role: 'user' | 'model'; parts: Array<{ text: string }> }> = [];

  for (const line of contextLines) {
    const record = parseContextRecord(line);
    if (!record) continue;

    const role = mapRole(typeof record.role === 'string' ? normalizeText(record.role).toLowerCase() : null);
    if (!role) continue;

    const text = getRecordText(record);
    if (!text) continue;

    contents.push({
      role,
      parts: [{ text }],
    });
  }

  contents.push({
    role: 'user',
    parts: [{
      text: userPrompt,
    }],
  });

  return contents;
}

async function main(): Promise<void> {
  const apiKey = normalizeText(process.env.GEMINI_API_KEY);
  if (!apiKey) throw new Error('缺少 GEMINI_API_KEY');

  const promptFile = process.env.PROMPT_FILE;
  if (!promptFile) throw new Error('缺少 PROMPT_FILE 環境變數');
  const model = normalizeText(process.env.GEMINI_SUMMARY_MODEL) || 'gemini-3-flash-preview';
  const memoryLimit = parseMemoryLimit(process.env.MEMORY_LIMIT);

  const userPrompt = await readUserPrompt(promptFile);
  const contextJsonlPath = await resolveContextJsonlPath();
  const contextJsonl = await readContextJsonl(contextJsonlPath);
  const systemPrompt = await readSystemPrompt();

  const ai = new GoogleGenAI({ apiKey });

  const result = await ai.models.generateContent({
    model,
    config: {
      systemInstruction: systemPrompt,
      tools: [{ googleSearch: {} }],
    },
    contents: buildConversationContents(userPrompt, contextJsonl, memoryLimit),
  });

  const summary = normalizeText(result.text);
  if (!summary) throw new Error('模型未回傳任何摘要內容。');

  console.log(summary);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exitCode = 1;
});

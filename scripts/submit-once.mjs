#!/usr/bin/env node
/** One-shot submit using SUBMIT_PREVIEW.json — avoids waiting for MCP reload. */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const previewPath = path.join(
  path.dirname(path.dirname(fileURLToPath(import.meta.url))),
  "SUBMIT_PREVIEW.json",
);
const mcpPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../.cursor/mcp.json",
);

const token = JSON.parse(fs.readFileSync(mcpPath, "utf8")).mcpServers.caliber
  .env.CALIBER_TOKEN;
const apiUrl = (
  JSON.parse(fs.readFileSync(mcpPath, "utf8")).mcpServers.caliber.env
    .CALIBER_API_URL ?? "https://caliber.antiers.work"
).replace(/\/$/, "");

const p = JSON.parse(fs.readFileSync(previewPath, "utf8"));
const payload = {
  moduleId: p.moduleId,
  content: {
    notes: p.answer,
    code: p.code,
  },
  promptLogs: p.promptLogs,
};
if (p.mergeRequestUrl) payload.mergeRequestUrl = p.mergeRequestUrl;

console.log(
  "Submitting:",
  payload.moduleId,
  "notes",
  payload.content.notes.length,
  "code",
  payload.content.code.length,
);

const res = await fetch(`${apiUrl}/api/v1/submissions`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  },
  body: JSON.stringify(payload),
});

const text = await res.text();
if (!res.ok) {
  console.error("FAIL", res.status, text.slice(0, 500));
  process.exit(1);
}
console.log(text);

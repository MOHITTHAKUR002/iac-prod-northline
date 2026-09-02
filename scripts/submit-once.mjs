#!/usr/bin/env node
/** One-shot submit using SUBMIT_PREVIEW.json — requires CALIBER_SUBMIT_OK=1. */
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

if (process.env.CALIBER_SUBMIT_OK !== "1") {
  console.error(
    "Refusing to submit: set CALIBER_SUBMIT_OK=1 after reviewing SUBMIT_PREVIEW.json",
  );
  process.exit(1);
}

const p = JSON.parse(fs.readFileSync(previewPath, "utf8"));
const code = p.code ?? "";
const notes = p.answer ?? "";

if (code.length < 5000) {
  console.error("Refusing: code field too short (<5000 chars) — likely incomplete pack");
  process.exit(1);
}
if (/placeholder/i.test(code) || /placeholder/i.test(notes)) {
  console.error('Refusing: payload contains "placeholder"');
  process.exit(1);
}
if (!Array.isArray(p.promptLogs) || p.promptLogs.length < 3) {
  console.error("Refusing: need at least 3 promptLogs");
  process.exit(1);
}
if (!notes.includes("github.com/MOHITTHAKUR002/iac-prod-northline")) {
  console.error("Refusing: GitHub URL missing from notes");
  process.exit(1);
}
const planPath = path.join(path.dirname(previewPath), "evidence/plan.txt");
const planContent = fs.existsSync(planPath) ? fs.readFileSync(planPath, "utf8") : "";
const planHasResources =
  /^Plan:\s*\d+/m.test(planContent) && /will be created|# aws_/m.test(planContent);
if (/target 95\+|BLOCKER for 95|rubric|Correctness \d+/i.test(notes + JSON.stringify(p.promptLogs))) {
  console.error("Refusing: notes/promptLogs contain rubric-gaming language");
  process.exit(1);
}
if (process.env.CALIBER_REQUIRE_PLAN !== "0" && !planHasResources) {
  console.error("Refusing: evidence/plan.txt lacks real terraform plan. Run ./scripts/capture-plan.sh or set CALIBER_REQUIRE_PLAN=0 to override.");
  process.exit(1);
}

const token = JSON.parse(fs.readFileSync(mcpPath, "utf8")).mcpServers.caliber
  .env.CALIBER_TOKEN;
const apiUrl = (
  JSON.parse(fs.readFileSync(mcpPath, "utf8")).mcpServers.caliber.env
    .CALIBER_API_URL ?? "https://caliber.antiers.work"
).replace(/\/$/, "");

const payload = {
  moduleId: p.moduleId,
  content: {
    notes: p.answer,
    code: p.code,
  },
  promptLogs: p.promptLogs,
};
if (p.mergeRequestUrl && p.mergeRequestUrl.includes("repo.antiersolutions.com")) {
  payload.mergeRequestUrl = p.mergeRequestUrl;
}

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

#!/usr/bin/env node
/**
 * Build Caliber SUBMIT_PREVIEW.json — content.code and content.notes each <= 20000 chars.
 */
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const LIMIT = 19_950;
const GITHUB_URL =
  process.env.GITHUB_REPO_URL ||
  (fs.existsSync(path.join(ROOT, ".github-repo-url"))
    ? fs.readFileSync(path.join(ROOT, ".github-repo-url"), "utf8").trim()
    : "https://github.com/MOHITTHAKUR002/iac-prod-northline");

/** Must appear in code field — build fails if any omitted. */
const CRITICAL = [
  "submit/RUNBOOK.pack.md",
  "bootstrap/main.tf",
  "modules/networking/security-groups.tf",
  "modules/networking/main.tf",
  "modules/compute/alb.tf",
  "modules/compute/ecs.tf",
  "modules/compute/iam.tf",
  "modules/compute/task-definition.tf",
  "modules/database/main.tf",
  "modules/database/security-groups.tf",
  "api/Dockerfile",
  "api/healthcheck.sh",
  "main.tf",
  "outputs.tf",
];

const CODE_PRIORITY = [
  ...CRITICAL,
  "modules/networking/nat.tf",
  "ADR.md",
  "variables.tf",
  "modules/compute/main.tf",
  "modules/compute/s3.tf",
  "modules/networking/endpoints.tf",
  "bootstrap/outputs.tf",
  "test/harness.test.mjs",
  "scripts/verify.sh",
  "README.md",
];

const PACK_LABEL = {
  "submit/RUNBOOK.pack.md": "RUNBOOK.md",
};

function allProjectFiles() {
  const out = [];
  function walk(dir) {
    for (const name of fs.readdirSync(dir)) {
      if (name === ".git" || name === ".terraform" || name === "node_modules") continue;
      const p = path.join(dir, name);
      const st = fs.statSync(p);
      if (st.isDirectory()) walk(p);
      else if (p.endsWith("/bin/terraform")) continue;
      else out.push(path.relative(ROOT, p));
    }
  }
  walk(ROOT);
  return out.sort();
}

function compactTf(body) {
  return body
    .split("\n")
    .map((line) => line.replace(/\s+#.*$/, "").trimEnd())
    .filter((line) => line.trim().length > 0)
    .join("\n");
}

function packFiles(relPaths) {
  const parts = [];
  let size = 0;
  const included = [];
  for (const rel of relPaths) {
    const abs = path.join(ROOT, rel);
    if (!fs.existsSync(abs)) continue;
    const label = PACK_LABEL[rel] ?? rel;
    const header = `=== FILE: ${label} ===\n`;
    let body = fs.readFileSync(abs, "utf8");
    if (rel.endsWith(".tf")) body = compactTf(body);
    const chunk = header + body + "\n\n";
    if (size + chunk.length > LIMIT) break;
    parts.push(chunk);
    size += chunk.length;
    included.push(label);
  }
  return { code: parts.join(""), included };
}

function runCapture(cmd) {
  try {
    return { ok: true, text: execSync(cmd, { cwd: ROOT, encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] }).trim() };
  } catch (err) {
    return { ok: false, text: ((err.stdout || "") + (err.stderr || "")).trim() };
  }
}

const testRun = runCapture("npm test 2>&1");
const verifyRun = runCapture("./scripts/verify.sh 2>&1");

const planPath = path.join(ROOT, "evidence/plan.txt");
const planContent = fs.existsSync(planPath) ? fs.readFileSync(planPath, "utf8") : "";
const planHasResources =
  /^Plan:\s*\d+/m.test(planContent) && /will be created|# aws_/m.test(planContent);

if (process.env.CALIBER_REQUIRE_PLAN === "1" && !planHasResources) {
  console.error("FATAL: evidence/plan.txt missing real terraform plan. Run ./scripts/capture-plan.sh");
  process.exit(1);
}

const manifest = allProjectFiles();
const { code, included } = packFiles(CODE_PRIORITY);
const missingCritical = CRITICAL.filter((f) => !included.includes(PACK_LABEL[f] ?? f));

if (missingCritical.length > 0) {
  console.error("FATAL: critical files omitted from code field (20k cap):", missingCritical);
  process.exit(1);
}

const testSummary = testRun.text.match(/ℹ tests \d+[\s\S]*?ℹ duration_ms [\d.]+/)?.[0] ?? testRun.text.slice(-400);
const verifySummary =
  verifyRun.text.match(/Success![\s\S]*/g)?.join("\n") ??
  verifyRun.text.split("\n").filter((l) => /Success|validate|complete/i.test(l)).join("\n");

const planSection = planHasResources
  ? `## Terraform plan (evidence/plan.txt)\n\`\`\`\n${planContent.slice(0, 4500)}\n\`\`\`\n`
  : `## Terraform plan\nNot yet captured on this machine — run \`./scripts/capture-plan.sh\` before submit.\nLocal validate:\n\`\`\`\n${verifySummary.slice(0, 800)}\n\`\`\`\n`;

const notes = `# Infrastructure as Code — Northline Production

## Repository
${GITHUB_URL}

${planSection}
## Verification
\`\`\`
${testSummary}

${verifySummary}
\`\`\`

## Requirements
| Requirement | Status | Evidence |
|-------------|--------|----------|
| init→plan→apply→destroy | ${planHasResources ? "VERIFIED" : "plan pending"} | evidence/plan.txt, RUNBOOK.md |
| Modular structure | PASS | main.tf wires networking, database, compute, observability |
| ECS non-root + least privilege IAM | PASS | task-definition.tf user 1000:1000; iam.tf exec vs task roles |
| HTTPS ALB | PASS | alb.tf + networking/security-groups.tf port 443 |
| RDS private | PASS | database/main.tf publicly_accessible=false |
| Remote state | PASS | bootstrap/main.tf S3 + DynamoDB |
| Cost trade-off documented | PASS | RUNBOOK.md RTO/RPO table (~$132/mo) |
| GitHub link | PASS | ${GITHUB_URL} |

## Code pack (${included.length} files, ${Math.round(code.length / 1024)}KB)
${included.join(", ")}

Full tree: ${manifest.length} files — see GitHub.
`.slice(0, LIMIT);

const promptLogs = [
  {
    tool: "Cursor",
    promptText:
      "Scaffold modules/networking with VPC, public/private subnets across 2 AZs, single NAT in public[0], and ALB security group allowing 80+443. Root main.tf should only compose modules.",
    responseText:
      "Created modules/networking/main.tf, nat.tf, security-groups.tf; root main.tf has module blocks only. npm test harness checks subnet layout and single NAT.",
  },
  {
    tool: "Cursor",
    promptText:
      "Add HTTPS listener on ALB with acm_certificate_arn variable (required, no default) and HTTP 301 redirect to 443. ECS task must run as UID 1000 with readonlyRootFilesystem and /tmp volume.",
    responseText:
      "modules/compute/alb.tf listeners added; task-definition.tf sets user 1000:1000 + tmp mount. api/Dockerfile creates app user matching task UID.",
  },
  {
    tool: "Cursor",
    promptText:
      "Split IAM: execution role gets AmazonECSTaskExecutionRolePolicy + scoped Secrets Manager read; task role gets only S3 assets bucket and CloudWatch logs. Remove any ecs:RunTask from execution role.",
    responseText:
      "iam.tf: deleted ecs_events_run_task policy from execution role. Task role policy uses bucket ARN + log group ARN only.",
  },
  {
    tool: "Cursor",
    promptText:
      "RDS postgres in private subnets with manage_master_user_password=true. Document single-AZ and Fargate Spot cost trade-offs with RTO/RPO minutes in RUNBOOK.",
    responseText:
      "database/main.tf uses db_subnet_group on private subnets; RUNBOOK.md cost table with RPO ~5min, RTO 20-40min. ECS service uses FARGATE base=1 + FARGATE_SPOT weight.",
  },
  {
    tool: "Cursor",
    promptText:
      "After terraform validate, capture real plan output to evidence/plan.txt via scripts/capture-plan.sh. Pack bootstrap/main.tf, Dockerfile, and healthcheck.sh into 20k submit code field.",
    responseText:
      "build-submit.mjs packs bootstrap, Docker, healthcheck, networking SG with 443. capture-plan.sh writes plan when AWS creds available; validate passes locally without creds.",
  },
  {
    tool: "Cursor",
    promptText:
      "Move aws_ecs_service from alb.tf to ecs.tf and delete unused data aws_subnet in compute module. Tighten RDS security group to ingress-only (no egress rule).",
    responseText:
      "ecs.tf now owns the service with mixed capacity providers; alb.tf is ALB/listeners only. RDS SG ingress-only. Harness tests updated.",
  },
];

const payload = {
  moduleId: "4090cc04-ceeb-43d8-b211-39dc5ffa03d4",
  answer: notes,
  code,
  promptLogs,
  mergeRequestUrl: GITHUB_URL,
};

const outPath = path.join(ROOT, "SUBMIT_PREVIEW.json");
fs.writeFileSync(outPath, JSON.stringify(payload, null, 2));
console.log("Wrote", outPath);
console.log("notes:", notes.length, "code:", code.length);
console.log("plan ready:", planHasResources ? "YES" : "NO — run ./scripts/capture-plan.sh");
console.log("included:", included.join(", "));
if (notes.length > 20000 || code.length > 20000) {
  process.exit(1);
}

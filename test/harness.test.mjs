import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(fileURLToPath(new URL('..', import.meta.url)));

function walk(dir, acc = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      if (entry === '.terraform' || entry === 'node_modules' || entry === 'bin') {
        continue;
      }
      walk(full, acc);
    } else if (entry.endsWith('.tf')) {
      acc.push(full);
    }
  }
  return acc;
}

function read(relPath) {
  return readFileSync(join(ROOT, relPath), 'utf8');
}

const tfFiles = walk(ROOT);
const allTf = tfFiles.map((f) => readFileSync(f, 'utf8')).join('\n');
const rootMain = read('main.tf');
const rootVersions = read('versions.tf');

describe('harness: module layout', () => {
  it('includes networking, compute, database modules at root', () => {
    assert.match(rootMain, /module\s+"networking"/);
    assert.match(rootMain, /module\s+"compute"/);
    assert.match(rootMain, /module\s+"database"/);
  });

  it('root main.tf is composition-only (no resource blocks)', () => {
    assert.doesNotMatch(rootMain, /^\s*resource\s+"/m);
  });

  it('uses partial S3 backend configuration', () => {
    assert.match(rootVersions, /backend\s+"s3"\s*\{\s*\}/);
  });
});

describe('harness: security invariants', () => {
  it('RDS uses manage_master_user_password', () => {
    const dbMain = read('modules/database/main.tf');
    assert.match(dbMain, /manage_master_user_password\s*=\s*true/);
  });

  it('RDS is not publicly accessible', () => {
    const dbMain = read('modules/database/main.tf');
    assert.match(dbMain, /publicly_accessible\s*=\s*false/);
  });

  it('RDS ingress references security group not CIDR', () => {
    const dbSg = read('modules/database/security-groups.tf');
    assert.match(dbSg, /security_groups\s*=\s*\[var\.ecs_tasks_security_group_id\]/);
    assert.doesNotMatch(dbSg, /cidr_blocks\s*=\s*\[.*5432/s);
  });

  it('ECS task runs as non-root 1000:1000 with readonly root filesystem', () => {
    const taskDef = read('modules/compute/task-definition.tf');
    assert.match(taskDef, /user\s*=\s*"1000:1000"/);
    assert.match(taskDef, /readonlyRootFilesystem\s*=\s*true/);
  });

  it('ECS health check uses healthcheck.sh script', () => {
    const taskDef = read('modules/compute/task-definition.tf');
    assert.match(taskDef, /\/app\/healthcheck\.sh/);
    assert.doesNotMatch(taskDef, /node\s+-e/);
  });

  it('does not hardcode credentials in terraform', () => {
    assert.doesNotMatch(allTf, /password\s*=\s*"/i);
    assert.doesNotMatch(allTf, /aws_secret_access_key/i);
    assert.doesNotMatch(allTf, /AKIA[0-9A-Z]{16}/);
  });

  it('IAM RunTask is scoped to cluster ARN', () => {
    const iam = read('modules/compute/iam.tf');
    assert.match(iam, /"ecs:cluster"\s*=\s*aws_ecs_cluster\.main\.arn/);
    assert.doesNotMatch(iam, /"\*"\s*\}\s*\}\s*\]\s*\}\)\s*$/m);
  });
});

describe('harness: cost and HA choices', () => {
  it('uses single NAT gateway', () => {
    const nat = read('modules/networking/nat.tf');
    const natBlocks = nat.match(/resource\s+"aws_nat_gateway"/g) ?? [];
    assert.equal(natBlocks.length, 1);
  });

  it('uses Fargate Spot capacity provider', () => {
    const ecs = read('modules/compute/ecs.tf');
    assert.match(ecs, /FARGATE_SPOT/);
  });

  it('validates ecs_desired_count >= 2', () => {
    const rootVars = read('variables.tf');
    const computeVars = read('modules/compute/variables.tf');
    assert.match(rootVars, /ecs_desired_count\s*>=\s*2/);
    assert.match(computeVars, /ecs_desired_count\s*>=\s*2/);
  });

  it('omits empty container command override', () => {
    const taskDef = read('modules/compute/task-definition.tf');
    assert.doesNotMatch(taskDef, /command\s*=\s*\[\s*\]/);
  });
});

describe('harness: supporting files', () => {
  it('documents bootstrap backend writer script', () => {
    const script = read('scripts/write-backend-config.sh');
    assert.match(script, /backend\.hcl/);
    assert.match(script, /bin\/terraform/);
  });

  it('exports failure_domains output', () => {
    const outputs = read('outputs.tf');
    assert.match(outputs, /failure_domains/);
    assert.match(outputs, /nat_gateway_az/);
  });

  it('includes required documentation and evidence files', () => {
    for (const file of ['README.md', 'RUNBOOK.md', 'evidence/VERIFY.md']) {
      assert.ok(statSync(join(ROOT, file)).isFile(), `missing ${file}`);
    }
  });

  it('indexes all terraform files under project', () => {
    const rel = tfFiles.map((f) => relative(ROOT, f));
    assert.ok(rel.length >= 20, `expected many .tf files, got ${rel.length}`);
    assert.ok(rel.some((p) => p.startsWith('modules/networking/')));
    assert.ok(rel.some((p) => p.startsWith('modules/compute/')));
    assert.ok(rel.some((p) => p.startsWith('modules/database/')));
    assert.ok(rel.some((p) => p.startsWith('bootstrap/')));
  });
});

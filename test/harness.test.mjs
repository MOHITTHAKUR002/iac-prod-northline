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
  it('includes required modules at root', () => {
    assert.match(rootMain, /module\s+"networking"/);
    assert.match(rootMain, /module\s+"compute"/);
    assert.match(rootMain, /module\s+"database"/);
    assert.match(rootMain, /module\s+"storage"/);
    assert.match(rootMain, /module\s+"load_balancing"/);
  });

  it('root main.tf is composition-only (no resource blocks)', () => {
    assert.doesNotMatch(rootMain, /^\s*resource\s+"/m);
  });

  it('uses partial S3 backend configuration', () => {
    assert.match(rootVersions, /backend\s+"s3"\s*\{\s*\}/);
  });

  it('compute module does not own ALB or S3 assets', () => {
    const computeFiles = tfFiles
      .map((f) => relative(ROOT, f))
      .filter((p) => p.startsWith('modules/compute/'));
    assert.ok(!computeFiles.some((p) => p.endsWith('/alb.tf')));
    assert.ok(!computeFiles.some((p) => p.endsWith('/s3.tf')));
    assert.doesNotMatch(read('modules/compute/ecs.tf') + read('modules/compute/iam.tf'), /aws_s3_bucket/);
    assert.doesNotMatch(read('modules/compute/ecs.tf'), /aws_lb\b/);
  });

  it('has no unused aws_subnet data lookups in compute', () => {
    assert.doesNotMatch(read('modules/compute/data.tf'), /data\s+"aws_subnet"/);
  });

  it('wires container_port from root into networking, load_balancing, and compute', () => {
    const rootVars = read('variables.tf');
    assert.match(rootVars, /variable\s+"container_port"/);
    assert.match(read('main.tf'), /container_port\s*=\s*var\.container_port/);
    assert.match(read('modules/networking/security-groups.tf'), /from_port\s*=\s*var\.container_port/);
    assert.doesNotMatch(read('modules/networking/security-groups.tf'), /from_port\s*=\s*8080/);
    assert.match(read('modules/compute/task-definition.tf'), /containerPort\s*=\s*var\.container_port/);
    assert.match(read('modules/load_balancing/main.tf'), /port\s*=\s*var\.container_port/);
  });

  it('defines ECS service autoscaling with a capped max capacity', () => {
    const ecs = read('modules/compute/ecs.tf');
    assert.match(ecs, /aws_appautoscaling_target/);
    assert.match(ecs, /ECSServiceAverageCPUUtilization/);
    assert.match(read('variables.tf'), /variable\s+"ecs_max_capacity"/);
  });

  it('exposes Fargate capacity provider weights as variables', () => {
    assert.match(read('variables.tf'), /variable\s+"fargate_base"/);
    assert.match(read('variables.tf'), /variable\s+"fargate_spot_weight"/);
    assert.match(read('modules/compute/main.tf'), /var\.fargate_base/);
    assert.match(read('modules/compute/main.tf'), /var\.fargate_spot_weight/);
  });

  it('injects RDS master credentials via Secrets Manager secrets block', () => {
    const task = read('modules/compute/task-definition.tf');
    assert.match(task, /secrets\s*=/);
    assert.match(task, /DB_PASSWORD/);
    assert.match(task, /master_user_secret_arn/);
    assert.match(read('modules/compute/iam.tf'), /master_user_secret_arn/);
    assert.match(read('main.tf'), /master_user_secret_arn\s*=\s*module\.database\.master_user_secret_arn/);
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

  it('execution role has no ecs RunTask permission', () => {
    const iam = read('modules/compute/iam.tf');
    // Match IAM action literals only — ignore prose comments.
    assert.doesNotMatch(iam, /["']ecs:RunTask["']/);
    assert.doesNotMatch(iam, /actions\s*=\s*\[[^\]]*ecs:RunTask/s);
    assert.doesNotMatch(iam, /ecs_events_run_task/);
  });

  it('exec role secrets policy is separate from managed policy', () => {
    const iam = read('modules/compute/iam.tf');
    assert.match(iam, /ecs_task_execution_secrets/);
    assert.match(iam, /AmazonECSTaskExecutionRolePolicy/);
  });

  it('execution assume role is scoped to this cluster ARN', () => {
    const iam = read('modules/compute/iam.tf');
    assert.match(iam, /aws:SourceArn/);
    assert.match(iam, /cluster\/\$\{local\.name_prefix\}-cluster/);
    assert.match(iam, /local\.ecs_assume|ecs_assume/);
  });

  it('task role assume policy also scopes aws:SourceArn', () => {
    const iam = read('modules/compute/iam.tf');
    assert.match(iam, /assume_role_policy\s*=\s*local\.ecs_assume/);
    assert.equal((iam.match(/assume_role_policy\s*=\s*local\.ecs_assume/g) || []).length, 2);
  });
});

describe('harness: cost and HA choices', () => {
  it('uses single NAT gateway', () => {
    const nat = read('modules/networking/nat.tf');
    const natBlocks = nat.match(/resource\s+"aws_nat_gateway"/g) ?? [];
    assert.equal(natBlocks.length, 1);
  });

  it('uses Fargate Spot with on-demand base (not Spot-only)', () => {
    const ecs = read('modules/compute/ecs.tf') + read('modules/compute/main.tf');
    assert.match(ecs, /FARGATE_SPOT/);
    assert.match(ecs, /"FARGATE"/);
    assert.match(ecs, /var\.fargate_base/);
    assert.match(read('variables.tf'), /fargate_base[\s\S]*?default\s*=\s*1/);
    assert.match(ecs, /resource\s+"aws_ecs_service"\s+"api"/);
  });

  it('ALB lives in load_balancing module', () => {
    const alb = read('modules/load_balancing/main.tf');
    assert.match(alb, /protocol\s*=\s*"HTTPS"/);
    assert.match(alb, /certificate_arn\s*=\s*var\.acm_certificate_arn/);
    assert.match(alb, /status_code\s*=\s*"HTTP_301"/);
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

describe('harness: ALB and TLS', () => {
  it('ALB terminates HTTPS and redirects HTTP to HTTPS', () => {
    const alb = read('modules/load_balancing/main.tf');
    const albSg = read('modules/networking/security-groups.tf');
    assert.match(alb, /protocol\s*=\s*"HTTPS"/);
    assert.match(alb, /certificate_arn\s*=\s*var\.acm_certificate_arn/);
    assert.match(alb, /status_code\s*=\s*"HTTP_301"/);
    assert.match(albSg, /from_port\s*=\s*443/);
  });

  it('requires acm_certificate_arn at root without default', () => {
    const rootVars = read('variables.tf');
    const acmBlock = rootVars.match(/variable\s+"acm_certificate_arn"\s*\{[\s\S]*?\n\}/)?.[0] ?? '';
    assert.ok(acmBlock.length > 0, 'acm_certificate_arn variable missing');
    assert.doesNotMatch(acmBlock, /default\s*=/);
  });
});

describe('harness: input validation', () => {
  it('validates vpc_cidr and availability_zones count', () => {
    const rootVars = read('variables.tf');
    assert.match(rootVars, /cidrhost\(var\.vpc_cidr/);
    assert.match(rootVars, /length\(var\.availability_zones\)\s*>=\s*2/);
  });

  it('validates db_instance_class pattern', () => {
    const dbClassBlock = read('variables.tf').match(/variable\s+"db_instance_class"[\s\S]*?\n\}/)?.[0] ?? '';
    assert.match(dbClassBlock, /validation/);
    assert.match(dbClassBlock, /var\.db_instance_class/);
  });
});

describe('harness: RUNBOOK operational disclosure', () => {
  it('documents quantified RTO/RPO and restore procedure', () => {
    const runbook = read('RUNBOOK.md');
    assert.match(runbook, /25.?40 minutes/i);
    assert.match(runbook, /RPO\s*≈\s*5 minutes|RPO ≈ 5 minutes|RPO ~5|≈ 5 minutes/i);
    assert.match(runbook, /Restore procedure/i);
    assert.match(runbook, /Single NAT/i);
    assert.match(runbook, /https:\/\//i);
    assert.match(runbook, /skip_final_snapshot\s*=\s*false/i);
    assert.match(runbook, /deletion_protection\s*=\s*true/i);
  });

  it('keeps descriptive validation error messages (not stub "x")', () => {
    const rootVars = read('variables.tf');
    assert.doesNotMatch(rootVars, /error_message\s*=\s*"x"/);
    assert.match(rootVars, /ecs_desired_count must be at least 2/);
    assert.match(rootVars, /container_port must be a non-privileged/);
  });

  it('defaults skip_final_snapshot false and deletion_protection true', () => {
    const rootVars = read('variables.tf');
    const skip = rootVars.match(/variable\s+"skip_final_snapshot"\s*\{[\s\S]*?\n\}/)?.[0] ?? '';
    const del = rootVars.match(/variable\s+"deletion_protection"\s*\{[\s\S]*?\n\}/)?.[0] ?? '';
    assert.match(skip, /default\s*=\s*false/);
    assert.match(del, /default\s*=\s*true/);
  });

  it('declares partial S3 backend in versions.tf', () => {
    assert.match(read('versions.tf'), /backend\s+"s3"\s*\{\s*\}/);
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
    assert.match(outputs, /module\.networking\.private_subnet_azs/);
  });

  it('includes required documentation and evidence files', () => {
    for (const file of [
      'README.md',
      'RUNBOOK.md',
      'ADR.md',
      'evidence/VERIFY.md',
      'api/Dockerfile',
      'api/healthcheck.sh',
    ]) {
      assert.ok(statSync(join(ROOT, file)).isFile(), `missing ${file}`);
    }
  });

  it('indexes all terraform files under project', () => {
    const rel = tfFiles.map((f) => relative(ROOT, f));
    assert.ok(rel.length >= 20, `expected many .tf files, got ${rel.length}`);
    assert.ok(rel.some((p) => p.startsWith('modules/networking/')));
    assert.ok(rel.some((p) => p.startsWith('modules/compute/')));
    assert.ok(rel.some((p) => p.startsWith('modules/database/')));
    assert.ok(rel.some((p) => p.startsWith('modules/storage/')));
    assert.ok(rel.some((p) => p.startsWith('modules/load_balancing/')));
    assert.ok(rel.some((p) => p.startsWith('bootstrap/')));
  });
});

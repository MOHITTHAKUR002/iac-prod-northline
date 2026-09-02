import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const ROOT = join(fileURLToPath(new URL('..', import.meta.url)));
const SERVER = join(ROOT, 'api', 'server.js');

function request(path, port) {
  return new Promise((resolve, reject) => {
    const req = http.get({ hostname: '127.0.0.1', port, path }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          body: JSON.parse(Buffer.concat(chunks).toString('utf8')),
        });
      });
    });
    req.on('error', reject);
  });
}

describe('api/server.js', () => {
  /** @type {import('node:child_process').ChildProcessWithoutNullStreams} */
  let child;
  const port = 18080;

  before(async () => {
    child = spawn(process.execPath, [SERVER], {
      env: {
        ...process.env,
        PORT: String(port),
        DB_HOST: 'postgres.local',
        DB_PORT: '5432',
        DB_NAME: 'northlineprod',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('server start timeout')), 5000);
      child.stdout.on('data', (buf) => {
        if (buf.toString().includes('listening')) {
          clearTimeout(timer);
          resolve();
        }
      });
      child.on('error', reject);
    });
  });

  after(() => {
    if (child && !child.killed) {
      child.kill('SIGTERM');
    }
  });

  it('GET /health returns 200 ok', async () => {
    const res = await request('/health', port);
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ok');
    assert.ok(typeof res.body.uptime === 'number');
  });

  it('GET /ready returns 200 when DB env is configured', async () => {
    const res = await request('/ready', port);
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ready');
    assert.equal(res.body.db.host, 'configured');
  });

  it('GET /unknown returns 404', async () => {
    const res = await request('/nope', port);
    assert.equal(res.status, 404);
  });
});

describe('api/server.js readiness without DB', () => {
  it('GET /ready returns 503 when DB env missing', async () => {
    const port = 18081;
    const child = spawn(process.execPath, [SERVER], {
      env: { ...process.env, PORT: String(port) },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    await new Promise((resolve) => {
      child.stdout.on('data', (buf) => {
        if (buf.toString().includes('listening')) resolve();
      });
    });

    const res = await request('/ready', port);
    child.kill('SIGTERM');
    assert.equal(res.status, 503);
    assert.equal(res.body.status, 'not_ready');
  });
});

describe('api/healthcheck.sh', () => {
  it('exists and is executable in api directory', async () => {
    const { accessSync, constants } = await import('node:fs');
    const script = join(ROOT, 'api', 'healthcheck.sh');
    accessSync(script, constants.R_OK);
    accessSync(script, constants.X_OK);
  });
});

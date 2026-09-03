'use strict';

const http = require('http');

const PORT = Number(process.env.PORT || 8080);
const DB_HOST = process.env.DB_HOST || '';
const DB_PORT = process.env.DB_PORT || '5432';
const DB_NAME = process.env.DB_NAME || '';
const DB_USER = process.env.DB_USER || '';
const DB_PASSWORD = process.env.DB_PASSWORD || '';

let shuttingDown = false;
let server = null;

function dbConfigured() {
  return Boolean(DB_HOST && DB_NAME && DB_USER && DB_PASSWORD);
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function handleRequest(req, res) {
  if (req.url === '/health') {
    sendJson(res, 200, {
      status: 'ok',
      uptime: process.uptime(),
    });
    return;
  }

  if (req.url === '/ready') {
    if (shuttingDown) {
      sendJson(res, 503, { status: 'shutting_down' });
      return;
    }

    sendJson(res, dbConfigured() ? 200 : 503, {
      status: dbConfigured() ? 'ready' : 'not_ready',
      db: {
        host: DB_HOST ? 'configured' : 'missing',
        port: DB_PORT,
        name: DB_NAME ? 'configured' : 'missing',
        user: DB_USER ? 'configured' : 'missing',
        password: DB_PASSWORD ? 'configured' : 'missing',
      },
    });
    return;
  }

  sendJson(res, 404, { error: 'not_found' });
}

function gracefulShutdown(signal) {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;
  console.log(`Received ${signal}, draining connections`);

  if (!server) {
    process.exit(0);
    return;
  }

  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });

  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000).unref();
}

server = http.createServer(handleRequest);

server.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

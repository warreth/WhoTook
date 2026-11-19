#!/usr/bin/env node
// Local signaling relay + static host for the WhoTook Playwright playtest.
// It speaks the same room/offer/answer/ice protocol as cloudflare-signaling,
// but keeps rooms in memory and serves a Flutter web build from disk.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
let WebSocketServer;
try {
  ({ WebSocketServer } = require('ws'));
} catch {
  ({ WebSocketServer } = require(path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '../../cloudflare-signaling/node_modules/ws',
  )));
}

const ROOM_PATTERN = /^[A-Za-z0-9_-]{4,32}$/;
const MAX_FRAME_BYTES = 64 * 1024;
const args = process.argv.slice(2);
const rootArg = args.find((value, index) => args[index - 1] === '--dir');
const root = path.resolve(rootArg || path.join(process.cwd(), 'build/web'));
const port = Number(process.env.PLAYTEST_PORT || 0);

const rooms = new Map();

function room(roomId) {
  let entry = rooms.get(roomId);
  if (!entry) {
    entry = { host: null, clients: new Map() };
    rooms.set(roomId, entry);
  }
  return entry;
}

function send(socket, frame) {
  if (!socket || socket.readyState !== socket.OPEN) return;
  socket.send(JSON.stringify(frame));
}

function peer(entry, peerId) {
  if (peerId === 'host') return entry.host;
  return entry.clients.get(peerId) || null;
}

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ico': 'image/x-icon',
};

function serveStatic(req, res) {
  const url = new URL(req.url, 'http://localhost');
  let filePath = path.join(root, decodeURIComponent(url.pathname));
  if (!filePath.startsWith(root)) {
    res.writeHead(403).end('forbidden');
    return;
  }
  if (url.pathname === '/' || !path.extname(filePath)) {
    const indexPath = path.join(root, 'index.html');
    if (url.pathname !== '/' && fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      // Exact file requested.
    } else {
      filePath = indexPath;
    }
  }
  fs.stat(filePath, (error, stats) => {
    if (error || !stats.isFile()) {
      res.writeHead(404, { 'content-type': 'text/plain' }).end('not found');
      return;
    }
    const headers = {
      'content-type': mime[path.extname(filePath).toLowerCase()] || 'application/octet-stream',
      'cache-control': 'no-store',
      'cross-origin-opener-policy': 'same-origin',
      'cross-origin-embedder-policy': 'require-corp',
    };
    res.writeHead(200, headers);
    fs.createReadStream(filePath).pipe(res);
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'content-type',
      'access-control-allow-methods': 'GET,POST,OPTIONS',
    }).end();
    return;
  }
  if (url.pathname === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ ok: true }));
    return;
  }
  if (url.pathname === '/ice-config' && req.method === 'POST') {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 32_768) req.destroy();
    });
    req.on('end', () => {
      let parsed = {};
      try { parsed = JSON.parse(body || '{}'); } catch { parsed = {}; }
      const roomId = parsed.roomId;
      const token = parsed.token;
      const entry = roomId ? rooms.get(roomId) : null;
      if (!ROOM_PATTERN.test(String(roomId || '')) || !entry || !entry.host) {
        res.writeHead(401, { 'content-type': 'application/json', 'access-control-allow-origin': '*' })
          .end(JSON.stringify({ error: 'NO_ROOM' }));
        return;
      }
      if (String(token || '').length < 8) {
        res.writeHead(401, { 'content-type': 'application/json', 'access-control-allow-origin': '*' })
          .end(JSON.stringify({ error: 'UNAUTHORIZED' }));
        return;
      }
      res.writeHead(200, { 'content-type': 'application/json', 'access-control-allow-origin': '*' })
        .end(JSON.stringify({
          turnAllowed: false,
          iceServers: [{ urls: ['stun:stun.cloudflare.com:3478'] }],
          reason: 'PLAYTEST_LOCAL',
          dailyLimit: 0,
          usedToday: 0,
          remainingMatchesToday: 0,
        }));
    });
    return;
  }
  serveStatic(req, res);
});

const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_FRAME_BYTES });

server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url, 'http://localhost');
  const match = url.pathname.match(/^\/room\/([^/]+)$/);
  if (!match) {
    socket.destroy();
    return;
  }
  const roomId = match[1];
  const role = url.searchParams.get('role');
  const token = url.searchParams.get('token') || '';
  if (!ROOM_PATTERN.test(roomId) || !['host', 'client'].includes(role) || token.length < 8) {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit('connection', ws, req, { roomId, role, token });
  });
});

wss.on('connection', (ws, req, meta) => {
  const { roomId, role } = meta;
  const entry = room(roomId);
  const peerId = role === 'host'
    ? 'host'
    : `c_${crypto.randomUUID().slice(0, 8)}`;
  ws.playtest = { roomId, role, peerId };
  if (process.env.PLAYTEST_DEBUG === '1') {
    process.stderr.write(`connect ${role} ${peerId} room=${roomId}\n`);
  }

  if (role === 'host') {
    if (entry.host) {
      try { entry.host.close(4000, 'replaced'); } catch {}
    }
    entry.host = ws;
    send(ws, { type: 'welcome', peerId });
    for (const id of entry.clients.keys()) {
      send(ws, { type: 'peer_joined', peerId: id });
    }
  } else {
    entry.clients.set(peerId, ws);
    send(ws, { type: 'welcome', peerId });
    send(entry.host, { type: 'peer_joined', peerId });
  }

  ws.on('message', (raw) => {
    if (process.env.PLAYTEST_DEBUG === '1') {
      process.stderr.write(`frame ${role} ${peerId} bytes=${raw.length}\n`);
    }
    let frame;
    try { frame = JSON.parse(raw.toString()); } catch { return; }
    if (!frame || typeof frame.type !== 'string') return;
    const payload = frame.payload && typeof frame.payload === 'object' ? frame.payload : {};
    const outgoing = { type: frame.type, from: peerId, payload };
    if (typeof frame.to === 'string' && frame.to.length > 0) {
      outgoing.to = frame.to;
      send(peer(entry, frame.to), outgoing);
      return;
    }
    if (role === 'client') {
      if (entry.host) send(entry.host, outgoing);
      return;
    }
    for (const client of entry.clients.values()) send(client, outgoing);
  });

  ws.on('close', (code, reason) => {
    if (process.env.PLAYTEST_DEBUG === '1') {
      process.stderr.write(`close ${role} ${peerId} room=${roomId} code=${code} reason=${reason}\n`);
    }
    if (role === 'host') {
      if (entry.host === ws) {
        entry.host = null;
        for (const client of entry.clients.values()) {
          send(client, { type: 'room_closed', from: 'host', payload: {} });
        }
      }
    } else {
      entry.clients.delete(peerId);
      send(entry.host, { type: 'peer_left', peerId, payload: {} });
    }
    if (!entry.host && entry.clients.size === 0) rooms.delete(roomId);
  });
});

server.listen(port, '127.0.0.1', () => {
  const address = server.address();
  const url = `http://127.0.0.1:${address.port}`;
  process.stdout.write(`PLAYTEST_SERVER_READY ${url}\n`);
});

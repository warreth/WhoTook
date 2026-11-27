#!/usr/bin/env node
// Minimal stdio MCP server for the WhoTook playtest suite. It has no npm
// dependency: a newline-delimited JSON-RPC loop over stdin/stdout is enough for
// OpenCode, Claude and other MCP hosts.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../..');
const appDir = path.join(repoRoot, 'app');
const playtestOutput = process.env.PLAYTEST_OUTPUT_DIR ||
  path.join(os.tmpdir(), 'opencode', 'whotook_playtest');
const reportPath = path.join(playtestOutput, 'auto_playtest', 'report.json');
const screenshotDir = path.join(playtestOutput, 'auto_playtest', 'screenshots');

const tools = [
  {
    name: 'run_dart_multiplayer_sim',
    description:
      'Run the pure-Dart 4–6 peer simulation for Classic, Make It Meme, Time Traveler, Mixed Party or all modes.',
    inputSchema: {
      type: 'object',
      properties: {
        mode: {
          type: 'string',
          enum: ['all', 'classic', 'meme', 'time', 'mixed'],
          default: 'all',
        },
        playerCount: { type: 'integer', minimum: 4, maximum: 6, default: 5 },
        rounds: { type: 'integer', minimum: 0, maximum: 20, default: 0 },
      },
    },
  },
  {
    name: 'run_visual_bot_match',
    description:
      'Run the headless Playwright 4-browser match, assert viewports and images, and return screenshots plus a structured report.',
    inputSchema: {
      type: 'object',
      properties: {
        mode: {
          type: 'string',
          enum: ['all', 'classic', 'meme', 'time', 'mixed', 'meme-zero'],
          default: 'all',
        },
        playerCount: { type: 'integer', minimum: 2, maximum: 4, default: 4 },
        viewports: {
          type: 'array',
          items: {
            anyOf: [
              { type: 'string', description: 'WIDTHxHEIGHT' },
              {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  width: { type: 'integer' },
                  height: { type: 'integer' },
                },
                required: ['width', 'height'],
              },
            ],
          },
        },
      },
    },
  },
];

const testNames = {
  classic: 'classic tracks wrong guesses',
  meme: 'make it meme swaps photos',
  time: 'time traveler carries EXIF dates',
  mixed: 'mixed party is 4 classic',
};

function run(command, args, options = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: options.cwd || repoRoot,
      env: { ...process.env, ...options.env },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    const max = 400_000;
    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
      if (stdout.length > max) stdout = stdout.slice(-max);
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      if (stderr.length > max) stderr = stderr.slice(-max);
    });
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
    }, options.timeoutMs || 12 * 60 * 1000);
    child.on('error', (error) => {
      clearTimeout(timer);
      resolve({ code: -1, stdout, stderr: `${stderr}\n${error.message}` });
    });
    child.on('exit', (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? -1, stdout, stderr });
    });
  });
}

async function runDart(args) {
  const mode = args.mode || 'all';
  const playerCount = Math.min(6, Math.max(4, args.playerCount || 5));
  const rounds = Math.max(0, Math.min(20, args.rounds || 0));
  const command = [
    'test',
    'test/multiplayer_simulation_test.dart',
    `--dart-define=SIM_PLAYER_COUNT=${playerCount}`,
    `--dart-define=SIM_ROUNDS=${rounds}`,
  ];
  if (mode !== 'all') command.push('--plain-name', testNames[mode]);
  const result = await run('flutter', command, { cwd: appDir });
  return {
    ok: result.code === 0,
    tool: 'run_dart_multiplayer_sim',
    mode,
    playerCount,
    rounds,
    command: `flutter ${command.join(' ')}`,
    exitCode: result.code,
    output: (result.stdout || result.stderr).slice(-12000),
  };
}

async function ensureWebBuild() {
  const configured = process.env.PLAYTEST_WEB_DIR;
  const candidates = [
    configured,
    '/tmp/opencode/whotook_playtest_build/build/web',
    path.join(repoRoot, 'build/web'),
  ].filter(Boolean);
  for (const candidate of candidates) {
    if (fs.existsSync(path.join(candidate, 'index.html'))) return candidate;
  }
  const build = await run(
    'bash',
    [path.join(here, 'run_full_playtest.sh'), '--build-only'],
    { timeoutMs: 20 * 60 * 1000 },
  );
  if (build.code !== 0) {
    throw new Error(`web playtest build failed:\n${build.stdout}\n${build.stderr}`);
  }
  const fallback = '/tmp/opencode/whotook_playtest_build/build/web';
  if (!fs.existsSync(path.join(fallback, 'index.html'))) {
    throw new Error('web playtest build finished without index.html');
  }
  return fallback;
}

function parseViewports(input) {
  if (!Array.isArray(input) || input.length === 0) return null;
  return input.slice(0, 4).map((entry, index) => {
    if (typeof entry === 'string') {
      const match = entry.match(/^(\d+)x(\d+)$/i);
      if (!match) throw new Error(`invalid viewport ${entry}`);
      return {
        name: index === 0 ? 'Host' : `Bot${index + 1}`,
        width: Number(match[1]),
        height: Number(match[2]),
      };
    }
    return {
      name: entry.name || (index === 0 ? 'Host' : `Bot${index + 1}`),
      width: Number(entry.width),
      height: Number(entry.height),
    };
  });
}

async function runVisual(args) {
  const mode = args.mode || 'all';
  const playerCount = Math.min(4, Math.max(2, args.playerCount || 4));
  const viewports = parseViewports(args.viewports);
  const webDir = await ensureWebBuild();
  const harnessArgs = [
    path.join(here, 'playtest_bot_match.mjs'),
    '--web-dir',
    webDir,
    '--mode',
    mode,
    '--report',
    reportPath,
  ];
  const env = {
    PLAYTEST_PLAYER_COUNT: String(playerCount),
  };
  if (viewports) env.PLAYTEST_VIEWPORTS = JSON.stringify(viewports);
  const result = await run(process.execPath, harnessArgs, {
    cwd: repoRoot,
    env,
    timeoutMs: 15 * 60 * 1000,
  });
  let report = null;
  try {
    report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  } catch {}
  return {
    ok: result.code === 0 && report?.ok === true,
    tool: 'run_visual_bot_match',
    mode,
    playerCount,
    viewports: viewports || 'default four viewports',
    exitCode: result.code,
    report,
    screenshots: fs.existsSync(screenshotDir)
      ? fs.readdirSync(screenshotDir).map((name) => path.join(screenshotDir, name))
      : [],
    output: (result.stdout || result.stderr).slice(-12000),
  };
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function reply(id, result) {
  send({ jsonrpc: '2.0', id, result });
}

function fail(id, code, message) {
  send({ jsonrpc: '2.0', id, error: { code, message } });
}

async function handle(message) {
  const { id, method, params } = message;
  if (method === 'initialize') {
    reply(id, {
      protocolVersion: params?.protocolVersion || '2024-11-05',
      capabilities: { tools: {} },
      serverInfo: { name: 'whotook-playtest', version: '1.0.0' },
    });
    return;
  }
  if (method === 'notifications/initialized' || method === 'initialized') return;
  if (method === 'ping') {
    reply(id, {});
    return;
  }
  if (method === 'tools/list') {
    reply(id, { tools });
    return;
  }
  if (method === 'tools/call') {
    const name = params?.name;
    const args = params?.arguments || {};
    try {
      const result =
        name === 'run_dart_multiplayer_sim'
          ? await runDart(args)
          : name === 'run_visual_bot_match'
          ? await runVisual(args)
          : null;
      if (!result) {
        reply(id, {
          content: [{ type: 'text', text: `Unknown tool: ${name}` }],
          isError: true,
        });
        return;
      }
      reply(id, {
        content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
        structuredContent: result,
        isError: !result.ok,
      });
    } catch (error) {
      reply(id, {
        content: [{ type: 'text', text: error.stack || error.message }],
        isError: true,
      });
    }
    return;
  }
  if (method === 'resources/list') {
    reply(id, { resources: [] });
    return;
  }
  if (id !== undefined) fail(id, -32601, `method not found: ${method}`);
}

let buffer = '';
let pending = 0;
let stdinEnded = false;
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  let newline;
  while ((newline = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, newline).trim();
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    let message;
    try {
      message = JSON.parse(line);
    } catch (error) {
      send({
        jsonrpc: '2.0',
        id: null,
        error: { code: -32700, message: `parse error: ${error.message}` },
      });
      continue;
    }
    pending += 1;
    handle(message)
      .catch((error) => {
        if (message.id !== undefined) fail(message.id, -32603, error.message);
      })
      .finally(() => {
        pending -= 1;
        if (stdinEnded && pending === 0) process.exit(0);
      });
  }
});
process.stdin.on('end', () => {
  stdinEnded = true;
  if (pending === 0) process.exit(0);
});

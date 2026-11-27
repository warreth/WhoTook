#!/usr/bin/env node
// Four isolated browser contexts play a real WhoTook match through the actual
// Flutter UI. The app is built with PLAYTEST_MODE=true, which swaps the gallery
// for bundled dated samples and publishes a state snapshot plus a tiny command
// bridge to localStorage. Screenshots are written outside the public tree.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../..');

function parseArgs(argv) {
  const options = {
    webDir: process.env.PLAYTEST_WEB_DIR || '',
    baseUrl: process.env.PLAYTEST_BASE_URL || '',
    mode: 'all',
    report: process.env.PLAYTEST_REPORT || '',
    headed: process.env.PLAYTEST_HEADED === '1',
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--web-dir') options.webDir = argv[++i];
    else if (arg === '--base-url') options.baseUrl = argv[++i];
    else if (arg === '--mode') options.mode = argv[++i];
    else if (arg === '--report') options.report = argv[++i];
    else if (arg === '--headed') options.headed = true;
  }
  return options;
}

function resolvePlaywright() {
  try {
    return require('playwright');
  } catch {
    const roots = [
      path.join(process.env.HOME || '', '.npm/_npx'),
      '/usr/lib/node_modules',
    ];
    for (const root of roots) {
      if (!fs.existsSync(root)) continue;
      for (const entry of fs.readdirSync(root)) {
        const candidate = path.join(root, entry, 'node_modules/playwright');
        if (fs.existsSync(candidate)) return require(candidate);
      }
    }
    throw new Error(
      'Playwright is not installed. Run: npx playwright install chromium',
    );
  }
}

function findChromium(playwright) {
  if (process.env.PLAYTEST_CHROMIUM) return process.env.PLAYTEST_CHROMIUM;
  try {
    const expected = playwright.chromium.executablePath();
    if (expected && fs.existsSync(expected)) return expected;
  } catch {}
  const cache = process.env.PLAYWRIGHT_BROWSERS_PATH ||
    path.join(process.env.HOME || '', '.cache/ms-playwright');
  if (!fs.existsSync(cache)) return undefined;
  const entries = fs
    .readdirSync(cache)
    .filter((name) => name.startsWith('chromium'))
    .sort((a, b) => {
      const number = (value) => Number((value.match(/(\d+)$/) || [0, 0])[1]);
      return number(b) - number(a);
    });
  // Prefer the headless shell: it needs fewer system libraries than the full
  // Chromium bundle.
  const ordered = [
    ...entries.filter((name) => name.startsWith('chromium_headless_shell')),
    ...entries.filter((name) => !name.startsWith('chromium_headless_shell')),
  ];
  for (const entry of ordered) {
    const candidates = [
      path.join(cache, entry, 'chrome-headless-shell-linux64/chrome-headless-shell'),
      path.join(cache, entry, 'chrome-linux64/chrome'),
      path.join(cache, entry, 'chrome-linux/chrome'),
    ];
    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) return candidate;
    }
  }
  return undefined;
}

function childEnv() {
  const env = { ...process.env };
  const candidates = [
    process.env.PLAYTEST_CHROMELIBS,
    path.join(
      process.env.HOME || '',
      '.cache/whotook-playtest/chromelibs/root/usr/lib/x86_64-linux-gnu',
    ),
    '/tmp/opencode/chromelibs/root/usr/lib/x86_64-linux-gnu',
  ].filter(Boolean);
  const libs = candidates.find((candidate) => fs.existsSync(candidate));
  if (libs) {
    env.LD_LIBRARY_PATH = env.LD_LIBRARY_PATH
      ? `${libs}:${env.LD_LIBRARY_PATH}`
      : libs;
  }
  return env;
}

async function startServer(webDir) {
  const child = spawn(
    process.execPath,
    [path.join(here, 'signaling_server.mjs'), '--dir', webDir],
    { cwd: repoRoot, env: childEnv(), stdio: ['ignore', 'pipe', 'pipe'] },
  );
  let buffer = '';
  const url = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`signaling server did not start:\n${buffer}`));
    }, 15000);
    child.stdout.on('data', (chunk) => {
      buffer += chunk.toString();
      const match = buffer.match(/PLAYTEST_SERVER_READY (\S+)/);
      if (match) {
        clearTimeout(timer);
        resolve(match[1]);
      }
    });
    child.stderr.on('data', (chunk) => {
      buffer += chunk.toString();
      if (process.env.PLAYTEST_DEBUG === '1') process.stderr.write(chunk);
    });
    child.on('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`signaling server exited ${code}:\n${buffer}`));
    });
  });
  return { child, url };
}

const VIEWPORTS = [
  { name: 'Host', width: 375, height: 667, device: 'iPhone 8 / SE' },
  { name: 'Bot2', width: 393, height: 852, device: 'iPhone 15' },
  { name: 'Bot3', width: 412, height: 915, device: 'Pixel 8 Pro' },
  { name: 'Bot4', width: 768, height: 1024, device: 'iPad tablet' },
];
let activeViewports = VIEWPORTS;

function configuredViewports() {
  let viewports = [...VIEWPORTS];
  const custom = process.env.PLAYTEST_VIEWPORTS;
  if (custom) {
    try {
      const parsed = JSON.parse(custom);
      if (Array.isArray(parsed) && parsed.length > 0) {
        viewports = parsed.slice(0, 4).map((entry, index) => {
          if (typeof entry === 'string') {
            const match = entry.match(/^(\d+)x(\d+)$/i);
            if (!match) throw new Error(`bad viewport ${entry}`);
            return {
              name: index === 0 ? 'Host' : `Bot${index + 1}`,
              width: Number(match[1]),
              height: Number(match[2]),
              device: entry,
            };
          }
          return {
            name: entry.name || (index === 0 ? 'Host' : `Bot${index + 1}`),
            width: Number(entry.width),
            height: Number(entry.height),
            device: entry.device || `${entry.width}x${entry.height}`,
          };
        });
      }
    } catch (error) {
      throw new Error(`PLAYTEST_VIEWPORTS: ${error.message}`);
    }
  }
  const count = Number(process.env.PLAYTEST_PLAYER_COUNT || viewports.length);
  if (Number.isFinite(count)) viewports = viewports.slice(0, Math.max(2, count));
  return viewports;
}

const SCREENSHOT_NAMES = new Set();
const screenshots = [];
const consoleErrors = [];
const checks = [];
let screenshotsDir = '';

function check(condition, message) {
  if (condition) {
    checks.push({ status: 'passed', assertion: message });
    return;
  }
  checks.push({ status: 'failed', assertion: message });
  throw new Error(message);
}

function screenshotPath(name) {
  return path.join(screenshotsDir, name);
}

async function shot(page, name, options = {}) {
  await enableSemantics(page);
  if (options.delay) await page.waitForTimeout(options.delay);
  const file = screenshotPath(name);
  await page.screenshot({ path: file, fullPage: false });
  SCREENSHOT_NAMES.add(name);
  screenshots.push(name);
  await assertViewport(page, name);
  process.stdout.write(`  screenshot ${name}\n`);
}

async function enableSemantics(page) {
  // Flutter installs the placeholder during its first frames; clicking too
  // early is a no-op. Retry until the accessibility tree is really present.
  for (let attempt = 0; attempt < 14; attempt++) {
    const count = await page.evaluate(
      () => document.querySelectorAll('flt-semantics').length,
    );
    if (count >= 3) return true;
    await page.evaluate(() => {
      document.querySelector('flt-semantics-placeholder')?.click();
    });
    await page.waitForTimeout(350);
  }
  return false;
}

async function readState(page) {
  const raw = await page.evaluate(() =>
    localStorage.getItem('whotook.playtest.state'),
  );
  return raw ? JSON.parse(raw) : null;
}

async function waitState(page, predicate, timeout = 25000, reason = 'state') {
  const deadline = Date.now() + timeout;
  let last = null;
  while (Date.now() < deadline) {
    const current = await readState(page);
    last = current;
    if (current && predicate(current)) return current;
    await page.waitForTimeout(100);
  }
  throw new Error(
    `timeout waiting for ${reason}; phase=${last?.phase} round=${last?.currentRound}`,
  );
}

async function command(page, action, value) {
  await page.evaluate(
    ({ action, value }) =>
      localStorage.setItem(
        'whotook.playtest.command',
        JSON.stringify({ action, value }),
      ),
    { action, value },
  );
}

async function ensureInvite(page) {
  return waitState(page, (state) => Boolean(state.inviteUrl), 20000, 'invite');
}

async function assertViewport(page, label) {
  if (label.endsWith('.png')) await enableSemantics(page);
  const metrics = await page.evaluate(() => {
    const scene =
      document.querySelector('flt-glass-pane') ||
      document.querySelector('flt-scene-host') ||
      document.querySelector('canvas');
    const rect = scene ? scene.getBoundingClientRect() : null;
    return {
      innerWidth: window.innerWidth,
      innerHeight: window.innerHeight,
      documentHeight: document.documentElement.scrollHeight,
      bodyHeight: document.body.scrollHeight,
      scene: rect
        ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
        : null,
      body: (() => {
        const bodyRect = document.body.getBoundingClientRect();
        return {
          x: bodyRect.x,
          y: bodyRect.y,
          width: bodyRect.width,
          height: bodyRect.height,
        };
      })(),
      devicePixelRatio: window.devicePixelRatio,
    };
  });
  check(
    metrics.documentHeight <= metrics.innerHeight + 1,
    `${label}: document height fits viewport (${metrics.documentHeight} <= ${metrics.innerHeight})`,
  );
  check(
    metrics.bodyHeight <= metrics.innerHeight + 1,
    `${label}: body height fits viewport (${metrics.bodyHeight} <= ${metrics.innerHeight})`,
  );
  check(
    metrics.body.width >= metrics.innerWidth * 0.95 &&
      metrics.body.height >= metrics.innerHeight * 0.95,
    `${label}: app fills the viewport (${metrics.body.width}x${metrics.body.height})`,
  );
  if (metrics.scene && metrics.scene.width > 0 && metrics.scene.height > 0) {
    check(
      metrics.scene.width >= metrics.innerWidth * 0.95 &&
        metrics.scene.height >= metrics.innerHeight * 0.95,
      `${label}: game canvas fills the viewport (${metrics.scene.width}x${metrics.scene.height})`,
    );
  }
}

async function semanticsNodes(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('flt-semantics')).map((node) => {
      const rect = node.getBoundingClientRect();
      return {
        label: node.getAttribute('aria-label') || '',
        role: node.getAttribute('role') || '',
        text: node.textContent || '',
        rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
      };
    }),
  );
}

async function findButton(page, label, { required = true } = {}) {
  await enableSemantics(page);
  const nodes = await semanticsNodes(page);
  const matches = nodes
    .filter(
      (node) =>
        (node.role === 'button' || node.role === 'link') &&
        `${node.label} ${node.text}`.toLowerCase().includes(label.toLowerCase()),
    )
    .filter((node) => node.rect.width > 4 && node.rect.height > 4)
    .sort((a, b) => b.rect.width * b.rect.height - a.rect.width * a.rect.height);
  if (required) {
    check(matches.length > 0, `button "${label}" is visible`);
  }
  return matches[0] || null;
}

async function assertPrimaryButton(page, label, minHeight = 44) {
  const button = await findButton(page, label);
  check(
    button.rect.height >= minHeight,
    `primary button "${label}" is ${button.rect.height.toFixed(1)}px high (>= ${minHeight})`,
  );
  check(
    button.rect.width >= 160,
    `primary button "${label}" is ${button.rect.width.toFixed(1)}px wide (>= 160)`,
  );
}

async function photoRect(page) {
  await enableSemantics(page);
  const nodes = await semanticsNodes(page);
  const photos = nodes
    .filter((node) => {
      const text = `${node.label} ${node.text}`.toLowerCase();
      return (
        text.includes('game photo') ||
        text.includes('spelfoto') ||
        text.includes('tap to zoom') ||
        text.includes('tik om te zoomen')
      );
    })
    .filter((node) => node.rect.width > 40 && node.rect.height > 40)
    .sort((a, b) => b.rect.width * b.rect.height - a.rect.width * a.rect.height);
  return photos[0]?.rect || null;
}

async function assertPhotoVisible(page, label) {
  const rect = await photoRect(page);
  check(Boolean(rect), `${label}: accessible photo area found`);
  check(
    rect.width >= 150 && rect.height >= 110,
    `${label}: photo is at least 150x110 (${rect.width.toFixed(0)}x${rect.height.toFixed(0)})`,
  );
  const buffer = await page.screenshot();
  const stats = await page.evaluate(
    async ({ dataUrl, rect }) => {
      const image = new Image();
      image.src = dataUrl;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width;
      canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      const scale = image.width / window.innerWidth;
      const x = Math.max(0, Math.floor(rect.x * scale));
      const y = Math.max(0, Math.floor(rect.y * scale));
      const width = Math.min(canvas.width - x, Math.floor(rect.width * scale));
      const height = Math.min(canvas.height - y, Math.floor(rect.height * scale));
      const data = context.getImageData(x, y, width, height).data;
      let count = 0;
      let dark = 0;
      let sum = 0;
      let sumSquares = 0;
      for (let i = 0; i < data.length; i += 4 * 17) {
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        if (luminance < 8) dark += 1;
        sum += luminance;
        sumSquares += luminance * luminance;
        count += 1;
      }
      const mean = count ? sum / count : 0;
      const variance = count ? sumSquares / count - mean * mean : 0;
      return {
        darkFraction: count ? dark / count : 1,
        variance,
        width,
        height,
      };
    },
    {
      dataUrl: `data:image/png;base64,${buffer.toString('base64')}`,
      rect,
    },
  );
  check(
    stats.darkFraction < 0.55,
    `${label}: photo area is not black (${(stats.darkFraction * 100).toFixed(0)}% dark)`,
  );
  check(
    stats.variance > 40,
    `${label}: photo area has visible detail (variance ${stats.variance.toFixed(1)})`,
  );
}

class Bot {
  constructor(page, viewport) {
    this.page = page;
    this.viewport = viewport;
  }

  get name() {
    return this.viewport.name;
  }
}

function modeQuery(mode, rounds) {
  return `role=host&mode=${mode}&rounds=${rounds}&roundSeconds=30`;
}

async function bootHost(bot, mode, rounds) {
  await bot.page.goto(
    `${bot.page.playtestBase}/?${modeQuery(mode, rounds)}`,
    { waitUntil: 'load' },
  );
  return ensureInvite(bot.page);
}

async function bootClient(bot, invite) {
  await bot.page.goto(
    `${bot.page.playtestBase}/?role=client&invite=${encodeURIComponent(invite)}`,
    { waitUntil: 'load' },
  );
}

async function waitForRoom(host, bots, timeout = 20000) {
  try {
    await waitState(
      host.page,
      (state) => state.players.length === bots.length && state.isHosting,
      timeout,
      'all players in the lobby',
    );
  } catch (error) {
    const debug = [];
    for (const bot of bots) {
      const snapshot = await readState(bot.page);
      debug.push({
        name: bot.name,
        phase: snapshot?.phase,
        roomId: snapshot?.roomId,
        hosting: snapshot?.isHosting,
        players: snapshot?.players?.length,
        error: snapshot?.errorMessage,
      });
    }
    throw new Error(`${error.message}\n${JSON.stringify(debug, null, 2)}`);
  }
  for (const bot of bots) {
    await waitState(
      bot.page,
      (state) => state.roomId !== null && state.players.length === bots.length,
      timeout,
      `${bot.name} joined the lobby`,
    );
  }
}

async function joinBots(host, bots, invite) {
  for (const bot of bots.slice(1)) await bootClient(bot, invite.inviteUrl);
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      await waitForRoom(host, bots, 18000);
      return;
    } catch (error) {
      const failed = [];
      for (const bot of bots.slice(1)) {
        const snapshot = await readState(bot.page);
        if (!snapshot || snapshot.roomId === null) failed.push(bot);
      }
      if (failed.length === 0 || attempt === 3) throw error;
      process.stdout.write(
        `  retry join for ${failed.map((bot) => bot.name).join(', ')}\n`,
      );
      for (const bot of failed) await bootClient(bot, invite.inviteUrl);
    }
  }
}

async function prepareMatch(host, bots, { capture = false } = {}) {
  await command(host.page, 'startPrepare');
  await waitState(
    host.page,
    (state) => state.candidates > 0,
    30000,
    'host vault candidates',
  );
  for (const bot of bots) {
    await waitState(
      bot.page,
      (state) => state.candidates > 0,
      30000,
      `${bot.name} vault candidates`,
    );
  }
  if (capture) {
    await shot(host.page, '02_vault.png', { delay: 800 });
    await assertPrimaryButton(host.page, 'Ready');
  }
  for (const bot of bots) await command(bot.page, 'ready');
  await waitState(
    host.page,
    (state) => state.phase !== 'preparing' && state.phase !== 'lobby',
    30000,
    'first gameplay phase',
  );
}

async function playZoomRound(host, bots, round, capture) {
  const start = await waitState(
    host.page,
    (state) => state.phase === 'guessing',
    25000,
    `zoom-out round ${round}`,
  );
  for (const bot of bots.slice(1)) {
    await waitState(
      bot.page,
      (state) => state.phase === 'guessing',
      20000,
      `zoom-out round ${round} on ${bot.name}`,
    );
  }
  await host.page.waitForTimeout(350);
  if (capture.zoomRound) {
    capture.zoomRound = false;
    await shot(host.page, '03_zoom_out_round.png', { delay: 200 });
    await assertPhotoVisible(host.page, '03_zoom_out_round');
    await assertPhotoVisible(bots[1].page, '03_zoom_out_round tablet/phone');
  }
  const options = start.activeRoundOptions;
  check(options.length >= 2, `zoom-out round ${round} exposes ${options.length} answer targets`);
  for (let i = 0; i < bots.length; i++) {
    const target = options[(i + round) % options.length].id;
    await command(bots[i].page, 'classicGuess', target);
  }
  const reveal = await waitState(
    host.page,
    (state) => state.phase === 'reveal' || state.phase === 'podium',
    25000,
    `zoom-out round ${round} reveal`,
  );
  if (reveal.phase === 'podium') return;
  await host.page.waitForTimeout(700);
  if (capture.zoomReveal) {
    capture.zoomReveal = false;
    await shot(host.page, '04_zoom_out_reveal.png', { delay: 100 });
    await assertPrimaryButton(host.page, 'Next Round');
  }
  await command(host.page, 'skipRound');
  await waitState(
    host.page,
    (state) =>
      state.phase !== 'reveal' && state.phase !== 'podium'
        ? true
        : state.phase === 'podium',
    20000,
    `zoom-out round ${round} advance`,
  );
}

async function playClassicRound(host, bots, round, capture) {
  const start = await waitState(
    host.page,
    (state) => state.phase === 'guessing',
    25000,
    `classic round ${round}`,
  );
  for (const bot of bots.slice(1)) {
    await waitState(
      bot.page,
      (state) => state.phase === 'guessing',
      20000,
      `classic round ${round} on ${bot.name}`,
    );
  }
  await host.page.waitForTimeout(350);
  if (capture.classicRound) {
    capture.classicRound = false;
    await shot(host.page, '03_classic_round.png', { delay: 200 });
    await assertPhotoVisible(host.page, '03_classic_round');
    await assertPhotoVisible(bots[1].page, '03_classic_round tablet/phone');
  }
  const options = start.activeRoundOptions;
  check(options.length >= 2, `classic round ${round} exposes ${options.length} answer targets`);
  for (let i = 0; i < bots.length; i++) {
    const target = options[(i + round) % options.length].id;
    await command(bots[i].page, 'classicGuess', target);
  }
  const reveal = await waitState(
    host.page,
    (state) => state.phase === 'reveal' || state.phase === 'podium',
    25000,
    `classic round ${round} reveal`,
  );
  if (reveal.phase === 'podium') return;
  await host.page.waitForTimeout(750);
  if (capture.classicReveal) {
    capture.classicReveal = false;
    await shot(host.page, '04_classic_reveal.png', { delay: 100 });
    await assertPrimaryButton(host.page, 'Next Round');
  }
  await command(host.page, 'skipRound');
  await waitState(
    host.page,
    (state) =>
      state.phase !== 'reveal' && state.phase !== 'podium'
        ? true
        : state.phase === 'podium',
    20000,
    `classic round ${round} advance`,
  );
}

async function playMemeRound(host, bots, round, capture, options = {}) {
  const sabotage = Boolean(options.sabotage);
  await waitState(
    host.page,
    (state) => state.phase === 'captionWriting',
    25000,
    `meme round ${round} writing`,
  );
  await host.page.waitForTimeout(400);
  if (sabotage) {
    for (const bot of bots) {
      await waitState(
        bot.page,
        (state) =>
          state.phase === 'captionWriting' && Boolean(state.memeAssignment),
        20000,
        `sabotage assignment for ${bot.name}`,
      );
    }
  }
  const createKey = sabotage ? 'sabotageCreate' : 'memeCreate';
  if (sabotage) {
    const rect = await photoRect(host.page);
    if (rect) {
      // The accessibility overlay sits above the canvas. Turn its hit testing
      // off for the drag so the marker actually reaches the drawing surface.
      await host.page.evaluate(() => {
        for (const el of document.querySelectorAll(
          'flt-semantics, flt-semantics-host',
        )) {
          el.style.pointerEvents = 'none';
        }
      });
      await host.page.mouse.move(
        rect.x + rect.width * 0.28,
        rect.y + rect.height * 0.32,
      );
      await host.page.mouse.down();
      await host.page.mouse.move(
        rect.x + rect.width * 0.62,
        rect.y + rect.height * 0.58,
        { steps: 10 },
      );
      await host.page.mouse.up();
      await host.page.waitForTimeout(160);
      await host.page.evaluate(() => {
        for (const el of document.querySelectorAll(
          'flt-semantics, flt-semantics-host',
        )) {
          el.style.pointerEvents = '';
        }
      });
    }
  }
  if (capture[createKey]) {
    capture[createKey] = false;
    await shot(host.page, sabotage ? '05_sabotage_draw.png' : '05_meme_create.png', {
      delay: 200,
    });
    for (const bot of bots) {
      await assertPrimaryButton(bot.page, sabotage ? 'Send sabotage' : 'Send meme');
    }
    await assertPrimaryButton(host.page, 'Swap photo', 44);
  }
  for (let i = 0; i < bots.length; i++) {
    if (sabotage) {
      await command(bots[i].page, 'sabotageSubmit');
    } else {
      await command(bots[i].page, 'memeSubmit', {
        template: i % 2 === 0 ? 'classic' : 'pov',
        topText: `${bots[i].name} roast ${round}`,
        bottomText: 'bottom text',
        snapY: 48,
      });
    }
  }
  let voting = await waitState(
    host.page,
    (state) => state.phase === 'captionVoting' && Boolean(state.memeFocusId),
    25000,
    `meme round ${round} voting`,
  );
  await host.page.waitForTimeout(500);
  const voteKey = sabotage ? 'sabotageVote' : 'memeVote';
  if (capture[voteKey]) {
    capture[voteKey] = false;
    // If the focus happens to be the host's own meme, advance once so the
    // screenshot shows the normal (votable) state.
    if (voting.memeFocusId === voting.ownMemeId) {
      for (const bot of bots) await command(bot.page, 'memeVote', 'up');
      voting = await waitState(
        host.page,
        (state) =>
          state.phase !== 'captionVoting' ||
          state.memeFocusId !== voting.memeFocusId,
        15000,
        'second meme focus',
      );
    }
    await host.page.waitForTimeout(300);
    await shot(host.page, sabotage ? '06_sabotage_vote.png' : '06_meme_vote.png', { delay: 100 });
    await assertPrimaryButton(host.page, 'End voting');
  }

  let guard = 0;
  while (voting.phase === 'captionVoting' && guard < 14) {
    guard += 1;
    const focus = voting.memeFocusId;
    for (const bot of bots) await command(bot.page, 'memeVote', 'up');
    voting = await waitState(
      host.page,
      (state) =>
        state.phase !== 'captionVoting' || state.memeFocusId !== focus,
      20000,
      'meme focus advance',
    );
  }
  await waitState(
    host.page,
    (state) => state.phase === 'captionReveal',
    25000,
    `meme round ${round} reveal`,
  );
  await host.page.waitForTimeout(650);
  const revealKey = sabotage ? 'sabotageReveal' : 'memeReveal';
  if (capture[revealKey]) {
    capture[revealKey] = false;
    await shot(host.page, sabotage ? '10_sabotage_reveal.png' : '10_meme_reveal.png', {
      delay: 100,
    });
    await assertPrimaryButton(host.page, 'Next Round');
  }
  await command(host.page, 'advanceMemeReveal');
  await waitState(
    host.page,
    (state) => state.phase !== 'captionReveal',
    20000,
    `meme round ${round} advance`,
  );
}

async function playTimelineRound(host, bots, round, capture) {
  await waitState(
    host.page,
    (state) => state.phase === 'timelineGuessing',
    25000,
    `timeline round ${round}`,
  );
  await host.page.waitForTimeout(350);
  if (capture.timeline) {
    capture.timeline = false;
    await shot(host.page, '11_time_traveler_round.png', { delay: 200 });
    for (const bot of bots) {
      await assertPrimaryButton(bot.page, 'Lock in');
    }
    await assertPhotoVisible(host.page, '11_time_traveler_round');
  }
  for (let i = 0; i < bots.length; i++) {
    await command(bots[i].page, 'timelineSubmit', {
      year: 1998 + ((round * 3 + i * 2) % 24),
      month: ((round + i) % 12) + 1,
    });
  }
  await waitState(
    host.page,
    (state) => state.phase === 'timelineReveal',
    25000,
    `timeline round ${round} reveal`,
  );
  await host.page.waitForTimeout(600);
  if (capture.timelineZoom) {
    capture.timelineZoom = false;
    await command(host.page, 'openPhotoZoom');
    await host.page.waitForTimeout(700);
    await shot(host.page, '07_time_traveler_zoom.png');
    const close = await findButton(host.page, 'Close');
    check(Boolean(close), 'photo zoom has no Close button');
    await command(host.page, 'closePhotoZoom');
    await host.page.waitForTimeout(450);
    await shot(host.page, '12_time_traveler_reveal.png');
    await assertPrimaryButton(host.page, 'Next Round');
  }
  await command(host.page, 'skipRound');
  await waitState(
    host.page,
    (state) => state.phase !== 'timelineReveal',
    20000,
    `timeline round ${round} advance`,
  );
}

async function playRound(host, bots, round, capture) {
  const current = await waitState(
    host.page,
    (state) =>
      ['guessing', 'captionWriting', 'timelineGuessing', 'podium'].includes(
        state.phase,
      ),
    30000,
    `round ${round} start`,
  );
  if (current.phase === 'podium') return false;
  if (current.activeMode === 'zoomOut') {
    await playZoomRound(host, bots, round, capture);
  } else if (current.activeMode === 'photoSabotage') {
    await playMemeRound(host, bots, round, capture, { sabotage: true });
  } else if (current.activeMode === 'makeItMeme') {
    await playMemeRound(host, bots, round, capture);
  } else if (current.activeMode === 'timeTraveler') {
    await playTimelineRound(host, bots, round, capture);
  } else if (current.phase === 'captionWriting') {
    // The legacy Caption This mode shares the meme submission wire format.
    await playMemeRound(host, bots, round, capture);
  } else {
    await playClassicRound(host, bots, round, capture);
  }
  return true;
}

async function podium(host, bots, captureTablet = true, sabotage = false) {
  await waitState(host.page, (state) => state.phase === 'podium', 30000, 'podium');
  await host.page.waitForTimeout(1200);
  const state = await waitState(host.page, (s) => s.phase === 'podium');
  check(state.awards.length > 0, `podium exposes ${state.awards.length} awards`);
  if (state.topMemes.length > 0) {
    check(
      state.topMemes.every((meme) => meme.photoId && meme.photoId.length > 0),
      'top memes all have photo ids',
    );
    await host.page.mouse.move(host.viewport.width / 2, host.viewport.height / 2);
    await host.page.mouse.wheel(0, sabotage ? 620 : 430);
    await host.page.waitForTimeout(400);
    await shot(
      host.page,
      sabotage ? '08_podium_top3_creations.png' : '08_podium_top3_memes.png',
      { delay: 200 },
    );
    let save = await findButton(host.page, 'Save meme', { required: false });
    save = save || (await findButton(host.page, 'Save sabotage', { required: false }));
    for (let rank = 2; rank <= state.topMemes.length; rank++) {
      await host.page.mouse.wheel(0, 520);
      await host.page.waitForTimeout(350);
      await shot(host.page, `08_top_meme_${rank}.png`, { delay: 150 });
      save = save || (await findButton(host.page, 'Save meme', { required: false }));
      save = save || (await findButton(host.page, 'Save sabotage', { required: false }));
    }
    check(Boolean(save), 'top creation Save button is not visible');
    if (captureTablet) {
      const tablet = bots[bots.length - 1];
      await tablet.page.mouse.move(
        tablet.viewport.width / 2,
        tablet.viewport.height / 2,
      );
      for (let i = 0; i < 3; i++) {
        await tablet.page.mouse.wheel(0, 900);
        await tablet.page.waitForTimeout(250);
      }
      await shot(tablet.page, '14_tablet_podium.png', { delay: 200 });
    }
  } else {
    await shot(host.page, '13_classic_podium.png');
  }
}

async function playMatch(browser, baseUrl, mode, rounds, capture) {
  process.stdout.write(`\n▶ ${mode} (${rounds} rounds, ${activeViewports.length} players)\n`);
  const bots = [];
  for (const viewport of activeViewports) {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      deviceScaleFactor: 1,
    });
    await context.addInitScript(
      ({ server, name }) => {
        const settings = {
          nickname: name,
          onboardingCompleted: true,
          customSignalingUrl: server,
          soundEnabled: false,
          musicEnabled: false,
          hapticsEnabled: false,
        };
        localStorage.setItem(
          'whotook.settings.v1',
          JSON.stringify(JSON.stringify(settings)),
        );
      },
      { server: baseUrl, name: viewport.name },
    );
    const page = await context.newPage();
    page.playtestBase = baseUrl;
    page.on('pageerror', (error) => {
      consoleErrors.push({
        page: viewport.name,
        type: 'pageerror',
        text: error.message,
      });
    });
    if (process.env.PLAYTEST_DEBUG === '1') {
      page.on('close', () => process.stderr.write(`page close ${viewport.name}\n`));
      page.on('crash', () => process.stderr.write(`page crash ${viewport.name}\n`));
      page.on('framenavigated', (frame) =>
        process.stderr.write(`page nav ${viewport.name} ${frame.url()}\n`),
      );
      page.on('websocket', (ws) =>
        process.stderr.write(`page ws ${viewport.name} ${ws.url()}\n`),
      );
      page.on('requestfailed', (request) =>
        process.stderr.write(
          `page reqfail ${viewport.name} ${request.url()} ${request.failure()?.errorText}\n`,
        ),
      );
      page.on('response', (response) => {
        if (response.url().includes('ice-config')) {
          process.stderr.write(
            `page ice ${viewport.name} ${response.status()} ${response.url()}\n`,
          );
        }
      });
    }
    page.on('console', (message) => {
      if (message.type() !== 'error') return;
      const text = message.text();
      if (/favicon|manifest\.json/i.test(text)) return;
      consoleErrors.push({ page: viewport.name, type: 'console', text });
    });
    bots.push(new Bot(page, viewport));
  }
  const host = bots[0];
  try {
    const invite = await bootHost(host, mode, rounds);
    await joinBots(host, bots, invite);
    if (capture.lobby && !SCREENSHOT_NAMES.has('01_lobby.png')) {
      await shot(host.page, '01_lobby.png', { delay: 600 });
      await assertPrimaryButton(host.page, 'Start photo check');
    }
    await prepareMatch(host, bots, { capture: capture.vault });
    for (let round = 1; round <= rounds; round++) {
      const played = await playRound(host, bots, round, capture);
      if (!played) break;
    }
    await podium(
      host,
      bots,
      capture.tabletPodium,
      mode === 'sabotage',
    );
    if (mode === 'classic' || mode === 'mixed') {
      const finalState = await readState(host.page);
      const mystery = finalState.awards.find(
        (award) => award.kind === 'masterOfMystery',
      );
      check(
        Boolean(mystery) && mystery.value > 0,
        `Unguessable Photo award carries an exact wrong-guess count (${mystery?.value ?? 0})`,
      );
    }
  } finally {
    for (const bot of bots) await bot.page.context().close();
  }
}

async function playZeroMemeMatch(browser, baseUrl) {
  process.stdout.write('\n▶ make it meme: zero submissions\n');
  const bots = [];
  for (const viewport of activeViewports.slice(0, 2)) {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      deviceScaleFactor: 1,
    });
    await context.addInitScript(
      ({ server, name }) => {
        const settings = {
          nickname: name,
          onboardingCompleted: true,
          customSignalingUrl: server,
          soundEnabled: false,
          musicEnabled: false,
          hapticsEnabled: false,
        };
        localStorage.setItem(
          'whotook.settings.v1',
          JSON.stringify(JSON.stringify(settings)),
        );
      },
      { server: baseUrl, name: viewport.name },
    );
    const page = await context.newPage();
    page.playtestBase = baseUrl;
    page.on('pageerror', (error) =>
      consoleErrors.push({
        page: viewport.name,
        type: 'pageerror',
        text: error.message,
      }),
    );
    page.on('console', (message) => {
      if (message.type() !== 'error') return;
      const text = message.text();
      if (/favicon|manifest\.json/i.test(text)) return;
      consoleErrors.push({ page: viewport.name, type: 'console', text });
    });
    bots.push(new Bot(page, viewport));
  }
  const host = bots[0];
  try {
    const invite = await bootHost(host, 'meme', 2);
    await joinBots(host, bots, invite);
    await prepareMatch(host, bots);
    await waitState(
      host.page,
      (state) => state.phase === 'captionWriting',
      25000,
      'zero-meme writing phase',
    );
    await command(host.page, 'skipRound');
    const empty = await waitState(
      host.page,
      (state) => state.phase === 'captionReveal',
      20000,
      'empty meme reveal',
    );
    check(empty.memeRevealCards === 0, `zero-meme reveal has ${empty.memeRevealCards} meme cards`);
    await shot(host.page, '09_meme_empty_reveal.png', { delay: 500 });
    await assertPrimaryButton(host.page, 'Next Round');
    const advanced = await waitState(
      host.page,
      (state) =>
        state.phase !== 'captionReveal' && state.currentRound >= 2,
      6000,
      'empty meme reveal auto-advance',
    );
    check(advanced.currentRound >= 2, `zero-meme round advanced to ${advanced.currentRound}`);
    process.stdout.write('  ✓ zero-meme reveal recovered to the next round\n');
  } finally {
    for (const bot of bots) await bot.page.context().close();
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  activeViewports = configuredViewports();
  const webDir = path.resolve(options.webDir || path.join(repoRoot, 'build/web'));
  if (!options.baseUrl && !fs.existsSync(path.join(webDir, 'index.html'))) {
    throw new Error(
      `No Flutter web build at ${webDir}. Run ./tool/playtest/run_full_playtest.sh first.`,
    );
  }
  screenshotsDir = process.env.PLAYTEST_SCREENSHOTS ||
    path.join(os.tmpdir(), 'opencode', 'whotook_playtest', 'auto_playtest', 'screenshots');
  fs.rmSync(screenshotsDir, { recursive: true, force: true });
  fs.mkdirSync(screenshotsDir, { recursive: true });

  let server = null;
  let browser = null;
  const startedAt = Date.now();
  try {
    let baseUrl = options.baseUrl;
    if (!baseUrl) {
      server = await startServer(webDir);
      baseUrl = server.url;
    }
    process.stdout.write(`playtest server ${baseUrl}\n`);

    const playwright = resolvePlaywright();
    const executablePath = findChromium(playwright);
    browser = await playwright.chromium.launch({
      headless: !options.headed,
      executablePath,
      env: childEnv(),
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--autoplay-policy=no-user-gesture-required',
        '--enable-unsafe-swiftshader',
      ],
    });

    const selected = options.mode;
    if (selected === 'all' || selected === 'classic') {
      await playMatch(browser, baseUrl, 'classic', 3, {
        classicRound: true,
        classicReveal: true,
      });
    }
    if (selected === 'all' || selected === 'meme') {
      await playMatch(browser, baseUrl, 'meme', 3, {
        memeCreate: true,
        memeVote: true,
        memeReveal: true,
      });
    }
    if (selected === 'all' || selected === 'time') {
      await playMatch(browser, baseUrl, 'time', 3, {
        timeline: true,
        timelineZoom: true,
      });
    }
    if (selected === 'all' || selected === 'zoom') {
      await playMatch(browser, baseUrl, 'zoom', 3, {
        zoomRound: true,
        zoomReveal: true,
      });
    }
    if (selected === 'all' || selected === 'sabotage') {
      await playMatch(browser, baseUrl, 'sabotage', 3, {
        sabotageCreate: true,
        sabotageVote: true,
        sabotageReveal: true,
      });
    }
    if (selected === 'all' || selected === 'mixed') {
      await playMatch(browser, baseUrl, 'mixed', 10, {
        lobby: true,
        vault: true,
        classicRound: true,
        classicReveal: true,
        zoomRound: true,
        zoomReveal: true,
        memeCreate: true,
        memeVote: true,
        memeReveal: true,
        sabotageCreate: true,
        sabotageVote: true,
        sabotageReveal: true,
        timeline: true,
        timelineZoom: true,
        tabletPodium: true,
      });
    }
    if (selected === 'all' || selected === 'meme-zero') {
      await playZeroMemeMatch(browser, baseUrl);
    }

    check(consoleErrors.length === 0, `console/page errors: ${consoleErrors.length === 0 ? 'none' : JSON.stringify(consoleErrors.slice(0, 5))}`);
    const requiredByMode = {
      all: [
        '01_lobby.png',
        '02_vault.png',
        '03_classic_round.png',
        '04_classic_reveal.png',
        '03_zoom_out_round.png',
        '04_zoom_out_reveal.png',
        '05_meme_create.png',
        '06_meme_vote.png',
        '05_sabotage_draw.png',
        '06_sabotage_vote.png',
        '07_time_traveler_zoom.png',
        '08_podium_top3_memes.png',
        '09_meme_empty_reveal.png',
      ],
      classic: ['03_classic_round.png', '04_classic_reveal.png'],
      meme: ['05_meme_create.png', '06_meme_vote.png', '10_meme_reveal.png'],
      time: [
        '07_time_traveler_zoom.png',
        '11_time_traveler_round.png',
        '12_time_traveler_reveal.png',
      ],
      zoom: ['03_zoom_out_round.png', '04_zoom_out_reveal.png'],
      sabotage: [
        '05_sabotage_draw.png',
        '06_sabotage_vote.png',
        '10_sabotage_reveal.png',
        '08_podium_top3_creations.png',
      ],
      mixed: [
        '01_lobby.png',
        '02_vault.png',
        '03_classic_round.png',
        '04_classic_reveal.png',
        '03_zoom_out_round.png',
        '04_zoom_out_reveal.png',
        '05_meme_create.png',
        '06_meme_vote.png',
        '05_sabotage_draw.png',
        '06_sabotage_vote.png',
        '10_sabotage_reveal.png',
        '07_time_traveler_zoom.png',
        '08_podium_top3_memes.png',
      ],
      'meme-zero': ['09_meme_empty_reveal.png'],
    };
    for (const name of requiredByMode[selected] || []) {
      check(SCREENSHOT_NAMES.has(name), `required screenshot ${name} is present`);
    }

    const report = {
      ok: true,
      durationMs: Date.now() - startedAt,
      screenshots,
      viewports: activeViewports,
      checks,
      consoleErrors,
    };
    const reportPath = options.report ||
      path.join(os.tmpdir(), 'opencode', 'whotook_playtest', 'auto_playtest', 'report.json');
    fs.mkdirSync(path.dirname(reportPath), { recursive: true });
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    process.stdout.write(
      `\n✓ Playtest passed: ${screenshots.length} screenshots, ${checks.length} checks\n`,
    );
  } catch (error) {
    const report = {
      ok: false,
      durationMs: Date.now() - startedAt,
      screenshots,
      consoleErrors,
      checks,
      error: error.message,
      stack: error.stack,
    };
    const reportPath = options.report ||
      path.join(os.tmpdir(), 'opencode', 'whotook_playtest', 'auto_playtest', 'report.json');
    fs.mkdirSync(path.dirname(reportPath), { recursive: true });
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    process.stderr.write(`\n✗ Playtest failed: ${error.message}\n`);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close().catch(() => {});
    if (server?.child) server.child.kill('SIGTERM');
  }
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exit(1);
});

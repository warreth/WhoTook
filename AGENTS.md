# Agent instructions

This is the public **WhoTook** product repository: the Flutter app and its
public website/docs assets. Keep it user-facing.

- Do not add App Store or Google Play submission guides, signing instructions,
  release checklists, deployment notes, account details, private tooling, or
  internal planning here.
- Do not recreate or link to private release material from public files.
- Never commit `.p12`, `.p8`, `.key`, `.mobileprovision`, `.jks`,
  `key.properties`, API keys, passwords, tokens or other credentials. Use
  GitHub Actions Secrets.
- Public documentation is `README.md` and `docs/screenshots` only.
- Do not rewrite public git history or force-push without the maintainer.


## Multiplayer playtest

Playtesting is part of the public product workflow, not a release checklist.
Use the reusable suite before shipping gameplay or layout changes:

```bash
./tool/playtest/run_full_playtest.sh
```

It runs the Dart 4–6 peer simulation in
`app/test/multiplayer_simulation_test.dart`, builds a throwaway
`PLAYTEST_MODE=true` web bundle under `/tmp/opencode`, and drives four isolated
Playwright browser contexts at `375x667`, `393x852`, `412x915` and `768x1024`
through Classic, Make It Meme, Time Traveler and Mixed Party. Screenshots and a
structured report land in `.private_prototypes/auto_playtest/` (gitignored).

Useful variants:

- `./tool/playtest/run_full_playtest.sh --dart-only`
- `./tool/playtest/run_full_playtest.sh --visual-only --skip-build --mode mixed`
- `./tool/playtest/run_full_playtest.sh --mode meme-zero` for the 0-meme freeze
  regression.
- The local MCP tools `run_dart_multiplayer_sim` and `run_visual_bot_match`
  (registered in `opencode.json` through `tool/playtest/mcp_playtest_server.mjs`)
  expose the same runs to a future OpenChamber session.
- `/playtest` runs the whole audit and asks a subagent for an independent
  screenshot review.
- To delegate it by hand, call the `subagent` tool with agent `general` and
  ask it to read `.private_prototypes/auto_playtest/report.json` plus every
  screenshot, and return only defects with screenshot names. Keep code fixes in
  the main session.

The web harness uses bundled sample photos with capture dates and never touches
a real gallery. Keep `PLAYTEST_MODE` test-only; it is a compile-time flag.


## Demo Mode

The demo runs the real host and three real clients over the in-process
loopback transport. Keep it fully in memory: no gallery permission, no network
socket, and no platform services. The demo host and every bot use
`platformServices: false`, because screenshot detection and the wake lock can
wait forever on an iOS channel and leave "Demotafel klaarzetten" spinning.
Every setup step is wrapped in a 4-second guard, and after 6 seconds the
loading screen offers Retry and "Meld dit probleem".


## Releases

When the user says **"maak een release"**, first ask with the OpenChamber
question tool whether it is a prerelease/beta or a regular release. Do not
guess from the version number. Write short, friendly release notes for players,
not a commit dump or internal changelog. Release automation is triggered only by
publishing a GitHub Release.

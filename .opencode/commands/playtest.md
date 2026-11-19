---
description: Play every WhoTook mode with bots and verify the UI on four viewports
---

Run the full WhoTook multiplayer playtest and report what you find.

1. Prefer the registered MCP tools when they are available:
   - `run_dart_multiplayer_sim` with `mode: all`, `playerCount: 5`.
   - `run_visual_bot_match` with `mode: all`, `playerCount: 4` and the default
     viewports `375x667`, `393x852`, `412x915`, `768x1024`.
   If those tools are not exposed, run the one-line script instead:
   `./tool/playtest/run_full_playtest.sh`

2. The script runs the Dart 4–6 peer simulation and then four isolated
   Playwright browser contexts through real matches of Classic, Make It Meme,
   Time Traveler and Mixed Party. It writes screenshots and `report.json` under
   `.private_prototypes/auto_playtest/`.

3. Inspect every screenshot with the image reader, not only the JSON:
   - `01_lobby.png`, `02_vault.png`
   - `03_classic_round.png`, `04_classic_reveal.png`
   - `05_meme_create.png`, `06_meme_vote.png`, `10_meme_reveal.png`
   - `07_time_traveler_zoom.png`, `11_time_traveler_round.png`,
     `12_time_traveler_reveal.png`
   - `08_podium_top3_memes.png`, `08_top_meme_2.png`, `08_top_meme_3.png`
   - `09_meme_empty_reveal.png`
   Check the big photo/canvas, full-width 48–60 px primary buttons, no clipped
   date, the three Top 3 meme cards with avatar + votes + Save meme, the
   "Onraadbare foto / Unguessable Photo" award with an exact wrong-guess count,
   and the zero-meme Next Round recovery.

4. Delegate a second opinion in parallel when subagents are available:
   spawn a `general` subagent to audit `report.json` and the screenshots for
   overflow, black images, missing rewards or a frozen phase. Ask it for a short
   defect list with screenshot names.

5. If anything fails, fix the code and rerun the same command. Do not weaken an
   assertion to make the playtest pass. Finish with: modes played, viewport
   coverage, screenshot audit result, and the exact commands that were run.

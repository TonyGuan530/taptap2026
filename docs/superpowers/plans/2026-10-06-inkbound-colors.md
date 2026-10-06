# Inkbound V10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development for scoped implementation and fresh review. User explicitly authorized evaluation followed by development; continue without repeat approval.

**Goal:** Deliver a tested black-ink vertical sketching chapter and a short yellow-ink blade chapter, with playable Web build and recording.

**Architecture:** New `game/v10` modules reuse V9 character/inkling visuals, lowpoly helpers and audio. Pure sketch analysis feeds an additive multi-stroke pad and shared 3D placement/ladder logic. No changes to V8/V9. QA snapshots are read-only and available only with `?qa=1`.

**Tech Stack:** Godot 4.7.2, GDScript, Node, isolated headless Edge, GitHub Pages.

**Spec:** docs/superpowers/specs/2026-10-06-inkbound-colors-design.md

## Global Constraints

- 3D world + 2D drawing/UI; only headless Godot and headless browser.
- Existing isolated f900 worktree on codex/inkbound-1930-sprint; preserve unrelated dirty/untracked work.
- New V10 files only; no shared project configuration changes outside temporary export with finally restore.
- No AI model/recognition dependencies. Real strokes retained; no fixed-shape replacement.
- Black structures and yellow blades; red/blue future scope. One property per creation.
- World completion uses actual player location, not prescribed recipes.
- Release through fresh current-main publication checkout, only explicit manifest paths; prior push/Pages authorization persists.

## Review Focus

- New strokes must not connect to older strokes across pen-up.
- Short/invalid ladders preserve drawing and never teleport onto target.
- Top exit has support and clear space; ramps have actual collision.
- Editor panel consumes mouse events, avoiding accidental world use.
- Ink recovery/removal cannot delete a support while the player is climbing it without safe release.

### Task 1: Black chapter and geometry

Files: game/v10/sketch_rules.gd, sketch_pad.gd, ink_world.gd, ink_world.tscn, structures.gd; tests/test_ink_v10_geometry.gd and test_ink_v10_smoke.gd.

- [ ] Write headless tests first; run expected failure for absent V10 helper/scene.
- [ ] Implement analyze(strokes:Array, kind:String, property:String="None") -> Dictionary with ok/reason, local segments/polygon, real dimensions/cost. Inputs bounded to 24 strokes × 256 points.
- [ ] Add multi-stroke Control with stroke_changed, clear_drawing(), undo_stroke(), get_strokes(); no pen-up connectors.
- [ ] Build independent scene with black ink HUD/intro, three real height goals, geometry placement/preview, climb/ramps, pickup/refund/fountain.
- [ ] Publish read-only __v10_ink_qa: version, player, ui buttons/draw_rect/message/intro/notebook, drawing strokes/vertices, active_tool, ink, words, structures, landmarks (world + ground_screen), goals, won, yellow_unlocked.
- [ ] Native import/scene start and headless contracts pass; review actual source and black-route browser input.

### Task 2: Yellow behavior and final flow

Files: game/v10/blade.gd, ink_world.gd; tests/test_ink_v10_smoke.gd; tools/verify-inkbound-v10-web.mjs.

- [ ] Write behavior tests/checks for locked yellow, unlock after actual geometry progression, retained drawing geometry and shorter reach.
- [ ] Add yellow hand-held stroke mesh, attack sweep, actual vine/enemy contact, property indicators and black bypass.
- [ ] Character intro/short story texts/ending show actual route and completion.
- [ ] All black/weapon and black/bypass input routes pass with no console errors; regression V9 entry.

### Task 3: Delivery and review

Files: tools/export-inkbound-v10.ps1, public/inkbound-v10.html, public/inkbound-v10-art/*, builds/demo-06-inkbound-v10/*, docs/inkbound-v10-validation.md.

- [ ] Headless import/native start/export with required artifacts and clean error logs, restore original shared config.
- [ ] Record actual game input/audio, encode MP4 and save real screenshots; label concepts separately.
- [ ] Fresh whole-change review and necessary fixes.
- [ ] Prepare explicit dependency/source/build manifest against current remote main; commit/push only task paths, preserve V8/V9.
- [ ] Verify workflow, deployed page/media and actual remote game route. Update Miro and delivery evidence.

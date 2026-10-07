# Demo08 Origami Workbench Implementation Plan

> Execute inline with superpowers:executing-plans, then one independent final reviewer. User already instructed direct edits and latest upload; no renewed approval gate.

**Goal:** A stable modeling-style folding workbench with editable crease history and five playable challenges.
**Architecture:** New PaperModel owns transactions/replay, new OrigamiEditor owns interaction and presentation; existing geometry and flight remain dimensional boundaries.
**Tech Stack:** Godot 4.7.2 GDScript, compatibility Web export, headless Edge.
**Spec:** docs/superpowers/specs/2026-10-07-demo08-origami-workbench-design.md

## Global Constraints
- Five challenges exactly; no Godot GUI; only demo08 metadata changes.
- Pick face before hinge; two points same face; explicit commit/cancel.
- Original material coordinates define feature replay; reject invalid topology atomically.
- Publish tested v29 and verify actual online UI and PCK.

## Review Focus
- Editing earlier hinge after later cuts preserves connections.
- Cancelling previews and undo/redo restore complete states.
- Overlapping layers select actual visible faces, snapping stays within face.
- Rotation/zoom/pan cannot mutate geometry or leave drag active.
- Leaving editor cannot launch unconfirmed geometry or leak inputs.

### Task 1: Replayable crease model
- [x] Add failing game/tests/test_demo08_workbench_model.gd assertions: edit earlier crease after two folds; cancel; undo/redo; NaN/degenerate rejection; same area/edges.
- [x] Run headless test and observe missing model API.
- [x] Create game/demo08_3d/paper_model.gd: begin_crease(face,a,b), preview_angle(angle), commit(), cancel(), select_feature(index), undo(), redo(), reset(ratio), load_dart(), world_to_material(face,point), material_to_world(face,point). Transactions atomic, max8features.
- [x] Run model test and physical regressions.

### Task 2: Independent workbench UI and integration
- [x] Add failing scene test for origami_editor: default select, new crease, snap, angle preview, gizmo, cancel, history reselection, orbit, final flight.
- [x] Create origami_editor.gd with large viewport, face colors, edge/hinge overlays, explicit modes, feature list, angle slider/value, presets, undo/redo, view controls.
- [x] Integrate with demo08_3d.gd; disable old fold UI/input, preserve throwing/menu/five-level flow.
- [x] Run actual headless UI input checks and browser mouse checks; inspect screenshots.

### Task 3: Delivery
- [x] Rebuild font subset, v29 export with exit0+artifacts, independent review and fixes.
- [x] Update only demo08 slots/archive/feedback, archive own v28 for size, keep others.
- [x] Commit/push, Pages success, online workbench actions and all five challenges, PCKhash.
- [x] Save evidence/report, sync only owned files to primary, direct play URL.

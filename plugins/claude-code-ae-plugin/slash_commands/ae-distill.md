---
name: ae-distill
description: Dispatch an AE 3.0 distillation task as a subagent. Usage — /ae-distill <pack> <concept>
---

You will run an AE distillation: turn a structural artifact (`<pack>` argument) into a canonical pack at `<concept>` (argument).

Steps:
1. Run `ae artifact list` to confirm `<pack>` exists.
2. Build a `DistillationTask` from the artifact (see ae-distill-skill for the wire format).
3. Read the artifact's `index.md`, `meta.yaml`, and source files referenced in `meta.source.files`.
4. Produce a `DistillationOutput` matching `ae.canonical.draft.v1` and return it to the caller for merge into `canonical/<concept>/`.

The follow-up `ae canonical distill --pack <pack> --concept <concept>` command (Phase 4 / Phase 5 follow-up) will wire this dispatch automatically. For now, this slash command guides you through the manual steps and uses `ae canonical init --concept <concept> --title <Title>` + `ae canonical merge` (also a follow-up) to land the result.

Refer to the `ae-distill-skill` for the exact JSON shape Claude must return.

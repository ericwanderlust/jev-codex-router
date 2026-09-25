# Changelog

## 0.1.1 — 2026-09-25

- Detect a provably empty upstream `response.completed` before sending any bytes to Codex. A native route makes at most one technical recovery attempt with GPT-6 Astra at medium effort, then returns an explicit `empty_completion` error if still empty.
- Keep visible text, reasoning, tools, and quota fallback routes outside this replay path. Private decision logs record the attempt result and recovery gate.
- The original large-context failure was not replayed end to end; this release addresses the observed empty terminal shape and its bounded recovery.

## 0.1.0 — 2026-09-24

- Publish the local Jev routing stack as a Codex plugin and GitHub marketplace source.
- Target Codex GPT-6 Luna, Sol, and Astra; show the selected model ID and reasoning effort on ordinary text replies by default.
- Add a one-command bootstrap, protected local credential setup, diagnostics, smoke verification, update, and rollback guidance.
- Keep the full Codex request and cache controls intact when routing; cache hits and savings are not guaranteed.
- Require each user to provide their own Jev credential and authenticated Codex session. Plugin installation alone does not deploy or authorize local services.

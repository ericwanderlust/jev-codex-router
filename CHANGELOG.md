# Changelog

## 0.1.3 — 2026-09-26

- 修复原生工具输出（包括恢复后的 `tool_search_call`）被外层误判为空回复、重复请求后返回 502 的问题。
- 保留未知类型输出交给客户端校验，避免因无法识别而重放潜在工具操作；真正的空消息和纯推理响应仍按空回复处理。
- 225 项相关检查通过；新增回归在旧实现上 5 项失败、修复后全部通过。本机已重启加载，原始失败任务的恢复尚未验收。
- 专为 Codex GPT-6 Luna / Sol / Astra 设计。独立 OS 用户或虚拟机的全新安装验收仍未完成。

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

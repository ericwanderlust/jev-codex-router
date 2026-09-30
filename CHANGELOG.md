# Changelog

## 0.2.1 — 2026-09-30

- Sol 档升级到 GPT-6.1 Sol，保持 Jev 独立选择模型和 low/medium/high/xhigh/max effort、Luna/Astra 分工及必要 Astra 下限。
- v17 按当前官方能力定位校准任务条件：Luna 接聚焦低风险工作，GPT-6.1 Sol 接常规复杂编码/多步工作，Astra 接最难问题、核实输入/权限后仍失败的实质修复及必要评审。模型强弱不锁定 effort，缺信息/权限及传输失败不等同能力不足；不设模型占比。
- 支持新版 macOS Codex/ChatGPT 应用内置 CLI 路径，避免 launchd 无客户端 PATH 时无法刷新目录；保留显式 CODEX_BIN 与旧路径兼容。
- 终止回执只增加固定错误类别及来源，区分上游终止与本地 EOF/空输出合成失败；不记录错误正文，不扩大已经输出后的重试。
- 保留旧 GPT-6 Sol 的历史统计和费率；同步插件清单版本。目录刷新后现有 Codex 仍需完全退出重开。独立 OS 用户/VM 新安装及缓存收益尚未证明。

## 0.2.0 — 2026-09-29

- 新增 `bin/jev-codex-router report --stats --policy current`，同表显示各模型最终路由次数/占比、原生尝试的缓存命中率、输入 token 复用率和未知用量；支持 `--json`。缓存尝试包含重试，未知用量不计入命中率。
- 在兼容的 GPT-6 完整历史续轮中原位回放既有 `configuration_update`，保留请求级 effort；完成压缩后开启新序列，工具轮需要改变 effort 时仍按请求级设置处理。
- 仅在当前请求前缀兼容时把实测缓存读取提供给 Jev，并在能力足够、总成本接近时更倾向热缓存。真实缓存收益尚未证明，独立新用户安装尚未验收；不承诺命中或省费。

## 0.1.5 — 2026-09-29

- 修复自动记录的 Codex 原生额度耗尽状态在额度提前恢复后仍阻挡请求的问题；自动状态最多每 60 秒重探测一次，原生调用成功后清除旧状态。
- 手动强制回退保持原行为。本机同一 Auto (Jev) 请求已恢复 200；独立用户或虚拟机的全新安装验收仍未完成。

## 0.1.4 — 2026-09-27

- v14 路由允许 Luna 承担目标清楚、风险低、沿用已有模式的跨文件机械修改和简单测试；文件数本身不再要求 Sol。保留 Astra 风险下限、独立 effort 与原有路由复用规则，不承诺模型占比或任务质量收益。

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

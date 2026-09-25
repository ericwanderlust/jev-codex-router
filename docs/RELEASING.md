# Maintenance and release checklist

This is the Jev monorepo release contract. The embedded router's version,
changelog and upstream release artifacts are not releases of this project.

## Before publishing

- Identify the exact source commit and scoped fixes; link their issues.
- Require all applicable checks in [SUPPORT.md](SUPPORT.md) to complete
  successfully on that commit. Record skips and investigate failures rather
  than lowering assertions or silently disabling a platform.
- Review dependency/lockfile changes, licenses and audit output.
- Review context preservation, retry boundaries, privacy, and migration impact
  for any affected component.
- On macOS, separately qualify the root installer and update path using an
  isolated test profile. Record paths and rollback behavior without credentials.
- If live routing changed, perform the explicitly authorized live smoke check.
  Record policy and terminal status without prompts or credentials. Unit tests
  alone are not proof of deployed runtime health.
- Write release notes distinguishing code changes, compatibility, known limits,
  and measured results. Do not claim quota savings from a fixed-token simulation.
- Verify the remote commit equals the tested source. If publishing archives,
  build from that source and verify their contents and checksums. Claim signatures
  or provenance only when actually generated and verified.

## After publishing

- Verify the published tag/artifact resolves to the intended source.
- Link the tested commit and CI run when closing issues.
- For a deployment, read back running policy/health separately from Git status.
- Roll back with a reviewed revert or known source version, preserving user
  state. Never rewrite shared history or delete credentials as a rollback.

## Repository controls

Private vulnerability reporting belongs to this repository, not the upstream
fork. Recheck its availability before changing the reporting documentation.

Branch protections and rulesets are repository settings, not implied by this
document. Agree stable check names and merge policy before enforcing them;
read back the actual GitHub settings before claiming protection. Do not make a
new or failing platform check a required merge gate without qualification.
# 安装验收隔离边界

临时 `HOME`、`CODEX_HOME`、state 目录、PATH 中的假 `launchctl`，以及
`JEV_ROUTER_LABEL` **均不隔离真实 launchd 用户域**。内嵌 router 使用
`/bin/launchctl` 和固定 label；Jev label 只控制 sidecar。禁止在日常工作
账号上运行完整安装 fixture。完整安装/卸载验收必须使用独立 OS 用户或 VM。

本机只运行 `--prepare-only`、纯渲染和明确跳过服务管理器的单元测试。
不要将 stub 或 skip 的结果报告为真实服务安装成功。检查服务必须核对
已加载 job 的 plist、源码路径、CODEX_HOME/state 和监听进程归属；仅
`/health` 返回 200 不能证明运行的是目标实例。

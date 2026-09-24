---
name: jev-codex-router
description: Use when the user asks to install, update, verify, explain, or uninstall Auto (Jev) for Codex.
---

# Auto (Jev) for Codex

本插件专为 Codex 的 GPT-6 系列设计：GPT-6 Luna、GPT-6 Sol、GPT-6 Astra。路由使用用户自己的 Codex 登录会话和 Jev 凭据；不代表可用于任意模型客户端或任意 OpenAI API key。

## 安装与验收

Codex 插件提供安装和排障指南。安装插件本身不会部署本机路由服务、修改 Codex provider 或启动 macOS 服务。

用户明确要求安装或更新时，说明完整安装会配置本机 provider，并需要授权本机读取已登录的 ChatGPT 会话。安装脚本会单独询问是否发起一次真实 Jev 路由验收；这会使用 Jev 与 ChatGPT 账户用量。拒绝验收不影响安装，但此时不能声称实际路由已验证。只有用户同意共享后，本机路由才会读取 Codex 自己的 `auth.json`；该 token 不会发送给 Jev。需要在 Terminal 操作时，给出完整命令，不要把未执行的步骤说成已完成。

支持 macOS、Codex CLI、Node.js 22.19+、Python 3.11+ 和用户自己的 Jev API key。绝不索取或输出 API key、ChatGPT token、caller secret 或 `auth.json` 内容。只询问本机 key 文件路径；建议文件权限为 `0600`。不要将凭据写进命令、URL、日志、仓库或聊天。

在 Terminal 中准备一个只含原始 Jev key 的本机受保护文件，然后把 bootstrap 下载到文件并运行。将 `JEV_API_KEY_FILE` 设为该文件路径；也可使用受保护的 `JEV_ENV_FILE`。默认还会检查 `~/.hermes/.env` 和 `~/.jev.env`。

```sh
curl -fsSL -o /tmp/jev-codex-router-bootstrap.sh https://raw.githubusercontent.com/ericwanderlust/jev-codex-router/main/scripts/bootstrap.sh
JEV_API_KEY_FILE="$HOME/.config/jev/api-key" bash /tmp/jev-codex-router-bootstrap.sh
```

完成验收必须同时满足：`bin/jev-codex-router doctor` 显示本机安装健康；`bin/jev-codex-router smoke` 的真实回执包含 `decision_source: jev`、相符的 `model` / `response_model`、effort、`visible_model_effort: confirmed` 和成功完成状态；完全退出并重开 Codex 后，模型选择器中出现 `Auto (Jev)`。成功克隆、目录项、模型菜单或 HTTP health 单独都不算通过。

## 模型与推理强度

- Jev 为每次符合条件的调用独立选择足够的模型和推理强度。原生梯队是 GPT-6 Luna、GPT-6 Sol、GPT-6 Astra；必要的架构及独立风险/最终评审保留 Astra 下限。
- 使用 `Auto (Jev)` 时，将 Codex 菜单中的 effort 保持默认即可。请求可能带有菜单值，但实际路由 effort 由 Jev 决定。符合条件的新用户轮次通过 `configuration_update` 应用；工具续接、压缩、自动截断和不兼容请求形状使用请求级 effort。菜单值不控制最终路由，无需反复调整。
- 普通文本回复默认以完整实际模型 ID 和强度开头，例如 `🧠 gpt-6-sol · reasoning: high`。思考摘要也带路由标签，但 Codex 界面可能折叠摘要，不要只依赖它。结构化 JSON 回复不会加前缀；此时运行 `bin/jev-codex-router smoke` 查看 `decision_source`、相符的 `model` / `response_model`、`effort`、`effort_transport`、`visible_model_effort: confirmed` 和成功状态。若使用 `configuration_update`，API 响应里的 `reasoning.effort` 仍是请求级值；实际更新后的强度以本机路由回执为准，详见 [OpenAI 官方说明](https://developers.openai.com/api/docs/guides/reasoning#change-reasoning-mid-conversation)。`/health` 只检查服务存活，不证明 Jev 鉴权成功；`doctor` 检查安装，`smoke` 必须证明一次真实 Jev 决策。路由记录仅供本机诊断，不要公开粘贴。
- Jev key 缺失或无效、Jev 报错或没有可用路由都属于需要排查的运行故障，会触发可见的技术 fallback（通常为 GPT-6 Astra、medium）。不能把 fallback 说成成功的 Auto 决策。

## 上下文与缓存

每个选中模型都会收到完整 Codex 请求；模型切换不依赖缓存保存对话内容，原始缓存控制项会继续传递。缓存命中随模型和请求形状变化，切换模型可能从冷前缀开始。缓存信号只辅助路由，不保证命中或省费。

## 更新、诊断与卸载

在 bootstrap 管理的源码目录运行 `bin/jev-codex-router update`、`doctor` 和 `smoke`。运行 `uninstall` 会停止 Jev 服务、隐藏 Auto 模型并禁用 Jev provider，同时保留路由状态、日志和 key 文件。只有用户明确要求撤销共享会话授权时，才使用 `uninstall --revoke-session`。

若模型未出现，运行 `doctor`、完全重启 Codex 后再检查选择器。若 `smoke` 显示技术 fallback，只在本机核对配置的 key 文件路径和文件内容，不要打印内容，然后重新运行 `smoke`。如需隐藏普通文本回复里的模型/强度前缀，创建 `~/.codex/codex-router/jev-router.hide-signature`；删除该文件可恢复显示。

## English quick install

This plugin is designed specifically for Codex GPT-6 Luna, Sol, and Astra. Install the plugin, save your own Jev key in a local file with mode `0600`, then run this in Terminal:

```sh
codex plugin marketplace add ericwanderlust/jev-codex-router
codex plugin add jev-codex-router@jev-codex-router
curl -fsSL -o /tmp/jev-codex-router-bootstrap.sh https://raw.githubusercontent.com/ericwanderlust/jev-codex-router/main/scripts/bootstrap.sh
JEV_API_KEY_FILE="$HOME/.config/jev/api-key" bash /tmp/jev-codex-router-bootstrap.sh
```

Review the ChatGPT session-sharing prompt and the separate prompt for one live smoke request, which uses your Jev and ChatGPT usage. After `smoke` confirms `decision_source: jev`, fully restart Codex and select **Auto (Jev)**. Ordinary assistant text displays the actual model ID and reasoning effort by default.

# AGENTS.md — autonomous install & operations playbook

This file lets a coding agent (Codex, Claude Code, Cursor, …) install, verify
and operate the **Jev Codex Router** on a user's machine without asking for
context it can discover itself. Follow it top to bottom. Do not skip the
verification step after each stage — they are what makes autonomy safe here.

## What you are installing

A self-contained monorepo with an embedded Codex Router fork (`router/`) and a
local Jev decision server (`server/`). Together they add **"Auto (Jev)"**
(`jev/auto`) to the Codex picker. Every call is classified by
[Jev](https://docs.typesafe.ai) (TypeSafe System One) and served by the
cheapest sufficient model at an adapted thinking depth. Local hops stay on
loopback; Jev calls go to TypeSafe. Authenticated model requests are fail-open
on Jev classification errors; there is a kill switch.

## Hard rules (never violate)

1. **Never print, log, commit, or transmit secrets** — the TypeSafe API key,
   the router `caller-secret`, or ChatGPT tokens. Reference them by file path.
2. **Edit the source, never the artifact.** `router/src/` is the embedded
   router's source and is meant to be edited: a behaviour bug is fixed there,
   committed in this repository, with the tests that cover it.
   What is off limits is the *generated and managed* output — `litellm.yaml`
   under the router's state directory is rendered from `src/litellm-config.mjs`
   whenever the catalog changes, and the `codex-router-managed` blocks of
   `~/.codex/config.toml` are written by the CLI, so a hand edit there is
   overwritten rather than applied. Change the generator, or drive the CLI and
   the documented state files (`user-models.json`, `generic-providers.json`),
   and leave the artifacts to be regenerated.
3. The server binds `127.0.0.1` only. Never expose it on another interface.
4. If `launchctl` is restricted in your environment (supervised agents often),
   skip the service install — use the watchdog pattern and let the user run
   `server/install-service.sh` from their own Terminal instead. Never fight
   the restriction.
5. Treat prompt excerpts in local logs (`jev-router-live.jsonl`,
   `shadow-log.jsonl`) as private user data: read locally, never republish.

## Prerequisites (check, and report what you found)

- **macOS** with **Codex**. No separate Codex Router checkout is required.
- **Node.js ≥ 22.19** — `node -v`.
- **Python ≥ 3.11** — `python3 -V`.
- A **Jev API key** for Jev. The server checks `JEV_ENV_FILE`, then the path in
  `JEV_API_KEY_FILE`, then `~/.hermes/.env`, `~/.jev.env`, and process
  environment variables. If none exists, ask only for the path to the user's
  protected local key file; never ask for the key value in chat.

## Install, step by step

### 1 — Verify the embedded source

```bash
cd <repo>
test -x router/bin/codex-router
node -p 'require("./router/package.json").name'
# expect: codex-model-router
```

### 2 — Install the complete stack

```bash
./install.sh
```

This is the supported full installation path. It uses `router/` directly,
preserves existing provider selection, idempotently configures the `jev`
provider and `jev/auto` model, provisions the protected local credential,
asks before enabling native ChatGPT sharing, installs both launchd services,
and publishes the picker. It separately asks before sending one live smoke
request that may use Jev and ChatGPT quota.
General credential discovery stays off; after consent, the sharing action reads
only Codex's own `auth.json`. The public bootstrap clones this monorepo into
`~/.local/share/jev-codex-router-source`; it does not clone a second router.

If `launchctl` is restricted, run `./install.sh --prepare-only`, perform
non-service diagnostics, then ask the user to run `./install.sh` in their own
Terminal. Do not redirect the installation to a second checkout.

### 3 — Restart Codex

Fully quit and reopen the Codex app so it reloads the picker catalog, then the
user can select **Auto (Jev)**.

## End-to-end verification (must pass before declaring success)

Run this only with the user's consent to a live Jev/model request; the installer
asks before running it.

```bash
python3 server/smoke.py
```

Expect HTTP 200 and status `completed`, with a selected model, effort, and
`decision_source=jev`. The script refuses a stale running policy or a technical
fallback and never prints credentials. Then:

```bash
tail -1 ~/.codex/codex-router/jev-router-live.jsonl
# expect one JSON line: gate=apply, tier, conf, depth, model, effort, speed,
# jev_ms, total_ms, status=200, out=sse
```

## Operations

- **Decision log**: `~/.codex/codex-router/jev-router-live.jsonl` — one line per
  routed turn.
- **Ask surface**: `POST /ask` (also `/v1/ask`) — typed pass-through to System
  One for local callers with their own question set (state ≤ 120k chars, ≤ 40
  questions, caller state never logged). `502 jev: HTTP Error 402` means the
  TypeSafe account is out of credits; `503` means no key was found.
- **Kill switch** (instant, no restart): `touch ~/.codex/codex-router/jev-router.off`
  → the server relays to astra without calling Jev. Remove the file to re-enable.
- **Codex-dry fallback** (only while native usage is exhausted):
  `touch ~/.codex/codex-router/jev-router.codex-dry` → calls go to at most two
  compatible routes discovered from this machine's configured models. OpenAI is
  always attempted first while its allowance works. A local model additionally
  requires a live runtime and a persisted successful Codex agent check
  (`router/bin/control failover qualify <local-model-slug>`).
  `JEV_FALLBACK_STANDARD` / `JEV_FALLBACK_FRONTIER` remain optional static
  overrides; retries never repeat an identical target.
  Remove the file to return to the
  luna/sol/astra native model ladder. An automatic flip (429 / usage-limit response) also
  retries the failed call on the discovered fallback, then lasts until the instant the edge
  announced for the window reset (30 minutes when the refusal announces none,
  one week at most) — `cat ~/.codex/codex-router/jev-router.codex-dry.json`
  reads the reason and `until_iso` — and is cleared by the next successful
  native call. Log fields to watch: `dry`, `native`, `retried`.
- **Thread display**: ordinary assistant text replies begin with the actual
  model ID and effort. Reasoning summaries also carry an exact route tag when
  Codex displays them; do not rely on that UI summary alone. Structured JSON
  output is never prefixed. `touch ~/.codex/codex-router/jev-router.hide-signature`
  hides the reply header; remove the sentinel to restore it.
- **Effort selector**: leave the Codex picker at its default for `Auto (Jev)`.
  Jev controls the actual effort through `configuration_update` on eligible new
  user turns or request-level `reasoning.effort` on other request shapes.
  `doctor` checks installation/service state; `smoke` proves a live Jev decision.
  A healthy `/health` response alone does not prove Jev authentication.
- **Shadow mode**: `touch ~/.codex/codex-router/jev-router.shadow` → decisions
  are logged (`would` field) while every call is still served by astra.
- **Debug capture** (bounded): `touch ~/.codex/codex-router/jev-router.debug`
  → request shapes in `jev-router-debug.jsonl` and transport counters in
  `jev-router-debug-stream.log`. Remove the file to stop.
  Logs are 0600, rotate at 8 MiB and retain one backup. No new prompt excerpts
  or raw model streams are recorded; old captures are protected, not deleted.
- **Tune the policy**: the shared contract in `server/routing_policy.py`. Keep decisions
  joint and evidence-based; restart the server after edits. Cache affinity
  (`last_model`, measured state/read percentage/age and context size) is a cost
  signal inside Jev's typed model choice, never a code-side model override.
- **Backtest**: `python3 poc/backtest_savings.py --days 7` (see BACKTEST.md).
- **Router CLI**: `bin/jev-codex-router router <command>` delegates to the
  embedded runtime.
- **Update**: `bin/jev-codex-router update` updates this monorepo and reruns the
  unified installer; it never pulls a separate router checkout.
- **Disable**: `bin/jev-codex-router router providers generic disable jev`
  (keeps state); full rollback: also
  `bin/jev-codex-router router chatgpt-session disable` and stop the
  service (`launchctl bootout gui/$(id -u)/com.thibaultsaintjean.jev-router`).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `{"detail":"Unauthorized"}` from the caller edge | native sharing off | `bin/jev-codex-router router chatgpt-session enable` |
| `{"detail":"Stream must be set to true"}` | the caller edge streams only | send `"stream": true`; the bundled server forces it |
| HTTP 502 `provider_api_proxy_error` on jev-auto | server-side error | check the `status`/`out` fields in `jev-router-live.jsonl`, and the server's stderr log |
| HTTP 502 `empty_completion` | upstream completed with no assistant output | check `attempts[].completion` and `gate` in the private decision log; a native route retries once on Astra medium before returning this error |
| "Auto (Jev)" absent from the picker | not published/visible, or Codex not restarted | `refresh-catalog`, `control picker set jev/auto show`, full Codex restart |
| Native 429 / "usage limit" while routing | ChatGPT usage window exhausted | expected: the Codex-dry fallback takes over (`jev-router.codex-dry.json`); delete the manual file to re-probe sooner |
| Jev calls fail with `402 Payment Required` (`gate=codex_dry(fallback)`, `tier` null in the log) | the TypeSafe account is out of credits | expected: the router keeps serving through a configured fallback; add credits at console.typesafe.ai to restore classification |
| `Unknown API gateway model: jev-auto` | catalog not republished | `bin/jev-codex-router router refresh-catalog` |
| Jev returns HTTP 422 | request body missing `"model"` | always send `"model": "jev-latest"` to the System One API |
| Native calls fail after a few days | shared session expired | re-run `chatgpt-session enable` |
| `launchctl` rejected inside a supervised agent | environment restriction | run `./install.sh --prepare-only`; let the user run `./install.sh` in Terminal |

## Latency & cost notes

- The current policy is `split-v12-gpt6-luna-sol-astra`: one System One request asks
  four independent Choice questions with explicit criteria — mandatory Astra
  policy, capability tier, reasoning effort and a bounded route lease. New user
  turns, errors, compactions and changed tool chains are always re-evaluated;
  clean continuations may reuse the exact route for one tool chain or user turn.
  Pre-project software/project
  architecture, independent final code review and risk-focused review force Astra while
  preserving Jev's independently selected effort. The model question also gets
  measured cache evidence for the private prompt-cache scope: `hot` requires an
  observed cache read, `warming` means successful service with zero read, and
  missing usage remains `unknown`. A sufficient hot model can beat a cold switch
  without blocking a materially required tier.
  Provider retries inside one
  call keep that decision.
  Routine in-progress quality checkpoints, score comparisons and fixes to established
  findings use normal routing. Good scores never waive a required final/risk review.
  The router does not run `jev-review` or create an independent reviewer; quality
  scoring and blind reviewer context must be handled by the calling workflow.
  The selected model always receives the complete canonical request and the
  original cache controls; Jev receives only the bounded decision dossier. For
  eligible GPT-6 user-turn calls, adaptive effort uses a `configuration_update` before the
  latest user message so the request-level prefix stays stable. A
  context-dependent short ask also gets one bounded active-task summary. Cache
  hits are a cost optimization, never the carrier of conversation continuity:
  reuse is measured per `(hashed session, model)`, while every model swap still
  gets the full replay. All tiers use adaptive effort and standard speed; never
  force Luna to max or enable Fast mode.
- Apart from the explicit mandatory-Astra policy, no scenario override, target
  model share, or confidence threshold may replace a valid Jev choice. Confidence
  is diagnostic. The native ladder is GPT-6 Luna → GPT-6 Sol → GPT-6 Astra.
  Sol covers bounded implementation and complex work; mandatory Astra categories still win.
  Judge remaining work, not completed phases: administrative follow-through is
  not review. Luna needs explicit mechanical work; implied intent and autonomous
  investigation belong to Sol. Optimize total task cost including clarification
  and correction turns, without scenario regexes or automatic opening floors.
  Every short ask receives one bounded preceding task and assistant proposal.
  The latest tool batch contributes counts and at most three excerpts, errors
  first. Replay and live routing share the same dossier builder.
- Provider/schema failures remain distinct: Astra at medium, logged as a
  technical fallback. Kill switch and exhausted-native-quota handling still apply.
- Jev usage and upstream per-attempt tokens are logged when available. Run
  `python3 server/report_routing.py --days 7 --policy current` for native-only
  credit estimates, lease savings and observed prompt-cache reads/writes by
  model/session; unknown usage remains unknown and reasoning tokens are not
  counted twice.
- `BACKTEST.md` documents an optional local simulation over private session
  usage. Replay prompts and results must not be committed or published. The
  simulation does not measure current quota savings or result quality.

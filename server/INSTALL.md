# Operations runbook

`jev_server.py` listens on `127.0.0.1:4319` and receives Responses requests for
the `jev/auto` model from the router fork embedded at `../router`. For each turn it asks Jev for a route
(tier + thinking depth), applies the routing policy, and relays the request to
the Codex Router's local caller edge, which serves native GPT models from the
shared ChatGPT session.

## Local authentication

After registering `jev`, run from the repository root:

```sh
node server/configure-auth.mjs
```

This uses the embedded router's credential transaction, retains an existing credential,
and prints metadata only. The Jev server reads the protected `jev.key` in the
router's `generic-provider-credentials` directory. All POSTs require a Bearer
header; the parent adds it automatically. Direct `/ask` clients must add it.
No OpenAI Platform API key is needed for this local ChatGPT-session relay.
The Jev key loader checks `JEV_ENV_FILE` first when configured, then
`JEV_API_KEY_FILE` (a protected file containing the raw key), followed by
`~/.hermes/.env`, `~/.jev.env`, and finally `JEV_API_KEY` or `TYPESAFE_API_KEY`
from the process environment. The launchd service stores only configured file
paths, never key values; a process-only key is not retained by launchd and the
full installer rejects it. Protect any key or env file with owner-only access.

The full installer asks before enabling native ChatGPT session sharing. On
consent, the embedded router reads only Codex's own `auth.json` and uses that
session for the native model request; the Jev decision request receives no
ChatGPT bearer token. After service setup, a separate prompt controls whether
one live Jev/model smoke request is sent; it may use both accounts' quota. If
skipped, run `bin/jev-codex-router smoke` later before treating routing as
verified.

## Lifecycle

The service installer copies the canonical checkout's runtime code to
`~/.local/share/jev-codex-router-runtime` before loading launchd. This avoids
macOS external-volume access failures; edit the checkout and rerun the installer
to deploy changes. Existing key-file paths are retained unless explicitly
overridden. The runtime directory is a deployment copy, not another checkout.

| Action | Command |
|---|---|
| Decision log | `tail -f ~/.codex/codex-router/jev-router-live.jsonl` |
| Current-policy cost/cache report | `python3 server/report_routing.py --days 7 --policy current` |
| Kill switch (no Jev → frontier) | `touch ~/.codex/codex-router/jev-router.off` / `rm` to re-enable |
| Install the launchd service | `bash server/install-service.sh` (in your own Terminal) |
| Service status | `launchctl print gui/$(id -u)/com.thibaultsaintjean.jev-router` |
| Service restart | `launchctl kickstart -k gui/$(id -u)/com.thibaultsaintjean.jev-router` |
| Watchdog (no launchd) | `server/watchdog.sh`, e.g. cron every 5 min |
| Router status | `bin/jev-codex-router router status` |
| Combined diagnosis | `bin/jev-codex-router doctor` |
| Verified live Jev decision | `bin/jev-codex-router smoke` |
| Hide or restore the model/effort label on text replies | `touch ~/.codex/codex-router/jev-router.hide-signature` / remove the sentinel to restore |
| Update the monorepo | `bin/jev-codex-router update` |
| Remove the Jev service/provider | `bin/jev-codex-router uninstall` |
| Hide the model | `router/bin/control picker set jev/auto hide` |
| Disable the provider | `bin/jev-codex-router router providers generic disable jev` |
| Revoke native sharing | `bin/jev-codex-router router chatgpt-session disable` |

## After an embedded router update

`bin/jev-codex-router update` fetches this repository's `origin/main`, updates
the complete monorepo and invokes the root installer. It never pulls the
embedded router from a second checkout. Provider and model state live outside
the source tree, so updates should not touch them. Verify anyway:

1. `bin/jev-codex-router router providers generic list` → should show `SHOW jev`.
2. `cat ~/.codex/codex-router/model-picker.json` → `jev/auto` under `visible`.
3. `curl -s http://127.0.0.1:4319/health` → `{"ok": true...}`.
4. If needed: `bin/jev-codex-router router refresh-catalog`, then restart Codex.
5. `bin/jev-codex-router smoke` → `decision_source=jev` plus the actual model,
   effort, and completed response. Health alone does not prove Jev auth.

## Troubleshooting

- **`invalid_responses_response` in router logs / “unavailable right now” in
  Codex**: the API forwarder parsed our reply as JSON instead of SSE. The server
  forces `Content-Type: text/event-stream` on streamed replies for exactly this
  reason; make sure you run the current `jev_server.py`.
- **401 / route refused by the edge**: the shared ChatGPT session expired —
  re-run `bin/jev-codex-router router chatgpt-session enable`.
- **Every turn routes to Astra**: inspect `decision_source` and `gate` in the
  local decision record. `technical_fallback`, `jev_error`, or
  `no_key_or_task` means authentication or Jev routing failed; fix it and rerun
  `smoke` instead of treating the fallback as Auto success.
- **Effort differs from the Codex selector**: expected for `Auto (Jev)`. Keep
  the selector at its default; the local record's `effort` is the applied value
  and `effort_transport` shows `configuration_update` or request-level routing.
- **Model/effort is not visible in a reply**: ordinary text replies show the
  actual model ID and effort by default. Structured JSON is not prefixed; run
  `bin/jev-codex-router smoke` and check `decision_source`, `model`, `effort`,
  `effort_transport`, and `status` instead. Codex may also collapse reasoning
  summaries, so use the reply label or smoke receipt.
- **Model missing from the picker**: re-run `refresh-catalog` and
  `picker set jev/auto show`, then fully restart Codex.

### Model visible but rejected by ChatGPT

`The 'jev/auto' model is not supported when using Codex with a ChatGPT account`
can mean the model is selected while the OpenAI provider still points directly
at OpenAI. Listing a model in a catalog, or declaring `[model_providers.jev]`,
does not associate an existing task with that provider.

1. Inspect `bin/jev-codex-router router status`: check `model_provider` and the redacted
   `openai_base_url`, not just whether the service is running.
2. Verify the main router has the enabled `jev` generic provider and the
   `jev/auto` entry in `user-models.json`. A direct Codex provider declaration
   is a separate configuration. Reload the router after restoring its routes;
   its startup regenerates the gateway configuration from source.
3. Preserve a user-owned `model_catalog_json`. With the built-in `openai`
   provider, Codex supports a user-level `openai_base_url` pointing to the
   router's authenticated loopback Responses entry. Use Codex's
   `config/value/write` API for this setting; resolve the caller capability
   locally from its protected file, never print it or put it in command
   arguments. Leave other provider definitions and model defaults intact.
4. Verify a small request through **4202 → Jev 4319 → native 4202**, then through
   an ephemeral Codex invocation reading the saved configuration. Checking
   Jev's health alone does not exercise the client transport.
5. Quit and reopen Codex on the host Mac to reload the configuration before
   retrying the existing task from desktop or mobile.

The built-in OpenAI transport override was verified with Codex
`0.155.0-alpha.9.2`; no switch to a different provider or catalog was needed.
See the [official configuration documentation](https://learn.chatgpt.com/docs/config-file/config-advanced)
for the distinction between the built-in endpoint override and custom providers.

## Design notes

- The edge emits SSE with no Content-Type; we always re-emit
  `text/event-stream; charset=utf-8` on stream relays.
- `stream: true` is forced upstream (the edge requires it); non-stream callers
  get the final response object assembled from the SSE stream.
- One compact Jev decision starts each semantic phase. Its explicit lease can
  cover a clean same-tool chain or the clean continuations of one user turn;
  changed tools, errors, compactions and new user turns are re-classified. The
  canonical request and `prompt_cache_key` remain unchanged for every selected
  model.

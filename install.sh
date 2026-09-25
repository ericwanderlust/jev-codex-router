#!/bin/sh
set -eu

# Install the complete Jev Codex Router stack from this monorepo. The embedded
# router is the only source checkout used by the service: no clone, submodule,
# or second source tree is required.
self=$0
while [ -L "$self" ]; do
  link=$(readlink "$self")
  case $link in
    /*) self=$link ;;
    *) self=$(dirname -- "$self")/$link ;;
  esac
done
repo_dir=$(CDPATH='' cd -P -- "$(dirname -- "$self")" && pwd -P)
router_dir=$repo_dir/router
router_cli=$router_dir/bin/codex-router
codex_home=${CODEX_HOME:-$HOME/.codex}
state_dir=${MODEL_ROUTER_STATE_DIR:-${CODEX_ROUTER_STATE_DIR:-${KIMI_CODEX_STATE_DIR:-$codex_home/codex-router}}}

usage() {
  cat <<'EOF'
Usage: ./install.sh [--prepare-only]

Install Jev Codex Router from the embedded router fork.

  --prepare-only  Install the embedded router's dependencies without changing
                  Codex configuration, services, credentials, or local state.
  -h, --help      Show this help.

The full install preserves configured router providers, adds the local Jev
provider and jev/auto model, provisions its protected loopback credential,
enables native ChatGPT sharing, and installs both launchd services. It asks
before reading Codex auth.json and separately asks whether to send one live
smoke request, which may use Jev and ChatGPT quota.
EOF
}

mode=install
case ${1:-} in
  "") ;;
  --prepare-only) mode=prepare ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { usage >&2; exit 2; }

[ -x "$router_cli" ] || {
  echo "Embedded router is missing at $router_cli." >&2
  exit 1
}

if [ "$mode" = prepare ]; then
  prepare_home=$(mktemp -d "${TMPDIR:-/tmp}/jev-codex-router-prepare.XXXXXX")
  cleanup_prepare_home() {
    [ -n "${prepare_home:-}" ] && [ -d "$prepare_home" ] &&
      rm -rf -- "$prepare_home"
  }
  trap cleanup_prepare_home EXIT HUP INT TERM
  CODEX_HOME=$prepare_home \
    CODEX_ROUTER_STATE_DIR=$prepare_home/codex-router \
    "$router_dir/bin/install" --prepare-only
  exit 0
fi

[ "$(uname -s)" = Darwin ] || { echo "The full install requires macOS." >&2; exit 1; }
node "$router_dir/src/service-write-guard.mjs" --live-install
command -v codex >/dev/null 2>&1 || { echo "Codex CLI not found; install Codex, then retry." >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node.js 22.19 or newer is required." >&2; exit 1; }
node -e 'const [a,b] = process.versions.node.split(".").map(Number); process.exit(a > 22 || (a === 22 && b >= 19) ? 0 : 1)' \
  || { echo "Node.js 22.19 or newer is required." >&2; exit 1; }
python=${JEV_PYTHON:-$(command -v python3 || true)}
[ -x "$python" ] || { echo "Python 3.11 or newer is required; set JEV_PYTHON to its executable path." >&2; exit 1; }
"$python" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' \
  || { echo "Python 3.11 or newer is required." >&2; exit 1; }

# Preserve a configured key-file path from this service without displaying it.
service_plist="$HOME/Library/LaunchAgents/${JEV_ROUTER_LABEL:-com.thibaultsaintjean.jev-router}.plist"
if [ -x /usr/libexec/PlistBuddy ] && [ -f "$service_plist" ]; then
  if [ -z "${JEV_API_KEY_FILE:-}" ]; then
    saved_key_file=$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:JEV_API_KEY_FILE' "$service_plist" 2>/dev/null || true)
    [ -z "$saved_key_file" ] || { JEV_API_KEY_FILE=$saved_key_file; export JEV_API_KEY_FILE; }
  fi
  if [ -z "${JEV_ENV_FILE:-}" ]; then
    saved_env_file=$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:JEV_ENV_FILE' "$service_plist" 2>/dev/null || true)
    [ -z "$saved_env_file" ] || { JEV_ENV_FILE=$saved_env_file; export JEV_ENV_FILE; }
  fi
fi

# The LaunchAgent stores file paths, not process-only API-key variables.
if ! env -u JEV_API_KEY -u TYPESAFE_API_KEY PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$repo_dir/server" \
  python3 -c 'from jev_server import load_key; raise SystemExit(0 if load_key() else 1)' \
  >/dev/null 2>&1; then
  echo "No Jev API key was found in JEV_ENV_FILE, JEV_API_KEY_FILE, ~/.hermes/.env, or ~/.jev.env." >&2
  echo "Store your own key in a protected local file, set its file-path variable, then retry." >&2
  exit 1
fi

if [ ! -r /dev/tty ]; then
  echo "Run the full install from an interactive Terminal to grant ChatGPT session sharing." >&2
  exit 1
fi
printf 'Allow the local router to read Codex auth.json and relay your signed-in ChatGPT session? The token is not sent to Jev. [y/N] '
IFS= read -r consent </dev/tty || consent=
case $consent in
  y|Y|yes|YES) ;;
  *) echo "Install cancelled before changing Codex configuration or services." >&2; exit 1 ;;
esac

if [ -f "$state_dir/enabled-providers.json" ]; then
  "$router_dir/bin/install" --take-over-managed-router
else
  "$router_dir/install.sh" --no-provider --no-discovery --no-tray
fi

if "$router_cli" providers generic show jev --json >/dev/null 2>&1; then
  "$router_cli" providers generic edit jev \
    --name "Jev Router" \
    --base-url http://127.0.0.1:4319/v1 \
    --adapter openai-responses \
    --allow-private
else
  "$router_cli" providers generic add jev \
    --name "Jev Router" \
    --base-url http://127.0.0.1:4319/v1 \
    --adapter openai-responses \
    --allow-private
fi
"$router_cli" providers generic enable jev

node "$repo_dir/server/configure-model.mjs"
node "$repo_dir/server/configure-auth.mjs"
"$router_cli" chatgpt-session enable
"$router_cli" refresh-catalog
"$router_dir/bin/control" picker set jev/auto show

JEV_PYTHON=$(command -v python3) CODEX_HOME=$codex_home CODEX_ROUTER_STATE_DIR=$state_dir \
  bash "$repo_dir/server/install-service.sh"

printf 'Run one live Jev route check now? It sends one request using your Jev and ChatGPT accounts and may use their quota. [y/N] '
IFS= read -r smoke_consent </dev/tty || smoke_consent=
case $smoke_consent in
  y|Y|yes|YES) "$python" "$repo_dir/server/smoke.py" ;;
  *) echo "Live route check skipped. Run 'bin/jev-codex-router smoke' when you want to verify a real Jev decision." ;;
esac

printf '\nJev Codex Router is installed from %s.\n' "$repo_dir"
printf 'Fully quit and reopen Codex, then select "Auto (Jev)".\n'

#!/bin/sh
set -eu

repo=$(CDPATH='' cd -P -- "$(dirname -- "$0")/.." && pwd -P)
router="$repo/router/bin/codex-router"
label=${JEV_ROUTER_LABEL:-com.thibaultsaintjean.jev-router}
plist="$HOME/Library/LaunchAgents/$label.plist"
runtime="$HOME/.local/share/jev-codex-router-runtime"
revoke_session=false

case ${1:-} in
  "") ;;
  --revoke-session) revoke_session=true ;;
  -h|--help)
    echo "Usage: bin/jev-codex-router uninstall [--revoke-session]"
    exit 0
    ;;
  *) echo "Usage: bin/jev-codex-router uninstall [--revoke-session]" >&2; exit 2 ;;
esac

node "$repo/router/src/service-write-guard.mjs" --live-install

if [ "$(uname -s)" = Darwin ]; then
  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  rm -f "$plist"
fi
rm -rf -- "$runtime"
"$router" providers generic disable jev >/dev/null 2>&1 || true
"$repo/router/bin/control" picker set jev/auto hide >/dev/null 2>&1 || true
if [ "$revoke_session" = true ]; then
  "$router" chatgpt-session disable >/dev/null
fi
echo "Jev service stopped and model hidden. Router state, logs, and key files were kept."
if [ "$revoke_session" = false ]; then
  echo "ChatGPT session sharing was left unchanged; add --revoke-session to revoke it."
fi

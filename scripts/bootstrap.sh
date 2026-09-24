#!/bin/sh
set -eu

repo_url=https://github.com/ericwanderlust/jev-codex-router.git
source_dir=${JEV_ROUTER_SOURCE_DIR:-$HOME/.local/share/jev-codex-router-source}

case ${1:-} in
  -h|--help)
    echo "Install or update Jev Codex Router from $repo_url"
    echo "Set JEV_ROUTER_SOURCE_DIR to choose the source checkout path."
    echo "Usage: bootstrap.sh [--prepare-only]"
    exit 0
    ;;
  ""|--prepare-only) ;;
  *) echo "Usage: bootstrap.sh [--prepare-only]" >&2; exit 2 ;;
esac

if [ -e "$source_dir" ]; then
  if ! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "The configured source path exists and is not a Git checkout; it was left untouched." >&2
    exit 1
  fi
  origin=$(git -C "$source_dir" remote get-url origin 2>/dev/null || true)
  case $origin in
    https://github.com/ericwanderlust/jev-codex-router|https://github.com/ericwanderlust/jev-codex-router.git) ;;
    *) echo "The source path belongs to a different remote; it was left untouched." >&2; exit 1 ;;
  esac
  if [ -n "$(git -C "$source_dir" status --porcelain)" ]; then
    echo "The source checkout has local changes; commit or move them before updating." >&2
    exit 1
  fi
  git -C "$source_dir" fetch --quiet origin main
  git -C "$source_dir" merge --ff-only --quiet origin/main
else
  mkdir -p "$(dirname -- "$source_dir")"
  git clone --quiet --depth 1 --branch main "$repo_url" "$source_dir"
fi

exec "$source_dir/install.sh" "$@"

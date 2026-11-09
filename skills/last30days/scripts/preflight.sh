#!/usr/bin/env bash
# last30days preflight: stale-clone self-check + Python 3.12+ resolution + key presence by NAME.
#
# Usage: bash scripts/preflight.sh [-h|--help]
#
# stdout on success (exit 0):
#   OK <python command>
#   KEYS_SET=<comma-separated names of optional keys set in the process env, may be empty>
# On failure stdout stays empty, stderr carries a clear message, exit is non-zero:
#   exit 2  STALE-CLONE: SKILL.md was loaded from the Claude Code marketplaces clone and a newer
#           versioned plugin cache exists. Re-read the SKILL.md path the message prints.
#   exit 1  no Python 3.12+ interpreter (and uv could not provision one), or the engine is missing.
#
# Key values are never printed or logged. Only the variable NAME appears, and only when the
# variable is set and non-empty in the process environment (config files are not read here).
#
# Why the stale-clone check exists: ~/.claude/plugins/marketplaces/last30days-skill/ is a git clone
# Claude Code restores to origin/main on session start. It can lag the versioned cache by one or
# more releases. Test runs loaded SKILL.md from marketplaces/, ran --help from the same stale path,
# did not see a flag that existed in the cache and fell back to a manual plan. Other install paths
# (~/.codex/skills/, ~/.agents/skills/, an npx skills add directory, a repo checkout) are valid
# load points and never abort this script.
set -u

case "${1:-}" in
  -h|--help)
    sed -n '2,/^set -u/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *) echo "ERROR: unknown argument '$1' (try --help)" >&2; exit 64 ;;
esac

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$SKILL_DIR/scripts/last30days.py" ]; then
  echo "ERROR: scripts/last30days.py not found under SKILL_DIR=$SKILL_DIR" >&2
  exit 1
fi

# ---- stale-clone self-check -------------------------------------------------
skill_version() {
  awk '/^version:/{gsub(/"/, "", $2); print $2; exit}' "$1" 2>/dev/null
}

case "$SKILL_DIR" in
  */.claude/plugins/marketplaces/*)
    CLAUDE_CACHE_LATEST=$(find "$HOME/.claude/plugins/cache/last30days-skill/last30days" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)
    CLAUDE_CACHE_SKILL_MD=""
    if [ -n "$CLAUDE_CACHE_LATEST" ]; then
      # Two cache layouts ship in the wild: nested ({version}/skills/last30days/SKILL.md) and flat ({version}/SKILL.md).
      if [ -f "$CLAUDE_CACHE_LATEST/skills/last30days/SKILL.md" ]; then
        CLAUDE_CACHE_SKILL_MD="$CLAUDE_CACHE_LATEST/skills/last30days/SKILL.md"
      elif [ -f "$CLAUDE_CACHE_LATEST/SKILL.md" ]; then
        CLAUDE_CACHE_SKILL_MD="$CLAUDE_CACHE_LATEST/SKILL.md"
      fi
    fi
    if [ -n "$CLAUDE_CACHE_SKILL_MD" ]; then
      HERE_VER="$(skill_version "$SKILL_DIR/SKILL.md")"
      CACHE_VER="$(skill_version "$CLAUDE_CACHE_SKILL_MD")"
      NEWEST="$(printf '%s\n%s\n' "${HERE_VER:-0}" "${CACHE_VER:-0}" | sort -V | tail -1)"
      if [ "${CACHE_VER:-0}" != "${HERE_VER:-0}" ] && [ "$NEWEST" = "${CACHE_VER:-0}" ]; then
        echo "STALE-CLONE: this SKILL.md (v${HERE_VER:-unknown}) was loaded from the marketplaces clone; a newer cache (v${CACHE_VER}) exists." >&2
        echo "Re-read $CLAUDE_CACHE_SKILL_MD before proceeding." >&2
        exit 2
      fi
    fi
    ;;
esac

# ---- Python 3.12+ resolution -------------------------------------------------
LAST30DAYS_PYTHON="${LAST30DAYS_PYTHON:-}"

try_last30days_python() {
  candidate="$1"
  [ -n "$candidate" ] || return 1
  if [ -x "$candidate" ]; then
    :
  elif command -v "$candidate" >/dev/null 2>&1; then
    :
  else
    return 1
  fi
  "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)' >/dev/null 2>&1 || return 1
  LAST30DAYS_PYTHON="$candidate"
  return 0
}

windows_path_to_unix() {
  [ -n "$1" ] || return 1
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s\n' "$1"
  fi
}

# A caller-provided LAST30DAYS_PYTHON wins when it is a valid 3.12+ interpreter.
if [ -n "$LAST30DAYS_PYTHON" ]; then
  preset="$LAST30DAYS_PYTHON"
  LAST30DAYS_PYTHON=""
  try_last30days_python "$preset" || echo "WARN: LAST30DAYS_PYTHON=$preset is not a Python 3.12+ interpreter; searching instead." >&2
fi

# Windows-style installs (Git Bash / MSYS): search the usual roots for python.exe.
if [ -z "${LAST30DAYS_PYTHON:-}" ]; then
  roots=""
  [ -n "${LOCALAPPDATA:-}" ] && roots="$roots
$(windows_path_to_unix "$LOCALAPPDATA")/Programs/Python"
  [ -n "${ProgramFiles:-}" ] && roots="$roots
$(windows_path_to_unix "$ProgramFiles")"
  pfx86="$(printenv 'ProgramFiles(x86)' 2>/dev/null || true)"
  [ -n "$pfx86" ] && roots="$roots
$(windows_path_to_unix "$pfx86")"
  while IFS= read -r windows_python_root; do
    [ -n "$windows_python_root" ] && [ -d "$windows_python_root" ] || continue
    while IFS= read -r py; do
      try_last30days_python "$py" && break 2
    done <<EOF_PYTHON_CANDIDATES
$(find "$windows_python_root" -maxdepth 2 -type f -iname python.exe 2>/dev/null | sort -r)
EOF_PYTHON_CANDIDATES
  done <<EOF_ROOTS
$roots
EOF_ROOTS
fi

if [ -z "${LAST30DAYS_PYTHON:-}" ]; then
  for py in python3.14 python3.13 python3.12 python3 python; do
    try_last30days_python "$py" && break
  done
fi

# uv fallback: hosts without a system 3.12 but with uv on PATH get a managed CPython 3.12.
if [ -z "${LAST30DAYS_PYTHON:-}" ] && command -v uv >/dev/null 2>&1; then
  uv_py="$(uv python find '>=3.12' 2>/dev/null)"
  if [ -z "$uv_py" ] || [ ! -x "$uv_py" ]; then
    echo "NOTE: no Python 3.12+ found; installing a managed CPython 3.12 via uv (~28MB, one-time)." >&2
    if UV_HTTP_TIMEOUT=30 uv python install 3.12 >/dev/null 2>&1; then
      uv_py="$(uv python find '>=3.12' 2>/dev/null)"
    else
      echo "WARN: 'uv python install 3.12' failed (network, disk space, or proxy?); falling through to the version-gate error below." >&2
    fi
  fi
  try_last30days_python "$uv_py"
fi

if [ -z "${LAST30DAYS_PYTHON:-}" ]; then
  echo "ERROR: last30days v3 requires Python 3.12+. Install Python 3.12+ or set LAST30DAYS_PYTHON to a supported interpreter." >&2
  exit 1
fi

"${LAST30DAYS_PYTHON}" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)' || {
  echo "ERROR: LAST30DAYS_PYTHON must point to Python 3.12+." >&2
  exit 1
}

# ---- optional keys, by NAME only ---------------------------------------------
KEY_NAMES="SCRAPECREATORS_API_KEY OPENAI_API_KEY XAI_API_KEY X_BEARER_TOKEN OPENROUTER_API_KEY PERPLEXITY_API_KEY PARALLEL_API_KEY BRAVE_API_KEY EXA_API_KEY SERPER_API_KEY APIFY_API_TOKEN AUTH_TOKEN CT0 BSKY_HANDLE BSKY_APP_PASSWORD TRUTHSOCIAL_TOKEN XIAOHONGSHU_API_BASE"
set_names=""
for name in $KEY_NAMES; do
  if [ -n "${!name:-}" ]; then
    set_names="${set_names:+$set_names,}$name"
  fi
done

echo "OK $LAST30DAYS_PYTHON"
echo "KEYS_SET=$set_names"

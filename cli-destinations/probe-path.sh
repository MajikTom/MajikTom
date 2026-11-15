#!/usr/bin/env bash
# Report whether GPT destination CLIs are callable from this shell.
# Git Bash on Windows often has Codex on PATH while `agent` and `claude`
# look missing because the Windows installers only drop .cmd / .exe shims.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$ROOT/lib.sh"

JSON=0
REQUIRE=()

usage() {
  cat <<'EOF'
Usage: probe-path.sh [--json] [--require cursor|claude|codex]...

Prints how this shell resolves node, git, bash, codex, claude, and Cursor agent.
Exit 0 unless --require names a destination that cannot be resolved (exit 2).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --require)
      shift
      REQUIRE+=("${1:-}")
      ;;
    --require=*)
      REQUIRE+=("${1#--require=}")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

tool_record() {
  local name="$1"
  local resolver="$2"
  local path=""
  local on_path="false"
  local resolved="false"
  local version=""
  local path_cmd=""

  path_cmd="$(cli_path_of "$name" 2>/dev/null || true)"
  if [ -n "$path_cmd" ]; then
    on_path="true"
  fi
  if path="$("$resolver" "$name")"; then
    resolved="true"
  else
    path=""
  fi
  if [ "$resolved" = "true" ]; then
    version="$(cli_version_of "$path" || true)"
  fi

  TOOL_NAME="$name"
  TOOL_ON_PATH="$on_path"
  TOOL_PATH_CMD="$path_cmd"
  TOOL_RESOLVED="$resolved"
  TOOL_PATH="$path"
  TOOL_VERSION="$version"
}

print_human_row() {
  local status="missing"
  if [ "$TOOL_RESOLVED" = "true" ]; then
    status="ok"
  elif [ "$TOOL_ON_PATH" = "true" ]; then
    status="path-only"
  fi
  printf '%-14s %-10s %-s\n' "$TOOL_NAME" "$status" "${TOOL_PATH:-${TOOL_PATH_CMD:-not found}}"
  if [ -n "$TOOL_VERSION" ]; then
    printf '%-14s %-10s %s\n' "" "" "$TOOL_VERSION"
  fi
}

json_tool() {
  printf '{"name":"%s","onPath":%s,"pathCommand":"%s","resolved":%s,"path":"%s","version":"%s"}' \
    "$(cli_json_escape "$TOOL_NAME")" \
    "$TOOL_ON_PATH" \
    "$(cli_json_escape "$TOOL_PATH_CMD")" \
    "$TOOL_RESOLVED" \
    "$(cli_json_escape "$TOOL_PATH")" \
    "$(cli_json_escape "$TOOL_VERSION")"
}

NODE_PATH="$(cli_path_of node || true)"
GIT_PATH="$(cli_path_of git || true)"
BASH_PATH="$(cli_path_of bash || true)"
UNAME="$(uname -a 2>/dev/null || true)"

tool_record node cli_path_of
NODE_JSON="$(json_tool)"

tool_record git cli_path_of
GIT_JSON="$(json_tool)"

tool_record bash cli_path_of
BASH_JSON="$(json_tool)"

tool_record codex cli_resolve_codex
CODEX_RESOLVED="$TOOL_RESOLVED"
CODEX_JSON="$(json_tool)"
CODEX_HUMAN_NAME="$TOOL_NAME"
CODEX_HUMAN_ON="$TOOL_ON_PATH"
CODEX_HUMAN_CMD="$TOOL_PATH_CMD"
CODEX_HUMAN_RES="$TOOL_RESOLVED"
CODEX_HUMAN_PATH="$TOOL_PATH"
CODEX_HUMAN_VER="$TOOL_VERSION"

tool_record claude cli_resolve_claude
CLAUDE_RESOLVED="$TOOL_RESOLVED"
CLAUDE_JSON="$(json_tool)"
CLAUDE_HUMAN_NAME="$TOOL_NAME"
CLAUDE_HUMAN_ON="$TOOL_ON_PATH"
CLAUDE_HUMAN_CMD="$TOOL_PATH_CMD"
CLAUDE_HUMAN_RES="$TOOL_RESOLVED"
CLAUDE_HUMAN_PATH="$TOOL_PATH"
CLAUDE_HUMAN_VER="$TOOL_VERSION"

tool_record agent cli_resolve_agent
AGENT_RESOLVED="$TOOL_RESOLVED"
AGENT_JSON="$(json_tool)"
AGENT_HUMAN_NAME="$TOOL_NAME"
AGENT_HUMAN_ON="$TOOL_ON_PATH"
AGENT_HUMAN_CMD="$TOOL_PATH_CMD"
AGENT_HUMAN_RES="$TOOL_RESOLVED"
AGENT_HUMAN_PATH="$TOOL_PATH"
AGENT_HUMAN_VER="$TOOL_VERSION"

APPDATA_U="$(cli_local_appdata 2>/dev/null || true)"
PROFILE_U="$(cli_user_profile)"

if [ "$JSON" -eq 1 ]; then
  printf '{'
  printf '"shell":"%s",' "$(cli_json_escape "${SHELL:-}")"
  printf '"uname":"%s",' "$(cli_json_escape "$UNAME")"
  printf '"msystem":"%s",' "$(cli_json_escape "${MSYSTEM:-}")"
  printf '"windows":%s,' "$(cli_is_windows && echo true || echo false)"
  printf '"pathContainsCursorAgent":%s,' "$(printf '%s' "$PATH" | grep -q 'cursor-agent' && echo true || echo false)"
  printf '"pathContainsLocalBin":%s,' "$(printf '%s' "$PATH" | grep -q '\.local/bin' && echo true || echo false)"
  printf '"localAppData":"%s",' "$(cli_json_escape "$APPDATA_U")"
  printf '"userProfile":"%s",' "$(cli_json_escape "$PROFILE_U")"
  printf '"tools":[%s,%s,%s,%s,%s,%s]' \
    "$NODE_JSON" "$GIT_JSON" "$BASH_JSON" "$CODEX_JSON" "$CLAUDE_JSON" "$AGENT_JSON"
  printf '}\n'
else
  echo "Shell: ${SHELL:-unknown}"
  echo "uname: $UNAME"
  [ -n "${MSYSTEM:-}" ] && echo "MSYSTEM: $MSYSTEM"
  echo
  printf '%-14s %-10s %s\n' "TOOL" "STATUS" "RESOLVED PATH"
  printf '%-14s %-10s %s\n' "----" "------" "-------------"

  TOOL_NAME="node"; TOOL_ON_PATH="$([ -n "$NODE_PATH" ] && echo true || echo false)"
  TOOL_PATH_CMD="$NODE_PATH"; TOOL_RESOLVED="$TOOL_ON_PATH"; TOOL_PATH="$NODE_PATH"
  TOOL_VERSION="$([ -n "$NODE_PATH" ] && node --version 2>/dev/null || true)"
  print_human_row

  TOOL_NAME="git"; TOOL_PATH_CMD="$GIT_PATH"; TOOL_ON_PATH="$([ -n "$GIT_PATH" ] && echo true || echo false)"
  TOOL_RESOLVED="$TOOL_ON_PATH"; TOOL_PATH="$GIT_PATH"
  TOOL_VERSION="$([ -n "$GIT_PATH" ] && git --version 2>/dev/null || true)"
  print_human_row

  TOOL_NAME="bash"; TOOL_PATH_CMD="$BASH_PATH"; TOOL_ON_PATH="$([ -n "$BASH_PATH" ] && echo true || echo false)"
  TOOL_RESOLVED="$TOOL_ON_PATH"; TOOL_PATH="$BASH_PATH"
  TOOL_VERSION="$([ -n "$BASH_PATH" ] && bash --version 2>/dev/null | head -n 1 || true)"
  print_human_row

  TOOL_NAME="$CODEX_HUMAN_NAME"; TOOL_ON_PATH="$CODEX_HUMAN_ON"; TOOL_PATH_CMD="$CODEX_HUMAN_CMD"
  TOOL_RESOLVED="$CODEX_HUMAN_RES"; TOOL_PATH="$CODEX_HUMAN_PATH"; TOOL_VERSION="$CODEX_HUMAN_VER"
  print_human_row

  TOOL_NAME="$CLAUDE_HUMAN_NAME"; TOOL_ON_PATH="$CLAUDE_HUMAN_ON"; TOOL_PATH_CMD="$CLAUDE_HUMAN_CMD"
  TOOL_RESOLVED="$CLAUDE_HUMAN_RES"; TOOL_PATH="$CLAUDE_HUMAN_PATH"; TOOL_VERSION="$CLAUDE_HUMAN_VER"
  print_human_row

  TOOL_NAME="$AGENT_HUMAN_NAME"; TOOL_ON_PATH="$AGENT_HUMAN_ON"; TOOL_PATH_CMD="$AGENT_HUMAN_CMD"
  TOOL_RESOLVED="$AGENT_HUMAN_RES"; TOOL_PATH="$AGENT_HUMAN_PATH"; TOOL_VERSION="$AGENT_HUMAN_VER"
  print_human_row

  echo
  if [ "$AGENT_RESOLVED" != "true" ]; then
    cat <<'EOF'
Cursor agent is not resolvable from this shell.

On a Windows PC, install the native CLI in PowerShell (not Git Bash):
  irm 'https://cursor.com/install?win32=true' | iex

That writes %LOCALAPPDATA%\cursor-agent\agent.cmd. Git Bash will still say
`agent: command not found` until you use this folder's shim:

  export PATH="$PWD/cli-destinations/bin:$PATH"
  ./cli-destinations/probe-path.sh

Or send work through the GPT destination wrapper, which finds agent.cmd itself:

  ./cli-destinations/cursor-destination.sh -- "your prompt"
EOF
  elif [ "$AGENT_HUMAN_ON" != "true" ]; then
    cat <<'EOF'
Cursor CLI is installed but `agent` is not a PATH command in this shell.
Git Bash does not run agent.cmd without the extension. Use:

  export PATH="$PWD/cli-destinations/bin:$PATH"

or call ./cli-destinations/cursor-destination.sh
EOF
  fi

  if [ "$CLAUDE_RESOLVED" != "true" ]; then
    cat <<'EOF'

Claude CLI is not resolvable. Optional, from PowerShell:
  irm https://claude.ai/install.ps1 | iex
Then add %USERPROFILE%\.local\bin to your User PATH and reopen Git Bash.
EOF
  fi
fi

fail_require() {
  echo "required destination not resolved: $1" >&2
  exit 2
}

for needed in "${REQUIRE[@]+"${REQUIRE[@]}"}"; do
  case "$needed" in
    cursor|agent|cursor-agent)
      [ "$AGENT_RESOLVED" = "true" ] || fail_require cursor
      ;;
    claude)
      [ "$CLAUDE_RESOLVED" = "true" ] || fail_require claude
      ;;
    codex)
      [ "$CODEX_RESOLVED" = "true" ] || fail_require codex
      ;;
    node)
      [ -n "$NODE_PATH" ] || fail_require node
      ;;
    git)
      [ -n "$GIT_PATH" ] || fail_require git
      ;;
    "")
      ;;
    *)
      echo "unknown --require value: $needed" >&2
      exit 2
      ;;
  esac
done

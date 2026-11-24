#!/usr/bin/env bash
# GPT / Codex input destination for Cursor CLI.
# Resolves agent.cmd on Windows Git Bash, clears MSYSTEM/SHELL, and runs
# print mode so the caller does not need a TTY.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$ROOT/lib.sh"

FORCE=0
MODE=""
WORKSPACE="${CURSOR_DESTINATION_WORKSPACE:-$PWD}"
OUTPUT_FORMAT="${CURSOR_DESTINATION_OUTPUT_FORMAT:-text}"
PROMPT_FILE=""
READ_STDIN=0
PASSTHRU=()
PROMPT_ARGS=()
SEEN_PRINT=0
SEEN_TRUST=0
SEEN_WORKSPACE=0
SEEN_OUTPUT=0

usage() {
  cat <<'EOF'
Usage: cursor-destination.sh [options] [--] prompt...

Options:
  --force            Auto-approve actions (needed for unattended GPT runs)
  --ask              Read-only (--mode=ask)
  --plan             Plan mode (--mode=plan)
  --workspace DIR    Workspace for the agent (default: current directory)
  --output-format F  text | json | stream-json (default: text)
  --prompt-file FILE Read the prompt from FILE
  --stdin            Read the prompt from stdin
  -h, --help         Show this help

Any extra flags after the options are forwarded to `agent`.
Print mode (-p) and --trust are always added for non-interactive GPT use.

Examples:
  cursor-destination.sh -- "explain the repo layout"
  cursor-destination.sh --force -- "add tests for cli-destinations"
  printf '%s' "$TASK" | cursor-destination.sh --stdin --force
EOF
}

take_value() {
  if [ $# -lt 2 ]; then
    echo "cursor-destination: $1 requires a value" >&2
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --force|-f|--yolo)
      FORCE=1
      ;;
    --ask)
      MODE="ask"
      ;;
    --plan)
      MODE="plan"
      ;;
    --workspace)
      take_value "$@"
      shift
      WORKSPACE="$1"
      ;;
    --workspace=*)
      WORKSPACE="${1#--workspace=}"
      ;;
    --output-format)
      take_value "$@"
      shift
      OUTPUT_FORMAT="$1"
      ;;
    --output-format=*)
      OUTPUT_FORMAT="${1#--output-format=}"
      ;;
    --prompt-file)
      take_value "$@"
      shift
      PROMPT_FILE="$1"
      ;;
    --prompt-file=*)
      PROMPT_FILE="${1#--prompt-file=}"
      ;;
    --mode)
      take_value "$@"
      shift
      MODE="$1"
      ;;
    --mode=*)
      MODE="${1#--mode=}"
      ;;
    --stdin)
      READ_STDIN=1
      ;;
    --)
      shift
      PROMPT_ARGS+=("$@")
      break
      ;;
    -p|--print)
      SEEN_PRINT=1
      PASSTHRU+=("$1")
      ;;
    --trust)
      SEEN_TRUST=1
      PASSTHRU+=("$1")
      ;;
    --model|--api-key|--sandbox|--header|--resume|--plugin-dir|--worktree-base)
      take_value "$@"
      PASSTHRU+=("$1")
      shift
      PASSTHRU+=("$1")
      ;;
    --model=*|--api-key=*|--sandbox=*|--header=*|--resume=*|--plugin-dir=*|--worktree-base=*)
      PASSTHRU+=("$1")
      ;;
    -*)
      PASSTHRU+=("$1")
      ;;
    *)
      PROMPT_ARGS+=("$1")
      ;;
  esac
  shift
done

PROMPT=""
if [ -n "$PROMPT_FILE" ]; then
  PROMPT="$(cat "$PROMPT_FILE")"
fi
if [ "$READ_STDIN" -eq 1 ]; then
  if [ -n "$PROMPT" ]; then
    PROMPT="$PROMPT"$'\n'"$(cat)"
  else
    PROMPT="$(cat)"
  fi
fi
if [ ${#PROMPT_ARGS[@]} -gt 0 ]; then
  joined="${PROMPT_ARGS[*]}"
  if [ -n "$PROMPT" ]; then
    PROMPT="$PROMPT"$'\n'"$joined"
  else
    PROMPT="$joined"
  fi
fi

if [ -z "$PROMPT" ]; then
  echo "cursor-destination: missing prompt" >&2
  usage >&2
  exit 2
fi

AGENT_ARGS=()
if [ "$SEEN_PRINT" -eq 0 ]; then
  AGENT_ARGS+=(-p)
fi
if [ "$SEEN_TRUST" -eq 0 ]; then
  AGENT_ARGS+=(--trust)
fi
if [ "$FORCE" -eq 1 ]; then
  AGENT_ARGS+=(--force)
fi
if [ -n "$MODE" ]; then
  AGENT_ARGS+=(--mode "$MODE")
fi
if [ "$SEEN_WORKSPACE" -eq 0 ]; then
  AGENT_ARGS+=(--workspace "$WORKSPACE")
fi
if [ "$SEEN_OUTPUT" -eq 0 ]; then
  AGENT_ARGS+=(--output-format "$OUTPUT_FORMAT")
fi
AGENT_ARGS+=("${PASSTHRU[@]+"${PASSTHRU[@]}"}")
AGENT_ARGS+=("$PROMPT")

cli_exec_agent "${AGENT_ARGS[@]}"

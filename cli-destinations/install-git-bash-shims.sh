#!/usr/bin/env bash
# Install extensionless `agent` / `cursor-agent` shims on PATH for Git Bash.
# Does not edit ~/.bashrc unless you pass --write-bashrc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$ROOT/lib.sh"

WRITE_BASHRC=0
TARGET="${HOME%/}/bin"

usage() {
  cat <<'EOF'
Usage: install-git-bash-shims.sh [--dir DIR] [--write-bashrc]

Copies the Git Bash shims from cli-destinations/bin into DIR (default: ~/bin)
so `agent` and `cursor-agent` resolve without typing .cmd.

  --dir DIR         Install location (default: ~/bin)
  --write-bashrc    Append `export PATH="$HOME/bin:$PATH"` to ~/.bashrc
                    if that exact line is not already present
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      shift
      TARGET="${1:-}"
      ;;
    --dir=*)
      TARGET="${1#--dir=}"
      ;;
    --write-bashrc)
      WRITE_BASHRC=1
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

if ! cli_resolve_agent >/dev/null; then
  echo "Cursor CLI is not installed yet. In PowerShell run:" >&2
  echo "  irm 'https://cursor.com/install?win32=true' | iex" >&2
  echo "Then re-run this script." >&2
  exit 1
fi

mkdir -p "$TARGET"
cp "$ROOT/bin/agent" "$TARGET/agent"
cp "$ROOT/bin/cursor-agent" "$TARGET/cursor-agent"
chmod +x "$TARGET/agent" "$TARGET/cursor-agent"

echo "Installed shims:"
echo "  $TARGET/agent"
echo "  $TARGET/cursor-agent"

path_line='export PATH="$HOME/bin:$PATH"'
if [ "$TARGET" != "${HOME%/}/bin" ]; then
  path_line="export PATH=\"$TARGET:\$PATH\""
fi

if [ "$WRITE_BASHRC" -eq 1 ]; then
  bashrc="${HOME%/}/.bashrc"
  touch "$bashrc"
  if grep -Fqx "$path_line" "$bashrc"; then
    echo "PATH line already present in $bashrc"
  else
    printf '\n# Cursor CLI Git Bash shims\n%s\n' "$path_line" >> "$bashrc"
    echo "Appended PATH line to $bashrc"
  fi
else
  echo
  echo "Add this to ~/.bashrc and open a new Git Bash:"
  echo "  $path_line"
fi

echo
echo "This shell: export PATH=\"$TARGET:\$PATH\""

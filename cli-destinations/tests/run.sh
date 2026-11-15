#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
# shellcheck source=../lib.sh
source "$ROOT/lib.sh"

FAILS=0
assert() {
  local label="$1"
  shift
  if "$@"; then
    echo "ok - $label"
  else
    echo "not ok - $label" >&2
    FAILS=$((FAILS + 1))
  fi
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $label"
  else
    echo "not ok - $label" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    FAILS=$((FAILS + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) echo "ok - $label" ;;
    *)
      echo "not ok - $label" >&2
      echo "  missing: $needle" >&2
      echo "  in: $haystack" >&2
      FAILS=$((FAILS + 1))
      ;;
  esac
}

chmod +x "$ROOT/probe-path.sh" "$ROOT/cursor-destination.sh" \
  "$ROOT/install-git-bash-shims.sh" "$ROOT/bin/agent" "$ROOT/bin/cursor-agent"

PROBE_OUT="$("$ROOT/probe-path.sh")"
assert_contains "probe mentions node" "node" "$PROBE_OUT"
assert_contains "probe mentions agent" "agent" "$PROBE_OUT"

JSON_OUT="$("$ROOT/probe-path.sh" --json)"
assert_contains "json has tools" '"tools":[' "$JSON_OUT"
assert_contains "json names agent" '"name":"agent"' "$JSON_OUT"

set +e
"$ROOT/probe-path.sh" --require cursor >/dev/null 2>&1
require_rc=$?
set -e
assert_eq "require cursor fails when agent is missing" "2" "$require_rc"

set +e
"$ROOT/cursor-destination.sh" >/dev/null 2>&1
missing_prompt_rc=$?
set -e
assert_eq "destination without prompt exits 2" "2" "$missing_prompt_rc"

FAKE_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$FAKE_ROOT"; }
trap cleanup EXIT

mkdir -p "$FAKE_ROOT/cursor-agent" "$FAKE_ROOT/bin" "$FAKE_ROOT/recorded"
cat > "$FAKE_ROOT/cursor-agent/agent.cmd" <<'EOF'
@echo off
echo fake-agent.cmd
EOF
chmod +x "$FAKE_ROOT/cursor-agent/agent.cmd"

cat > "$FAKE_ROOT/bin/agent" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$FAKE_ROOT/recorded/args.txt"
echo fake-agent-ok
EOF
chmod +x "$FAKE_ROOT/bin/agent"

resolved="$(
  LOCALAPPDATA="$FAKE_ROOT" PATH="/usr/bin:/bin" HOME="$FAKE_ROOT/empty-home"
  mkdir -p "$FAKE_ROOT/empty-home"
  cli_resolve_agent
)"
assert_eq "resolver finds LOCALAPPDATA agent.cmd" \
  "$FAKE_ROOT/cursor-agent/agent.cmd" "$resolved"

shim_only="$(
  PATH="$ROOT/bin:/usr/bin:/bin" LOCALAPPDATA="" HOME="$FAKE_ROOT/empty-home"
  unset LOCALAPPDATA USERPROFILE
  cli_resolve_agent || true
)"
assert_eq "resolver skips repo PATH shims" "" "$shim_only"

PATH="$FAKE_ROOT/bin:$PATH" "$ROOT/cursor-destination.sh" -- "hello world" >/dev/null
recorded="$(cat "$FAKE_ROOT/recorded/args.txt")"
assert_contains "adds print flag" "-p" "$recorded"
assert_contains "adds trust flag" "--trust" "$recorded"
assert_contains "adds workspace" "--workspace" "$recorded"
assert_contains "forwards prompt" "hello world" "$recorded"

PATH="$FAKE_ROOT/bin:$PATH" "$ROOT/cursor-destination.sh" --force --ask -- "task" >/dev/null
recorded="$(cat "$FAKE_ROOT/recorded/args.txt")"
assert_contains "adds force" "--force" "$recorded"
assert_contains "adds ask mode" "--mode" "$recorded"
assert_contains "adds ask value" "ask" "$recorded"

PATH="$FAKE_ROOT/bin:$PATH" "$ROOT/cursor-destination.sh" --model auto -- "use model" >/dev/null
recorded="$(cat "$FAKE_ROOT/recorded/args.txt")"
assert_contains "forwards --model" "--model" "$recorded"
assert_contains "forwards model value" "auto" "$recorded"

cd "$REPO"
if [ "$FAILS" -ne 0 ]; then
  echo "$FAILS test(s) failed" >&2
  exit 1
fi
echo "all tests passed"

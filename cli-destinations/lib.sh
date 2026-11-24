# Shared Cursor / Claude / Codex CLI resolution for Git Bash, PowerShell, and Unix.
# Sourced by probe-path.sh, cursor-destination.sh, and bin/agent.

cli_is_windows() {
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
  esac
  [ -n "${MSYSTEM:-}" ] && return 0
  return 1
}

cli_unix_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s\n' "$1"
  fi
}

# True if a name is a hashed command or executable file, including Windows .cmd.
cli_on_path() {
  command -v "$1" >/dev/null 2>&1
}

cli_path_of() {
  local p
  p="$(command -v "$1" 2>/dev/null)" || return 1
  printf '%s\n' "$p"
}

cli_is_file() {
  [ -n "${1:-}" ] && [ -f "$1" ]
}

# Repo and ~/bin shims source this file and must not resolve as the real CLI.
cli_is_our_shim() {
  [ -n "${1:-}" ] && [ -f "$1" ] && grep -q 'CURSOR_GIT_BASH_SHIM=1' "$1"
}

cli_first_file() {
  local candidate
  for candidate in "$@"; do
    [ -n "$candidate" ] || continue
    if cli_is_file "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

cli_local_appdata() {
  if [ -n "${LOCALAPPDATA:-}" ]; then
    cli_unix_path "$LOCALAPPDATA"
    return 0
  fi
  if [ -n "${USERPROFILE:-}" ]; then
    cli_unix_path "$USERPROFILE/AppData/Local"
    return 0
  fi
  if [ -n "${HOME:-}" ] && [ -d "$HOME/AppData/Local" ]; then
    printf '%s\n' "$HOME/AppData/Local"
    return 0
  fi
  return 1
}

cli_user_profile() {
  if [ -n "${USERPROFILE:-}" ]; then
    cli_unix_path "$USERPROFILE"
    return 0
  fi
  printf '%s\n' "${HOME:-}"
}

cli_npm_global_bin() {
  if cli_on_path npm; then
    npm prefix -g 2>/dev/null || true
  fi
}

cli_accept_agent() {
  local found="$1"
  if cli_is_file "$found" && ! cli_is_our_shim "$found"; then
    printf '%s\n' "$found"
    return 0
  fi
  return 1
}

# Cursor Windows installer writes only agent.cmd / cursor-agent.cmd under
# %LOCALAPPDATA%\cursor-agent. Git Bash does not resolve those as `agent`.
cli_resolve_agent() {
  local found appdata npm_bin candidate

  appdata="$(cli_local_appdata 2>/dev/null || true)"
  npm_bin="$(cli_npm_global_bin)"

  for candidate in \
    "${appdata:+$appdata/cursor-agent/agent.cmd}" \
    "${appdata:+$appdata/cursor-agent/cursor-agent.cmd}" \
    "${appdata:+$appdata/cursor-agent/agent.exe}" \
    "${HOME:-}/.local/bin/agent" \
    "${HOME:-}/.local/bin/cursor-agent" \
    "${HOME:-}/.cursor/bin/agent" \
    "${HOME:-}/.cursor/bin/cursor-agent" \
    "${npm_bin:+$npm_bin/agent.cmd}" \
    "${npm_bin:+$npm_bin/agent}"; do
    [ -n "$candidate" ] || continue
    if cli_accept_agent "$candidate"; then
      return 0
    fi
  done

  for found in agent.cmd cursor-agent.cmd agent.exe cursor-agent.exe agent cursor-agent; do
    candidate="$(cli_path_of "$found" 2>/dev/null || true)"
    if cli_accept_agent "$candidate"; then
      return 0
    fi
  done
  return 1
}

cli_resolve_claude() {
  local found profile npm_bin

  found="$(cli_path_of claude || true)"
  if cli_is_file "$found"; then
    printf '%s\n' "$found"
    return 0
  fi

  found="$(cli_path_of claude.exe || true)"
  if cli_is_file "$found"; then
    printf '%s\n' "$found"
    return 0
  fi

  found="$(cli_path_of claude.cmd || true)"
  if cli_is_file "$found"; then
    printf '%s\n' "$found"
    return 0
  fi

  profile="$(cli_user_profile)"
  npm_bin="$(cli_npm_global_bin)"

  cli_first_file \
    "${profile:+$profile/.local/bin/claude.exe}" \
    "${profile:+$profile/.local/bin/claude}" \
    "${HOME:-}/.local/bin/claude" \
    "${HOME:-}/.local/bin/claude.exe" \
    "${npm_bin:+$npm_bin/claude}" \
    "${npm_bin:+$npm_bin/claude.cmd}" \
    "${npm_bin:+$npm_bin/claude.exe}"
}

cli_resolve_codex() {
  local found npm_bin

  found="$(cli_path_of codex || true)"
  if cli_is_file "$found"; then
    printf '%s\n' "$found"
    return 0
  fi

  found="$(cli_path_of codex.cmd || true)"
  if cli_is_file "$found"; then
    printf '%s\n' "$found"
    return 0
  fi

  npm_bin="$(cli_npm_global_bin)"
  cli_first_file \
    "${npm_bin:+$npm_bin/codex}" \
    "${npm_bin:+$npm_bin/codex.cmd}" \
    "${HOME:-}/.local/bin/codex"
}

cli_needs_msystem_clear() {
  local bin="$1"
  cli_is_windows || return 1
  case "$bin" in
    *.cmd|*.CMD|*.bat|*.BAT|*.ps1|*.PS1) return 0 ;;
  esac
  return 1
}

# Exec the real Cursor CLI. Git Bash must clear MSYSTEM and SHELL or Cursor
# runs PowerShell hook wrappers through bash eval and blocks every hook.
cli_exec_agent() {
  local bin
  if ! bin="$(cli_resolve_agent)"; then
    echo "cursor-destination: Cursor CLI not found." >&2
    echo "Install from PowerShell, then re-run probe-path.sh:" >&2
    echo "  irm 'https://cursor.com/install?win32=true' | iex" >&2
    exit 127
  fi
  if cli_needs_msystem_clear "$bin"; then
    exec env MSYSTEM= SHELL= "$bin" "$@"
  fi
  exec "$bin" "$@"
}

cli_json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

cli_version_of() {
  local bin="$1"
  if [ -z "$bin" ] || ! cli_is_file "$bin"; then
    return 1
  fi
  if cli_needs_msystem_clear "$bin"; then
    env MSYSTEM= SHELL= "$bin" --version 2>/dev/null | head -n 1
    return 0
  fi
  "$bin" --version 2>/dev/null | head -n 1
  return 0
}

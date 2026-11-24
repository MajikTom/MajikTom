# GPT CLI destinations

Use Cursor CLI as a non-interactive destination from GPT/Codex on a Windows PC
that already has Node.js 22, Git, Git Bash, and Codex on PATH.

`agent` and `claude` missing from PATH is expected until those CLIs are
installed **and** Git Bash can see an extensionless command. Codex is usually
an `.exe` or npm shim Git Bash already searches for. The native Cursor
installer is not.

## What was missing

On Windows, this is the Cursor install:

```powershell
irm 'https://cursor.com/install?win32=true' | iex
```

It writes `%LOCALAPPDATA%\cursor-agent\agent.cmd` (and `cursor-agent.cmd`) and
adds that folder to the **User** PATH. It does not write `~/.local/bin/agent`.

Git Bash then reports `agent: command not found` for two reasons:

1. Bash does not treat `agent.cmd` as the command `agent`.
2. If you started Git Bash before the install, it still has the old PATH.

Do **not** run `curl https://cursor.com/install | bash` from Git Bash on
Windows. That installer is for macOS, Linux, and WSL.

## One-time setup

1. Install Cursor CLI from **PowerShell**:

   ```powershell
   irm 'https://cursor.com/install?win32=true' | iex
   ```

2. Authenticate once:

   ```powershell
   agent login
   agent status
   ```

   For unattended GPT runs, create a key at
   [Cursor API keys](https://cursor.com/dashboard/settings/api-keys) and set
   `CURSOR_API_KEY` in your user environment. Do not put the key on the
   command line.

3. From **Git Bash**, in this repo:

   ```bash
   ./cli-destinations/probe-path.sh
   ```

   If the probe finds `agent.cmd` but not `agent`, put the shim directory on
   PATH for that shell:

   ```bash
   export PATH="$PWD/cli-destinations/bin:$PATH"
   ./cli-destinations/probe-path.sh --require cursor
   ```

   To persist the shim in `~/bin` (does not edit `~/.bashrc` unless asked):

   ```bash
   ./cli-destinations/install-git-bash-shims.sh
   ./cli-destinations/install-git-bash-shims.sh --write-bashrc
   ```

## GPT destination command

Codex/GPT should exec the wrapper, not a bare `agent` string. The wrapper
finds `agent.cmd`, clears `MSYSTEM`/`SHELL` (required so Cursor hooks do not
run through bash `eval`), and uses print mode.

```bash
./cli-destinations/cursor-destination.sh --force -- "implement the task"
```

Read-only:

```bash
./cli-destinations/cursor-destination.sh --ask -- "what does this repo do?"
```

Prompt on stdin (good when GPT already has the task text):

```bash
printf '%s' "$TASK" | ./cli-destinations/cursor-destination.sh --stdin --force
```

Machine-readable preflight:

```bash
./cli-destinations/probe-path.sh --json --require cursor
```

`--force` is the unattended switch. Without it, print mode still edits
workspace files that do not need approval, and it **rejects** shell/MCP/web
actions that would have prompted. GPT coding tasks should pass `--force`.

Contract: `cli-destinations/destinations.json`.

## Optional: Claude CLI

Not needed for the Cursor destination. If GPT should also route to Claude,
install from PowerShell, then add `%USERPROFILE%\.local\bin` to User PATH and
open a new Git Bash:

```powershell
irm https://claude.ai/install.ps1 | iex
```

## Checks

```bash
./cli-destinations/tests/run.sh
```

# Install Claude Code + caveman plugin (Windows)

Setup Claude Code CLI and caveman plugin on fresh Windows PC. Idempotent — safe to re-run.

## Prerequisites

- Windows 10/11
- PowerShell 5.1+ (built-in) or PowerShell 7
- Git for Windows — https://git-scm.com/download/win
- Internet access to `claude.ai` and `github.com`

Check git:

```powershell
git --version
```

If missing — install, then reopen PowerShell.

## Quick install

1. Copy `install-caveman.ps1` to PC.
2. Open PowerShell (regular, not admin).
3. Allow script for current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

4. Run:

```powershell
.\install-caveman.ps1
```

5. Close PowerShell. Open new one (PATH refresh).
6. Run `claude` — type `/caveman` in chat.

## What script does

9 steps, each verified:

| # | Step | Action | Fail condition |
|---|------|--------|----------------|
| 1 | Check git | Verify `git --version` | git not in PATH |
| 2 | Install Claude Code | Run native installer if `claude.exe` missing | `claude.exe` still missing after install |
| 3 | PATH | Add `%USERPROFILE%\.local\bin` to user PATH (permanent) + current session | — |
| 4 | Verify CLI | `claude --version` | exit code != 0 |
| 5 | Clone source | Clone `caveman` repo to `%USERPROFILE%\.claude\plugins\sources\caveman`. If exists — `git pull` | clone failed / not git repo |
| 6 | Marketplace | `claude plugin marketplace add <local-path>` | warn if errors |
| 7 | Plugin install | `claude plugin install caveman@caveman` | install failed |
| 8 | Settings check | Verify `settings.json` has `enabledPlugins."caveman@caveman": true` | not enabled |
| 9 | Cache check | Verify `.toml` command files exist in cache | no files found |

## Manual install (if script breaks)

### 1. Install Claude Code

```powershell
irm https://claude.ai/install.ps1 | iex
```

Output shows `Location: C:\Users\<user>\.local\bin\claude.exe`.

### 2. Add to PATH (permanent)

```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\.local\bin", "User")
```

Close PowerShell. Open new.

### 3. Verify

```powershell
claude --version
```

### 4. Clone plugin source

```powershell
$dest = "$env:USERPROFILE\.claude\plugins\sources\caveman"
New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
git clone https://github.com/JuliusBrussee/caveman.git $dest
```

> **Note:** Don't use Temp folder. Windows cleans Temp — plugin breaks.

### 5. Add marketplace + install

```powershell
claude plugin marketplace add "$env:USERPROFILE\.claude\plugins\sources\caveman"
claude plugin install caveman@caveman
claude plugin list
```

### 6. Verify

```powershell
Get-Content "$env:USERPROFILE\.claude\settings.json"
```

Expect:

```json
{
  "enabledPlugins": {
    "caveman@caveman": true
  },
  "extraKnownMarketplaces": { "caveman": { ... } }
}
```

### 7. Restart Claude Code session

Plugins load at session start. Existing session won't see new commands.

## Troubleshooting

### `claude: command not found`

PATH didn't refresh. Reopen PowerShell. Or run with full path:

```powershell
& "$env:USERPROFILE\.local\bin\claude.exe" --version
```

### `SSH authentication failed` on `marketplace add owner/repo`

CLI tried `git@github.com:`. Use HTTPS URL or local path:

```powershell
claude plugin marketplace add https://github.com/JuliusBrussee/caveman.git
# OR
claude plugin marketplace add "$env:USERPROFILE\.claude\plugins\sources\caveman"
```

Or set git rewrite globally:

```powershell
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

### `remote helper 'https' aborted session`

Claude CLI's git env broken. Workaround — clone manually with system git, then add as local path:

```powershell
git clone https://github.com/JuliusBrussee/caveman.git $env:USERPROFILE\.claude\plugins\sources\caveman
claude plugin marketplace add "$env:USERPROFILE\.claude\plugins\sources\caveman"
```

### `/caveman` returns "Unknown command"

Session started before plugin installed. Exit and restart Claude Code:

```
/exit
```

Then `claude` again.

### `installed_plugins.json` is empty (`"plugins": {}`)

Plugin lost registration. Re-install:

```powershell
claude plugin install caveman@caveman
```

### Source folder moved/deleted

Marketplace points to old path. Re-register:

```powershell
claude plugin marketplace remove caveman
claude plugin marketplace add "<new-path>"
claude plugin install caveman@caveman
```

## Usage

In Claude Code chat:

| Command | Effect |
|---------|--------|
| `/caveman` | Enable full mode (default) |
| `/caveman lite` | Mild — drop filler, keep articles |
| `/caveman full` | Standard — fragments, drop articles |
| `/caveman ultra` | Max compression — abbreviations, arrows |
| `/caveman wenyan` | Classical Chinese 文言文 |
| `/caveman-commit` | Terse Conventional Commits message for staged changes |
| `/caveman-review` | One-line code review of branch changes |

Disable: type `stop caveman` or `normal mode` in chat.

## File locations

| Path | Purpose |
|------|---------|
| `%USERPROFILE%\.local\bin\claude.exe` | CLI binary |
| `%USERPROFILE%\.claude\settings.json` | Enabled plugins + marketplaces |
| `%USERPROFILE%\.claude\plugins\sources\caveman` | Plugin source (do not delete) |
| `%USERPROFILE%\.claude\plugins\cache\caveman\` | Plugin runtime cache |
| `%USERPROFILE%\.claude\plugins\installed_plugins.json` | Install registry |

## Uninstall

```powershell
claude plugin uninstall caveman@caveman
claude plugin marketplace remove caveman
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\sources\caveman"
```

Uninstall Claude Code:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.local\bin\claude.exe"
# Also remove %USERPROFILE%\.local\bin from User PATH manually
```

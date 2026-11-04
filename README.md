# Ship It

A full-screen **SHIP IIIIITTTT** flashes across every monitor whenever something gets merged.

It catches merges two ways, so it works in every Claude Code session *and* for merges made on GitHub:

| Trigger | Catches | Speed |
| --- | --- | --- |
| Claude Code hook (`hook.js`) | `git merge …` (incl. `--squash`), `gh pr merge …` (incl. `--squash`) and merge MCP tools that Claude runs in any session | instant |
| GitHub watcher (`watch.js`) | any PR of yours merged anywhere: the GitHub button, auto-merge, cloud agents, other machines | ~30 s |

If both catch the same merge you still get just one overlay at a time.

Windows only (the overlay is PowerShell + WinForms). Needs [Node.js](https://nodejs.org) and, for the watcher, the [GitHub CLI](https://cli.github.com) logged in (`gh auth login`).

## Install

```bash
git clone https://github.com/<you>/ship-it "%USERPROFILE%/.claude/ship-it"
cd "%USERPROFILE%/.claude/ship-it"
node install.js
```

`install.js` adds the hook to `~/.claude/settings.json`, starts the watcher, and makes it start at every logon (a hidden launcher in your Startup folder). Restart Claude Code sessions that were already open.

## Try it

Preview the overlay without merging anything:

```bash
powershell -NoProfile -STA -ExecutionPolicy Bypass -File shipit.ps1
```

Test the real thing: open a pull request in this repo and merge it. Within about 30 seconds the overlay should hit your screen. `watch.log` shows what the watcher saw; a `FIRE` line means it triggered, followed by `overlay exit 0`. `shipit.log` records every overlay run (screens it covered, skips, errors).

The overlay must be started by `launch.js` (or from a shell), never as a detached process: Windows PowerShell started without a console exits without running the script, which is why it once showed nothing.

## Add a sound

Drop an MP3 named `shipit.mp3` next to `shipit.ps1`. It plays with the overlay, and the overlay stays up as long as the clip (2.2 s minimum, 8 s maximum). The file is git-ignored.

## Tweak it

Everything is in `shipit.ps1`: the text and timing in the `[ShipItOverlay]::Run(...)` call, colors and font in `OnPaint`.

## Uninstall

```bash
node uninstall.js
```

Removes the hook, the logon launcher, and stops the watcher.

## Files

- `shipit.ps1`: the overlay (click-through, never steals focus, one at a time)
- `launch.js`: starts the overlay correctly (hidden console, survives the caller exiting)
- `hook.js`: Claude Code `PostToolUse` hook
- `watch.js`: GitHub merge watcher
- `install.js` / `uninstall.js`: set up and remove everything

## License

MIT

> Merge test: merging this PR should flash SHIP IIIIITTTT.

Merge test 2.

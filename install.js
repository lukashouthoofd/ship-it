// Installs Ship It for the current user:
//  1. a Claude Code PostToolUse hook (merges Claude runs itself), added to ~/.claude/settings.json
//  2. a hidden GitHub watcher (merges made anywhere), started now and at every logon
// Run: node install.js        Undo: node uninstall.js
const fs = require('fs')
const os = require('os')
const path = require('path')
const { spawn } = require('child_process')

const dir = __dirname
const slash = p => p.split(path.sep).join('/')
const settingsPath = path.join(os.homedir(), '.claude', 'settings.json')
const startupVbs = path.join(process.env.APPDATA || '', 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup', 'ship-it-watcher.vbs')

// 1. Claude hook
fs.mkdirSync(path.dirname(settingsPath), { recursive: true })
const settings = fs.existsSync(settingsPath) ? JSON.parse(fs.readFileSync(settingsPath, 'utf8')) : {}
settings.hooks = settings.hooks || {}
settings.hooks.PostToolUse = (settings.hooks.PostToolUse || []).filter(h => !JSON.stringify(h).includes('ship-it'))
settings.hooks.PostToolUse.push({
  matcher: 'Bash|PowerShell|mcp__.*',
  hooks: [{ type: 'command', command: `node "${slash(path.join(dir, 'hook.js'))}"` }],
})
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2))
console.log('Claude hook added to', settingsPath)

// 2. GitHub watcher at logon
if (process.platform === 'win32') {
  const vbs = `' Starts the Ship It GitHub merge watcher hidden at logon. Delete this file to disable.\r\n` +
    `CreateObject("WScript.Shell").Run "node ""${path.join(dir, 'watch.js')}""", 0, False\r\n`
  fs.writeFileSync(startupVbs, vbs)
  console.log('Watcher will start at logon:', startupVbs)
}
spawn(process.execPath, [path.join(dir, 'watch.js')], { detached: true, stdio: 'ignore', windowsHide: true }).unref()
console.log('Watcher started. Needs `gh auth login` once. Log:', path.join(dir, 'watch.log'))
console.log('Restart open Claude sessions so they load the hook. Preview now: powershell -STA -File shipit.ps1')

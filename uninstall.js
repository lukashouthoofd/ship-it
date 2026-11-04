// Removes what install.js added: the Claude hook, the logon launcher, and stops the watcher.
const fs = require('fs')
const os = require('os')
const path = require('path')
const { execFileSync } = require('child_process')

const settingsPath = path.join(os.homedir(), '.claude', 'settings.json')
if (fs.existsSync(settingsPath)) {
  const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'))
  if (settings.hooks && settings.hooks.PostToolUse) {
    settings.hooks.PostToolUse = settings.hooks.PostToolUse.filter(h => !JSON.stringify(h).includes('ship-it'))
    if (!settings.hooks.PostToolUse.length) delete settings.hooks.PostToolUse
    if (!Object.keys(settings.hooks).length) delete settings.hooks
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2))
  }
}
const vbs = path.join(process.env.APPDATA || '', 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup', 'ship-it-watcher.vbs')
if (fs.existsSync(vbs)) fs.unlinkSync(vbs)
if (process.platform === 'win32') {
  try {
    execFileSync('powershell', ['-NoProfile', '-Command',
      "Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" | Where-Object { $_.CommandLine -like '*ship-it*watch.js*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"])
  } catch {}
}
console.log('Ship It uninstalled.')

// Shows the Ship It overlay. Used by hook.js and watch.js.
//
// Why this file exists: Windows PowerShell 5.1 silently exits (code 0, script never runs)
// when it is started without a console. Node's `detached: true` on Windows means
// DETACHED_PROCESS = no console, so spawning powershell detached never showed anything.
// Instead we spawn powershell NON-detached with windowsHide + no inherited stdio, which makes
// libuv pass CREATE_NO_WINDOW: powershell gets a real but invisible console (no Windows
// Terminal window either). Non-detached children die with their parent's job, so callers that
// exit immediately (the hook) run this file as a detached node process, which waits for it.
const { spawn } = require('child_process')
const path = require('path')

function runOverlay(cb) {
  const ps = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(__dirname, 'shipit.ps1')], { stdio: 'ignore', windowsHide: true })
  ps.on('error', e => cb && cb(e))
  ps.on('exit', code => cb && cb(null, code))
  return ps
}

// fire-and-forget from a short-lived process: detached node (fine without a console) runs us
function launchDetached() {
  spawn(process.execPath, [__filename], { detached: true, stdio: 'ignore', windowsHide: true }).unref()
}

module.exports = { runOverlay, launchDetached }

if (require.main === module) runOverlay(() => process.exit(0))

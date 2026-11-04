// Background watcher: flashes the Ship It overlay when any of your GitHub PRs gets merged,
// wherever the merge happened (web button, auto-merge, cloud session, other machine).
// GitHub's search index lags by up to a minute, so it also reads the PR lists of your
// most recently pushed repos, which update immediately.
const { execFile } = require('child_process')
const { runOverlay } = require('./launch')
const fs = require('fs')
const path = require('path')

const POLL_MS = 15000
const seen = new Set()
let primed = false

function log(msg) {
  try { fs.appendFileSync(path.join(__dirname, 'watch.log'), `${new Date().toISOString()} ${msg}\n`) } catch {}
}

function gh(args) {
  return new Promise(resolve =>
    execFile('gh', args, { windowsHide: true, timeout: 30000 }, (err, out) =>
      resolve(err ? null : out.split(/\s+/).filter(Boolean)),
    ),
  )
}

function fire() {
  log('FIRE')
  // not detached: a console-less (detached) powershell exits without running; see launch.js
  runOverlay((err, code) => log(err ? `overlay spawn error: ${err.message}` : `overlay exit ${code}`))
}

async function mergedUrls() {
  const urls = []
  const search = await gh(['api', 'search/issues?q=is:pr+is:merged+involves:@me&sort=updated&order=desc&per_page=15',
    '--jq', '.items[].pull_request.html_url'])
  if (search) urls.push(...search)
  const repos = await gh(['api', 'user/repos?sort=pushed&per_page=6', '--jq', '.[].full_name'])
  for (const repo of repos || []) {
    const prs = await gh(['api', `repos/${repo}/pulls?state=closed&sort=updated&direction=desc&per_page=5`,
      '--jq', '.[] | select(.merged_at) | .html_url'])
    if (prs) urls.push(...prs)
  }
  return search || repos ? urls : null
}

async function poll() {
  try {
    const urls = await mergedUrls()
    if (urls) {
      const fresh = urls.filter(u => !seen.has(u))
      urls.forEach(u => seen.add(u))
      log(`poll ok, ${urls.length} merged, ${fresh.length} new, primed=${primed}`)
      if (primed && fresh.length) fire()
      primed = true
    } else log('poll failed')
  } catch (e) {
    log(`poll error: ${e.message}`)
  }
  setTimeout(poll, POLL_MS)
}

poll()

// PostToolUse hook: flash the Ship It overlay after a successful merge.
const { launchDetached } = require('./launch')
let raw = ''
process.stdin.on('data', d => (raw += d))
process.stdin.on('end', () => {
  try {
    const e = JSON.parse(raw)
    const tool = e.tool_name || ''
    const cmd = (e.tool_input && e.tool_input.command) || ''
    const shell = /^(Bash|PowerShell)$/.test(tool)
    const MERGE = /(^|[;&|]\s*|\s)(git\s+(-\S+\s+)*merge(?!\S)(?!.*--(abort|quit|continue))|gh\s+pr\s+merge)\b/
    const hit = shell ? MERGE.test(cmd)
      : /^mcp__.*(merge_pull_request|merge_pr|pull_request_merge|sync_with_base_branch)/i.test(tool)
    if (!hit) return
    launchDetached()
  } catch {}
})

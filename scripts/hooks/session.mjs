#!/usr/bin/env node
/**
 * session — SessionStart (Cursor) / SessionStart (Claude: --harness=claude)
 */
import {
  readStdin,
  parseHookInput,
  out,
  resolveHarness,
  gateContextLines,
  claudeOut,
} from './shared.mjs'

const harness = resolveHarness()
await readStdin()
parseHookInput('')

const lines = gateContextLines().join('\n')

if (harness === 'claude') {
  claudeOut({
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext: lines,
    },
  })
} else {
  out({
    additional_context: lines,
    env: {
      SDD_SUPERPOWERS: '1',
      SDD_DEFAULT_RAIL: 'intake',
    },
  })
}

# Protocol Thunderdome

> "Two devs enter. One codebase."

AI-powered scrum master and queue-driven workflow for Claude Code. Provides session management, multi-agent coordination, gamified contribution tracking, and isolated sub-agent execution.

## Problem

When using Claude Code for collaborative development:
- Context accumulates and drifts over long sessions
- Multiple agents can conflict on the same files
- No visibility into what's been done or what's pending
- Hard to maintain consistent quality across contributors

## Solution

Thunderdome provides three complementary skills:

| Skill | Purpose |
|-------|---------|
| `/thunderdome` | Scrum master - status, gamification, coordination |
| `/capture-request` | Intent capture - queue work without executing |
| `/work-loop` | Orchestrator - process queue with isolated sub-agents |

## Mental Model

Two terminals:

**Terminal 1: Capture** (human-facing)
```
> /capture-request Add dark mode toggle

Captured 1 request:
1. do-work/requests/20260128-143022-dark-mode.md

> /capture-request Fix the footer bug and add analytics

Captured 2 requests:
1. do-work/requests/20260128-143045-footer-fix.md
2. do-work/requests/20260128-143046-analytics.md
```

**Terminal 2: Worker** (background)
```
$ ./runner/work-loop.sh --watch

Processing: 20260128-143022-dark-mode.md
[Sub-agent spawned]
Completed.

Processing: 20260128-143045-footer-fix.md
[Sub-agent spawned]
Completed.

Queue empty. Waiting for requests...
```

## Install

```bash
# Clone
git clone https://github.com/chickensintrees/claude-thunderdome.git

# Copy skills to Claude Code
cp -r claude-thunderdome/plugins/thunderdome/skills/* ~/.claude/skills/

# Make runner executable
chmod +x claude-thunderdome/runner/work-loop.sh
```

Or install as a plugin marketplace:
```
/plugin marketplace add chickensintrees/claude-thunderdome
/plugin install thunderdome@thunderdome
```

## Usage

### Session Start
```
/thunderdome
```
Shows git status, open PRs, issues, test status, contributor scores.

### Capture Work
```
/capture-request <description>
```
Creates structured request files in `do-work/requests/`.

### Process Queue
```
/work-loop
```
Processes all pending requests with isolated sub-agents.

### Session End
```
/thunderdome debrief
```
Verifies tests pass, changes committed, queue empty.

## Guarantees

- **Context isolation** - Each request runs with fresh context
- **Atomic execution** - Requests complete or fail, no partial states
- **Crash resilience** - Recovery possible from any interruption
- **Audit trail** - All requests preserved in archive/errors

## Directory Structure

```
do-work/
├── requests/     # Pending work
├── in-progress/  # Currently executing (max 1)
├── archive/      # Completed successfully
└── errors/       # Failed with error summary
```

## Gamification

Scoring system incentivizes good practices:

| Action | Points |
|--------|--------|
| Commit with tests | +50 |
| Small commit (<50 lines) | +10 |
| PR merged | +100 |
| **Breaking CI** | **-100** |
| Untested code dump | -75 |

Titles range from "Keyboard Polisher" (0-99) to "Code Demigod" (15000+).

## Request Format

Every request follows a contract:

```markdown
# Request: <title>

## Intent
What outcome is desired.

## Context
Relevant files, constraints, assumptions.

## Tasks
- Step 1
- Step 2

## Done When
Completion criteria.
```

See `templates/request.template.md` for the full template.

## Configuration

Optional `.thunderdome/config.json`:

```json
{
  "contributors": ["user1", "user2"],
  "gamification": true,
  "testCommand": "npm test"
}
```

## Runner Script

For non-interactive/CI use:

```bash
./runner/work-loop.sh          # Process queue, exit when empty
./runner/work-loop.sh --once   # Process one request, exit
./runner/work-loop.sh --watch  # Continuous mode, poll for new
```

## Failure Handling

Failed requests move to `do-work/errors/` with appended error summary:

```markdown
---
## Execution Failed

**Timestamp:** 2026-01-28T14:30:22Z
**Reason:** Tests failed
**Details:** ...
```

Re-queue by moving back to `requests/`.

## Multi-Agent Coordination

When multiple Claude Code instances work on the same repo:
- Declare intent before starting work
- Check for file conflicts
- Safe parallel zones: different components, backend vs frontend, tests vs impl

## Publishing

This skill is designed to be forked and adapted.

Submit to:
- [awesome-claude-skills](https://github.com/daymade/claude-code-skills)
- Claude Code community indexes

## License

MIT

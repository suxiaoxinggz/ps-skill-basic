# Frontend Design Workflow

An orchestration skill for Antigravity, Claude Code, and agentic coding platforms to eliminate "AI slop" and ensure production-grade frontend design craft.

## Overview

This skill establishes a strict 6-phase pipeline that orchestrates existing design intelligence tools:

1. **Phase 1: Design Read & Anti-Slop** (`design-taste-frontend`)
2. **Phase 2: Design Intelligence & Brand Reference** (`meoo-design-kungfu`)
3. **Phase 3: Design System Persistence** (`ui-ux-pro-max`)
4. **Phase 4: Implementation** (Code against frozen tokens)
5. **Phase 5: Craft Review & Quality Floor** (`impeccable`)
6. **Phase 6: Runtime Browser Verification** (Playwright / DevTools)

## Installation

### For Antigravity / Gemini CLI:
Copy or link to `~/.gemini/config/skills/`:
```bash
git clone https://github.com/suxiaoxinggz/ps-skill-basic.git
cp -r ps-skill-basic/frontend-design-workflow ~/.gemini/config/skills/
```

### For Claude Code / Cursor:
Copy to `~/.claude/skills/` or `.agents/skills/`:
```bash
cp -r ps-skill-basic/frontend-design-workflow ~/.claude/skills/
```

## Mandatory Rule (AGENTS.md)

Add the following gate to your project or global `AGENTS.md`:

```markdown
## Mandatory frontend workflow

For any non-trivial frontend design, redesign, dashboard, landing page,
application UI, or major component task:

MUST invoke `frontend-design-workflow` before implementation.

Do not bypass individual workflow stages even if the task appears simple,
unless the user explicitly asks for a targeted isolated change.
```

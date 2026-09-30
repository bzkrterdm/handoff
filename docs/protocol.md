# Task file protocol

A Handoff task is one markdown file. Agents write them, the app and you
edit them, and they stay in your workspace as plain files, so they also
render on GitHub and in Obsidian. This page is the complete format; the
agent-facing instructions are in [`../skills/handoff-task/SKILL.md`](../skills/handoff-task/SKILL.md).

## Where

```
<workspace>/
├── .handoff/tasks/                 ← the task folder Handoff watches
│   ├── acme/api/                   ← project key = path of the project folder
│   │   └── 20260929-1420-api-rate-limiting.md
│   ├── acme/web/
│   └── docs/
├── acme/api/                       ← your projects
├── acme/web/
└── docs/
```

- The **workspace** is the folder your projects live in. Handoff is pointed
  at it once and covers every project below it.
- The **task folder** is `.handoff/tasks` inside the workspace. (`_hub/tasks`
  is accepted too, for workspaces that already keep notes under `_hub`.)
- The **project key** is the path from the workspace root to the project
  folder (`acme/api`). It is the sub folder the task goes in and the group
  the app shows it under. Create the sub folder if it is missing.
- Folders whose name starts with `_` or `.` are not scanned, and
  `README.md` / `index.md` are never tasks, so templates and notes can live
  next to the tasks.

## File name

`YYYYMMDD-HHMM-<project-short>-<topic>.md`, for example
`20260929-1420-api-rate-limiting.md`. The file name without `.md` is the
task's `id` and must be unique across all projects.

## Contents

```markdown
---
id: 20260929-1420-api-rate-limiting
project: acme/api
title: Rate limiting for the public API
agent: claude
created: 2026-09-29T14:20:00+02:00
status: open
related: []
cwd: acme/api
session: 3f9c1b2e-0000-4000-8000-0f9c1b2e3d4a
---

## Done

- What changed and where: files, PR, migration name. Short bullets.

## Info

Results the owner asked for, numbers, warnings, links. May be empty.

## Actions

- [ ] One concrete thing only the owner can do
- [ ] Another, each testable on its own
```

### Front matter

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | same as the file name |
| `project` | yes | project key (folder path); falls back to the folder the file is in |
| `title` | yes | one line, says what was done; falls back to the first `# ` heading, then the id |
| `agent` | yes | `claude`, `codex`, `gemini`, … whatever wrote it |
| `created` | yes | ISO 8601 with a timezone offset |
| `status` | yes | `open` or `done`; anything else reads as `open` |
| `closed` | when done | ISO 8601; written by the app or the agent when the task closes |
| `related` | no | ids of earlier tasks this one touched |
| `cwd` | no | folder to start the agent in for "Connect to agent", relative to the workspace root; defaults to the project key |
| `session` | no | the agent's own session id; when present, "Connect to agent" resumes that conversation |

A malformed front matter line does not break the task: the app reads the
header line by line and keeps what parses.

### Which files are tasks

- Inside `.handoff/tasks` (or `_hub/tasks`) every markdown file is a task,
  except `README.md`, `index.md` and anything under a folder that starts with
  `.` or `_`.
- In any other folder a file is a task only if its front matter has `status`
  and `agent` or `created`, so a repository's docs never show up as tasks.
- `node_modules`, `build`, `dist`, `vendor`, `Pods`, `target` and `venv` are
  never entered, and the app reads at most eight folder levels deep.

### Sections

Three `##` sections. The canonical headings are English; the alternatives
are recognised as well, case-insensitively.

| Section | Heading | Also accepted |
|---|---|---|
| what was done | `## Done` | `Yapılan` |
| things to know | `## Info` | `Notes`, `Bilgi` |
| the checklist | `## Actions` | `Expected`, `Todo`, `Senden beklenenler`, `Beklenenler` |

Checkboxes (`- [ ]` / `- [x]`) count only inside the checklist section, so
a "Done" bullet that happens to contain a checkbox is left alone. Anything
else in the file, including text before the first heading, is preserved
untouched.

## What the app writes

Handoff never regenerates a file. It changes single lines:

- Ticking a box flips ` ` and `x` on that one line.
- **Mark done** sets `status: done` and adds `closed: <now>` to the front
  matter; **Reopen** sets `status: open` and removes `closed`. A file
  without a front matter gets one.

Anything else is yours or the agent's and stays as written.

## What "Connect to agent" runs

The button opens a new window in iTerm (Terminal.app if iTerm is not
installed) and types one line into it:

```bash
cd '<workspace>/<cwd>' && claude '<first message>'
# or, when the task has a session:
cd '<workspace>/<cwd>' && claude --resume '<session>' '<first message>'
# codex:
cd '<workspace>/<cwd>' && codex resume '<session>' '<first message>'
```

The first message is always English. It names the task and its file, asks
the agent to read the file (and the project's own status notes if it keeps
any), and to walk the checklist with you, ticking items in the file as they
finish. The per-item "ask" button sends a variant that is about that one
item only. The exact texts are in
[`lib/shared/domain/agent_prompt.dart`](../lib/shared/domain/agent_prompt.dart).

---
name: handoff-task
description: Leave a Handoff task for the owner when a piece of work is finished, and tick or close the earlier tasks of the same project that this session completed. Use at the end of every session that changed something in a project under this workspace.
---

# Handoff task

The owner does not read transcripts. What they read is `.handoff/tasks/`
at the workspace root: one markdown file per finished piece of work,
grouped by project, shown by the Handoff app. This skill is the protocol
for writing those files. Full format reference: the `docs/protocol.md` of
the Handoff repository (<https://github.com/bzkrterdm/handoff>).

## When

At the end of a session in which you changed something worth the owner's
attention: code, migrations, docs that need a decision, anything that
leaves a step for them (apply, test on a device, approve, answer). A
session that only answered questions leaves no task.

## Steps

1. **Find the workspace root and the project key.** The workspace root is
   the folder that holds `.handoff/tasks` (create it there if this is the
   first task). The project key is the path from that root to the project
   you worked in, for example `acme/api`. Work on the workspace itself
   uses `_workspace`.
2. **Update earlier tasks first.** List `.handoff/tasks/<project-key>/*.md`
   with `status: open`. For each checkbox under `## Actions` that this
   session verifiably completed (you applied the migration, the owner told
   you it was tested, the PR is merged), change `- [ ]` to `- [x]` on that
   line only. If every box is ticked or the task is moot, set
   `status: done` and add `closed: <ISO 8601 now>` to the front matter.
   Never rewrite other lines; never delete a task file.
3. **Write one new task.** Path:
   `.handoff/tasks/<project-key>/<YYYYMMDD-HHMM>-<project-short>-<topic>.md`.
   Start from `task-template.md` next to this file; the file name without
   `.md` is the `id`.
   - `title`: one line, what was done.
   - `## Done`: 2–6 bullets, what changed and where (files, PR, migration
     name). No essays; link the project's docs or a session note for detail.
   - `## Info`: results the owner asked for, numbers, warnings, links.
     Leave empty if nothing.
   - `## Actions`: the important part. One `- [ ]` per concrete action the
     owner must take, each testable ("Apply the migration to staging:
     `pnpm db:migrate --env staging`", "Merge PR #64", "Answer Q-13"). If
     nothing is expected, write `- [ ] For information, read` so the owner
     can acknowledge it.
   - `related`: ids of the earlier tasks you touched in step 2.
   - `cwd` (optional): folder to start you in when the owner clicks
     "Connect to agent", relative to the workspace root. Defaults to the
     project key; set it only when you worked somewhere else.
   - `session` (optional, recommended): your own session id, so the owner
     can resume this very conversation. Claude Code: the newest transcript
     of the current folder is this session —
     `ls -t ~/.claude/projects/$(pwd | sed 's#/#-#g')/*.jsonl | head -1 | xargs basename | sed 's/.jsonl//'`.
     Codex: the id `codex resume` lists for this session. Leave the key out
     if you cannot tell; never guess.
4. **Do not** put secrets, tokens or passwords in a task. Point to where
   they live ("secret manager → acme/staging/DATABASE_URL").
5. Mention the task path in your final message to the owner.

## Example

```markdown
---
id: 20260929-1420-api-rate-limiting
project: acme/api
title: Rate limiting for the public API
agent: claude
created: 2026-09-29T14:20:00+02:00
status: open
related: [20260927-1800-api-pg16]
cwd: acme/api
session: 3f9c1b2e-0000-4000-8000-0f9c1b2e3d4a
---

## Done

- Token bucket limiter in `middleware/rate_limit.ts`, 100 req/min per key.
- 42 new tests, suite green. Migration `20260929_api_keys_tier.sql`.

## Info

- Staging Redis has no persistence; a restart resets every window.

## Actions

- [ ] Review PR #212
- [ ] Apply the migration to staging: `pnpm db:migrate --env staging`
```

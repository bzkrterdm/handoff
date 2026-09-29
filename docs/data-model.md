# Data model

One record type: a **task**. It lives as a markdown file today and will
live as a table row later. This file is the mapping between the two; the
agent-facing format is in [`protocol.md`](protocol.md).

## Fields

| `TaskModel` / column | Markdown | Type | Notes |
|---|---|---|---|
| `id` | front matter `id` (= file name) | text, PK | unique across projects |
| `project` | `project` (fallback: folder path) | text | workspace-relative folder, e.g. `acme/api` |
| `title` | `title` (fallback: first `# ` line, then id) | text | |
| `agent` | `agent` | text | `claude`, `codex`, … |
| `created_at` | `created` | timestamptz | ISO 8601 with offset |
| `closed_at` | `closed` | timestamptz null | set on close, removed on reopen |
| `status` | `status` | text | `open` \| `done`; unknown → open |
| `related` | `related` (yaml list) | text[] | ids of earlier tasks |
| `summary` | `## Yapılan` body | text (markdown) | |
| `info` | `## Bilgi` body | text (markdown) | |
| `actions` | `- [ ]` lines under `## Senden beklenenler` | jsonb `[{text, is_done}]` | order = file order |
| `location` | file path | — | not persisted remotely |
| `cwd` | `cwd` (fallback: project) | text null | relative in the file; the data source resolves it to an absolute folder for the app |
| `session_id` | `session` | text null | agent session to resume on "connect" |

Canonical headings in the public protocol ([`protocol.md`](protocol.md)) are
`Done` / `Info` / `Actions`; the parser also accepts Yapılan, Bilgi/Notes and
Senden beklenenler/Beklenenler/Expected/Todo. Checkboxes outside
the checklist section are ignored on purpose (they may be part of a
"Yapılan" narrative).

## Future Supabase schema (not created)

```sql
create table public.handoff_tasks (
  id          text primary key,
  project     text not null,
  title       text not null,
  agent       text not null,
  created_at  timestamptz not null,
  closed_at   timestamptz,
  status      text not null default 'open' check (status in ('open','done')),
  related     text[] not null default '{}',
  summary     text not null default '',
  info        text not null default '',
  actions     jsonb not null default '[]',
  updated_at  timestamptz not null default now()
);
create index on public.handoff_tasks (project, status, created_at desc);
```

Single user, so RLS is "authenticated owner only". `actions` as jsonb keeps
the write of one checkbox a single-row update, mirroring the single-line
file edit.

## Migration path

1. Add `SupabaseTaskDataSource implements TaskDataSource` in
   `lib/features/tasks/data/data_sources/` (`supabase_flutter`, client
   registered in the locator from `EnvConfig`). `changes` = realtime channel
   on the table.
2. Swap the registration in `DependencyConfig._registerData`.
3. Decide how agents write (Q-02): keep writing files and sync them to the
   table with a script, or write rows directly. The UI does not care.

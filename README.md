<p align="center">
  <img src="docs/icon.png" width="96" alt="Handoff icon">
</p>

<h1 align="center">Handoff</h1>

<p align="center">
  <b>From agents to you.</b><br>
  An inbox for the tasks your coding agents leave behind:<br>
  a macOS app, and the same inbox in the terminal on macOS, Linux and Windows.
</p>

<p align="center">
  <a href="https://github.com/bzkrterdm/handoff/actions/workflows/ci.yaml"><img src="https://github.com/bzkrterdm/handoff/actions/workflows/ci.yaml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/app-macOS-111" alt="macOS app">
  <img src="https://img.shields.io/badge/terminal-macOS%20%7C%20Linux%20%7C%20Windows-111" alt="Terminal app: macOS, Linux, Windows">
  <img src="https://img.shields.io/badge/built%20with-Flutter-02569B" alt="Flutter">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT"></a>
</p>

<p align="center">
  <img src="docs/screenshots/handoff-light.png" width="900" alt="Handoff showing the tasks of a workspace, grouped by project, with the checklist of the selected task">
</p>

## Quick start

1. **Get the app.** Download `Handoff-<version>-macos.zip` from
   [Releases](https://github.com/bzkrterdm/handoff/releases), unzip, drop
   `Handoff.app` into Applications. It is not notarised yet, so open it once
   with right-click → *Open* (or `xattr -d com.apple.quarantine /Applications/Handoff.app`).
   On Linux or Windows, or if you live in a terminal, take the `handoff`
   binary for your platform instead ([In the terminal](#in-the-terminal)).
2. **Pick your workspace.** On first start Handoff asks for a folder: choose
   the one your projects live in. It creates `.handoff/tasks` inside and
   watches it.
3. **Hand the protocol to your agent.** Copy
   [`skills/handoff-task/`](skills/handoff-task) into your workspace as
   `.agents/skills/handoff-task/` and add this line to your `AGENTS.md` or
   `CLAUDE.md`:

   > At the end of every session that changed something, follow
   > `.agents/skills/handoff-task/SKILL.md`.

4. **Work as usual.** From now on every agent session ends with a task in
   your inbox: what it did, what you should know, and a checklist of what
   only you can do. Tick, close, or hit *Connect to agent* to pick the
   conversation back up. Nothing gets lost in a transcript again.

No account, no server: the tasks are markdown files in your repository.

## The problem

Claude Code, Codex, Gemini CLI and friends finish a piece of work and the
result lives in a transcript you will never read again. What you actually
need from each session fits on a card: **what was done, what you should
know, and the two or three things only you can do next** (merge the PR,
apply the migration, test on the device, answer a question).

Handoff turns that card into a convention and gives it a window:

- Every agent session ends by writing **one small markdown file** into
  `.handoff/tasks/<project>/` in your workspace. A checklist of what is
  expected from you is the heart of it.
- **Handoff watches the folder** and shows the tasks grouped by project,
  open or done, with progress. Tick a box and the app edits that one line
  in the file. Mark a task done and it stamps `status: done`.
- **Connect to agent** opens a terminal in the task's folder, resumes the
  very session that wrote it, and hands the agent the task file so you can
  continue in conversation.

No server, no account, no database. Plain files in your repository, which
also render on GitHub and in Obsidian, and stay useful when the app is not
running.

## How it works

```
 ┌──────────────┐   writes    ┌────────────────────────────┐   watches   ┌──────────────┐
 │ coding agent │ ──────────► │ .handoff/tasks/<project>/  │ ◄─────────  │   Handoff    │
 │ (end of      │             │   20260929-1420-…-.md      │ ──────────► │  (this app)  │
 │  session)    │ ◄────────── │   - [ ] merge PR #212      │  edits one  │              │
 └──────────────┘  "connect"  │   - [x] apply migration    │    line     └──────────────┘
                    resumes   └────────────────────────────┘
```

1. **Teach your agents the protocol.** Copy
   [`skills/handoff-task/`](skills/handoff-task) into your workspace as a
   skill (`.agents/skills/handoff-task/` works for Claude Code, Codex and
   most agents; Claude Code also reads `.claude/skills/`) and add one line
   to your `AGENTS.md` or `CLAUDE.md`:

   > At the end of every session that changed something, follow
   > `.agents/skills/handoff-task/SKILL.md`.

2. **Point Handoff at your workspace** the first time it starts. The
   workspace is the folder your projects live in; Handoff creates
   `.handoff/tasks` inside it and watches everything below.

   <p align="center">
     <img src="docs/screenshots/handoff-welcome.png" width="620" alt="First start: choose the workspace folder">
   </p>

3. **Work from the inbox.** New tasks appear as agents finish. Tick, close,
   open the file, or connect to the agent.

## Install

Handoff runs on macOS 12 or later. There is no signed build yet, so pick one:

**From a release.** Download `Handoff-<version>-macos.zip` from the
[Releases](https://github.com/bzkrterdm/handoff/releases) page, unzip, move
`Handoff.app` to Applications. Because the app is not notarised, macOS will
refuse to open it the first time; right-click it and choose *Open*, or run:

```bash
xattr -d com.apple.quarantine /Applications/Handoff.app
```

**From source.** With [Flutter](https://docs.flutter.dev/get-started/install)
3.47 or newer:

```bash
git clone https://github.com/bzkrterdm/handoff.git
cd handoff
flutter pub get
flutter build macos --release -t lib/main_prod.dart
open build/macos/Build/Products/Release/Handoff.app
```

Or run it straight away against the bundled example workspace, no agents
needed:

```bash
flutter run -d macos -t lib/main_dev.dart \
  --dart-define=HANDOFF_TASKS_DIR="$PWD/example/.handoff/tasks"
```

> Handoff reads whatever folder you point it at, so the macOS App Sandbox
> is turned off in the entitlements. It never leaves your machine: the app
> has no network code paths in use.

## Using the app

<p align="center">
  <img src="docs/screenshots/handoff-dark.png" width="900" alt="Handoff in dark mode">
</p>

- **Sidebar.** Every project that has tasks, with its open count, and the
  workspace folder at the bottom (click to reveal it in Finder, the folder
  button to change it). The gear holds **Language** (system default,
  English, Türkçe) and **Appearance** (system, light, dark).
- **List.** Open or done tasks of the selected project, newest first, with
  the agent, the date and the checklist progress.
- **Detail.** The checklist first, since it is what you act on, then what
  was done, what you should know, and related tasks. Everything is
  rendered from the markdown file; *Open file* and *Show in Finder* take
  you to it.
- **Ticking a box** rewrites that one line in the file (`- [ ]` ↔ `- [x]`).
  Nothing else in the file is touched, ever.
- **Mark done** writes `status: done` and `closed: <now>` into the front
  matter; **Reopen** reverses it after a confirmation.
- **Dock badge** shows the number of open tasks.
- **Connect to agent** opens a new iTerm window (Terminal.app if iTerm is
  not installed) in the task's folder and starts the agent that wrote the
  task, resuming its session when the task records one:

  ```bash
  cd '<workspace>/acme/api' && claude --resume '<session>' '<first message>'
  ```

  The first message, always in English, tells the agent to read the task
  file and walk the checklist with you, ticking items in the file as they
  are finished. Hover an item and press the speech bubble to send a message
  about **that item only**. `claude` and `codex` are supported today;
  anything else falls back to `claude`.

## In the terminal

`handoff` is the same inbox as a terminal app: one self-contained binary
for macOS, Linux and Windows, no Flutter or Dart needed to run it. It reads
and writes the task files with the very same code as the desktop app
([`packages/handoff_core`](packages/handoff_core)), so both can be open on
the same folder at once.

```
 ⇄ Handoff  ·  example                                         4 open   ? Help
 Projects               │  Open 4   Done 2                  │  ▪ acme/api
                        │                                   │
▌ All projects        4 │▌ Rate limiting for the public API │  Rate limiting for the public API
  acme/api            2 │▌ ● claude  ·  acme/api     29 Sep │  ● claude  ·  29 Sep 2026, 15:20
  acme/web            1 │▌ ━━━━━━━━━──────────────────  1/4 │
  docs                1 │                                   │  [d] Mark done   [a] Connect to agent
                        │  Dark mode for the settings page  │  [e] Edit   [o] Open file   [f] Show in Finder
                        │  ● gemini  ·  acme/web     29 Sep │
                        │  ─────────────────────────── 0/2  │  ▍ Expected from you          1/4 done
                        │                                   │  1 [✓] Review PR #212 (feat/rate-limiting)
                        │                                   │▌ 2 [ ] Apply the migration to staging
```

**Install.** Download `handoff-<version>-<platform>` from
[Releases](https://github.com/bzkrterdm/handoff/releases) (`macos-arm64`,
`linux-x64`, `windows-x64`), unpack it and put `handoff` (`handoff.exe`)
on your `PATH`. Or build it with Dart 3.12+:

```bash
cd tui
dart pub get
dart compile exe bin/handoff.dart -o handoff
```

**Run.** `handoff` opens the folder you used last, or asks for one (a
folder browser; `/` lets you type a path). `handoff <folder>` picks a
workspace directly, exactly like choosing it in the app.

| Key | Does |
|-----|------|
| `↑` `↓` / `j` `k` | Move in the pane |
| `Tab` / `←` `→` / `h` `l` | Switch between projects, list and details |
| `Enter` | Go into the selected project / task, tick in the details |
| `Space` | Tick the checklist item under the cursor |
| `1`–`9` | Tick that item from anywhere |
| `t` | Open ↔ Done list |
| `d` / `u` | Mark done / reopen (asks first) |
| `a` | Connect to the task's agent |
| `i` | Ask the agent about the item under the cursor only |
| `e` | Edit the task file in `$EDITOR` |
| `o` / `f` | Open the file in its app / show it in the file manager |
| `w` / `W` | Choose / open the workspace folder |
| `r` | Refresh (the folder is watched anyway) |
| `,` | Language (system, English, Türkçe) and appearance (system, light, dark) |
| `?` / `q` | Help / quit |

Everything the desktop app does is here; what differs is where it happens:

- **Connect to agent** starts the agent in *this* terminal, in the task's
  folder, with the same English first message and `--resume` session;
  Handoff comes back when you leave the agent. Inside tmux it opens a new
  tmux window instead, so the inbox stays on screen.
- **The Dock badge** becomes the window title: `Handoff (3)`.
- **Settings** live in `~/.config/handoff/tui.json` (`$XDG_CONFIG_HOME`
  respected; `%APPDATA%\handoff\tui.json` on Windows), not in the desktop
  app's preferences, so pick the folder once in each.
- **Appearance "system"** uses your terminal's own colours; light and dark
  paint their own background.
- The window splits like the desktop app when it is wide enough, shows the
  list and the details when it is medium, and one pane at a time when it is
  narrow (`Esc` goes back).

## The task file

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

- Token bucket limiter in `middleware/rate_limit.ts`, 100 req/min per key.
- 42 new tests, suite green. Migration `20260929_api_keys_tier.sql`.

## Info

- Staging Redis has no persistence; a restart resets every window.

## Actions

- [x] Review PR #212
- [ ] Apply the migration to staging: `pnpm db:migrate --env staging`
- [ ] Decide the prod limits for the enterprise tier
```

Three sections and a checklist. Turkish headings (`Yapılan`, `Bilgi`,
`Senden beklenenler`) and a few English synonyms are recognised as well.
The full reference, including every front matter field and exactly what
the app writes, is in [docs/protocol.md](docs/protocol.md).

## For agents

[`skills/handoff-task/SKILL.md`](skills/handoff-task/SKILL.md) is the
protocol written for the agent: when to leave a task, how to tick the
earlier tasks of the same project first, how to find its own session id so
"Connect to agent" can resume it, and what never goes into a task
(secrets). [`task-template.md`](skills/handoff-task/task-template.md) sits
next to it. Both are plain markdown, so they work with any agent that
reads instructions from the repository.

## Development

```bash
dart format .
flutter analyze
flutter test
(cd packages/handoff_core && dart test)
(cd tui && dart analyze && dart test)
```

That is the whole gate, and what CI runs (the terminal app's tests on
macOS, Linux and Windows); the desktop app is not built in CI.
The rules of the codebase are in [AGENTS.md](AGENTS.md), the architecture
in [docs/architecture.md](docs/architecture.md) and the task file's mapping
to the model in [docs/data-model.md](docs/data-model.md).

`lib/stack/` is a small clean-architecture stack (base classes, DI,
routing, theming, localization); `lib/features/tasks/` is the app. The
task format and the folder store are plain Dart in
[`packages/handoff_core`](packages/handoff_core), shared by the desktop app
and the terminal app ([`tui/`](tui)). The task store is one interface
(`TaskDataSource`); the markdown folder is its only implementation today,
and a remote one can be added without touching either UI.

## Roadmap

- Keyboard in the desktop app (the terminal app has it): ↑↓ through tasks,
  space to tick, ⌘R to refresh.
- Search and filters (agent, date).
- More agents for "Connect to agent" (Gemini CLI, …).
- An optional remote store, so the inbox follows you across machines.

Ideas and bug reports are welcome as issues; see
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE).

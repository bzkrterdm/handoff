# Architecture

> Code-facing notes for contributors. The maintainers' decision log and
> progress notes are kept outside this repository.

Handoff is a single-feature Flutter macOS app on a small clean-architecture
stack (`lib/stack/`: base classes, data layer, DI, routing, theming,
localization), plus a terminal app for macOS, Linux and Windows (`tui/`).
Both build on `packages/handoff_core`, the task format and folder store in
plain Dart. This file records what they add on top of the stack.

## Data flow

```
.handoff/tasks/**/*.md  ──(DirectoryWatcher)──►  MarkdownTaskDataSource
        ▲                                          │  TaskModel
        │ line-level edits                         ▼
        └───────────────────────────────  TaskRepositoryImpl
                                                   │  HandoffTask (Result)
                                                   ▼
                      WatchTasks (stream) · SetActionDone · SetTaskStatus
                                                   │
                                                   ▼
                                              TasksCubit ── TasksState
                                                   │
                                                   ▼
                    TasksController ◄── TasksPage ── ProjectColumn
                          │                       ├── TaskListColumn
                          ▼                       └── TaskDetailColumn
                    ExternalOpener (open / open -R)
```

- **Source of truth is the folder.** The cubit never patches its own copy
  for long: a write returns the stored task (applied immediately for
  responsiveness), then the watcher's change event reloads everything.
- **One state object** (`TasksLoaded`) holds the list, the selected project,
  the selected task and the open/done filter, so the three columns always
  render one consistent snapshot. Derived views (`projects`,
  `visibleTasks`, `selectedTask`) are getters on the state.
- **Selection rules.** Changing project or filter selects the first visible
  task; a reload keeps the selection if the task still exists, otherwise
  falls back the same way.

## Layers

| Layer | Files | Notes |
|-------|-------|-------|
| domain | `entities/handoff_task.dart`, `task_action.dart`, `task_status.dart` | `HandoffTask` (not `Task`: the stack has a presentation `Task`) |
| domain | `repositories/task_repository.dart` | `getAll`, `onChanged`, `setActionDone`, `setStatus` |
| domain | `use_cases/watch_tasks.dart` | `StreamUseCase` over a `StreamController` |
| domain | `use_cases/set_action_done.dart`, `set_task_status.dart` | `UseCase` with `Equatable` params |
| core | `task_data_source.dart` (re-exported from `data_sources/`) | the store contract — Supabase implements this |
| core | `task_markdown_parser.dart` (re-exported) | parse + `withActionDone` + `withStatus`, line-level |
| core | `markdown_task_data_source.dart` (re-exported) | recursive scan, id→path index, debounced watcher, `package:path` paths; skipped files go to a `TaskStoreLog` callback (the app passes its logger) |
| core | `task_model.dart` | `@JsonSerializable`, snake_case = future columns; `data/models/task_model_mapping.dart` maps it to `HandoffTask` |
| data | `repositories/task_repository_impl.dart` | exceptions → `Failure`, sort newest first |
| presentation | `blocs/tasks_cubit.dart` (+ `tasks_state.dart`) | |
| presentation | `ui/controllers/tasks_controller.dart` | reopen asks `ConfirmTask`; opens files via `ExternalOpener` |
| presentation | `ui/pages/tasks_page.dart`, `ui/widgets/*` | three fixed-width columns + expanded detail; `settings_menu.dart` = language and appearance; the error view doubles as the welcome screen when no folder is set |
| core | `workspace_layout.dart` (re-exported from `domain/entities/`) | task folder names, workspace root of a task folder |
| core | `agent_prompt.dart` (re-exported from `shared/domain/`) | the English first message for "connect to agent" |
| data | `data_sources/workspace_settings_impl.dart` | remembered folder (`shared_preferences`); the contract is in core |
| shared | `domain/external_opener.dart`, `data/external_opener_impl.dart` | `Process.run('open', …)` |
| shared | `domain/folder_picker.dart`, `data/folder_picker_impl.dart` | `file_selector.getDirectoryPath` |
| shared | `domain/dock_badge.dart`, `data/dock_badge_impl.dart` | method channel `handoff/dock` → `DockBadgeChannel.swift` |
| shared | `domain/agent_launcher.dart`, `data/agent_launcher_impl.dart` | `AgentCommand.shellLine` (core) + AppleScript into iTerm/Terminal |
| shared | `presentation/theme/app_theme.dart` | seed `#3B5BDB`, pill buttons, round checkboxes, `AppLayout` constants |
| shared | `presentation/format/date_text.dart` | "Bugün 11:00", "Dün", "29 Eyl" from translation keys |
| shared | `presentation/widgets/` | `MarkdownText` (+`inline`), `AgentAvatar`, `ProgressBar`, `EmptyState`, `HoverSurface` |

## Shared core (`packages/handoff_core`)

The task format and the folder store are plain Dart with no Flutter
dependency, so the desktop app and the terminal app read, tick and close
task files with the same code. The app's old files under `lib/` stay
as one-line re-exports, so imports and tests did not change.

| File | Contents |
|------|----------|
| `task_model.dart` (+ `.g.dart`) | storage shape, snake_case JSON |
| `task_markdown_parser.dart` | parse, `isTask`, line-level `withActionDone` / `withStatus` |
| `markdown_task_data_source.dart` | the folder store (scan rules, watcher, `setLocation`) |
| `task_data_source.dart`, `workspace_settings.dart` | the store contract, the remembered folder contract |
| `workspace_layout.dart` | task folder names and the workspace root; accepts `/` and `\` |
| `agent_prompt.dart` | the English first message |
| `agent_launch.dart` | `AgentLaunch`; `AgentCommand.arguments` (argv, no shell) and `shellLine` |

Paths are built with `package:path`; project keys are always written with
`/` (`acme/web`) because they go into task files.

## Terminal app (`tui/`)

A Dart command-line app, `handoff`, compiled to one binary per platform
(`dart compile exe`). No TUI framework: a small terminal layer and a
painter, so nothing between the app and the terminal can break on one
platform.

| Folder / file | Contents |
|---------------|----------|
| `bin/handoff.dart` | arguments (`[folder]`, `--config`), wiring, crash guard |
| `lib/src/terminal/` | `StdTerminal` (raw mode, alternate screen, resize and interrupt signals, `suspend` for child processes), `KeyDecoder` (VT sequences), `Canvas` + `FrameWriter` (row diff), `TextWidth` / `Wrap`, `Style` (truecolour or xterm-256, `NO_COLOR`), `WindowsConsole` (kernel32 FFI: VT input/output) |
| `lib/src/app/board.dart` | the desktop `TasksLoaded` + `TasksCubit` selection rules on `TaskModel` |
| `lib/src/app/app.dart` | `HandoffApp`: keys → actions, numbered reloads on store changes, writes, agent / editor / opener |
| `lib/src/app/views.dart` | `Painter`: wide (3 panes) / medium (2) / narrow (1) layouts, dialogs |
| `lib/src/app/ui_state.dart` | focus, cursor, scroll, toast, modals (confirm, help, settings, folder picker) |
| `lib/src/app/settings.dart` | `TuiSettings`: folder, language, appearance in `~/.config/handoff/tui.json` |
| `lib/src/app/system.dart` | `open` / `xdg-open` / `start`, reveal, `$EDITOR`, `Process.start(inheritStdio)`, tmux window |
| `lib/src/app/strings.dart` | the desktop app's en/tr texts plus key hints |

Desktop → terminal mapping: connect to agent runs the agent attached to
this terminal (`AgentCommand.arguments`, no shell quoting) and returns when
it exits, or opens a tmux window inside tmux; the Dock badge is the window
title `Handoff (n)`; the folder dialog is an in-app folder browser; hover
actions are keys (`?` lists them).

Tests (`tui/test/`): key decoding, text width and wrapping, frame diff,
colours, board rules, settings, and the whole app against a copy of
`example/` through a fake terminal and a fake shell. CI runs them on
macOS, Linux and Windows and compiles the binary on each.

## Configuration

- `EnvConfig.tasksDirectory` — the task folder to start with, resolved in
  `EnvConfigs` from `HANDOFF_TASKS_DIR`; empty when not given, which makes
  the first start show the welcome screen and ask for a workspace.
  The folder the owner picked in the app (`WorkspaceSettings`) wins
  over it. Read only in `DependencyConfig._registerData`.
- Workspace vs task folder: the user picks the workspace root, the store
  resolves (and creates) `.handoff/tasks` inside it
  (`MarkdownTaskDataSource.resolveTasksDirectory`); the path rules are in
  the domain (`WorkspaceLayout`) so the sidebar can name the root too.
- `EnvConfig.apiSetupParams` — unused for now; kept for the Supabase/HTTP
  path so the bootstrap does not change.
- Localization: device language, `en` fallback, `tr` shipped; the settings
  menu switches language (system / en / tr) and appearance.
- The first message to an agent is English and built in
  `shared/domain/agent_prompt.dart`, not translated.

## macOS

- Generated with `flutter create --platforms=macos`; bundle id
  `io.github.bzkrterdm.handoff`, product name `Handoff`.
- Sandbox off in both entitlement files. Turning it on breaks
  reading the workspace.
- `MainFlutterWindow.swift`: transparent title bar, full-size content view,
  min size 980×620; the Dart side pads each column by
  `AppLayout.titleBarHeight` for the traffic lights. `DockBadgeChannel.swift`
  handles `setBadge`.
- Plugins compiled for macOS: `connectivity_plus`, `device_info_plus`,
  `flutter_secure_storage`, `path_provider`, `shared_preferences`.
  `permission_handler` and `android_path_provider` have no macOS side and
  are simply not registered.
- Run: `flutter run -d macos -t lib/main_dev.dart`.

## Tests (desktop app: 121)

- `test/features/tasks/data/…` — parser (round trip, line-level edits,
  broken yaml), data source against a temp folder (scan, ignore rules,
  edits on disk, watcher event), repository mapping.
- `test/features/tasks/presentation/…` — cubit with a mocked repository and
  a manual change stream; page with a mocked cubit on a 1400×900 surface.
- `test/main_base_test.dart` — boots the real tree against a temp task
  folder (`tester.runAsync` for real I/O).
- `test/stack/*`, `test/architecture_test.dart` — inherited from the stack.

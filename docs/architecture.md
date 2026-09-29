# Architecture

> Code-facing notes for contributors. The maintainers' decision log and
> progress notes are kept outside this repository.

Handoff is a single-feature Flutter macOS app on a small clean-architecture
stack (`lib/stack/`: base classes, data layer, DI, routing, theming,
localization). This file records what the app adds on top of it.

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
| data | `data_sources/task_data_source.dart` | the store contract — Supabase implements this |
| data | `data_sources/task_markdown_parser.dart` | parse + `withActionDone` + `withStatus`, line-level |
| data | `data_sources/markdown_task_data_source.dart` | recursive scan, id→path index, debounced watcher |
| data | `models/task_model.dart` | `@JsonSerializable`, snake_case = future columns |
| data | `repositories/task_repository_impl.dart` | exceptions → `Failure`, sort newest first |
| presentation | `blocs/tasks_cubit.dart` (+ `tasks_state.dart`) | |
| presentation | `ui/controllers/tasks_controller.dart` | reopen asks `ConfirmTask`; opens files via `ExternalOpener` |
| presentation | `ui/pages/tasks_page.dart`, `ui/widgets/*` | three fixed-width columns + expanded detail; `settings_menu.dart` = language and appearance; the error view doubles as the welcome screen when no folder is set |
| domain | `entities/workspace_layout.dart` | task folder names, workspace root of a task folder |
| shared | `domain/agent_prompt.dart` | the English first message for "connect to agent" |
| data | `data_sources/workspace_settings.dart` | remembered folder (`shared_preferences`) |
| shared | `domain/external_opener.dart`, `data/external_opener_impl.dart` | `Process.run('open', …)` |
| shared | `domain/folder_picker.dart`, `data/folder_picker_impl.dart` | `file_selector.getDirectoryPath` |
| shared | `domain/dock_badge.dart`, `data/dock_badge_impl.dart` | method channel `handoff/dock` → `DockBadgeChannel.swift` |
| shared | `domain/agent_launcher.dart`, `data/agent_launcher_impl.dart` | `AgentCommand.shellLine` + AppleScript into iTerm/Terminal |
| shared | `presentation/theme/app_theme.dart` | seed `#3B5BDB`, pill buttons, round checkboxes, `AppLayout` constants |
| shared | `presentation/format/date_text.dart` | "Bugün 11:00", "Dün", "29 Eyl" from translation keys |
| shared | `presentation/widgets/` | `MarkdownText` (+`inline`), `AgentAvatar`, `ProgressBar`, `EmptyState`, `HoverSurface` |

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

## Tests (115)

- `test/features/tasks/data/…` — parser (round trip, line-level edits,
  broken yaml), data source against a temp folder (scan, ignore rules,
  edits on disk, watcher event), repository mapping.
- `test/features/tasks/presentation/…` — cubit with a mocked repository and
  a manual change stream; page with a mocked cubit on a 1400×900 surface.
- `test/main_base_test.dart` — boots the real tree against a temp task
  folder (`tester.runAsync` for real I/O).
- `test/stack/*`, `test/architecture_test.dart` — inherited from the stack.

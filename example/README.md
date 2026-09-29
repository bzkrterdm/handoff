# Example workspace

A small workspace to try Handoff with, no agents required. Point the app at
this folder (or start it with the folder preselected):

```bash
flutter run -d macos -t lib/main_dev.dart \
  --dart-define=HANDOFF_TASKS_DIR="$PWD/example/.handoff/tasks"
```

`.handoff/tasks/` holds the tasks, one folder per project key (`acme/api`,
`acme/web`, `docs`). The project folders next to it exist only so that
"Connect to agent" has a folder to open a terminal in.

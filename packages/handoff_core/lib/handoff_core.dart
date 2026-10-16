/// The task format and the folder store behind Handoff.
///
/// Plain Dart with no Flutter dependency: the desktop app and the terminal
/// app both build on it, so a task file is read, ticked and closed exactly
/// the same way from either.
library;

export 'src/agent_launch.dart';
export 'src/agent_prompt.dart';
export 'src/markdown_task_data_source.dart';
export 'src/task_data_source.dart';
export 'src/task_markdown_parser.dart';
export 'src/task_model.dart';
export 'src/workspace_layout.dart';
export 'src/workspace_settings.dart';

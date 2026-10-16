import 'package:handoff_core/handoff_core.dart';

export 'package:handoff_core/handoff_core.dart' show AgentLaunch;

/// Opens a terminal with a coding agent started (or resumed) in a folder,
/// with a first message already sent, so the owner can pick a task up in
/// conversation right away.
abstract class AgentLauncher {
  Future<void> launch(AgentLaunch launch);
}

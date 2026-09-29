import 'package:equatable/equatable.dart';

/// Opens a terminal with a coding agent started (or resumed) in a folder,
/// with a first message already sent, so the owner can pick a task up in
/// conversation right away.
abstract class AgentLauncher {
  Future<void> launch(AgentLaunch launch);
}

/// What to start: which agent, where, with which message, and optionally
/// which earlier session to continue.
class AgentLaunch extends Equatable {
  const AgentLaunch({
    required this.agent,
    required this.workingDirectory,
    required this.prompt,
    this.sessionId,
  });

  /// `claude`, `codex`, … as the task names it. Unknown names fall back to
  /// Claude.
  final String agent;

  /// Absolute folder to start in.
  final String workingDirectory;

  final String prompt;
  final String? sessionId;

  @override
  List<Object?> get props => [agent, workingDirectory, prompt, sessionId];
}

import 'package:equatable/equatable.dart';

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

/// The command line per agent — pure, so it is unit tested without a
/// terminal.
abstract class AgentCommand {
  /// The program and its arguments, for starting the agent directly (no
  /// shell, so nothing needs quoting): `claude [--resume <id>] <prompt>`.
  static List<String> arguments(AgentLaunch launch) {
    final session = launch.sessionId;

    return switch (launch.agent.trim().toLowerCase()) {
      'codex' => [
        'codex',
        if (session != null) ...['resume', session],
        launch.prompt,
      ],
      _ => [
        'claude',
        if (session != null) ...['--resume', session],
        launch.prompt,
      ],
    };
  }

  /// `cd '<dir>' && <agent> [resume] '<prompt>'`, for typing into a POSIX
  /// shell (a new terminal window, a tmux window).
  static String shellLine(AgentLaunch launch) {
    // Flags and the program name stay bare; values are quoted.
    const bare = {'claude', 'codex', 'resume', '--resume'};
    final words = [
      for (final (i, word) in arguments(launch).indexed)
        i == 0 || (bare.contains(word) && i < 2) ? word : quote(word),
    ];

    return 'cd ${quote(launch.workingDirectory)} && ${words.join(' ')}';
  }

  /// Single-quotes [value] for POSIX shells.
  static String quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}

import 'dart:io';

import 'package:handoff_core/handoff_core.dart';

import '../../stack/core/logging/logger.dart';
import '../domain/agent_launcher.dart';

export 'package:handoff_core/handoff_core.dart' show AgentCommand;

/// Builds the shell line for an [AgentLaunch] and types it into a new
/// iTerm window (Terminal.app when iTerm is not installed). AppleScript
/// receives the line as an argument, so no quoting survives two layers.
class AgentLauncherImpl implements AgentLauncher {
  AgentLauncherImpl(this._logger);

  static const String _iterm = '/Applications/iTerm.app';

  final Logger _logger;

  @override
  Future<void> launch(AgentLaunch launch) async {
    final line = AgentCommand.shellLine(launch);
    final useIterm = Directory(_iterm).existsSync();
    final result = await Process.run('osascript', [
      '-e',
      useIterm ? _itermScript : _terminalScript,
      line,
    ]);
    if (result.exitCode != 0) {
      _logger.error(
        'Agent launch failed (${result.exitCode}): ${result.stderr}',
        callerType: runtimeType,
      );
    }
  }

  // Helpers
  static const String _itermScript = '''
on run argv
  tell application "iTerm"
    activate
    set newWindow to (create window with default profile)
    tell current session of newWindow to write text (item 1 of argv)
  end tell
end run''';

  static const String _terminalScript = '''
on run argv
  tell application "Terminal"
    activate
    do script (item 1 of argv)
  end tell
end run''';

  // - Helpers
}

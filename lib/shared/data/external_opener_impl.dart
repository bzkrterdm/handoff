import 'dart:io';

import '../../stack/core/logging/logger.dart';
import '../domain/external_opener.dart';

/// macOS implementation over the `open` command. Kept dependency-free on
/// purpose: a url launcher plugin would buy nothing on a desktop-only tool.
class ExternalOpenerImpl implements ExternalOpener {
  ExternalOpenerImpl(this._logger);

  final Logger _logger;

  @override
  Future<void> open(String location) => _run(['open', location]);

  @override
  Future<void> reveal(String location) => _run(['open', '-R', location]);

  // Helpers
  Future<void> _run(List<String> command) async {
    final result = await Process.run(command.first, command.sublist(1));
    if (result.exitCode != 0) {
      _logger.error(
        'Command failed (${result.exitCode}): ${command.join(' ')}\n'
        '${result.stderr}',
        callerType: runtimeType,
      );
    }
  }

  // - Helpers
}

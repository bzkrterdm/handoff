import 'dart:async';
import 'dart:io';

import 'keys.dart';
import 'style.dart';
import 'windows_console.dart';

/// What the app needs from a terminal. [StdTerminal] is the real one; tests
/// drive the app through a fake with a fixed size.
abstract class TerminalIO {
  int get width;

  int get height;

  ColorMode get colorMode;

  Stream<Key> get keys;

  /// Fires after the window changed size.
  Stream<void> get resizes;

  /// Ctrl-C delivered as a signal, or a termination request.
  Stream<void> get interrupts;

  /// Full-screen mode: alternate screen, no echo, no line buffering.
  void enter();

  /// Back to the shell as it was.
  void leave();

  void write(String data);

  void setTitle(String title);

  /// Hands the terminal to [body] (an editor, a coding agent) and takes it
  /// back afterwards.
  Future<T> suspend<T>(Future<T> Function() body);
}

/// The process's own terminal: stdin, stdout and the platform's resize and
/// interrupt signals.
class StdTerminal implements TerminalIO {
  StdTerminal() : colorMode = ColorMode.detect();

  static const String _enterSequence =
      '\x1b[22;0t' // remember the window title
      '\x1b[?1049h' // alternate screen
      '\x1b[?25l' // hide the cursor
      '\x1b[?7l'; // no auto-wrap: the last column never scrolls
  static const String _leaveSequence =
      '\x1b[0m\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[23;0t';

  @override
  final ColorMode colorMode;

  final KeyDecoder _decoder = KeyDecoder();
  final StreamController<Key> _keys = StreamController.broadcast();
  final StreamController<void> _resizes = StreamController.broadcast();
  final StreamController<void> _interrupts = StreamController.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  StreamSubscription<List<int>>? _input;
  Timer? _sizePoll;
  bool _active = false;

  /// Whether stdin and stdout are an interactive terminal.
  static bool get isInteractive => stdin.hasTerminal && stdout.hasTerminal;

  @override
  int get width => stdout.hasTerminal ? stdout.terminalColumns : 80;

  @override
  int get height => stdout.hasTerminal ? stdout.terminalLines : 24;

  @override
  Stream<Key> get keys => _keys.stream;

  @override
  Stream<void> get resizes => _resizes.stream;

  @override
  Stream<void> get interrupts => _interrupts.stream;

  @override
  void enter() {
    if (_input == null) _listen();
    _rawMode(on: true);
    stdout.write(_enterSequence);
    _active = true;
  }

  @override
  void leave() {
    if (!_active) return;
    _active = false;
    stdout.write(_leaveSequence);
    _rawMode(on: false);
  }

  /// Leaves full-screen mode and stops listening for good.
  Future<void> close() async {
    leave();
    _sizePoll?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await stdout.flush();
    // Cancelling stdin would block until the next key; the process exits
    // right after this anyway.
    _input?.pause();
  }

  @override
  void write(String data) => stdout.write(data);

  @override
  void setTitle(String title) => stdout.write('\x1b]0;$title\x07');

  @override
  Future<T> suspend<T>(Future<T> Function() body) async {
    _input?.pause();
    leave();
    await stdout.flush();
    try {
      return await body();
    } finally {
      enter();
      _input?.resume();
      _resizes.add(null);
    }
  }

  // Helpers
  void _listen() {
    _input = stdin.listen((bytes) {
      for (final key in _decoder.decode(bytes)) {
        _keys.add(key);
      }
    });

    if (Platform.isWindows) {
      // No SIGWINCH on Windows: watch the size instead.
      var last = (width, height);
      _sizePoll = Timer.periodic(const Duration(milliseconds: 300), (_) {
        final now = (width, height);
        if (now != last) {
          last = now;
          _resizes.add(null);
        }
      });
    } else {
      _subscriptions
        ..add(ProcessSignal.sigwinch.watch().listen((_) => _resizes.add(null)))
        ..add(
          ProcessSignal.sigterm.watch().listen((_) => _interrupts.add(null)),
        );
    }
    _subscriptions.add(
      ProcessSignal.sigint.watch().listen((_) => _interrupts.add(null)),
    );
  }

  void _rawMode({required bool on}) {
    try {
      if (on) {
        // Echo has to go before line mode on Windows.
        stdin.echoMode = false;
        stdin.lineMode = false;
        WindowsConsole.enable();
      } else {
        WindowsConsole.restore();
        stdin.lineMode = true;
        stdin.echoMode = true;
      }
    } on StdinException {
      // Not a terminal; the caller checked [isInteractive] already.
    }
  }

  // - Helpers
}

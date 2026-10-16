import 'dart:async';
import 'dart:io';

import 'package:handoff_core/handoff_core.dart';
import 'package:handoff_tui/handoff_tui.dart';

/// A terminal of fixed size that records what is written and lets a test
/// type keys.
class FakeTerminal implements TerminalIO {
  FakeTerminal({this.width = 140, this.height = 40});

  @override
  int width;

  @override
  int height;

  @override
  ColorMode get colorMode => ColorMode.truecolor;

  final StreamController<Key> keyController = StreamController.broadcast();
  final StreamController<void> resizeController = StreamController.broadcast();
  final StreamController<void> interruptController =
      StreamController.broadcast();
  final StringBuffer output = StringBuffer();
  String title = '';
  int suspends = 0;
  bool active = false;

  @override
  Stream<Key> get keys => keyController.stream;

  @override
  Stream<void> get resizes => resizeController.stream;

  @override
  Stream<void> get interrupts => interruptController.stream;

  @override
  void enter() => active = true;

  @override
  void leave() => active = false;

  @override
  void write(String data) => output.write(data);

  @override
  void setTitle(String value) => title = value;

  @override
  Future<T> suspend<T>(Future<T> Function() body) async {
    suspends++;
    leave();
    try {
      return await body();
    } finally {
      enter();
    }
  }

  void type(String text) {
    for (final key in KeyDecoder().decodeString(text)) {
      keyController.add(key);
    }
  }

  void press(KeyType type) => keyController.add(Key(type));
}

/// Records what the app asks of the operating system.
class FakeShell implements SystemShell {
  final List<String> calls = [];
  final List<List<String>> attached = [];
  final List<String?> attachedIn = [];
  bool tmux = false;
  bool failAttach = false;

  @override
  bool get inTmux => tmux;

  @override
  List<String> editorCommand(String path) => ['editor', path];

  @override
  Future<void> open(String path) async => calls.add('open $path');

  @override
  Future<void> openTmuxWindow(AgentLaunch launch) async =>
      calls.add('tmux ${AgentCommand.shellLine(launch)}');

  @override
  Future<void> reveal(String path) async => calls.add('reveal $path');

  @override
  Future<int> runAttached(
    List<String> command, {
    String? workingDirectory,
  }) async {
    if (failAttach) throw ProcessException(command.first, command.sublist(1));
    attached.add(command);
    attachedIn.add(workingDirectory);
    return 0;
  }
}

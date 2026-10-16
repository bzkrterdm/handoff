import 'package:handoff_tui/handoff_tui.dart';
import 'package:test/test.dart';

void main() {
  final decoder = KeyDecoder();

  test('arrows in normal and application mode', () {
    expect(decoder.decodeString('\x1b[A\x1b[B\x1bOC\x1bOD'), [
      const Key(KeyType.up),
      const Key(KeyType.down),
      const Key(KeyType.right),
      const Key(KeyType.left),
    ]);
  });

  test('modifiers are ignored, page and home keys are known', () {
    expect(decoder.decodeString('\x1b[1;5A\x1b[5~\x1b[6~\x1b[H\x1b[4~'), [
      const Key(KeyType.up),
      const Key(KeyType.pageUp),
      const Key(KeyType.pageDown),
      const Key(KeyType.home),
      const Key(KeyType.end),
    ]);
  });

  test('control bytes, a lone escape and text', () {
    expect(decoder.decodeString('\r\t\x7f\x03\x15ğ\x1b'), [
      const Key(KeyType.enter),
      const Key(KeyType.tab),
      const Key(KeyType.backspace),
      const Key(KeyType.ctrlC),
      const Key(KeyType.ctrl, 'u'),
      const Key.char('ğ'),
      const Key(KeyType.escape),
    ]);
  });

  test('a pasted CRLF is one enter; mouse reports are dropped', () {
    expect(decoder.decodeString('a\r\nb\x1b[<0;3;4M'), [
      const Key.char('a'),
      const Key(KeyType.enter),
      const Key.char('b'),
    ]);
  });

  test('UTF-8 bytes', () {
    expect(decoder.decode([0xC3, 0xBC]), [const Key.char('ü')]);
  });
}

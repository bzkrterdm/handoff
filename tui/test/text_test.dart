import 'package:handoff_tui/handoff_tui.dart';
import 'package:test/test.dart';

void main() {
  group('TextWidth', () {
    test('counts wide and zero-width characters', () {
      expect(TextWidth.ofString('abc'), 3);
      expect(TextWidth.ofString('çğış'), 4);
      expect(TextWidth.ofString('日本'), 4);
      expect(TextWidth.ofString('é'), 1);
    });

    test('truncates with an ellipsis and fits exactly', () {
      expect(TextWidth.truncate('Handoff', 5), 'Hand…');
      expect(TextWidth.truncate('Hi', 5), 'Hi');
      expect(TextWidth.fit('ab', 4), 'ab  ');
    });
  });

  group('Wrap', () {
    test('breaks at spaces and keeps the spaces between words', () {
      expect(Wrap.text('one two three four', 9), ['one two', 'three', 'four']);
    });

    test('hangs continuation lines at the indent', () {
      expect(Wrap.text('- alpha beta gamma', 10, indent: 2), [
        '- alpha',
        '  beta',
        '  gamma',
      ]);
    });

    test('breaks a word longer than the line', () {
      expect(Wrap.text('abcdefghij', 4), ['abcd', 'efgh', 'ij']);
    });

    test('keeps styles across words', () {
      final lines = Wrap.spans([
        const Span('plain '),
        const Span('bold words', Style(bold: true)),
      ], 11);
      expect(lines.length, 2);
      expect(lines[1].single.style.bold, isTrue);
    });
  });

  group('Canvas and FrameWriter', () {
    test('writes only rows that changed', () {
      final writer = FrameWriter();
      final first = Canvas(10, 3)..text(0, 0, 'hello', Style.plain);
      expect(writer.diff(first, ColorMode.none), contains('hello'));

      final second = Canvas(10, 3)
        ..text(0, 0, 'hello', Style.plain)
        ..text(0, 2, 'bye', Style.plain);
      final diff = writer.diff(second, ColorMode.none);
      expect(diff, contains('\x1b[3;1H'));
      expect(diff, isNot(contains('hello')));
    });

    test('a wide character takes two cells', () {
      final canvas = Canvas(4, 1)..text(0, 0, '日a', Style.plain);
      expect(canvas.rowText(0), '日a ');
    });
  });

  test('colours fall back to xterm-256', () {
    expect(const Rgb.hex(0xFF0000).xterm256, 196);
    expect(const Rgb.hex(0x767676).xterm256, 244);
    expect(
      const Style(fg: Rgb(1, 2, 3), bold: true).sgr(ColorMode.truecolor),
      '\x1b[0;1;38;2;1;2;3m',
    );
    expect(ColorMode.detect({'NO_COLOR': '1'}), ColorMode.none);
    expect(ColorMode.detect({'COLORTERM': 'truecolor'}), ColorMode.truecolor);
  });
}

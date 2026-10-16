import '../terminal/style.dart';
import '../terminal/text.dart';
import 'theme.dart';

/// Renders the markdown subset the desktop app renders (`MarkdownText`):
/// paragraphs, `-`/`*` bullets, numbered lines, `inline code`, **bold** and
/// headings below level two. Anything else is plain text — the file is one
/// key away for the rest.
class Markdown {
  Markdown(this.palette);

  static final RegExp _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final RegExp _heading = RegExp(r'^#{3,6}\s+(.*)$');
  static final RegExp _inline = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*)');

  final Palette palette;

  /// [text] as wrapped lines of at most [width] columns.
  List<List<Span>> block(String text, int width) {
    final lines = <List<Span>>[];
    final paragraph = <String>[];

    void gap() {
      if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add(const []);
    }

    void flush() {
      if (paragraph.isEmpty) return;
      gap();
      lines.addAll(Wrap.spans(inline(paragraph.join(' ')), width));
      paragraph.clear();
    }

    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        flush();
        continue;
      }
      final bullet = _bullet.firstMatch(line);
      final numbered = _numbered.firstMatch(line);
      final heading = _heading.firstMatch(line);
      if (bullet != null) {
        flush();
        lines.addAll(_item('•', bullet.group(1)!, width));
      } else if (numbered != null) {
        flush();
        lines.addAll(_item('${numbered.group(1)}.', numbered.group(2)!, width));
      } else if (heading != null) {
        flush();
        gap();
        lines.addAll(
          Wrap.spans([Span(heading.group(1)!, palette.title)], width),
        );
      } else {
        paragraph.add(line.trim());
      }
    }
    flush();

    return lines;
  }

  /// Inline spans only (`code`, **bold**) — for one checklist line, where
  /// "1. step" is a sentence, not a list.
  List<Span> inline(String text, [Style base = Style.plain]) {
    final spans = <Span>[];
    var last = 0;
    for (final match in _inline.allMatches(text)) {
      if (match.start > last) {
        spans.add(Span(text.substring(last, match.start), base));
      }
      final token = match.group(0)!;
      spans.add(
        token.startsWith('`')
            ? Span(
                token.substring(1, token.length - 1),
                base.merge(Style(fg: palette.code)),
              )
            : Span(
                token.substring(2, token.length - 2),
                base.merge(const Style(bold: true)),
              ),
      );
      last = match.end;
    }
    if (last < text.length) spans.add(Span(text.substring(last), base));

    return spans;
  }

  // Helpers
  List<List<Span>> _item(String marker, String text, int width) {
    final prefix = '  $marker ';
    final indent = TextWidth.ofString(prefix);

    return Wrap.spans(
      [Span(prefix, palette.mutedText), ...inline(text)],
      width,
      indent: indent,
    );
  }

  // - Helpers
}

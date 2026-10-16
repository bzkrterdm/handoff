import 'style.dart';

/// Cell widths of text: how many terminal columns a string takes. Good
/// enough for the text agents write — Latin, Turkish, CJK and emoji — without
/// a full Unicode table.
abstract class TextWidth {
  /// Columns taken by one code point: 0 for combining marks and joiners,
  /// 2 for East Asian wide characters and emoji, 1 otherwise.
  static int of(int rune) {
    if (rune == 0) return 0;
    if (rune < 0x20 || (rune >= 0x7F && rune < 0xA0)) return 0;
    if (_isZeroWidth(rune)) return 0;
    if (_isWide(rune)) return 2;

    return 1;
  }

  /// Columns taken by [text].
  static int ofString(String text) {
    var width = 0;
    for (final rune in text.runes) {
      width += of(rune);
    }

    return width;
  }

  /// [text] cut to at most [width] columns, ending in `…` when cut.
  static String truncate(String text, int width) {
    if (width <= 0) return '';
    if (ofString(text) <= width) return text;

    final buffer = StringBuffer();
    var used = 0;
    for (final rune in text.runes) {
      final w = of(rune);
      if (used + w > width - 1) break;
      buffer.writeCharCode(rune);
      used += w;
    }
    buffer.write('…');

    return buffer.toString();
  }

  /// [text] padded with spaces (or cut) to exactly [width] columns.
  static String fit(String text, int width) {
    final cut = truncate(text, width);

    return cut + ' ' * (width - ofString(cut));
  }

  // Helpers
  static bool _isZeroWidth(int r) =>
      (r >= 0x0300 && r <= 0x036F) ||
      (r >= 0x1AB0 && r <= 0x1AFF) ||
      (r >= 0x20D0 && r <= 0x20FF) ||
      r == 0x200B ||
      r == 0x200C ||
      r == 0x200D ||
      r == 0x2060 ||
      (r >= 0xFE00 && r <= 0xFE0F) ||
      (r >= 0xFE20 && r <= 0xFE2F);

  static bool _isWide(int r) =>
      (r >= 0x1100 && r <= 0x115F) ||
      (r >= 0x2E80 && r <= 0x303E) ||
      (r >= 0x3041 && r <= 0x33FF) ||
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0xA000 && r <= 0xA4CF) ||
      (r >= 0xAC00 && r <= 0xD7A3) ||
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0xFE30 && r <= 0xFE4F) ||
      (r >= 0xFF00 && r <= 0xFF60) ||
      (r >= 0xFFE0 && r <= 0xFFE6) ||
      (r >= 0x1F300 && r <= 0x1F64F) ||
      (r >= 0x1F900 && r <= 0x1F9FF) ||
      (r >= 0x1FA70 && r <= 0x1FAFF) ||
      (r >= 0x20000 && r <= 0x3FFFD);

  // - Helpers
}

/// Word wrapping for styled text.
abstract class Wrap {
  /// Breaks [spans] into lines of at most [width] columns, at spaces where
  /// possible. Continuation lines start with [indent] spaces (a hanging
  /// indent for list items). Always returns at least one line.
  static List<List<Span>> spans(List<Span> spans, int width, {int indent = 0}) {
    if (width <= 0) return [<Span>[]];

    final words = _words(spans);
    final lines = <List<Span>>[];
    var line = <Span>[];
    var used = 0;
    // True right after a wrap: spaces there are the break, not text.
    var wrapped = false;

    void newLine() {
      lines.add(line);
      line = [if (indent > 0) Span(' ' * indent)];
      used = indent;
      wrapped = true;
    }

    for (final word in words) {
      final w = TextWidth.ofString(word.text);
      final isSpace = word.text.trim().isEmpty;
      if (isSpace) {
        if (!wrapped && used + w <= width) {
          line.add(word);
          used += w;
        }
        continue;
      }
      if (used + w > width && used > indent) {
        _trimTrailingSpace(line, keep: indent > 0 ? 1 : 0);
        newLine();
      }
      wrapped = false;
      if (w <= width - used) {
        line.add(word);
        used += w;
        continue;
      }
      // A word longer than the line is broken by columns.
      var rest = word.text;
      while (rest.isNotEmpty) {
        final room = width - used;
        final piece = _take(rest, room > 0 ? room : 1);
        line.add(Span(piece, word.style));
        used += TextWidth.ofString(piece);
        rest = rest.substring(piece.length);
        if (rest.isNotEmpty) {
          newLine();
          wrapped = false;
        }
      }
    }
    _trimTrailingSpace(line);
    lines.add(line);

    return lines;
  }

  /// Plain-text convenience over [spans].
  static List<String> text(String text, int width, {int indent = 0}) {
    return [
      for (final line in spans([Span(text)], width, indent: indent))
        line.map((span) => span.text).join(),
    ];
  }

  // Helpers
  /// Splits spans into words and runs of spaces, keeping each piece's style.
  static List<Span> _words(List<Span> spans) {
    final words = <Span>[];
    final pattern = RegExp(r'\s+|[^\s]+');
    for (final span in spans) {
      for (final match in pattern.allMatches(span.text)) {
        final piece = match.group(0)!;
        words.add(
          Span(piece.trim().isEmpty ? ' ' * piece.length : piece, span.style),
        );
      }
    }

    return words;
  }

  /// The longest prefix of [text] that fits in [columns].
  static String _take(String text, int columns) {
    var used = 0;
    var end = 0;
    for (final rune in text.runes) {
      final w = TextWidth.of(rune);
      if (used + w > columns && end > 0) break;
      used += w;
      end += rune > 0xFFFF ? 2 : 1;
    }

    return text.substring(0, end);
  }

  /// Drops trailing spaces, keeping the first [keep] spans (the indent).
  static void _trimTrailingSpace(List<Span> line, {int keep = 0}) {
    while (line.length > keep && line.last.text.trim().isEmpty) {
      line.removeLast();
    }
  }

  // - Helpers
}

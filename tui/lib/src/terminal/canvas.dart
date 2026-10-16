import 'style.dart';
import 'text.dart';

/// One terminal cell. A wide character takes two cells; the second one has
/// an empty [char] and is skipped when writing.
class Cell {
  Cell(this.char, this.style);

  String char;
  Style style;

  bool sameAs(Cell other) => other.char == char && other.style == style;
}

/// A rectangle on the canvas.
class Rect {
  const Rect(this.x, this.y, this.width, this.height);

  final int x;
  final int y;
  final int width;
  final int height;

  int get right => x + width;

  int get bottom => y + height;

  Rect inset({int left = 0, int top = 0, int right = 0, int bottom = 0}) {
    return Rect(
      x + left,
      y + top,
      (width - left - right).clamp(0, width),
      (height - top - bottom).clamp(0, height),
    );
  }
}

/// An off-screen frame. Views draw into it; [FrameWriter] turns the
/// difference to the previous frame into escape sequences.
class Canvas {
  Canvas(this.width, this.height, [this.base = Style.plain])
    : _cells = List.generate(width * height, (_) => Cell(' ', base));

  final int width;
  final int height;
  final Style base;
  final List<Cell> _cells;

  Cell cellAt(int x, int y) => _cells[y * width + x];

  /// Paints [rect] with [style] (and [char]).
  void fill(Rect rect, Style style, [String char = ' ']) {
    for (var y = rect.y; y < rect.bottom && y < height; y++) {
      if (y < 0) continue;
      for (var x = rect.x; x < rect.right && x < width; x++) {
        if (x < 0) continue;
        final cell = cellAt(x, y);
        cell
          ..char = char
          ..style = style;
      }
    }
  }

  /// Writes [text] at ([x], [y]) without going past [maxX]; returns the
  /// column after the last character written. [style] is merged over what
  /// the cell already shows, so a span keeps its row's background.
  int text(int x, int y, String text, Style style, {int? maxX}) {
    final limit = (maxX ?? width).clamp(0, width);
    if (y < 0 || y >= height) return x;

    var column = x;
    for (final rune in text.runes) {
      final w = TextWidth.of(rune);
      final char = String.fromCharCode(rune);
      if (w == 0) {
        // Combining marks join the character before them.
        if (column > 0 && column - 1 < limit && column - 1 >= x) {
          cellAt(column - 1, y).char += char;
        }
        continue;
      }
      if (column + w > limit) break;
      if (column >= 0) {
        final cell = cellAt(column, y);
        cell
          ..char = char
          ..style = cell.style.merge(style);
        if (w == 2 && column + 1 < width) {
          final next = cellAt(column + 1, y);
          next
            ..char = ''
            ..style = cell.style;
        }
      }
      column += w;
    }

    return column;
  }

  /// Writes a styled line; returns the column after it.
  int spans(int x, int y, List<Span> spans, {int? maxX, Style? base}) {
    var column = x;
    for (final span in spans) {
      final style = base == null ? span.style : base.merge(span.style);
      column = text(column, y, span.text, style, maxX: maxX);
    }

    return column;
  }

  /// Row [y] as plain text, for tests.
  String rowText(int y) {
    final buffer = StringBuffer();
    for (var x = 0; x < width; x++) {
      buffer.write(cellAt(x, y).char);
    }

    return buffer.toString();
  }

  /// The whole frame as plain text, for tests.
  String toPlainText() =>
      [for (var y = 0; y < height; y++) rowText(y).trimRight()].join('\n');
}

/// Writes frames to the terminal, redrawing only the rows that changed.
class FrameWriter {
  Canvas? _previous;

  /// Forgets the last frame, so the next one is drawn in full (after a
  /// resize or when coming back from a child process).
  void invalidate() => _previous = null;

  /// The escape sequences that turn the screen into [next].
  String diff(Canvas next, ColorMode mode) {
    final previous = _previous;
    final full =
        previous == null ||
        previous.width != next.width ||
        previous.height != next.height;
    final buffer = StringBuffer();
    if (full) buffer.write('\x1b[0m\x1b[2J');

    for (var y = 0; y < next.height; y++) {
      if (!full && _sameRow(previous, next, y)) continue;

      buffer.write('\x1b[${y + 1};1H');
      Style? current;
      for (var x = 0; x < next.width; x++) {
        final cell = next.cellAt(x, y);
        if (cell.char.isEmpty) continue;
        if (cell.style != current) {
          buffer.write(cell.style.sgr(mode));
          current = cell.style;
        }
        buffer.write(cell.char);
      }
      buffer.write('\x1b[0m');
    }
    _previous = next;

    return buffer.toString();
  }

  // Helpers
  bool _sameRow(Canvas a, Canvas b, int y) {
    for (var x = 0; x < b.width; x++) {
      if (!a.cellAt(x, y).sameAs(b.cellAt(x, y))) return false;
    }

    return true;
  }

  // - Helpers
}

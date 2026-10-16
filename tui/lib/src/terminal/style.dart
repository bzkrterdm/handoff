import 'dart:io';

/// A 24-bit colour. Written as truecolour where the terminal supports it and
/// mapped to the nearest of the 256 xterm colours elsewhere.
class Rgb {
  const Rgb(this.r, this.g, this.b);

  const Rgb.hex(int value)
    : r = (value >> 16) & 0xFF,
      g = (value >> 8) & 0xFF,
      b = value & 0xFF;

  final int r;
  final int g;
  final int b;

  /// The nearest xterm-256 index: the 6×6×6 cube or the grey ramp,
  /// whichever is closer.
  int get xterm256 {
    int level(int v) => v < 48 ? 0 : (v < 115 ? 1 : (v - 35) ~/ 40);
    const steps = [0, 95, 135, 175, 215, 255];
    final ri = level(r), gi = level(g), bi = level(b);
    final cube = 16 + 36 * ri + 6 * gi + bi;
    final cubeDistance = _distance(steps[ri], steps[gi], steps[bi]);

    final average = (r + g + b) ~/ 3;
    final greyIndex = average > 238 ? 23 : ((average - 3) / 10).round();
    final grey = greyIndex.clamp(0, 23);
    final greyValue = 8 + 10 * grey;
    final greyDistance = _distance(greyValue, greyValue, greyValue);

    return greyDistance < cubeDistance ? 232 + grey : cube;
  }

  @override
  bool operator ==(Object other) =>
      other is Rgb && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  // Helpers
  int _distance(int r2, int g2, int b2) {
    final dr = r - r2, dg = g - g2, db = b - b2;

    return dr * dr + dg * dg + db * db;
  }

  // - Helpers
}

/// How many colours the terminal can show.
enum ColorMode {
  /// `NO_COLOR` is set: attributes (bold, underline) only.
  none,
  ansi256,
  truecolor;

  /// Best guess from the environment. Every terminal Handoff targets does at
  /// least 256 colours; truecolour is announced by `COLORTERM` or known by
  /// the terminal's name.
  static ColorMode detect([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    if (env.containsKey('NO_COLOR')) return none;

    final colorTerm = (env['COLORTERM'] ?? '').toLowerCase();
    if (colorTerm == 'truecolor' || colorTerm == '24bit') return truecolor;
    if (env.containsKey('WT_SESSION')) return truecolor;
    const truecolorPrograms = {
      'iTerm.app',
      'WezTerm',
      'vscode',
      'ghostty',
      'Hyper',
    };
    if (truecolorPrograms.contains(env['TERM_PROGRAM'])) return truecolor;
    if (Platform.isWindows && environment == null) return truecolor;

    return ansi256;
  }
}

/// How a run of cells looks. Null colours mean "the terminal's own", which
/// keeps the "system" appearance in step with whatever theme the terminal
/// uses.
class Style {
  const Style({
    this.fg,
    this.bg,
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
  });

  static const Style plain = Style();

  final Rgb? fg;
  final Rgb? bg;
  final bool bold;
  final bool dim;
  final bool italic;
  final bool underline;
  final bool strike;

  /// [other] on top of this style: its colours win where set, attributes
  /// add up.
  Style merge(Style other) {
    return Style(
      fg: other.fg ?? fg,
      bg: other.bg ?? bg,
      bold: bold || other.bold,
      dim: dim || other.dim,
      italic: italic || other.italic,
      underline: underline || other.underline,
      strike: strike || other.strike,
    );
  }

  Style copyWith({Rgb? fg, Rgb? bg, bool? bold, bool? dim, bool? strike}) {
    return Style(
      fg: fg ?? this.fg,
      bg: bg ?? this.bg,
      bold: bold ?? this.bold,
      dim: dim ?? this.dim,
      italic: italic,
      underline: underline,
      strike: strike ?? this.strike,
    );
  }

  /// The escape sequence that switches to this style from any other. Always
  /// starts with a reset, so the output never depends on what came before.
  String sgr(ColorMode mode) {
    final codes = <String>['0'];
    if (bold) codes.add('1');
    if (dim) codes.add('2');
    if (italic) codes.add('3');
    if (underline) codes.add('4');
    if (strike) codes.add('9');
    final foreground = fg;
    final background = bg;
    if (mode != ColorMode.none) {
      if (foreground != null) codes.add(_color(foreground, mode, 38));
      if (background != null) codes.add(_color(background, mode, 48));
    }

    return '\x1b[${codes.join(';')}m';
  }

  @override
  bool operator ==(Object other) =>
      other is Style &&
      other.fg == fg &&
      other.bg == bg &&
      other.bold == bold &&
      other.dim == dim &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike;

  @override
  int get hashCode => Object.hash(fg, bg, bold, dim, italic, underline, strike);

  // Helpers
  static String _color(Rgb color, ColorMode mode, int base) {
    return mode == ColorMode.truecolor
        ? '$base;2;${color.r};${color.g};${color.b}'
        : '$base;5;${color.xterm256}';
  }

  // - Helpers
}

/// A piece of text in one style; a line of the screen is a list of spans.
class Span {
  const Span(this.text, [this.style = Style.plain]);

  final String text;
  final Style style;

  @override
  String toString() => text;
}

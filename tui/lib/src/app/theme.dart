import '../terminal/style.dart';

/// Appearance, as in the desktop app. "System" draws on the terminal's own
/// background and text colour, so it follows whatever theme the terminal
/// has; light and dark paint their own.
enum Appearance {
  system,
  light,
  dark;

  static Appearance parse(Object? value) => switch (value) {
    'light' => light,
    'dark' => dark,
    _ => system,
  };
}

/// The colours of one appearance. The accent is the desktop app's seed
/// (`#3B5BDB`), lightened where it sits on a dark background.
class Palette {
  const Palette({
    required this.background,
    required this.sidebar,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.selection,
    required this.border,
    required this.success,
    required this.danger,
    required this.code,
  });

  factory Palette.of(Appearance appearance) => switch (appearance) {
    Appearance.system => const Palette(
      background: null,
      sidebar: null,
      text: null,
      muted: Rgb.hex(0x8A909C),
      accent: Rgb.hex(0x5C7CFA),
      onAccent: Rgb.hex(0xFFFFFF),
      selection: null,
      border: Rgb.hex(0x6B7280),
      success: Rgb.hex(0x22A55A),
      danger: Rgb.hex(0xE5484D),
      code: Rgb.hex(0xD9822B),
    ),
    Appearance.light => const Palette(
      background: Rgb.hex(0xFFFFFF),
      sidebar: Rgb.hex(0xF3F4F8),
      text: Rgb.hex(0x1B1D22),
      muted: Rgb.hex(0x6B7080),
      accent: Rgb.hex(0x3B5BDB),
      onAccent: Rgb.hex(0xFFFFFF),
      selection: Rgb.hex(0xE4E9FF),
      border: Rgb.hex(0xD9DCE3),
      success: Rgb.hex(0x16A34A),
      danger: Rgb.hex(0xC62828),
      code: Rgb.hex(0xB4530C),
    ),
    Appearance.dark => const Palette(
      background: Rgb.hex(0x15171C),
      sidebar: Rgb.hex(0x1B1E24),
      text: Rgb.hex(0xE6E8EE),
      muted: Rgb.hex(0x8C93A3),
      accent: Rgb.hex(0x748FFC),
      onAccent: Rgb.hex(0x0E1530),
      selection: Rgb.hex(0x26305A),
      border: Rgb.hex(0x2C313B),
      success: Rgb.hex(0x4ADE80),
      danger: Rgb.hex(0xF87171),
      code: Rgb.hex(0xF0A35E),
    ),
  };

  final Rgb? background;
  final Rgb? sidebar;
  final Rgb? text;
  final Rgb muted;
  final Rgb accent;
  final Rgb onAccent;

  /// Background of the selected row; null in "system", which marks the
  /// selection with a bar and bold text instead.
  final Rgb? selection;
  final Rgb border;
  final Rgb success;
  final Rgb danger;
  final Rgb code;

  Style get base => Style(fg: text, bg: background);

  Style get sidebarBase => Style(fg: text, bg: sidebar ?? background);

  Style get mutedText => Style(fg: muted);

  Style get accentText => Style(fg: accent);

  Style get title => Style(fg: text, bold: true);

  Style get borderLine => Style(fg: border);

  /// The agent avatar colours of the desktop app, picked by name the same
  /// way, so an agent has the same colour in both.
  static const List<Rgb> _agentColors = [
    Rgb.hex(0xD97706),
    Rgb.hex(0x0891B2),
    Rgb.hex(0x7C3AED),
    Rgb.hex(0x059669),
    Rgb.hex(0xDB2777),
    Rgb.hex(0x2563EB),
  ];

  static Rgb agentColor(String agent) {
    final hash = agent.toLowerCase().codeUnits.fold(0, (a, b) => a * 31 + b);

    return _agentColors[hash.abs() % _agentColors.length];
  }
}

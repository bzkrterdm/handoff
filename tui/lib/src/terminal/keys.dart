import 'dart:convert';

/// Keys the app reacts to. Letters and other printable input arrive as
/// [KeyType.char].
enum KeyType {
  char,
  up,
  down,
  left,
  right,
  home,
  end,
  pageUp,
  pageDown,
  enter,
  escape,
  tab,
  backTab,
  backspace,
  delete,
  ctrlC,

  /// Ctrl + a letter other than C; the letter is in [Key.char].
  ctrl,
  unknown,
}

class Key {
  const Key(this.type, [this.char = '']);

  const Key.char(this.char) : type = KeyType.char;

  final KeyType type;

  /// The character for [KeyType.char], the letter for [KeyType.ctrl].
  final String char;

  bool isChar(String value) => type == KeyType.char && char == value;

  @override
  bool operator ==(Object other) =>
      other is Key && other.type == type && other.char == char;

  @override
  int get hashCode => Object.hash(type, char);

  @override
  String toString() => type == KeyType.char ? 'Key($char)' : 'Key($type)';
}

/// Turns raw terminal input into keys: UTF-8 text, control bytes and the
/// VT escape sequences that macOS, Linux and Windows terminals send for
/// arrows and the like. Mouse reports and unknown sequences are dropped.
class KeyDecoder {
  List<Key> decode(List<int> bytes) =>
      decodeString(utf8.decode(bytes, allowMalformed: true));

  List<Key> decodeString(String input) {
    final keys = <Key>[];
    final runes = input.runes.toList();
    var i = 0;
    while (i < runes.length) {
      final rune = runes[i];
      if (rune == 0x1B) {
        i = _escape(runes, i, keys);
        continue;
      }
      i++;
      switch (rune) {
        case 0x0D:
          keys.add(const Key(KeyType.enter));
          // "\r\n" from a paste is one line break.
          if (i < runes.length && runes[i] == 0x0A) i++;
        case 0x0A:
          keys.add(const Key(KeyType.enter));
        case 0x09:
          keys.add(const Key(KeyType.tab));
        case 0x7F || 0x08:
          keys.add(const Key(KeyType.backspace));
        case 0x03:
          keys.add(const Key(KeyType.ctrlC));
        case final int c when c >= 0x01 && c <= 0x1A:
          keys.add(Key(KeyType.ctrl, String.fromCharCode(c + 0x60)));
        case final int c when c < 0x20:
          keys.add(const Key(KeyType.unknown));
        default:
          keys.add(Key.char(String.fromCharCode(rune)));
      }
    }

    return keys;
  }

  // Helpers
  /// Reads one escape sequence starting at [start]; returns the index after
  /// it.
  int _escape(List<int> runes, int start, List<Key> keys) {
    final next = start + 1;
    if (next >= runes.length) {
      keys.add(const Key(KeyType.escape));
      return next;
    }
    final kind = runes[next];
    if (kind == 0x5B) return _csi(runes, next + 1, keys);
    if (kind == 0x4F && next + 1 < runes.length) {
      keys.add(_final(String.fromCharCode(runes[next + 1]), ''));
      return next + 2;
    }
    if (kind == 0x1B) {
      keys.add(const Key(KeyType.escape));
      return next;
    }
    // Alt + key: the key alone.
    return next;
  }

  /// CSI: parameters then one final byte, e.g. `ESC [ 1 ; 5 A`.
  int _csi(List<int> runes, int start, List<Key> keys) {
    var i = start;
    final params = StringBuffer();
    while (i < runes.length && !(runes[i] >= 0x40 && runes[i] <= 0x7E)) {
      params.writeCharCode(runes[i]);
      i++;
    }
    if (i >= runes.length) {
      keys.add(const Key(KeyType.escape));
      return i;
    }
    final text = params.toString();
    // SGR mouse reports (`ESC [ < b ; x ; y M`) are not used.
    if (!text.startsWith('<')) {
      keys.add(_final(String.fromCharCode(runes[i]), text));
    }

    return i + 1;
  }

  Key _final(String finalByte, String params) {
    final first = params.split(';').first;

    return switch (finalByte) {
      'A' => const Key(KeyType.up),
      'B' => const Key(KeyType.down),
      'C' => const Key(KeyType.right),
      'D' => const Key(KeyType.left),
      'H' => const Key(KeyType.home),
      'F' => const Key(KeyType.end),
      'Z' => const Key(KeyType.backTab),
      '~' => switch (first) {
        '1' || '7' => const Key(KeyType.home),
        '4' || '8' => const Key(KeyType.end),
        '5' => const Key(KeyType.pageUp),
        '6' => const Key(KeyType.pageDown),
        '3' => const Key(KeyType.delete),
        _ => const Key(KeyType.unknown),
      },
      _ => const Key(KeyType.unknown),
    };
  }

  // - Helpers
}

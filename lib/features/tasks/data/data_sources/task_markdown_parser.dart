import 'package:yaml/yaml.dart';

import '../models/task_model.dart';

/// Reads and edits the task file format documented in `docs/protocol.md`:
/// a YAML front matter and three `##` sections — "Yapılan", "Bilgi" and
/// "Senden beklenenler" (the checklist).
///
/// Edits are line-level on purpose: ticking a box or closing a task rewrites
/// only the line that changed, so whatever else a person or agent wrote in
/// the file survives untouched. Nothing here re-renders a whole file.
abstract class TaskMarkdownParser {
  static const String statusKey = 'status';
  static const String closedKey = 'closed';

  static const List<String> _summaryHeadings = ['yapılan', 'yapilan', 'done'];
  static const List<String> _infoHeadings = ['bilgi', 'info', 'notes'];
  static const List<String> _actionHeadings = [
    'senden beklenenler',
    'beklenenler',
    'expected',
    'actions',
    'todo',
  ];

  static final RegExp _frontMatterDelimiter = RegExp(r'^---\s*$');
  static final RegExp _heading = RegExp(r'^##\s+(.+?)\s*$');
  static final RegExp _checkbox = RegExp(r'^(\s*[-*]\s+\[)( |x|X)(\]\s?)(.*)$');

  /// Whether [content] is a task written by this protocol rather than any
  /// markdown note: a front matter with a `status` and an `agent` or
  /// `created` line. Used to recognise a folder that already holds tasks.
  static bool isTask(String content) {
    final lines = content.split('\n');
    final end = _frontMatterEnd(lines);
    if (end == null) return false;

    final header = _readFrontMatter(lines.sublist(1, end));

    return header.containsKey(statusKey) &&
        (header.containsKey('agent') || header.containsKey('created'));
  }

  /// Parses [content]; [id] and [fallbackProject] come from the file's place
  /// on disk and are used when the front matter lacks them.
  static TaskModel parse(
    String content, {
    required String id,
    required String fallbackProject,
    String? location,
  }) {
    final lines = content.split('\n');
    final frontMatterEnd = _frontMatterEnd(lines);
    final frontMatter = frontMatterEnd == null
        ? const <String, Object?>{}
        : _readFrontMatter(lines.sublist(1, frontMatterEnd));
    final bodyLines = frontMatterEnd == null
        ? lines
        : lines.sublist(frontMatterEnd + 1);
    final sections = _sections(bodyLines);

    return TaskModel(
      id: _string(frontMatter['id']) ?? id,
      project: _string(frontMatter['project']) ?? fallbackProject,
      title: _string(frontMatter['title']) ?? _titleFromBody(bodyLines) ?? id,
      agent: _string(frontMatter['agent']) ?? 'unknown',
      createdAt: _date(frontMatter['created']) ?? DateTime(1970),
      closedAt: _date(frontMatter[closedKey]),
      status: _string(frontMatter[statusKey]) ?? 'open',
      related: _strings(frontMatter['related']),
      summary: _joined(sections, _summaryHeadings),
      info: _joined(sections, _infoHeadings),
      actions: _actions(sections),
      location: location,
      cwd: _string(frontMatter['cwd']),
      sessionId: _string(frontMatter['session']),
    );
  }

  /// Returns [content] with the [index]th checkbox of the checklist section
  /// set to [isDone]. Throws a [RangeError] when there is no such box.
  static String withActionDone(
    String content, {
    required int index,
    required bool isDone,
  }) {
    final lines = content.split('\n');
    final frontMatterEnd = _frontMatterEnd(lines);
    final bodyStart = frontMatterEnd == null ? 0 : frontMatterEnd + 1;
    var seen = 0;
    var inActions = false;

    for (var i = bodyStart; i < lines.length; i++) {
      final heading = _heading.firstMatch(lines[i]);
      if (heading != null) {
        inActions = _matches(heading.group(1)!, _actionHeadings);
        continue;
      }
      if (!inActions) continue;

      final box = _checkbox.firstMatch(lines[i]);
      if (box == null) continue;
      if (seen == index) {
        lines[i] =
            '${box.group(1)}${isDone ? 'x' : ' '}${box.group(3)}'
            '${box.group(4)}';
        return lines.join('\n');
      }
      seen++;
    }

    throw RangeError.index(index, List.filled(seen, null), 'index');
  }

  /// Returns [content] with `status` set and `closed` stamped or removed in
  /// the front matter. A file without front matter gets one.
  static String withStatus(
    String content, {
    required String status,
    required DateTime? closedAt,
  }) {
    final lines = content.split('\n');
    final frontMatterEnd = _frontMatterEnd(lines);
    final closedLine = closedAt == null
        ? null
        : '$closedKey: ${closedAt.toIso8601String()}';

    if (frontMatterEnd == null) {
      return [
        '---',
        '$statusKey: $status',
        ?closedLine,
        '---',
        ...lines,
      ].join('\n');
    }

    final header = lines.sublist(1, frontMatterEnd)
      ..removeWhere(
        (line) => _isKey(line, statusKey) || _isKey(line, closedKey),
      )
      ..add('$statusKey: $status');
    if (closedLine != null) header.add(closedLine);

    return [
      '---',
      ...header,
      '---',
      ...lines.sublist(frontMatterEnd + 1),
    ].join('\n');
  }

  // Helpers
  static int? _frontMatterEnd(List<String> lines) {
    if (lines.isEmpty || !_frontMatterDelimiter.hasMatch(lines.first)) {
      return null;
    }
    for (var i = 1; i < lines.length; i++) {
      if (_frontMatterDelimiter.hasMatch(lines[i])) return i;
    }

    return null;
  }

  static Map<String, Object?> _readFrontMatter(List<String> lines) {
    final Object? parsed;
    try {
      parsed = loadYaml(lines.join('\n'));
    } on YamlException {
      return _readFrontMatterLeniently(lines);
    }
    if (parsed is! YamlMap) return const {};

    return {
      for (final entry in parsed.entries) entry.key.toString(): entry.value,
    };
  }

  /// One malformed line (an agent wrote `title: "A": b`) must not cost the
  /// task its `status`, so read the header line by line: a line that is valid
  /// YAML on its own keeps its parsed value, any other keeps its raw text.
  static Map<String, Object?> _readFrontMatterLeniently(List<String> lines) {
    final result = <String, Object?>{};
    for (final line in lines) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;

      final key = line.substring(0, colon).trim();
      final raw = line.substring(colon + 1).trim();
      try {
        final single = loadYaml(line);
        result[key] = single is YamlMap ? single[key] : raw;
      } on YamlException {
        // An unclosed `[` or `{` is a broken list, not text worth showing.
        if (!raw.startsWith('[') && !raw.startsWith('{')) result[key] = raw;
      }
    }

    return result;
  }

  /// Body split into `## heading` → lines. Text before the first heading is
  /// kept under an empty key.
  static Map<String, List<String>> _sections(List<String> bodyLines) {
    final sections = <String, List<String>>{'': []};
    var current = '';
    for (final line in bodyLines) {
      final heading = _heading.firstMatch(line);
      if (heading != null) {
        current = heading.group(1)!.trim().toLowerCase();
        sections.putIfAbsent(current, () => []);
        continue;
      }
      sections[current]!.add(line);
    }

    return sections;
  }

  static String _joined(
    Map<String, List<String>> sections,
    List<String> headings,
  ) {
    final parts = <String>[];
    for (final entry in sections.entries) {
      if (_matches(entry.key, headings)) parts.add(entry.value.join('\n'));
    }

    return parts.join('\n').trim();
  }

  static List<TaskActionModel> _actions(Map<String, List<String>> sections) {
    final actions = <TaskActionModel>[];
    for (final entry in sections.entries) {
      if (!_matches(entry.key, _actionHeadings)) continue;
      for (final line in entry.value) {
        final box = _checkbox.firstMatch(line);
        if (box == null) continue;
        actions.add(
          TaskActionModel(
            text: box.group(4)!.trim(),
            isDone: box.group(2)!.toLowerCase() == 'x',
          ),
        );
      }
    }

    return actions;
  }

  static String? _titleFromBody(List<String> bodyLines) {
    for (final line in bodyLines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) return trimmed.substring(2).trim();
    }

    return null;
  }

  static bool _matches(String heading, List<String> candidates) {
    final normalized = heading.trim().toLowerCase();

    return candidates.contains(normalized);
  }

  static bool _isKey(String line, String key) => line.startsWith('$key:');

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  static List<String> _strings(Object? value) {
    if (value is YamlList) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];

    return const [];
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;

    return DateTime.tryParse(value.toString().trim());
  }

  // - Helpers
}

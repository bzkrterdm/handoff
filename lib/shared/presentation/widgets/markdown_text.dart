import 'package:flutter/material.dart';

/// Renders the small markdown subset agents write in task bodies: paragraphs,
/// `-`/`*` bullets, numbered lines, `inline code`, **bold** and headings
/// below level two. Anything else is shown as plain text — the file is one
/// click away for the rest.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.text, {super.key, this.inline = false});

  static final RegExp _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final RegExp _heading = RegExp(r'^#{3,6}\s+(.*)$');
  static final RegExp _inline = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*)');

  final String text;

  /// Inline spans only (`code`, **bold**), no block parsing — for a single
  /// checklist line, where "1. adım" is a sentence, not a numbered list.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium!
        .copyWith(height: 1.45)
        .merge(DefaultTextStyle.of(context).style);
    if (inline) return _line(context, text.trim(), body);

    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(_line(context, paragraph.join(' '), body));
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
        blocks.add(_listItem(context, '•', bullet.group(1)!, body));
      } else if (numbered != null) {
        flush();
        blocks.add(
          _listItem(context, '${numbered.group(1)}.', numbered.group(2)!, body),
        );
      } else if (heading != null) {
        flush();
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(heading.group(1)!, style: theme.textTheme.titleSmall),
          ),
        );
      } else {
        paragraph.add(line.trim());
      }
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          blocks[i],
        ],
      ],
    );
  }

  // Helpers
  Widget _listItem(
    BuildContext context,
    String marker,
    String text,
    TextStyle style,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, child: Text(marker, style: style)),
          Expanded(child: _line(context, text, style)),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text, TextStyle style) {
    final scheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _inline.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: (style.fontSize ?? 14) - 1,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      }
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return SelectableText.rich(TextSpan(style: style, children: spans));
  }

  // - Helpers
}

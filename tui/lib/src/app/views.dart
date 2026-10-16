import 'dart:io';
import 'dart:math' as math;

import 'package:handoff_core/handoff_core.dart';

import '../terminal/canvas.dart';
import '../terminal/style.dart';
import '../terminal/text.dart';
import 'board.dart';
import 'dates.dart';
import 'markdown.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui_state.dart';

/// How the board is split at a given width.
enum LayoutMode {
  /// Projects, list and details side by side, like the desktop app.
  wide,

  /// List (or projects, while focused) and details.
  medium,

  /// One pane at a time.
  narrow,
}

class BoardLayout {
  const BoardLayout({
    required this.mode,
    this.projects,
    this.list,
    this.detail,
    this.separators = const [],
  });

  factory BoardLayout.of(Rect body, Pane focus) {
    final w = body.width;
    if (w >= wideFrom) {
      const left = projectsWidth;
      final listWidth = ((w - left - 2) * 0.4).round().clamp(34, 48);
      final detailX = left + 1 + listWidth + 1;

      return BoardLayout(
        mode: LayoutMode.wide,
        projects: Rect(body.x, body.y, left, body.height),
        list: Rect(body.x + left + 1, body.y, listWidth, body.height),
        detail: Rect(body.x + detailX, body.y, w - detailX, body.height),
        separators: [body.x + left, body.x + left + 1 + listWidth],
      );
    }
    if (w >= mediumFrom) {
      final left = (w * 0.42).round().clamp(30, 44);
      final leftRect = Rect(body.x, body.y, left, body.height);
      final detail = Rect(body.x + left + 1, body.y, w - left - 1, body.height);

      return BoardLayout(
        mode: LayoutMode.medium,
        projects: focus == Pane.projects ? leftRect : null,
        list: focus == Pane.projects ? null : leftRect,
        detail: detail,
        separators: [body.x + left],
      );
    }

    return BoardLayout(
      mode: LayoutMode.narrow,
      projects: focus == Pane.projects ? body : null,
      list: focus == Pane.list ? body : null,
      detail: focus == Pane.detail ? body : null,
    );
  }

  static const int wideFrom = 110;
  static const int mediumFrom = 72;
  static const int projectsWidth = 26;

  final LayoutMode mode;
  final Rect? projects;
  final Rect? list;
  final Rect? detail;
  final List<int> separators;
}

/// A line of the details and, for checklist rows, which item it shows.
class DetailLine {
  const DetailLine(this.spans, {this.item});

  final List<Span> spans;
  final int? item;
}

/// Draws one frame from the board and the UI state. Keeps scroll offsets in
/// range as it goes (it is the only place that knows how tall things are).
class Painter {
  Painter({
    required this.board,
    required this.ui,
    required this.strings,
    required this.palette,
  }) : markdown = Markdown(palette);

  static const int minWidth = 40;
  static const int minHeight = 10;

  final Board board;
  final UiState ui;
  final Strings strings;
  final Palette palette;
  final Markdown markdown;

  Canvas paint(int width, int height) {
    final canvas = Canvas(width, height, palette.base);
    if (width < minWidth || height < minHeight) {
      _centered(canvas, Rect(0, 0, width, height), [
        [Span(strings('text_too_small'), palette.mutedText)],
      ]);
      return canvas;
    }

    final body = Rect(0, 1, width, height - 2);
    _header(canvas, width);
    switch (ui.screen) {
      case Screen.loading:
        _centered(canvas, body, [
          [Span(strings('text_loading'), palette.mutedText)],
        ]);
      case Screen.welcome:
        _welcome(canvas, body);
      case Screen.error:
        _error(canvas, body);
      case Screen.board:
        _board(canvas, body);
    }
    _footer(canvas, width, height - 1);

    switch (ui.modal) {
      case null:
        break;
      case final ConfirmModal modal:
        _confirm(canvas, modal);
      case final HelpModal modal:
        _help(canvas, modal);
      case final SettingsModal modal:
        _settings(canvas, modal);
      case final FolderModal modal:
        _folder(canvas, modal);
    }

    return canvas;
  }

  /// The checklist rows of [task] in the details, laid out at [width]; the
  /// app uses it to move the cursor by item.
  List<DetailLine> detailLines(
    TaskModel task,
    int width, {
    bool focused = false,
  }) {
    final lines = <DetailLine>[];
    void add(List<Span> spans, {int? item}) =>
        lines.add(DetailLine(spans, item: item));
    void blank() => add(const []);

    // Project, and when closed, since when.
    final closedAt = task.closedAt;
    add([
      Span('▪ ', palette.accentText),
      Span(task.project.isEmpty ? '—' : task.project, palette.accentText),
      if (task.isDone) ...[
        const Span('   '),
        Span(
          '${strings('text_closed_at')} · '
          '${closedAt == null ? '' : DateText.full(closedAt, strings)}',
          Style(fg: palette.success, bold: true),
        ),
      ],
    ]);
    blank();
    for (final line in Wrap.spans([Span(task.title, palette.title)], width)) {
      add(line);
    }
    add([
      Span('● ', Style(fg: Palette.agentColor(task.agent))),
      Span(task.agent, palette.mutedText),
      Span('  ·  ', palette.mutedText),
      Span(DateText.full(task.createdAt, strings), palette.mutedText),
    ]);
    blank();
    for (final line in _buttons(task, width)) {
      add(line);
    }
    blank();

    // The checklist: the part the owner acts on.
    final total = task.actions.length;
    final done = task.doneActionCount;
    add(
      _sectionTitle(
        strings('section_actions'),
        width,
        trailing: total == 0
            ? null
            : strings('text_progress', {'done': done, 'total': total}),
      ),
    );
    if (total == 0) {
      add([Span(strings('text_no_actions'), palette.mutedText)]);
    } else {
      add(_progressBar(done, total, width));
      for (var i = 0; i < total; i++) {
        final action = task.actions[i];
        final number = i < 9 ? '${i + 1}' : ' ';
        final prefix = [
          Span('$number ', palette.mutedText),
          action.isDone
              ? Span('[✓]', Style(fg: palette.success, bold: true))
              : Span('[ ]', palette.mutedText),
          const Span(' '),
        ];
        final textStyle = action.isDone
            ? Style(fg: palette.muted, strike: true)
            : Style.plain;
        final wrapped = Wrap.spans(
          [...prefix, ...markdown.inline(action.text, textStyle)],
          width,
          indent: 6,
        );
        for (final line in wrapped) {
          add(line, item: i);
        }
      }
      if (task.areAllActionsDone && task.isOpen) {
        add([
          Span('✓ ', Style(fg: palette.success, bold: true)),
          Span(strings('text_all_done_hint'), Style(fg: palette.success)),
        ]);
      }
    }

    if (task.summary.isNotEmpty) {
      blank();
      add(_sectionTitle(strings('section_summary'), width));
      for (final line in markdown.block(task.summary, width)) {
        add(line);
      }
    }
    if (task.info.isNotEmpty) {
      blank();
      add(_sectionTitle(strings('section_info'), width));
      for (final line in markdown.block(task.info, width)) {
        add(line);
      }
    }
    if (task.related.isNotEmpty) {
      blank();
      add(_sectionTitle(strings('text_related'), width));
      final tags = <Span>[];
      for (final id in task.related) {
        tags
          ..add(Span('[$id]', palette.mutedText))
          ..add(const Span(' '));
      }
      for (final line in Wrap.spans(tags, width)) {
        add(line);
      }
    }

    return lines;
  }

  /// Width of the text column in the details for a pane of [paneWidth].
  static int detailWidth(int paneWidth) => math.min<int>(paneWidth - 4, 100);

  // Helpers
  void _header(Canvas canvas, int width) {
    final style = palette.sidebarBase;
    canvas.fill(Rect(0, 0, width, 1), style);
    var x = canvas.spans(1, 0, [
      Span('⇄ ', Style(fg: palette.accent, bold: true)),
      Span(strings('title_app'), palette.title),
    ]);
    if (ui.workspace.isNotEmpty) {
      x = canvas.spans(x, 0, [
        Span('  ·  ', palette.mutedText),
        Span(WorkspaceLayout.rootNameOf(ui.workspace)),
      ], maxX: width - 24);
    }

    final open = board.openCount;
    final right = [
      if (ui.screen == Screen.board)
        Span(
          strings('text_open_count_short', {'count': open}),
          Style(fg: open > 0 ? palette.accent : palette.muted, bold: open > 0),
        ),
      Span('   ?', Style(fg: palette.accent, bold: true)),
      Span(' ${strings('button_help')} ', palette.mutedText),
    ];
    final rightWidth = _width(right);
    if (x + rightWidth + 2 <= width) {
      canvas.spans(width - rightWidth, 0, right);
    }
  }

  void _footer(Canvas canvas, int width, int y) {
    final toast = ui.toast;
    if (toast != null) {
      final style = Style(
        fg: palette.onAccent,
        bg: toast.isError ? palette.danger : palette.accent,
        bold: true,
      );
      canvas
        ..fill(Rect(0, y, width, 1), style)
        ..text(1, y, TextWidth.truncate(toast.text, width - 2), style);
      return;
    }

    canvas.fill(Rect(0, y, width, 1), palette.sidebarBase);
    final hints = _hints();
    List<Span> spansOf(List<(String, String)> pairs) => [
      for (final (key, label) in pairs) ...[
        Span(key, Style(fg: palette.accent, bold: true)),
        Span(' $label   ', palette.mutedText),
      ],
    ];
    // Drop hints before "help" and "quit" until the rest fit, rather than
    // cutting one in half.
    while (hints.length > 2 && _width(spansOf(hints)) > width - 2) {
      hints.removeAt(hints.length - 3);
    }
    canvas.spans(1, y, spansOf(hints), maxX: width - 1);
  }

  List<(String, String)> _hints() {
    final s = strings;
    if (ui.modal != null) return const [];
    switch (ui.screen) {
      case Screen.loading:
        return [('q', s('button_quit'))];
      case Screen.welcome:
        return [
          ('Enter', s('button_choose_folder')),
          (',', s('menu_settings')),
          ('q', s('button_quit')),
        ];
      case Screen.error:
        return [
          ('r', s('button_retry')),
          ('w', s('button_choose_folder')),
          ('q', s('button_quit')),
        ];
      case Screen.board:
        break;
    }
    final task = board.selectedTask;
    const common = <(String, String)>[];
    return switch (ui.focus) {
      Pane.projects => [
        ...common,
        ('t', '${s('tab_open')}/${s('tab_done')}'),
        ('w', s('button_choose_folder')),
        (',', s('menu_settings')),
        ('?', s('button_help')),
        ('q', s('button_quit')),
      ],
      Pane.list => [
        ...common,
        ('t', '${s('tab_open')}/${s('tab_done')}'),
        if (task != null && task.isOpen) ('d', s('button_close_task')),
        if (task != null && task.isDone) ('u', s('button_reopen')),
        if (task != null) ('a', s('button_connect_agent')),
        if (task != null) ('e', s('button_edit_file')),
        ('?', s('button_help')),
        ('q', s('button_quit')),
      ],
      Pane.detail => [
        ...common,
        if (task != null && task.actions.isNotEmpty) ...[
          ('␣', s('button_tick')),
          ('i', s('button_ask_item')),
        ],
        if (task != null && task.isOpen) ('d', s('button_close_task')),
        if (task != null && task.isDone) ('u', s('button_reopen')),
        if (task != null) ('a', s('button_connect_agent')),
        if (task != null) ('e', s('button_edit_file')),
        ('?', s('button_help')),
        ('q', s('button_quit')),
      ],
    };
  }

  void _board(Canvas canvas, Rect body) {
    final layout = BoardLayout.of(body, ui.focus);
    for (final x in layout.separators) {
      canvas.fill(Rect(x, body.y, 1, body.height), palette.borderLine, '│');
    }
    final projects = layout.projects;
    final list = layout.list;
    final detail = layout.detail;
    if (projects != null) {
      _projects(canvas, projects, ui.focus == Pane.projects);
    }
    if (list != null) _list(canvas, list, ui.focus == Pane.list);
    if (detail != null) _detail(canvas, detail, ui.focus == Pane.detail);
  }

  // Projects pane
  void _projects(Canvas canvas, Rect rect, bool focused) {
    final base = palette.sidebarBase;
    canvas.fill(rect, base);
    final x = rect.x + 1;
    final right = rect.right - 1;
    canvas.text(
      x,
      rect.y + 1,
      strings('text_projects'),
      Style(fg: palette.muted, bold: true),
      maxX: right,
    );

    final footerHeight = rect.height >= 16 ? 6 : 0;
    final top = rect.y + 3;
    final height = rect.height - 3 - footerHeight;
    final keys = board.projectKeys;
    final summaries = {for (final s in board.projects) s.key: s};
    final selected = math.max<int>(0, keys.indexOf(board.selectedProject));
    ui.projectScroll = _follow(ui.projectScroll, selected, height, keys.length);

    for (var row = 0; row < height; row++) {
      final index = ui.projectScroll + row;
      if (index >= keys.length) break;
      final key = keys[index];
      final y = top + row;
      final isSelected = key == board.selectedProject;
      final count = key == Board.allProjects
          ? board.openCount
          : summaries[key]?.openCount ?? 0;
      final label = key == Board.allProjects
          ? strings('text_all_projects')
          : key;
      final rowStyle = _rowStyle(isSelected, focused);
      if (rowStyle.bg != null) {
        canvas.fill(Rect(rect.x, y, rect.width, 1), base.merge(rowStyle));
      }
      if (isSelected) canvas.text(rect.x, y, '▌', _barStyle(focused));
      final countText = count > 0 ? '$count' : '';
      canvas
        ..text(
          x + 1,
          y,
          TextWidth.truncate(label, right - x - 2 - countText.length - 1),
          rowStyle.merge(Style(bold: isSelected)),
        )
        ..text(
          right - countText.length,
          y,
          countText,
          rowStyle.fg != null && rowStyle.bg == palette.accent
              ? rowStyle
              : Style(fg: palette.accent, bold: true),
        );
    }

    if (footerHeight > 0) {
      final y = rect.bottom - footerHeight;
      canvas
        ..fill(Rect(x, y, rect.width - 2, 1), palette.borderLine, '─')
        ..text(
          x,
          y + 1,
          strings('text_workspace'),
          palette.mutedText,
          maxX: right,
        )
        ..text(
          x,
          y + 2,
          TextWidth.truncate(
            WorkspaceLayout.rootNameOf(ui.workspace),
            right - x,
          ),
          const Style(bold: true),
        )
        ..text(
          x,
          y + 3,
          TextWidth.truncate(
            _shortPath(WorkspaceLayout.rootOf(ui.workspace)),
            right - x,
          ),
          palette.mutedText,
        )
        ..spans(x, y + 4, [
          Span('w', Style(fg: palette.accent, bold: true)),
          Span(' ${strings('button_choose_folder')}  ', palette.mutedText),
          Span('W', Style(fg: palette.accent, bold: true)),
          Span(' ${strings('button_open_workspace')}', palette.mutedText),
        ], maxX: right);
    }
  }

  // List pane
  void _list(Canvas canvas, Rect rect, bool focused) {
    canvas.fill(rect, palette.base);
    final x = rect.x + 1;
    final right = rect.right - 1;

    // Open / Done tabs.
    var tabX = x;
    for (final done in [false, true]) {
      final active = board.showDone == done;
      final label =
          ' ${strings(done ? 'tab_done' : 'tab_open')} '
          '${board.countFor(done: done)} ';
      final style = active
          ? Style(fg: palette.onAccent, bg: palette.accent, bold: true)
          : palette.mutedText;
      tabX = canvas.text(tabX, rect.y + 1, label, style, maxX: right) + 1;
    }

    final top = rect.y + 3;
    final height = rect.height - 3;
    final tasks = board.visibleTasks;
    if (tasks.isEmpty) {
      final key = board.showDone ? 'text_no_tasks_done' : 'text_no_tasks_open';
      _centered(canvas, Rect(rect.x, top, rect.width, height), [
        [Span(strings(key), palette.title)],
        const [],
        for (final line in Wrap.text(strings('${key}_hint'), rect.width - 4))
          [Span(line, palette.mutedText)],
      ]);
      return;
    }

    final width = rect.width - 4;
    final showProject = board.selectedProject == Board.allProjects;
    final cards = <List<List<Span>>>[];
    final tops = <int>[];
    var lineCount = 0;
    for (final task in tasks) {
      final card = _card(task, width, showProject);
      tops.add(lineCount);
      cards.add(card);
      lineCount += card.length + 1;
    }
    final selected = math.max<int>(
      0,
      tasks.indexWhere((task) => task.id == board.selectedTaskId),
    );
    final cardTop = tops[selected];
    final cardBottom = cardTop + cards[selected].length;
    if (cardTop < ui.listScroll) ui.listScroll = cardTop;
    if (cardBottom > ui.listScroll + height) {
      ui.listScroll = cardBottom - height;
    }
    ui.listScroll = ui.listScroll.clamp(
      0,
      math.max<int>(0, lineCount - 1 - height),
    );

    for (var i = 0; i < cards.length; i++) {
      final isSelected = i == selected;
      final rowStyle = _cardStyle(isSelected, focused);
      for (var line = 0; line < cards[i].length; line++) {
        final y = top + tops[i] + line - ui.listScroll;
        if (y < top || y >= top + height) continue;
        if (rowStyle.bg != null) {
          canvas.fill(
            Rect(rect.x, y, rect.width, 1),
            palette.base.merge(rowStyle),
          );
        }
        if (isSelected) canvas.text(rect.x, y, '▌', _barStyle(focused));
        canvas.spans(x + 1, y, cards[i][line], maxX: right, base: rowStyle);
      }
    }
    _scrollMarks(
      canvas,
      rect.right - 1,
      top,
      height,
      ui.listScroll,
      lineCount - 1,
    );
  }

  List<List<Span>> _card(TaskModel task, int width, bool showProject) {
    // The title on at most two lines, like the desktop card.
    final title = Wrap.text(task.title, width);
    final lines = <List<Span>>[
      [Span(title.first, palette.title)],
      if (title.length > 1)
        [
          Span(
            TextWidth.truncate(title.sublist(1).join(' '), width),
            palette.title,
          ),
        ],
    ];

    final date = DateText.relative(task.createdAt, strings);
    final meta = showProject ? '${task.agent}  ·  ${task.project}' : task.agent;
    final metaWidth = width - 2 - TextWidth.ofString(date) - 1;
    final metaText = TextWidth.truncate(meta, metaWidth);
    lines.add([
      Span('● ', Style(fg: Palette.agentColor(task.agent))),
      Span(metaText, palette.mutedText),
      Span(
        ' ' * math.max<int>(1, metaWidth - TextWidth.ofString(metaText) + 1),
      ),
      Span(date, palette.mutedText),
    ]);

    if (task.actions.isNotEmpty) {
      final count = '${task.doneActionCount}/${task.actions.length}';
      lines.add([
        ..._progressBar(
          task.doneActionCount,
          task.actions.length,
          width - count.length - 1,
        ),
        Span(' $count', palette.mutedText),
      ]);
    }

    return lines;
  }

  // Detail pane
  void _detail(Canvas canvas, Rect rect, bool focused) {
    canvas.fill(rect, palette.base);
    final task = board.selectedTask;
    if (task == null) {
      _centered(canvas, rect, [
        [Span(strings('text_select_task'), palette.title)],
        const [],
        for (final line in Wrap.text(
          strings('text_select_task_hint'),
          rect.width - 4,
        ))
          [Span(line, palette.mutedText)],
      ]);
      return;
    }

    final width = detailWidth(rect.width);
    final x = rect.x + 2;
    final top = rect.y + 1;
    final height = rect.height - 1;
    final lines = detailLines(task, width, focused: focused);

    if (ui.followCursor && task.actions.isNotEmpty) {
      final rows = [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].item == ui.detailCursor) i,
      ];
      if (rows.isNotEmpty) {
        // Keep the checklist title in view while the cursor is on the first
        // items, so the list is never cut off from its heading.
        final first = ui.detailCursor == 0 ? 0 : rows.first;
        if (first < ui.detailScroll) ui.detailScroll = first;
        if (rows.last >= ui.detailScroll + height) {
          ui.detailScroll = rows.last - height + 1;
        }
      }
    }
    ui.detailScroll = ui.detailScroll.clamp(
      0,
      math.max<int>(0, lines.length - height),
    );

    for (var row = 0; row < height; row++) {
      final index = ui.detailScroll + row;
      if (index >= lines.length) break;
      final line = lines[index];
      final y = top + row;
      final isCursor =
          focused && line.item != null && line.item == ui.detailCursor;
      final rowStyle = isCursor ? _rowStyle(true, true) : Style.plain;
      if (isCursor) {
        canvas
          ..fill(Rect(rect.x, y, rect.width, 1), palette.base.merge(rowStyle))
          ..text(rect.x, y, '▌', _barStyle(true));
      }
      canvas.spans(
        x,
        y,
        line.spans,
        maxX: rect.right - 1,
        base: isCursor ? rowStyle : null,
      );
    }
    _scrollMarks(
      canvas,
      rect.right - 1,
      top,
      height,
      ui.detailScroll,
      lines.length,
    );
  }

  List<List<Span>> _buttons(TaskModel task, int width) {
    final hasAgent = task.cwd != null;
    final buttons = <(String, String, bool)>[
      if (task.isOpen) ('d', strings('button_close_task'), true),
      if (task.isDone) ('u', strings('button_reopen'), true),
      if (hasAgent) ('a', strings('button_connect_agent'), false),
      ('e', strings('button_edit_file'), false),
      if (task.location != null) ...[
        ('o', strings('button_open_file'), false),
        ('f', strings.revealLabel, false),
      ],
    ];
    final lines = <List<Span>>[];
    var line = <Span>[];
    var used = 0;
    for (final (key, label, primary) in buttons) {
      final pill = [
        Span('[$key]', Style(fg: palette.accent, bold: true)),
        Span(' $label', primary ? const Style(bold: true) : Style.plain),
      ];
      final w = _width(pill) + 3;
      if (used > 0 && used + w > width) {
        lines.add(line);
        line = [];
        used = 0;
      }
      line
        ..addAll(pill)
        ..add(const Span('   '));
      used += w;
    }
    if (line.isNotEmpty) lines.add(line);

    return lines;
  }

  List<Span> _sectionTitle(String title, int width, {String? trailing}) {
    final left = [
      Span('▍', Style(fg: palette.accent, bold: true)),
      Span(' $title', palette.title),
    ];
    if (trailing == null) return left;
    final gap = width - _width(left) - TextWidth.ofString(trailing);

    return [
      ...left,
      Span(' ' * math.max<int>(2, gap)),
      Span(trailing, palette.mutedText),
    ];
  }

  List<Span> _progressBar(int done, int total, int width) {
    if (width <= 0 || total == 0) return const [];
    final filled = (done / total * width).round().clamp(0, width);
    final complete = done == total;

    return [
      Span(
        '━' * filled,
        Style(fg: complete ? palette.success : palette.accent),
      ),
      Span('─' * (width - filled), palette.borderLine),
    ];
  }

  // Screens
  void _welcome(Canvas canvas, Rect body) {
    final width = math.min<int>(64, body.width - 6);
    _centered(canvas, body, [
      [
        Span('⇄  ', Style(fg: palette.accent, bold: true)),
        Span(strings('title_app'), palette.title),
      ],
      [Span(strings('text_tagline'), palette.mutedText)],
      const [],
      const [],
      [Span(strings('text_welcome'), palette.title)],
      const [],
      for (final line in Wrap.text(strings('text_welcome_hint'), width))
        [Span(line)],
      const [],
      [
        Span(
          ' Enter ',
          Style(fg: palette.onAccent, bg: palette.accent, bold: true),
        ),
        Span('  ${strings('button_choose_folder')}', const Style(bold: true)),
      ],
      const [],
      [Span('handoff <folder>', Style(fg: palette.code))],
    ]);
  }

  void _error(Canvas canvas, Rect body) {
    final width = math.min<int>(72, body.width - 6);
    _centered(canvas, body, [
      [Span(strings('text_error_load'), Style(fg: palette.danger, bold: true))],
      const [],
      for (final line in Wrap.text(ui.errorMessage, width)) [Span(line)],
      const [],
      if (ui.workspace.isNotEmpty)
        [
          Span(
            TextWidth.truncate(_shortPath(ui.workspace), width),
            palette.mutedText,
          ),
        ],
      const [],
      [Span(strings('text_retry_hint'), palette.accentText)],
    ]);
  }

  // Dialogs
  Rect _dialog(Canvas canvas, int width, int height, String title) {
    final w = math.min<int>(width, canvas.width - 2);
    final h = math.min<int>(height, canvas.height - 2);
    final x = (canvas.width - w) ~/ 2;
    final y = (canvas.height - h) ~/ 2;
    final box = Rect(x, y, w, h);
    final base = palette.sidebarBase;
    canvas.fill(box, base);
    final border = base.merge(Style(fg: palette.accent));
    canvas
      ..fill(Rect(x + 1, y, w - 2, 1), border, '─')
      ..fill(Rect(x + 1, y + h - 1, w - 2, 1), border, '─')
      ..fill(Rect(x, y + 1, 1, h - 2), border, '│')
      ..fill(Rect(x + w - 1, y + 1, 1, h - 2), border, '│')
      ..text(x, y, '╭', border)
      ..text(x + w - 1, y, '╮', border)
      ..text(x, y + h - 1, '╰', border)
      ..text(x + w - 1, y + h - 1, '╯', border)
      ..text(x + 2, y, ' $title ', base.merge(palette.title), maxX: x + w - 2);

    return box.inset(left: 2, top: 1, right: 2, bottom: 1);
  }

  void _confirm(Canvas canvas, ConfirmModal modal) {
    final width = math.max<int>(40, TextWidth.ofString(modal.message) + 8);
    final inner = _dialog(canvas, width, 7, strings('title_app'));
    canvas.text(
      inner.x,
      inner.y + 1,
      modal.message,
      const Style(bold: true),
      maxX: inner.right,
    );
    var x = inner.x;
    for (final (i, label) in [
      strings('button_confirm'),
      strings('button_cancel'),
    ].indexed) {
      final active = modal.choice == i;
      x =
          canvas.text(
            x,
            inner.y + 3,
            ' $label ',
            active
                ? Style(fg: palette.onAccent, bg: palette.accent, bold: true)
                : palette.mutedText,
          ) +
          2;
    }
  }

  void _settings(Canvas canvas, SettingsModal modal) {
    final inner = _dialog(canvas, 44, 14, strings('menu_settings'));
    final languages = [strings('menu_system_default'), 'English', 'Türkçe'];
    final appearances = [
      strings('menu_appearance_system'),
      strings('menu_appearance_light'),
      strings('menu_appearance_dark'),
    ];
    final language = Language.values.indexOf(_language);
    final appearance = Appearance.values.indexOf(_appearance);
    var y = inner.y;
    void group(String title, List<String> options, int chosen, int offset) {
      canvas.text(inner.x, y++, title, Style(fg: palette.muted, bold: true));
      for (var i = 0; i < options.length; i++) {
        final isCursor = modal.cursor == offset + i;
        final style = isCursor
            ? Style(fg: palette.onAccent, bg: palette.accent, bold: true)
            : Style.plain;
        if (isCursor) {
          canvas.fill(
            Rect(inner.x, y, inner.width, 1),
            palette.sidebarBase.merge(style),
          );
        }
        canvas.text(
          inner.x + 1,
          y++,
          '${chosen == i ? '●' : '○'} ${options[i]}',
          style,
        );
      }
      y++;
    }

    group(strings('menu_language'), languages, language, 0);
    group(strings('menu_appearance'), appearances, appearance, 3);
    canvas.text(
      inner.x,
      inner.bottom - 1,
      strings('text_settings_hint'),
      palette.mutedText,
      maxX: inner.right,
    );
  }

  void _help(Canvas canvas, HelpModal modal) {
    final rows = <(String, String)>[
      ('↑↓  j k', strings('help_move')),
      ('Tab ←→ h l', strings('help_panes')),
      ('Enter', strings('help_open')),
      ('Esc', strings('help_back')),
      ('Space', strings('help_tick')),
      ('1–9', strings('help_tick_n')),
      ('t', strings('help_tab')),
      ('d', strings('help_done')),
      ('u', strings('help_reopen')),
      ('a', strings('help_agent')),
      ('i', strings('help_ask')),
      ('e', strings('help_edit')),
      ('o', strings('help_open_file')),
      ('f', strings('help_reveal')),
      ('w', strings('help_workspace')),
      ('W', strings('help_open_workspace')),
      ('r', strings('help_refresh')),
      ('PgUp PgDn', strings('help_scroll')),
      (',  s', strings('help_settings')),
      ('q', strings('help_quit')),
    ];
    final width = math.min<int>(74, canvas.width - 4);
    final note = Wrap.text(strings('help_agent_note'), width - 4);
    final inner = _dialog(
      canvas,
      width,
      rows.length + note.length + 5,
      '${strings('text_keys')} · ${strings('title_app')}',
    );
    final lines = <List<Span>>[
      for (final (keys, label) in rows)
        [
          Span(TextWidth.fit(keys, 13), Style(fg: palette.accent, bold: true)),
          Span(label),
        ],
      const [],
      for (final line in note) [Span(line, palette.mutedText)],
    ];
    modal.scroll = modal.scroll.clamp(
      0,
      math.max<int>(0, lines.length - inner.height),
    );
    for (var row = 0; row < inner.height; row++) {
      final index = modal.scroll + row;
      if (index >= lines.length) break;
      canvas.spans(inner.x, inner.y + row, lines[index], maxX: inner.right);
    }
  }

  void _folder(Canvas canvas, FolderModal modal) {
    final width = math.min<int>(76, canvas.width - 4);
    final height = math.min<int>(modal.rowCount + 7, canvas.height - 2);
    final inner = _dialog(
      canvas,
      width,
      math.max<int>(height, 10),
      strings('button_choose_folder'),
    );
    final right = inner.right;

    // The folder, or the path being typed.
    if (modal.typing) {
      canvas
        ..fill(
          Rect(inner.x, inner.y, inner.width, 1),
          palette.sidebarBase.merge(
            Style(bg: palette.selection ?? palette.border),
          ),
        )
        ..text(
          inner.x,
          inner.y,
          '${_tail(modal.typed, inner.width - 2)}▏',
          Style(bold: true, bg: palette.selection ?? palette.border),
        );
    } else {
      canvas.text(
        inner.x,
        inner.y,
        _tail(_shortPath(modal.directory), inner.width),
        Style(fg: palette.accent, bold: true),
      );
    }
    final note = modal.error != null
        ? Span(
            TextWidth.truncate('✗ ${modal.error}', inner.width),
            Style(fg: palette.danger),
          )
        : Span(
            modal.typing ? strings('text_type_path') : '',
            palette.mutedText,
          );
    canvas.spans(inner.x, inner.y + 1, [note], maxX: right);

    final top = inner.y + 2;
    final height2 = inner.height - 3;
    modal.scroll = _follow(modal.scroll, modal.cursor, height2, modal.rowCount);
    for (var row = 0; row < height2; row++) {
      final index = modal.scroll + row;
      if (index >= modal.rowCount) break;
      final y = top + row;
      final isCursor = index == modal.cursor && !modal.typing;
      final style = isCursor
          ? Style(fg: palette.onAccent, bg: palette.accent, bold: true)
          : Style.plain;
      if (isCursor) {
        canvas.fill(
          Rect(inner.x, y, inner.width, 1),
          palette.sidebarBase.merge(style),
        );
      }
      final List<Span> spans;
      var hasTasks = false;
      if (index == 0) {
        hasTasks = FolderModal.hasTasks(modal.directory);
        spans = [
          Span('✓ ', isCursor ? style : Style(fg: palette.success, bold: true)),
          Span(
            strings('text_use_folder'),
            style.merge(const Style(bold: true)),
          ),
        ];
      } else if (index == 1) {
        spans = [
          Span('↰ ', isCursor ? style : palette.mutedText),
          Span(
            strings('text_parent_folder'),
            isCursor ? style : palette.mutedText,
          ),
        ];
      } else {
        final entry = modal.entries[index - 2];
        hasTasks = entry.hasTasks;
        spans = [
          Span('▸ ', isCursor ? style : palette.mutedText),
          Span(entry.name, style),
        ];
      }
      canvas.spans(inner.x + 1, y, spans, maxX: right - 10, base: style);
      if (hasTasks) {
        final badge = '◆ ${strings('text_has_tasks')}';
        canvas.text(
          right - TextWidth.ofString(badge),
          y,
          badge,
          isCursor ? style : Style(fg: palette.accent),
        );
      }
    }
    if (modal.rowCount == 2 && height2 > 3) {
      canvas.text(
        inner.x + 3,
        top + 3,
        strings('text_no_subfolders'),
        palette.mutedText,
      );
    }
    canvas.text(
      inner.x,
      inner.bottom - 1,
      strings('text_folder_hints'),
      palette.mutedText,
      maxX: right,
    );
  }

  // Shared bits
  Language _language = Language.system;
  Appearance _appearance = Appearance.system;

  /// The choices the settings dialog marks as current.
  void setChoices(Language language, Appearance appearance) {
    _language = language;
    _appearance = appearance;
  }

  Style _rowStyle(bool selected, bool focused) {
    if (!selected) return Style.plain;
    if (!focused) return const Style(bold: true);
    final selection = palette.selection;

    return selection == null
        ? Style(fg: palette.onAccent, bg: palette.accent, bold: true)
        : Style(bg: selection, bold: true);
  }

  /// Cards are taller than rows: in "system" a focused card gets the accent
  /// bar and an accent title rather than a solid accent block.
  Style _cardStyle(bool selected, bool focused) {
    if (!selected) return Style.plain;
    final selection = palette.selection;
    if (focused && selection != null) return Style(bg: selection);

    return Style.plain;
  }

  Style _barStyle(bool focused) =>
      Style(fg: focused ? palette.accent : palette.muted, bold: true);

  void _centered(Canvas canvas, Rect rect, List<List<Span>> lines) {
    final top = rect.y + math.max<int>(0, (rect.height - lines.length) ~/ 2);
    for (var i = 0; i < lines.length; i++) {
      final y = top + i;
      if (y >= rect.bottom) break;
      final w = _width(lines[i]);
      final x = rect.x + math.max<int>(0, (rect.width - w) ~/ 2);
      canvas.spans(x, y, lines[i], maxX: rect.right);
    }
  }

  void _scrollMarks(
    Canvas canvas,
    int x,
    int top,
    int height,
    int scroll,
    int total,
  ) {
    if (total <= height) return;
    if (scroll > 0) canvas.text(x, top, '↑', palette.mutedText);
    if (scroll + height < total) {
      canvas.text(x, top + height - 1, '↓', palette.mutedText);
    }
  }

  static int _follow(int scroll, int index, int height, int count) {
    if (height <= 0) return 0;
    var next = scroll;
    if (index < next) next = index;
    if (index >= next + height) next = index - height + 1;

    return next.clamp(0, math.max<int>(0, count - height));
  }

  static int _width(List<Span> spans) =>
      spans.fold(0, (sum, span) => sum + TextWidth.ofString(span.text));

  /// The end of [text] when it does not fit: the folder name matters more
  /// than the start of its path.
  static String _tail(String text, int width) {
    if (TextWidth.ofString(text) <= width) return text;
    final runes = text.runes.toList();
    var used = 1;
    var start = runes.length;
    while (start > 0 && used + TextWidth.of(runes[start - 1]) <= width) {
      start--;
      used += TextWidth.of(runes[start]);
    }

    return '…${String.fromCharCodes(runes.sublist(start))}';
  }

  static String _shortPath(String path) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }

    return path;
  }

  // - Helpers
}

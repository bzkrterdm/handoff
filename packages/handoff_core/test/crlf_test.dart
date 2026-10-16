import 'package:handoff_core/handoff_core.dart';
import 'package:test/test.dart';

/// Files saved on Windows (or checked out there) use CRLF line endings.
void main() {
  const lf =
      '---\n'
      'title: T\n'
      'agent: claude\n'
      'status: open\n'
      'created: 2026-10-01T09:00:00+02:00\n'
      '---\n'
      '\n'
      '## Actions\n'
      '\n'
      '- [ ] first\n'
      '- [x] second\n';
  final crlf = lf.replaceAll('\n', '\r\n');

  test('reads the checklist of a CRLF file', () {
    final model = TaskMarkdownParser.parse(crlf, id: 't', fallbackProject: 'p');

    expect(model.actions.map((a) => a.text), ['first', 'second']);
    expect(model.actions.map((a) => a.isDone), [false, true]);
    expect(model.title, 'T');
    expect(TaskMarkdownParser.isTask(crlf), isTrue);
  });

  test('ticks a box and keeps the line ending', () {
    final edited = TaskMarkdownParser.withActionDone(
      crlf,
      index: 0,
      isDone: true,
    );

    expect(edited, crlf.replaceFirst('- [ ] first', '- [x] first'));
  });

  test('closes a task with CRLF lines throughout', () {
    final edited = TaskMarkdownParser.withStatus(
      crlf,
      status: 'done',
      closedAt: DateTime(2026, 10, 2, 8),
    );

    expect(
      edited,
      contains('status: done\r\nclosed: 2026-10-02T08:00:00.000\r\n'),
    );
    expect(edited.replaceAll('\r\n', ''), isNot(contains('\n')));
    expect(
      TaskMarkdownParser.parse(edited, id: 't', fallbackProject: 'p').status,
      'done',
    );
  });

  test('LF files are unchanged by the CRLF handling', () {
    expect(
      TaskMarkdownParser.withStatus(lf, status: 'done', closedAt: null),
      isNot(contains('\r')),
    );
  });
}

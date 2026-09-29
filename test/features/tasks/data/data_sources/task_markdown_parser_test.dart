import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/features/tasks/data/data_sources/task_markdown_parser.dart';

import '../../../../fixtures/task_fixtures.dart';

void main() {
  group('TaskMarkdownParser.parse', () {
    test('reads front matter, sections and checkboxes', () {
      final model = TaskMarkdownParser.parse(
        sampleTaskFile,
        id: 'ignored',
        fallbackProject: 'ignored',
        location: '/x.md',
      );

      expect(model.toEntity(), sampleTask(location: '/x.md'));
    });

    test('falls back to the file name and folder without front matter', () {
      final model = TaskMarkdownParser.parse(
        '# Başlık\n\n## Senden beklenenler\n\n- [ ] bir şey\n',
        id: 'file-id',
        fallbackProject: 'acme/web',
      );

      expect(model.id, 'file-id');
      expect(model.project, 'acme/web');
      expect(model.title, 'Başlık');
      expect(model.status, 'open');
      expect(model.actions.single.text, 'bir şey');
    });

    test('treats an unknown status as open and accepts english headings', () {
      final model = TaskMarkdownParser.parse(
        '---\nstatus: whatever\n---\n## Done\n\nyapıldı\n\n## Actions\n\n'
        '* [X] tick\n',
        id: 'x',
        fallbackProject: 'p',
      );

      expect(model.toEntity().isOpen, isTrue);
      expect(model.summary, 'yapıldı');
      expect(model.actions.single.isDone, isTrue);
    });

    test('survives broken yaml', () {
      final model = TaskMarkdownParser.parse(
        '---\ntitle: [unclosed\n---\nbody',
        id: 'x',
        fallbackProject: 'p',
      );

      expect(model.title, 'x');
    });
  });

  group('TaskMarkdownParser.withActionDone', () {
    test('rewrites only the addressed checkbox line', () {
      final edited = TaskMarkdownParser.withActionDone(
        sampleTaskFile,
        index: 2,
        isDone: true,
      );

      expect(edited, contains('- [x] Sonucu bildir'));
      expect(edited, contains("- [ ] Migration'ı v2'ye uygula"));
      // Everything else is byte-identical.
      expect(
        edited.replaceFirst('- [x] Sonucu bildir', '- [ ] Sonucu bildir'),
        sampleTaskFile,
      );
    });

    test('unticks', () {
      final edited = TaskMarkdownParser.withActionDone(
        sampleTaskFile,
        index: 1,
        isDone: false,
      );

      expect(edited, contains('- [ ] `share_plus`'));
    });

    test('ignores checkboxes outside the checklist section', () {
      const file =
          '## Yapılan\n\n- [ ] not a task\n\n## Senden beklenenler\n\n'
          '- [ ] real\n';

      final edited = TaskMarkdownParser.withActionDone(
        file,
        index: 0,
        isDone: true,
      );

      expect(edited, contains('- [ ] not a task'));
      expect(edited, contains('- [x] real'));
    });

    test('throws for a missing index', () {
      expect(
        () => TaskMarkdownParser.withActionDone(
          sampleTaskFile,
          index: 3,
          isDone: true,
        ),
        throwsRangeError,
      );
    });
  });

  group('TaskMarkdownParser.withStatus', () {
    test('closes with a timestamp and keeps the other keys', () {
      final closedAt = DateTime.parse('2026-09-30T09:00:00.000');
      final edited = TaskMarkdownParser.withStatus(
        sampleTaskFile,
        status: 'done',
        closedAt: closedAt,
      );
      final model = TaskMarkdownParser.parse(
        edited,
        id: 'x',
        fallbackProject: 'p',
      );

      expect(model.status, 'done');
      expect(model.closedAt, closedAt);
      expect(model.title, 'API için hız sınırı');
      expect(model.related, ['20260926-1800-api-pg16']);
      expect(edited, contains('## Senden beklenenler'));
    });

    test('reopening drops the closed stamp', () {
      final closed = TaskMarkdownParser.withStatus(
        sampleTaskFile,
        status: 'done',
        closedAt: DateTime(2026),
      );
      final reopened = TaskMarkdownParser.withStatus(
        closed,
        status: 'open',
        closedAt: null,
      );
      final model = TaskMarkdownParser.parse(
        reopened,
        id: 'x',
        fallbackProject: 'p',
      );

      expect(model.status, 'open');
      expect(model.closedAt, isNull);
      expect('closed:'.allMatches(reopened), isEmpty);
    });

    test('adds a front matter to a file without one', () {
      final edited = TaskMarkdownParser.withStatus(
        '# Başlık\n',
        status: 'done',
        closedAt: DateTime(2026),
      );

      expect(edited, startsWith('---\nstatus: done\nclosed: 2026-01-01'));
      expect(edited, endsWith('---\n# Başlık\n'));
    });
  });

  group('TaskMarkdownParser.parse with a malformed header line', () {
    test('keeps status and the other keys when one line is not YAML', () {
      const content =
          '---\n'
          'agent: claude\n'
          'title: "Agenta bağlan": görevden oturum\n'
          'related: [a, b]\n'
          'status: done\n'
          '---\n'
          '## Yapılan\n- x\n';

      final task = TaskMarkdownParser.parse(
        content,
        id: 'id',
        fallbackProject: 'p',
      );

      expect(task.status, 'done');
      expect(task.agent, 'claude');
      expect(task.title, '"Agenta bağlan": görevden oturum');
      expect(task.related, ['a', 'b']);
    });
  });
}

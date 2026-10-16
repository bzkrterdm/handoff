import 'package:handoff_core/handoff_core.dart';
import 'package:handoff_tui/handoff_tui.dart';
import 'package:test/test.dart';

TaskModel _task(
  String id, {
  String project = 'acme/api',
  String status = 'open',
  int day = 1,
}) {
  return TaskModel(
    id: id,
    project: project,
    title: id,
    agent: 'claude',
    createdAt: DateTime(2026, 9, day),
    status: status,
  );
}

void main() {
  late Board board;

  setUp(() {
    board = Board()
      ..load([
        _task('old', day: 1),
        _task('web', project: 'acme/web', day: 3),
        _task('new', day: 5),
        _task('closed', status: 'done', day: 4),
      ]);
  });

  test('sorts newest first and selects the first open task', () {
    expect(board.tasks.map((t) => t.id), ['new', 'closed', 'web', 'old']);
    expect(board.selectedTaskId, 'new');
    expect(board.openCount, 3);
  });

  test('projects carry open and total counts', () {
    final api = board.projects.firstWhere((p) => p.key == 'acme/api');
    expect(api.openCount, 2);
    expect(api.totalCount, 3);
    expect(board.projectKeys.first, Board.allProjects);
  });

  test('changing project or filter lands on the first visible task', () {
    board.selectProject('acme/web');
    expect(board.selectedTaskId, 'web');
    board
      ..selectProject('acme/api')
      ..setShowDone(true);
    expect(board.selectedTaskId, 'closed');
  });

  test('a reload keeps the selection while the task exists', () {
    board
      ..moveSelection(1)
      ..load(board.tasks);
    expect(board.selectedTaskId, 'web');
    board.load([_task('other')]);
    expect(board.selectedTaskId, 'other');
  });

  test('a status other than done is open', () {
    expect(_task('x', status: 'Done ').isDone, isTrue);
    expect(_task('x', status: 'opne').isOpen, isTrue);
  });
}

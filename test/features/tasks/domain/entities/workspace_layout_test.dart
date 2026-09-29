import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/features/tasks/domain/entities/workspace_layout.dart';

void main() {
  test('strips a known task folder to reach the workspace root', () {
    expect(WorkspaceLayout.rootOf('/ws/.handoff/tasks/'), '/ws');
    expect(WorkspaceLayout.rootOf('/ws/_hub/tasks'), '/ws');
    expect(WorkspaceLayout.rootOf('/ws/tasks'), '/ws');
    expect(WorkspaceLayout.rootOf('/ws'), '/ws');
  });

  test('names the workspace after its root folder', () {
    expect(WorkspaceLayout.rootNameOf('/Users/me/code/.handoff/tasks'), 'code');
    expect(
      WorkspaceLayout.rootNameOf('/Users/me/notes/.handoff/tasks'),
      'notes',
    );
    expect(WorkspaceLayout.rootNameOf(''), '');
  });
}

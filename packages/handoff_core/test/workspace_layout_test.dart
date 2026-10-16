import 'package:handoff_core/handoff_core.dart';
import 'package:test/test.dart';

void main() {
  group('WorkspaceLayout on Windows paths', () {
    test('finds the root above a backslash task folder', () {
      expect(
        WorkspaceLayout.rootOf(r'C:\work\acme\.handoff\tasks'),
        r'C:\work\acme',
      );
      expect(WorkspaceLayout.rootOf(r'D:\vault\_hub\tasks\'), r'D:\vault');
    });

    test('recognises a task folder written with either separator', () {
      expect(WorkspaceLayout.isTaskFolder(r'C:\w\.handoff\tasks'), isTrue);
      expect(WorkspaceLayout.isTaskFolder(r'C:\w/.handoff\tasks'), isTrue);
      expect(WorkspaceLayout.isTaskFolder(r'C:\w\notes'), isFalse);
    });

    test('names the workspace by its last segment', () {
      expect(
        WorkspaceLayout.rootNameOf(r'C:\Users\me\acme\.handoff\tasks'),
        'acme',
      );
    });

    test('keeps a bare drive or root', () {
      expect(WorkspaceLayout.trimSlash(r'C:\'), r'C:\');
      expect(WorkspaceLayout.trimSlash('/'), '/');
      expect(WorkspaceLayout.trimSlash('/a/b//'), '/a/b');
    });
  });
}

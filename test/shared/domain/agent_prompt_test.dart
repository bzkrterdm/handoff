import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/shared/domain/agent_prompt.dart';

void main() {
  const title = 'Ship the API';
  const path = '/ws/.handoff/tasks/api/20260929-1000-api-ship.md';

  test('the task prompt names the task, the file and the checklist', () {
    final prompt = AgentPrompt.forTask(title: title, path: path);

    expect(prompt, startsWith('We are continuing a Handoff task: "$title"'));
    expect(prompt, contains('Task file: $path'));
    expect(prompt, contains('Ask me which of the checklist items'));
    expect(prompt, contains('tick it ([x])'));
  });

  test('the item prompt is about that item only', () {
    final prompt = AgentPrompt.forItem(
      title: title,
      path: path,
      item: 'Merge PR 12',
    );

    expect(prompt, contains('Task file: $path'));
    expect(prompt, contains('this one checklist item only: "Merge PR 12"'));
    expect(prompt, contains('Do not ask about or go into the other items'));
    expect(prompt, isNot(contains('Ask me which')));
  });
}

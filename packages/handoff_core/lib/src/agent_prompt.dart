/// The first message Handoff sends to a coding agent when the owner picks a
/// task up from the app.
///
/// Always English, whatever language the UI is in: the agents work best in
/// English and the task file itself may be written in any language. Pure
/// string building, so it is unit tested without a terminal or a localizor.
abstract class AgentPrompt {
  /// The general prompt: the agent reads the task and walks the checklist
  /// with the owner.
  static String forTask({required String title, required String path}) {
    return '${_intro(title: title, path: path)}\n'
        'Ask me which of the checklist items (the "Actions" section, '
        'shown as "Expected from you" in the app) I have already finished. '
        'Help me with the rest, and when an item is done tick it ([x]) '
        'in the task file.';
  }

  /// The focused prompt: one checklist [item] only, the rest is off limits.
  static String forItem({
    required String title,
    required String path,
    required String item,
  }) {
    return '${_intro(title: title, path: path)}\n'
        'Right now we work on this one checklist item only: "$item"\n'
        'Do not ask about or go into the other items. Help me with this '
        'one, and when it is done tick it ([x]) in the task file.';
  }

  // Helpers
  static String _intro({required String title, required String path}) {
    return 'We are continuing a Handoff task: "$title"\n'
        'Task file: $path\n'
        'Read the task file first, then the project\'s own status notes if '
        'it keeps any (for example ai_docs/progress/status.md). '
        'I am the task owner.';
  }

  // - Helpers
}

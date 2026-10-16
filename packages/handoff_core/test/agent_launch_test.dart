import 'package:handoff_core/handoff_core.dart';
import 'package:test/test.dart';

void main() {
  group('AgentCommand.arguments', () {
    test('passes the prompt as one argument, no shell quoting', () {
      expect(
        AgentCommand.arguments(
          const AgentLaunch(
            agent: 'claude',
            workingDirectory: '/w',
            prompt: "it's \"quoted\"\nand multi-line",
          ),
        ),
        ['claude', "it's \"quoted\"\nand multi-line"],
      );
    });

    test('resumes claude and codex sessions their own way', () {
      expect(
        AgentCommand.arguments(
          const AgentLaunch(
            agent: 'Claude',
            workingDirectory: '/w',
            prompt: 'p',
            sessionId: 's1',
          ),
        ),
        ['claude', '--resume', 's1', 'p'],
      );
      expect(
        AgentCommand.arguments(
          const AgentLaunch(
            agent: 'codex',
            workingDirectory: '/w',
            prompt: 'p',
            sessionId: 's2',
          ),
        ),
        ['codex', 'resume', 's2', 'p'],
      );
    });

    test('quotes a prompt that happens to read "resume"', () {
      expect(
        AgentCommand.shellLine(
          const AgentLaunch(
            agent: 'codex',
            workingDirectory: '/w',
            prompt: 'resume',
            sessionId: 's',
          ),
        ),
        "cd '/w' && codex resume 's' 'resume'",
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/shared/data/agent_launcher_impl.dart';
import 'package:handoff/shared/domain/agent_launcher.dart';

void main() {
  group('AgentCommand.shellLine', () {
    test('starts claude in the folder with the prompt', () {
      final line = AgentCommand.shellLine(
        const AgentLaunch(
          agent: 'claude',
          workingDirectory: '/v/acme/api',
          prompt: 'Görev: "x"',
        ),
      );

      expect(line, "cd '/v/acme/api' && claude 'Görev: \"x\"'");
    });

    test('resumes a claude session when the task has one', () {
      final line = AgentCommand.shellLine(
        const AgentLaunch(
          agent: 'Claude',
          workingDirectory: '/v',
          prompt: 'p',
          sessionId: 'abc',
        ),
      );

      expect(line, "cd '/v' && claude --resume 'abc' 'p'");
    });

    test('knows codex and falls back to claude for unknown agents', () {
      expect(
        AgentCommand.shellLine(
          const AgentLaunch(
            agent: 'codex',
            workingDirectory: '/v',
            prompt: 'p',
          ),
        ),
        "cd '/v' && codex 'p'",
      );
      expect(
        AgentCommand.shellLine(
          const AgentLaunch(
            agent: 'codex',
            workingDirectory: '/v',
            prompt: 'p',
            sessionId: 's',
          ),
        ),
        "cd '/v' && codex resume 's' 'p'",
      );
      expect(
        AgentCommand.shellLine(
          const AgentLaunch(
            agent: 'gemini',
            workingDirectory: '/v',
            prompt: 'p',
          ),
        ),
        startsWith("cd '/v' && claude "),
      );
    });

    test('escapes single quotes and keeps newlines', () {
      final line = AgentCommand.shellLine(
        const AgentLaunch(
          agent: 'claude',
          workingDirectory: "/v/it's",
          prompt: "line1\nit's",
        ),
      );

      expect(line, "cd '/v/it'\\''s' && claude 'line1\nit'\\''s'");
    });
  });
}

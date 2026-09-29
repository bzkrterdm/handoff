# Contributing

Thanks for taking a look. Handoff is small on purpose; the best
contributions keep it that way.

- **Rules of the codebase** are in [AGENTS.md](AGENTS.md). They apply to
  people and to coding agents alike (this repository is itself developed
  with them).
- **Before opening a PR** run the whole gate, which is also what CI runs:

  ```bash
  dart format .
  flutter analyze
  flutter test
  ```

- **Commits** follow the `type: summary` style already in the history
  (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
- **Task format changes** touch three places at once:
  `lib/features/tasks/data/data_sources/task_markdown_parser.dart`,
  [docs/protocol.md](docs/protocol.md) and the skill in
  [skills/handoff-task](skills/handoff-task). Keep them in step.
- **Bigger ideas** (a new store, another platform, a new agent) are worth
  an issue first; [docs/architecture.md](docs/architecture.md) explains why
  things are the way they are.

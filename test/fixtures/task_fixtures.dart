import 'package:handoff/features/tasks/domain/entities/handoff_task.dart';
import 'package:handoff/features/tasks/domain/entities/task_action.dart';
import 'package:handoff/features/tasks/domain/entities/task_status.dart';

/// A task file exactly as an agent would write it.
const String sampleTaskFile = '''
---
id: 20260929-1500-api-hiz-siniri
project: acme/api
title: API için hız sınırı
agent: claude
created: 2026-09-29T15:00:00+03:00
status: open
related:
  - 20260926-1800-api-pg16
cwd: acme/api
session: 8c1f0d3e-1111-4222-8333-444455556666
---

## Yapılan

- Migration `20260929090000_api_rate_limit` yazıldı.
- 253/253 test geçiyor.

## Bilgi

Ayarlar sayfasında "Dakikada istek" alanı var.

## Senden beklenenler

- [ ] Migration'ı v2'ye uygula (`supabase db push`)
- [x] `share_plus` paylaşımını cihazda dene
- [ ] Sonucu bildir
''';

/// The same task as the parser should read it.
HandoffTask sampleTask({String? location}) {
  return HandoffTask(
    id: '20260929-1500-api-hiz-siniri',
    project: 'acme/api',
    title: 'API için hız sınırı',
    agent: 'claude',
    createdAt: DateTime.parse('2026-09-29T15:00:00+03:00'),
    status: TaskStatus.open,
    related: const ['20260926-1800-api-pg16'],
    summary:
        '- Migration `20260929090000_api_rate_limit` yazıldı.\n'
        '- 253/253 test geçiyor.',
    info: 'Ayarlar sayfasında "Dakikada istek" alanı var.',
    actions: const [
      TaskAction(text: "Migration'ı v2'ye uygula (`supabase db push`)"),
      TaskAction(text: '`share_plus` paylaşımını cihazda dene', isDone: true),
      TaskAction(text: 'Sonucu bildir'),
    ],
    location: location,
    workingDirectory: 'acme/api',
    sessionId: '8c1f0d3e-1111-4222-8333-444455556666',
  );
}

HandoffTask task({
  required String id,
  String project = 'handoff',
  String title = 'Task',
  TaskStatus status = TaskStatus.open,
  DateTime? createdAt,
  List<TaskAction> actions = const [],
}) {
  return HandoffTask(
    id: id,
    project: project,
    title: title,
    agent: 'claude',
    createdAt: createdAt ?? DateTime(2026, 9, 29),
    status: status,
    actions: actions,
    location: '/ws/.handoff/tasks/$project/$id.md',
    workingDirectory: '/ws/$project',
  );
}

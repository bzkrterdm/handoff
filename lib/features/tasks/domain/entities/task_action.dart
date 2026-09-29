import 'package:equatable/equatable.dart';

/// One item the owner is expected to do, i.e. one checkbox line under the
/// "Senden beklenenler" section of a task.
class TaskAction extends Equatable {
  const TaskAction({required this.text, this.isDone = false});

  final String text;
  final bool isDone;

  TaskAction copyWith({String? text, bool? isDone}) {
    return TaskAction(text: text ?? this.text, isDone: isDone ?? this.isDone);
  }

  @override
  List<Object?> get props => [text, isDone];
}

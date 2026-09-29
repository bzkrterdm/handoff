import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/localization/localizor.dart';
import '../../core/logging/logger.dart';
import '../../core/popup/popup_manager.dart';
import '../../core/routing/route_manager.dart';

/// Base class for tasks in presentation layer.
///
/// Every task should extend this class.
///
/// The motivation of this component is to have reusable presentation
/// pieces to be able to execute in different UI regions.
///
/// If any of [TInput] or [TOutput] is not needed,
/// void can be passed as a generic type to be ignored.
///
/// Example usage:
///
/// ```dart
/// class Foo extends Task<void, bool> {
///   Foo(
///     super.logger,
///     super.localizor,
///     super.routeManager,
///     super.popupManager,
///   );
///
///   @override
///   Future<bool> call({void params}) async {
///     return true;
///   }
/// }
///
/// // Instantiate task.
/// final foo = Foo(
///   logger,
///   localizor,
///   routeManager,
///   popupManager,
/// );
///
/// // Execute task.
/// await foo.execute(context);
/// ```
abstract class Task<TInput, TOutput> {
  Task(this.logger, this.localizor, this.routeManager, this.popupManager);

  final Logger logger;
  final Localizor localizor;
  final RouteManager routeManager;
  final PopupManager popupManager;

  /// Executes task with the given [params] and
  /// returns a Future of a [TOutput] instance.
  Future<TOutput?> execute(BuildContext context, {TInput? params});

  /// Useful to be overriden to stop a long running execution.
  @mustCallSuper
  Future<void> stop() => Future.value();
}

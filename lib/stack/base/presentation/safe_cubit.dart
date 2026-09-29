import 'package:flutter_bloc/flutter_bloc.dart';

/// Base class for cubits to ensure emits are safe when a cubit is closed
/// but tries to emit a state usually after an asynchronous call is completed.
abstract class SafeCubit<State> extends Cubit<State> {
  SafeCubit(super.initialState);

  @override
  void emit(State state) {
    if (!isClosed) super.emit(state);
  }
}

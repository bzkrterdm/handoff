import 'dart:ffi';
import 'dart:io';

/// Windows console modes the app needs, set through kernel32 directly so no
/// package is pulled in: VT input (arrow keys arrive as the same escape
/// sequences as on macOS and Linux) and VT output (colours, cursor moves).
///
/// A no-op everywhere else, and when the process has no console.
abstract class WindowsConsole {
  static const int _stdInputHandle = -10;
  static const int _stdOutputHandle = -11;
  static const int _enableVirtualTerminalInput = 0x0200;
  static const int _enableVirtualTerminalProcessing = 0x0004;

  static int? _savedInput;
  static int? _savedOutput;

  /// Turns VT input and output on, remembering the previous modes.
  static void enable() {
    if (!Platform.isWindows) return;
    try {
      final api = _Kernel32();
      _savedInput = api.addMode(_stdInputHandle, _enableVirtualTerminalInput);
      _savedOutput = api.addMode(
        _stdOutputHandle,
        _enableVirtualTerminalProcessing,
      );
    } on Object {
      // Not a console (redirected) or an old Windows: keys still work as
      // letters, which every action has.
    }
  }

  /// Puts the modes back as [enable] found them.
  static void restore() {
    if (!Platform.isWindows) return;
    try {
      final api = _Kernel32();
      final input = _savedInput;
      final output = _savedOutput;
      if (input != null) api.setMode(_stdInputHandle, input);
      if (output != null) api.setMode(_stdOutputHandle, output);
    } on Object {
      // Nothing to restore.
    }
  }
}

typedef _GetStdHandleC = IntPtr Function(Int32 handle);
typedef _GetStdHandle = int Function(int handle);
typedef _GetConsoleModeC = Int32 Function(IntPtr handle, Pointer<Uint32> mode);
typedef _GetConsoleMode = int Function(int handle, Pointer<Uint32> mode);
typedef _SetConsoleModeC = Int32 Function(IntPtr handle, Uint32 mode);
typedef _SetConsoleMode = int Function(int handle, int mode);
typedef _HeapAllocC =
    Pointer<Uint32> Function(IntPtr heap, Uint32 flags, IntPtr size);
typedef _HeapAlloc = Pointer<Uint32> Function(int heap, int flags, int size);
typedef _HeapFreeC =
    Int32 Function(IntPtr heap, Uint32 flags, Pointer<Uint32> memory);
typedef _HeapFree = int Function(int heap, int flags, Pointer<Uint32> memory);
typedef _GetProcessHeapC = IntPtr Function();
typedef _GetProcessHeap = int Function();

class _Kernel32 {
  _Kernel32() : _library = DynamicLibrary.open('kernel32.dll');

  final DynamicLibrary _library;

  late final _GetStdHandle _getStdHandle = _library
      .lookupFunction<_GetStdHandleC, _GetStdHandle>('GetStdHandle');
  late final _GetConsoleMode _getConsoleMode = _library
      .lookupFunction<_GetConsoleModeC, _GetConsoleMode>('GetConsoleMode');
  late final _SetConsoleMode _setConsoleMode = _library
      .lookupFunction<_SetConsoleModeC, _SetConsoleMode>('SetConsoleMode');
  late final _HeapAlloc _heapAlloc = _library
      .lookupFunction<_HeapAllocC, _HeapAlloc>('HeapAlloc');
  late final _HeapFree _heapFree = _library
      .lookupFunction<_HeapFreeC, _HeapFree>('HeapFree');
  late final _GetProcessHeap _getProcessHeap = _library
      .lookupFunction<_GetProcessHeapC, _GetProcessHeap>('GetProcessHeap');

  /// ORs [flag] into the mode of [stdHandle]; returns the old mode.
  int? addMode(int stdHandle, int flag) {
    final handle = _getStdHandle(stdHandle);
    final heap = _getProcessHeap();
    final mode = _heapAlloc(heap, 0, 4);
    try {
      if (_getConsoleMode(handle, mode) == 0) return null;
      final old = mode.value;
      _setConsoleMode(handle, old | flag);

      return old;
    } finally {
      _heapFree(heap, 0, mode);
    }
  }

  void setMode(int stdHandle, int mode) {
    _setConsoleMode(_getStdHandle(stdHandle), mode);
  }
}

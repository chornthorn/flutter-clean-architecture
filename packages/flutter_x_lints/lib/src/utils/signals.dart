import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'packages.dart';

/// The packages `signals` reaches through: `signals_core` declares
/// `AsyncSignal` and `Computed`, and `preact_signals` declares `Signal` itself.
const _signalPackages = {'preact_signals', 'signals_core', 'signals'};

/// Whether [type] is a signal its holder can write to.
///
/// `ReadonlySignal` and `Computed` are not: `Signal` is the writable one, and
/// `AsyncSignal<T>` extends `Signal<AsyncState<T>>`.
bool isWritableSignal(DartType? type) {
  if (type is! InterfaceType) return false;

  return _isSignalClass(type.element) ||
      type.allSupertypes.any((supertype) => _isSignalClass(supertype.element));
}

bool _isSignalClass(InterfaceElement element) =>
    element.name == 'Signal' && _signalPackages.contains(packageOf(element));

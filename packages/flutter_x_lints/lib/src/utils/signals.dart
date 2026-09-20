import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'packages.dart';

/// The packages `signals` reaches through: `signals_core` declares
/// `AsyncSignal` and `Computed`, and `preact_signals` declares the signal bases
/// themselves.
const _signalPackages = {'preact_signals', 'signals_core', 'signals'};

/// Whether [type] is a signal its holder can write to.
///
/// `ReadonlySignal` and `Computed` are not: `Signal` is the writable one, and
/// `AsyncSignal<T>` extends `Signal<AsyncState<T>>`.
bool isWritableSignal(DartType? type) => _isOrExtends(type, 'Signal');

bool _isOrExtends(DartType? type, String className) {
  if (type is! InterfaceType) return false;

  return _isSignalClass(type.element, className) ||
      type.allSupertypes.any(
        (supertype) => _isSignalClass(supertype.element, className),
      );
}

bool _isSignalClass(InterfaceElement element, String className) =>
    element.name == className && _signalPackages.contains(packageOf(element));

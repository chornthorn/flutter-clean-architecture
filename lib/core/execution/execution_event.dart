import '../error/app_exception.dart';

/// What an execution context captured, in the order it happened.
///
/// The timeline is the capture: nothing in it decides anything, it records. What
/// reads it — a trace, a metric, a replay — is a provider.
sealed class ExecutionEvent {
  const ExecutionEvent(this.at);

  /// When it happened.
  final DateTime at;
}

/// An action began: `ctx-7 loadPosts`.
final class ExecutionStarted extends ExecutionEvent {
  const ExecutionStarted(super.at, this.operation, this.args);

  /// The action's name — the view model method, e.g. `loadPosts`.
  final String operation;

  /// What the action was given, when the caller took the trouble to say.
  final List<Object?> args;
}

/// Someone recorded something worth keeping.
final class ExecutionNoted extends ExecutionEvent {
  const ExecutionNoted(super.at, this.label, [this.value]);

  final String label;
  final Object? value;
}

/// A provider this action asked for, e.g. `http-client/api`.
final class ProviderUsed extends ExecutionEvent {
  const ProviderUsed(super.at, this.spi, this.id);

  /// The SPI the provider serves, e.g. `http-client`.
  final String spi;

  /// The id the caller asked for, or `default`.
  final String id;
}

/// The action's work returned.
final class ExecutionSucceeded extends ExecutionEvent {
  const ExecutionSucceeded(super.at, this.value);

  final Object? value;
}

/// The action's work threw an [AppException].
final class ExecutionFailed extends ExecutionEvent {
  const ExecutionFailed(super.at, this.error);

  final AppException error;
}

/// The screen closed: what the action cost in total, the providers included.
final class ExecutionClosed extends ExecutionEvent {
  const ExecutionClosed(super.at, this.elapsed);

  final Duration elapsed;
}

import 'package:dio/dio.dart';

import '../async/cancellation.dart';
import 'safe_call.dart';

/// Base repository for network-driven data sources.
///
/// Bridges cancellation tokens and guarantees error unboxing via [.guard()]
/// without silencing domain failures or assuming 404 semantics.
abstract class Repository {
  const Repository();

  /// Converts a pure Dart [Cancellation] token to a Dio [CancelToken].
  CancelToken? cancelToken(Cancellation? cancellation) {
    if (cancellation == null) return null;
    final token = CancelToken();
    cancellation.whenComplete(token.cancel).ignore();
    return token;
  }

  /// Executes a network [action], bridging [cancellation] into a Dio [CancelToken],
  /// and automatically applying [.guard()] to unbox strongly-typed [AppException]s.
  ///
  /// Network and HTTP failures (including 404 [NotFoundException]) are never
  /// silently swallowed here — the calling repository handles domain-specific
  /// interpretation if needed.
  Future<T> execute<T>(
    Future<T> Function(CancelToken? cancelToken) action, {
    Cancellation? cancellation,
  }) {
    return action(cancelToken(cancellation)).guard();
  }
}

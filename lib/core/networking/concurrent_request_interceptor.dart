import 'package:dio/dio.dart';

/// Drops a duplicate call: a request to the same method and URL that starts
/// while an identical one is still in flight within [window] cancels the older.
///
/// The superseded request fails with [DioExceptionType.cancel], which
/// `ErrorInterceptor` normalizes into a `CancelledException` — the same signal a
/// view model already drops when a screen walks away from a read, so no call
/// site changes.
///
/// This is an app-wide policy on the one client every feature shares, so it is
/// deliberately narrow: reads only, and only within the window. Two unrelated
/// screens asking for the same URL will supersede each other; that is the cost
/// of holding the policy here rather than in the view model that knows what a
/// duplicate means for its own screen.
///
/// The body is not part of the key, so two writes to the same URL carrying
/// different payloads count as duplicates — a further reason to leave this on
/// reads.
class ConcurrentRequestInterceptor extends Interceptor {
  ConcurrentRequestInterceptor({
    this.window = defaultWindow,
    this.methods = readMethods,
  });

  /// The window used when a caller does not pick another.
  static const Duration defaultWindow = Duration(milliseconds: 600);

  /// The methods this applies to unless widened: reads, which are safe to drop.
  ///
  /// A cancelled write is not a retry. The server may have committed it before
  /// the cancel arrived, and the caller sees the same cancellation either way,
  /// so it cannot tell a dropped write from one that landed. Widen [methods]
  /// only for an endpoint you know is safe to abandon.
  static const Set<String> readMethods = {'GET', 'HEAD'};

  /// How long a request stays supersedable, measured from when it started.
  ///
  /// Only requests still in flight are in the map at all, so this bounds how old
  /// an in-flight duplicate may be and still be cancelled: one that outlives the
  /// window is left to finish, and the newcomer runs alongside it.
  final Duration window;

  /// The methods this applies to. See [readMethods].
  final Set<String> methods;

  /// Keyed by method and full URI, so query parameters keep pages and filters
  /// apart — `?page=1` and `?page=2` are different requests, not duplicates.
  final Map<String, _InFlightRequest> _inFlight = {};

  /// Carried on the request, so a terminal callback finds its own entry.
  static const String _entryKey = '_concurrent_request_entry';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!methods.contains(options.method.toUpperCase())) {
      handler.next(options);
      return;
    }

    final key = '${options.method.toUpperCase()} ${options.uri}';
    final superseded = _inFlight[key];

    if (superseded != null && superseded.elapsed < window) {
      // Cancelled with no reason: `Repository` cancels this same token later
      // with none, and Dio warns when a second cancel carries a different one.
      superseded.token.cancel();
    }

    // Every request already carries its own token — `Repository.cancelToken`
    // mints a fresh one per call — so cancelling it drops only this request.
    final entry = _InFlightRequest(key, options.cancelToken ??= CancelToken());
    _inFlight[key] = entry;
    options.extra[_entryKey] = entry;

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _forget(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _forget(err.requestOptions);
    handler.next(err);
  }

  void _forget(RequestOptions options) {
    final entry = options.extra[_entryKey];
    if (entry is! _InFlightRequest) return;

    // Identity, not liveness: a request that outlived the window has already
    // been replaced in the map, and removing by key alone would evict the newer
    // request that replaced it — leaving it unsupersedable.
    if (identical(_inFlight[entry.key], entry)) {
      _inFlight.remove(entry.key);
    }
  }
}

class _InFlightRequest {
  _InFlightRequest(this.key, this.token) : _stopwatch = Stopwatch()..start();

  final String key;
  final CancelToken token;

  // Monotonic, unlike `DateTime.now()`, which a clock change can move backwards.
  final Stopwatch _stopwatch;

  Duration get elapsed => _stopwatch.elapsed;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';
import 'package:flutter_x/core/networking/repository.dart';

// `Repository` is abstract but holds no state, so a bare subclass is the unit
// under test: the bridge from the domain's token to the transport's.
class _TestRepository extends Repository {
  const _TestRepository();
}

void main() {
  group('Repository.cancelToken', () {
    test('should hand back no token when the caller has none', () {
      expect(const _TestRepository().cancelToken(null), isNull);
    });

    test('should give each call its own transport token', () {
      final source = CancellationSource();
      final repository = const _TestRepository();

      final first = repository.cancelToken(source.token);
      final second = repository.cancelToken(source.token);

      // One domain token, a separate Dio token per request: each request is
      // cancelled on its own terms even though they share the one signal.
      expect(identical(first, second), isFalse);
      expect(first!.isCancelled, isFalse);
      expect(second!.isCancelled, isFalse);
    });

    test('should cancel every request in flight from one cancel', () async {
      final source = CancellationSource();
      final repository = const _TestRepository();

      // Three requests in flight together on one screen's token.
      final tokens = [
        repository.cancelToken(source.token)!,
        repository.cancelToken(source.token)!,
        repository.cancelToken(source.token)!,
      ];
      expect(
        tokens.every((token) => !token.isCancelled),
        isTrue,
        reason: 'nothing is cancelled before the source is',
      );

      source.cancel();
      // The listeners run as microtasks once the shared future completes.
      await Future<void>.delayed(Duration.zero);

      expect(tokens.map((token) => token.isCancelled), [true, true, true]);
    });

    test('should cancel a request started after the screen went away', () async {
      final source = CancellationSource();
      source.cancel();

      // A job that starts late must not outlive the scope that owns it.
      final token = const _TestRepository().cancelToken(source.token)!;
      await Future<void>.delayed(Duration.zero);

      expect(token.isCancelled, isTrue);
    });
  });
}

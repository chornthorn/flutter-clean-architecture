import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';

void main() {
  group('CancellationSource', () {
    test('should hand every caller the same token', () {
      final source = CancellationSource();

      // One source is one scope. Every job on the screen shares the one future,
      // which is what lets a single cancel reach all of them.
      expect(identical(source.token, source.token), isTrue);
    });

    test('should drop every job in flight when it is cancelled once', () async {
      final source = CancellationSource();
      final dropped = <String>[];

      // A read and a write in flight together, both handed the screen's token.
      Future<void> job(String name) async {
        await source.token;
        dropped.add(name);
      }

      final jobs = [job('load posts'), job('load post'), job('create post')];
      expect(dropped, isEmpty, reason: 'nothing is dropped before the cancel');

      source.cancel();
      await Future.wait(jobs);

      // One cancel, three dropped jobs: the future broadcasts to every listener.
      expect(
        dropped,
        unorderedEquals(['load posts', 'load post', 'create post']),
      );
    });

    test('should resolve a job that starts after it was cancelled', () async {
      final source = CancellationSource();
      source.cancel();

      // The token is already complete, so a late job returns at once instead of
      // hanging on a future nobody will ever complete.
      await expectLater(source.token, completes);
    });

    test('should be idempotent', () async {
      final source = CancellationSource();

      source.cancel();
      source.cancel();

      expect(source.isCancelled, isTrue);
      await expectLater(source.token, completes);
    });

    test('should report cancelled only once cancel has run', () {
      final source = CancellationSource();

      expect(source.isCancelled, isFalse);
      source.cancel();
      expect(source.isCancelled, isTrue);
    });
  });
}

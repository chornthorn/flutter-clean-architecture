import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';
import 'package:flutter_x/core/presentation/view_model.dart';

// A view model the way a real one is written: it implements the hook, and
// reaches the scope through the base.
class _TestViewModel extends ViewModel {
  int released = 0;
  bool landedAfterDispose = false;

  /// What every view model method does: await under the scope, then check
  /// before publishing.
  Future<void> publishAfter(Future<void> work) async {
    await work;
    if (!isAlive) return;
    landedAfterDispose = true;
  }

  // The base's members are `@protected`, so the test reaches them the way a
  // subclass does.
  bool get alive => isAlive;
  Cancellation get token => cancellation;

  @override
  void onDispose() => released++;
}

void main() {
  group('ViewModel', () {
    test('should be alive until it is disposed', () {
      final viewModel = _TestViewModel();

      expect(viewModel.alive, isTrue);
      viewModel.dispose();
      expect(viewModel.alive, isFalse);
    });

    test('should end the scope before it releases, so nothing lands after', () async {
      final viewModel = _TestViewModel();
      final inFlight = Completer<void>();

      // A response still on its way when the page goes away.
      final job = viewModel.publishAfter(inFlight.future);
      expect(viewModel.alive, isTrue, reason: 'nothing has ended it yet');

      viewModel.dispose();
      inFlight.complete();
      await job;

      // The continuation resumed, found the scope already ended, and published
      // nothing — which is the whole point of cancelling before releasing.
      expect(viewModel.landedAfterDispose, isFalse);
    });

    test('should release once, however many times it is disposed', () {
      final viewModel = _TestViewModel();

      viewModel.dispose();
      viewModel.dispose();

      expect(viewModel.released, 1);
    });

    test('should not leave a job started after it was disposed waiting', () async {
      final viewModel = _TestViewModel();
      viewModel.dispose();

      // The token is already complete, so a late job returns at once instead of
      // hanging on a future nobody will ever complete.
      await expectLater(viewModel.token, completes);
    });
  });
}

import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/entities/product.dart';
import '../../domain/usecases/get_cart_products_query.dart';

// State for the cart screen. Same scope and lifecycle rules as the other view
// models: factory-scoped, created once per mount by a provider.
//
// One `AsyncSignal` per use case — the cart read is the only one — each
// published as a `ReadonlySignal`. See `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopCartViewModel {
  ShopCartViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  bool _isDisposed = false;

  // `GetCartProductsQuery`. Loading until the read settles, and the cart's rows
  // after that.
  final _products = asyncSignal<List<Product>>(AsyncState.loading());

  // What the screen is showing: the cart, a load in flight, or a load that
  // failed.
  ReadonlySignal<AsyncState<List<Product>>> get products => _products;

  // Derived, never stored: a second source of truth would drift from the items.
  // A computed rather than a getter, so the total card rebuilds off the rows
  // without the page reading both in step.
  late final total = computed(
    () =>
        _products.value.value?.fold<double>(
          0,
          (sum, product) => sum + product.price,
        ) ??
        0,
  );

  Future<void> load() async {
    _products.setLoading();

    try {
      final products = await _dispatcher.query(const GetCartProductsQuery());
      if (_isDisposed) return;
      _products.setValue(products);
    } catch (error, stackTrace) {
      // The page can be gone by the time the read answers. There is nobody left
      // to report the failure to, and a disposed signal *throws* on a write.
      if (_isDisposed) return;
      _products.setError(error, stackTrace);
    }
  }

  // Walking away: the provider above the page calls this when the route
  // unmounts.
  //
  // The flag comes first, so a read still in flight finds the view model already
  // closed and writes nothing back. A signal that has been disposed *throws* on
  // a write, which is why every write above checks the flag first.
  void dispose() {
    _isDisposed = true;
    _products.dispose();
    total.dispose();
  }
}

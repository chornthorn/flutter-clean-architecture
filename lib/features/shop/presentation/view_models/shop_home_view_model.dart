import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_products_query.dart';

// State for the shop list screen. Factory-scoped: one per page, disposed by the
// provider that created it.
//
// One `AsyncSignal` per use case — the catalog read is the only one — each
// published as a `ReadonlySignal`. See `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopHomeViewModel implements ViewModel {
  ShopHomeViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  bool _isDisposed = false;

  // `GetProductsQuery`. Loading until the read settles, and the catalog after
  // that.
  final _products = asyncSignal<List<Product>>(AsyncState.loading());

  // What the screen is showing: the catalog, a load in flight, or a load that
  // failed.
  ReadonlySignal<AsyncState<List<Product>>> get products => _products;

  Future<void> load() async {
    _products.setLoading();

    try {
      final products = await _dispatcher.query(const GetProductsQuery());
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
  @override
  void dispose() {
    _isDisposed = true;
    _products.dispose();
  }
}

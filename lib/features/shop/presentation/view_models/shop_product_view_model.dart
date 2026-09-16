import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/entities/product.dart';
import '../../domain/usecases/add_product_to_cart_command.dart';
import '../../domain/usecases/get_cart_query.dart';
import '../../domain/usecases/get_product_query.dart';

// State for the single-product screen. Same scope and lifecycle rules as
// `ShopHomeViewModel`.
//
// The id is a `load` argument rather than a field: it comes from the route, and
// the page that owns it passes it in.
//
// One `AsyncSignal` per use case, each published as a `ReadonlySignal`. See
// `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopProductViewModel {
  ShopProductViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  bool _isDisposed = false;

  // `GetProductQuery`. Loading until the read settles, and the product after
  // that — or `AsyncData(null)` for an id that has none, which is a value and
  // not a failure, and is what tells "not found" apart from "could not load".
  final _product = asyncSignal<Product?>(AsyncState.loading());

  // `AddProductToCartCommand`. Carries no payload: reaching `AsyncData` is the
  // add landing and `AsyncError` is it failing. Settled rather than loading,
  // because no write has run yet.
  final _add = asyncSignal<void>(AsyncState.data(null));

  // `GetCartQuery`'s answer. A plain signal rather than an `AsyncSignal`: it is
  // a value that two use cases write — the load reads it alongside the product,
  // and the add re-reads it — and not an async lifecycle of its own.
  final _cartCount = signal(0);

  // What the screen is showing: a product, a missing product, a load in flight,
  // or a load that failed.
  ReadonlySignal<AsyncState<Product?>> get product => _product;

  // The last add's attempt, for as long as it is worth reporting.
  ReadonlySignal<AsyncState<void>> get add => _add;

  // The cart's size, read back from the query after every add.
  ReadonlySignal<int> get cartCount => _cartCount;

  // The page's one load, over the two queries it needs: what the product is, and
  // how many of them the cart holds. Either one failing fails the load, because
  // the page is not useful without both.
  Future<void> load(String id) async {
    _product.setLoading();

    try {
      final product = await _dispatcher.query(GetProductQuery(id));
      final cart = await _dispatcher.query(const GetCartQuery());
      if (_isDisposed) return;
      _product.setValue(product);
      _cartCount.value = cart.itemCount;
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      _product.setError(error, stackTrace);
    }
  }

  // Sends the command, then re-reads the cart: the count is the query's answer,
  // never a guess made from the command's side.
  Future<void> addToCart() async {
    final product = _product.value.value;

    // Nothing to add until the load has resolved.
    if (product == null) return;

    _add.setLoading();

    try {
      await _dispatcher.command(AddProductToCartCommand(product.id));
      final cart = await _dispatcher.query(const GetCartQuery());
      if (_isDisposed) return;
      _cartCount.value = cart.itemCount;
      _add.setValue(null);
    } catch (error, stackTrace) {
      // The failure is the add's, so it stays off the product's own state: what
      // is on screen is untouched by a write that did not land.
      if (_isDisposed) return;
      _add.setError(error, stackTrace);
    }
  }

  // Walking away: the provider above the page calls this when the route unmounts.
  //
  // A signal that has been disposed *throws* on a write, which is why the writes
  // above check the flag first.
  void dispose() {
    _isDisposed = true;
    _product.dispose();
    _add.dispose();
    _cartCount.dispose();
  }
}

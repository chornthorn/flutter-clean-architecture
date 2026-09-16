import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

import '../../domain/entities/product.dart';
import '../../domain/usecases/add_product_to_cart_command.dart';
import '../../domain/usecases/get_cart_query.dart';
import '../../domain/usecases/get_product_query.dart';

// State for the single-product screen. Same scope and lifecycle rules as
// `ShopHomeViewModel`.
//
// The id is a `load` argument rather than a field: it comes from the route, and
// the page that owns it passes it in.
@Injectable(scope: Scope.factory)
class ShopProductViewModel extends ChangeNotifier {
  ShopProductViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  Product? _product;
  int _cartCount = 0;
  Object? _error;
  bool _isLoading = false;
  bool _isDisposed = false;

  // `null` while loading, and `null` once a missing id has resolved —
  // [isLoading] tells the two apart.
  Product? get product => _product;

  // The cart's size, read back from the query after every add.
  int get cartCount => _cartCount;

  // The last failure, from the load or from an add; `null` after a success.
  Object? get error => _error;

  bool get isLoading => _isLoading;

  Future<void> load(String id) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      _product = await _dispatcher.query(GetProductQuery(id));
      _cartCount = (await _dispatcher.query(const GetCartQuery())).itemCount;
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // Sends the command, then re-reads the cart: the count is the query's answer,
  // never a guess made from the command's side.
  Future<void> addToCart() async {
    final product = _product;

    // Nothing to add until the load has resolved.
    if (product == null) return;

    _error = null;
    _notify();

    try {
      await _dispatcher.command(AddProductToCartCommand(product.id));
      _cartCount = (await _dispatcher.query(const GetCartQuery())).itemCount;
    } catch (error) {
      _error = error;
    }

    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }
}

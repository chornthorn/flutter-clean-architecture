import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

import '../../domain/entities/product.dart';
import '../../domain/usecases/get_cart_products_query.dart';

// State for the cart screen. Same scope and lifecycle rules as the other view
// models: factory-scoped, created once per mount by a provider.
@Injectable(scope: Scope.factory)
class ShopCartViewModel extends ChangeNotifier {
  ShopCartViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  List<Product>? _products;
  Object? _error;
  bool _isLoading = false;
  bool _isDisposed = false;

  // `null` until the first load resolves, so the page can tell "not read yet"
  // from "read, and empty".
  List<Product>? get products => _products;

  Object? get error => _error;

  bool get isLoading => _isLoading;

  // Derived, never stored: a second source of truth would drift from the items.
  double get total =>
      _products?.fold<double>(0, (sum, product) => sum + product.price) ?? 0;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      _products = await _dispatcher.query(const GetCartProductsQuery());
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      _notify();
    }
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

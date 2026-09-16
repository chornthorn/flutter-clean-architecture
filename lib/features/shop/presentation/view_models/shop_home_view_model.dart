import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

import '../../domain/entities/product.dart';
import '../../domain/usecases/get_products_query.dart';

// State for the shop list screen. Factory-scoped: one per page, disposed by the
// `ChangeNotifierProvider` that created it.
@Injectable(scope: Scope.factory)
class ShopHomeViewModel extends ChangeNotifier {
  ShopHomeViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  List<Product>? _products;
  Object? _error;
  bool _isLoading = false;
  bool _isDisposed = false;

  // `null` before the first load completes.
  List<Product>? get products => _products;

  Object? get error => _error;

  bool get isLoading => _isLoading;

  // Failures land in [error] rather than escaping to the framework.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      _products = await _dispatcher.query(const GetProductsQuery());
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

  // A load can outlive the page; notifying a disposed ChangeNotifier throws.
  void _notify() {
    if (!_isDisposed) notifyListeners();
  }
}

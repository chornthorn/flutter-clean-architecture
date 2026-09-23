import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/add_product_to_cart_use_case.dart';
import '../../domain/usecases/get_cart_use_case.dart';
import '../../domain/usecases/get_product_use_case.dart';

// State for the single-product screen: one signal per use case, per
// `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopProductViewModel extends ViewModel {
  ShopProductViewModel({
    required this._getProduct,
    required this._getCart,
    required this._addProductToCart,
  });

  // The screen's reads and its one write, each one the domain's own entry point
  // rather than a message the view model has to name.
  final GetProductUseCase _getProduct;
  final GetCartUseCase _getCart;
  final AddProductToCartUseCase _addProductToCart;

  bool _isDisposed = false;

  final _product = asyncSignal<Product?>(AsyncState.loading());

  // Settled, not loading: no write has run yet.
  final _add = asyncSignal<void>(AsyncState.data(null));

  // A value two use cases write, not an async lifecycle of its own.
  final _cartCount = signal(0);

  ReadonlySignal<AsyncState<Product?>> get product => _product;
  ReadonlySignal<AsyncState<void>> get add => _add;
  ReadonlySignal<int> get cartCount => _cartCount;

  // The page's one load, over the two reads it needs.
  Future<void> load(String id) async {
    _product.setLoading();

    try {
      final product = await _getProduct(id);
      final cart = await _getCart();
      if (_isDisposed) return;
      _product.setValue(product);
      _cartCount.value = cart.itemCount;
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      _product.setError(error, stackTrace);
    }
  }

  Future<void> addToCart() async {
    final id = _productOnScreenId;
    if (id == null) return;

    _add.setLoading();

    try {
      await _addProductToCart(id);
      final cart = await _getCart();
      if (_isDisposed) return;
      _cartCount.value = cart.itemCount;
      _add.setValue(null);
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      _add.setError(error, stackTrace);
    }
  }

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    _isDisposed = true;
    _product.dispose();
    _add.dispose();
    _cartCount.dispose();
  }

  // The id the add goes to: null until the read lands on a product.
  String? get _productOnScreenId => _product.value.value?.id;
}

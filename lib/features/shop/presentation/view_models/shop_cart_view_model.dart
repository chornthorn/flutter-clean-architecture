import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_cart_products_use_case.dart';

// State for the cart screen: one signal per use case, per `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopCartViewModel extends ViewModel {
  ShopCartViewModel({required this._getCartProducts});

  final GetCartProductsUseCase _getCartProducts;

  final _products = asyncSignal<List<Product>>(AsyncState.loading());

  ReadonlySignal<AsyncState<List<Product>>> get products => _products;

  // Derived, never stored.
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
      final products = await _getCartProducts();
      if (!isAlive) return;
      _products.setValue(products);
    } catch (error, stackTrace) {
      if (!isAlive) return;
      _products.setError(error, stackTrace);
    }
  }

  // The base cancels the scope before this runs, so a read still on its way
  // finds `isAlive` false and the guards above drop it.
  @override
  void onDispose() {
    _products.dispose();
    total.dispose();
  }
}

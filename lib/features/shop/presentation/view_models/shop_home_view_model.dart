import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_products_use_case.dart';

// State for the shop list: one signal per use case, per `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopHomeViewModel extends ViewModel {
  ShopHomeViewModel({required this._getProducts});

  final GetProductsUseCase _getProducts;

  final _products = asyncSignal<List<Product>>(AsyncState.loading());

  ReadonlySignal<AsyncState<List<Product>>> get products => _products;

  Future<void> load() async {
    _products.setLoading();

    try {
      final products = await _getProducts();
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
  }
}

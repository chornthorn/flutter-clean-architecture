import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_products_query.dart';

// State for the shop list: one signal per use case, per `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopHomeViewModel extends ViewModel {
  ShopHomeViewModel({required super.dispatcher});

  bool _isDisposed = false;

  final _products = asyncSignal<List<Product>>(AsyncState.loading());

  ReadonlySignal<AsyncState<List<Product>>> get products => _products;

  Future<void> load() async {
    _products.setLoading();

    try {
      final products = await dispatcher.query(const GetProductsQuery());
      if (_isDisposed) return;
      _products.setValue(products);
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      _products.setError(error, stackTrace);
    }
  }

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    _isDisposed = true;
    _products.dispose();
  }
}

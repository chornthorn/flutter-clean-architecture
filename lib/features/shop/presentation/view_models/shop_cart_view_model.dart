import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_cart_products_query.dart';

// State for the cart screen: one signal per use case, per `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopCartViewModel extends ViewModel {
  ShopCartViewModel({required super.dispatcher, required super.context});

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
      final products = await context.run(
        () => dispatcher.query(const GetCartProductsQuery()),
      );
      if (isDisposed) return;
      _products.setValue(products);
    } catch (error, stackTrace) {
      if (isDisposed) return;
      _products.setError(error, stackTrace);
    }
  }

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    super.dispose();
    _products.dispose();
    total.dispose();
  }
}

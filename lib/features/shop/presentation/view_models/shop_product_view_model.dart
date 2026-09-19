import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/add_product_to_cart_command.dart';
import '../../domain/usecases/get_cart_query.dart';
import '../../domain/usecases/get_product_query.dart';

// State for the single-product screen: one signal per use case, per
// `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class ShopProductViewModel extends ViewModel {
  ShopProductViewModel({required super.dispatcher, required super.context});

  final _product = asyncSignal<Product?>(AsyncState.loading());

  // Settled, not loading: no write has run yet.
  final _add = asyncSignal<void>(AsyncState.data(null));

  // A value two use cases write, not an async lifecycle of its own.
  final _cartCount = signal(0);

  ReadonlySignal<AsyncState<Product?>> get product => _product;
  ReadonlySignal<AsyncState<void>> get add => _add;
  ReadonlySignal<int> get cartCount => _cartCount;

  // The page's one load, over the two queries it needs.
  Future<void> load(String id) async {
    _product.setLoading();

    try {
      await context.run(() async {
        final product = await dispatcher.query(GetProductQuery(id));
        final cart = await dispatcher.query(const GetCartQuery());
        if (isDisposed) return;
        _product.setValue(product);
        _cartCount.value = cart.itemCount;
      }, args: [id]);
    } catch (error, stackTrace) {
      if (isDisposed) return;
      _product.setError(error, stackTrace);
    }
  }

  Future<void> addToCart() async {
    final id = _productOnScreenId;
    if (id == null) return;

    _add.setLoading();

    try {
      await context.run(() async {
        await dispatcher.command(AddProductToCartCommand(id));
        final cart = await dispatcher.query(const GetCartQuery());
        if (isDisposed) return;
        _cartCount.value = cart.itemCount;
        _add.setValue(null);
      }, args: [id]);
    } catch (error, stackTrace) {
      if (isDisposed) return;
      _add.setError(error, stackTrace);
    }
  }

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    super.dispose();
    _product.dispose();
    _add.dispose();
    _cartCount.dispose();
  }

  // The id the add goes to: null until the read lands on a product.
  String? get _productOnScreenId => _product.value.value?.id;
}

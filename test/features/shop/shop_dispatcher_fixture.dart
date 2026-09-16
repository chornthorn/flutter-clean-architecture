import 'package:cqrs/cqrs.dart';
import 'package:flutter_application_1/features/shop/domain/repositories/product_repository.dart';
import 'package:flutter_application_1/features/shop/domain/usecases/get_product_query.dart';
import 'package:flutter_application_1/features/shop/domain/usecases/get_products_query.dart';
import 'package:flutter_application_1/features/shop/shop_handler.dart';

// A real dispatcher over the shop's generated handler module — the query path
// the container builds at runtime, with the repository passed in instead of
// resolved. Built from the generated module, so a handler the generator misses
// fails here rather than in the app.
CqrsDispatcher shopDispatcher(ProductRepository repository) =>
    CqrsDispatcher()
      ..registry.registerModule(
        ShopCqrsModule(
          getProductQueryHandler: () => GetProductQueryHandler(repository),
          getProductsQueryHandler: () => GetProductsQueryHandler(repository),
        ),
      );

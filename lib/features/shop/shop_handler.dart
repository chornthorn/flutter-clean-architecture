import 'package:cqrs_codegen/cqrs_codegen.dart';

export 'shop_handler.cqrs.dart';

// The shop feature's CQRS micro-package; `shop_module.dart` owns routing and DI.
// The shop feature's CQRS micro-package; `shop_module.dart` owns routing and DI.
// It carries one handler — the audit reaction to `ProductAddedToCartEvent` —
// because an event is the only message the feature still sends.
@CqrsMicroPackage(moduleName: 'Shop', generateInjectable: true)
void configureShopHandlers() {}

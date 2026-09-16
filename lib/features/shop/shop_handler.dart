import 'package:cqrs_codegen/cqrs_codegen.dart';

export 'shop_handler.cqrs.dart';

// The shop feature's CQRS micro-package; `shop_module.dart` owns routing and DI.
@CqrsMicroPackage(moduleName: 'Shop', generateInjectable: true)
void configureShopHandlers() {}

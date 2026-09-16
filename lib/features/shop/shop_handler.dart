import 'package:cqrs_codegen/cqrs_codegen.dart';

export 'shop_handler.cqrs.dart';

// The shop feature's CQRS micro-package: every handler under this folder is
// registered by this module and by nothing else. Distinct from
// `shop_module.dart`, which owns routing and the injectify registrations.
@CqrsMicroPackage(moduleName: 'Shop')
void configureShopHandlers() {}

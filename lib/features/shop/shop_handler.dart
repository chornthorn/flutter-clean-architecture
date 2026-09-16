import 'package:cqrs_codegen/cqrs_codegen.dart';

export 'shop_handler.cqrs.dart';

// The shop feature's CQRS micro-package: every handler under this folder is
// registered by this module and by nothing else. Distinct from
// `shop_module.dart`, which owns routing and the injectify registrations.
//
// `generateInjectable` is declared here as well as on the root `@CqrsInit`:
// the module emits its own `fromLocator`, rather than depending on the root
// propagating the flag.
@CqrsMicroPackage(moduleName: 'Shop', generateInjectable: true)
void configureShopHandlers() {}

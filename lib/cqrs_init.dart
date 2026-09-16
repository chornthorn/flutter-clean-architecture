import 'package:cqrs_codegen/cqrs_codegen.dart';

import 'features/shop/shop_handler.dart';

export 'cqrs_init.cqrs.dart';
export 'features/shop/shop_handler.dart';

// The app's CQRS entry point: a compositor over each feature's handler module.
// `generateInjectable` emits `AppCqrsModule.fromLocator`, which is how the
// container wires the dispatcher in one line.
@CqrsInit(
  moduleName: 'App',
  useMicroPackage: true,
  generateInjectable: true,
  modules: [ShopCqrsModule],
)
void configureCqrs() {}

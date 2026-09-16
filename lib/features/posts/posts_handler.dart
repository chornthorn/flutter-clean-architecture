import 'package:cqrs_codegen/cqrs_codegen.dart';

export 'posts_handler.cqrs.dart';

// The feature's CQRS micro-package — distinct from `posts_module.dart`, which
// owns routing and DI.
@CqrsMicroPackage(moduleName: 'Posts', generateInjectable: true)
void configurePostsHandlers() {}

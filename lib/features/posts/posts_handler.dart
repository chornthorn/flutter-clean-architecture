import 'package:cqrs_codegen/cqrs_codegen.dart';

export 'posts_handler.cqrs.dart';

// The posts feature's CQRS micro-package: every handler under this folder is
// registered by this module and by nothing else. Distinct from `posts_module.dart`,
// which owns routing and the injectify registrations.
@CqrsMicroPackage(moduleName: 'Posts', generateInjectable: true)
void configurePostsHandlers() {}

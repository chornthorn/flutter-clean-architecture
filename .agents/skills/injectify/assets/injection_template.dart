import 'package:get_it/get_it.dart';
import 'package:injectify/injectify.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
  useMicroPackage: true,
  // Compose external package modules in declaration order if in a monorepo:
  // externalMicroPackages: [
  //   ExternalMicroPackage(SharedInjectableModule),
  // ],
)
Future<void> configureDependencies({String? environment}) async =>
    getIt.init(environment: environment);

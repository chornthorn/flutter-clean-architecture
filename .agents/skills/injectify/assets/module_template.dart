import 'package:injectify/injectify.dart';

/// Defines an isolated micro-package for this folder.
///
/// Set [useMicroPackage: true] if this module contains nested sub-folder micro-packages
/// that should be auto-composed within this module's initializer.
@InjectableMicroPackage(
  moduleName: 'FeatureName',
  useMicroPackage: false,
)
void configureFeatureModule() {}

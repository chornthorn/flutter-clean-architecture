/// The names the generator derives from what a project declares.
///
/// A `@KaiselModule` class name carries three derived names and each has exactly
/// one spelling rule: a route type and a mount marker read `<Feature>Route` /
/// `<Feature>Mount`, and a manifest declares a mount field as the camelCase of
/// its marker (`ShopMount` → `shopMount`).
library;

/// `FeatureShop` → `feature_shop`.
String toSnakeCase(String value) {
  final buffer = StringBuffer();
  var previousWasUnderscore = false;

  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    if (char != char.toLowerCase()) {
      if (index > 0 && !previousWasUnderscore) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
      previousWasUnderscore = false;
    } else {
      buffer
        .write(char);
      previousWasUnderscore = char == '_';
    }
  }

  return buffer.toString();
}

/// `feature_shop` → `FeatureShop`.
String toPascalCase(String value) {
  final buffer = StringBuffer();
  var capitalizeNext = true;

  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    if (char == '_' || char == '-' || char == ' ') {
      capitalizeNext = true;
      continue;
    }
    if (capitalizeNext) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
    } else {
      buffer.write(char);
    }
  }

  return buffer.toString();
}

/// `ShopMount` → `shopMount`, the field a micro-package manifest declares.
String toCamelCase(String value) {
  if (value.isEmpty) {
    return '';
  }
  return value[0].toLowerCase() + value.substring(1);
}

/// `ShopRouterModule` → `Shop`, the stem of a module's default names.
String moduleBaseName(String className) {
  final withoutSuffix = className.endsWith('RouterModule')
      ? className.substring(0, className.length - 'RouterModule'.length)
      : className;
  return withoutSuffix.endsWith('Module')
      ? withoutSuffix.substring(0, withoutSuffix.length - 'Module'.length)
      : withoutSuffix;
}

/// The directory a feature's layers live under.
const _featuresDirectory = 'features';

/// The layers a feature is made of.
const _layers = {'domain', 'infrastructure', 'presentation'};

/// The feature layer [path] sits in, or `null` when it sits in none.
String? layerOf(String path) {
  final segments = path.replaceAll(r'\', '/').split('/');
  final index = segments.indexOf(_featuresDirectory);
  if (index < 0 || index + 2 >= segments.length) return null;

  final layer = segments[index + 2];
  return _layers.contains(layer) ? layer : null;
}

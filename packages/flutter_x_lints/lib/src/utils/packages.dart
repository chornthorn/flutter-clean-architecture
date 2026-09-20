import 'package:analyzer/dart/element/element.dart';

/// Whether [uri] addresses the package [name].
bool isPackageUri(String? uri, String name) =>
    uri != null && (uri == 'package:$name' || uri.startsWith('package:$name/'));

/// The package [element] is declared in, or `null` when it is not in one.
String? packageOf(Element element) {
  final uri = element.library?.uri;
  if (uri == null || uri.scheme != 'package' || uri.pathSegments.isEmpty) {
    return null;
  }

  return uri.pathSegments.first;
}

/// Whether [element] is declared in the package [name].
bool isInPackage(Element element, String name) => packageOf(element) == name;

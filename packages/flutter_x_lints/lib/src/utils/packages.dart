import 'package:analyzer/dart/element/element.dart';

/// Whether [uri] addresses the package [name].
bool isPackageUri(String? uri, String name) =>
    uri != null && (uri == 'package:$name' || uri.startsWith('package:$name/'));

/// Whether [element] is declared in the package [name].
///
/// Resolved rather than matched by name, so a project's own look-alike is not
/// mistaken for the real thing.
bool isInPackage(Element element, String name) {
  final uri = element.library?.uri;
  return uri != null &&
      uri.scheme == 'package' &&
      uri.pathSegments.first == name;
}

import 'package:analyzer/dart/element/element.dart';

/// Whether [uri] addresses the `cqrs` package.
bool isCqrsUri(String? uri) =>
    uri != null && (uri == 'package:cqrs' || uri.startsWith('package:cqrs/'));

/// Whether [element] is declared inside the `cqrs` package.
///
/// Resolved rather than matched by name, so a project's own `CqrsDispatcher`
/// look-alike is not mistaken for the real one.
bool isInCqrs(Element element) {
  final uri = element.library?.uri;
  return uri != null &&
      uri.scheme == 'package' &&
      uri.pathSegments.first == 'cqrs';
}

import 'package:analyzer/dart/element/element.dart';

import 'packages.dart';

/// Whether [uri] addresses the `cqrs` package.
bool isCqrsUri(String? uri) => isPackageUri(uri, 'cqrs');

/// Whether [element] is declared inside the `cqrs` package.
///
/// Resolved rather than matched by name, so a project's own `CqrsDispatcher`
/// look-alike is not mistaken for the real one.
bool isInCqrs(Element element) => isInPackage(element, 'cqrs');

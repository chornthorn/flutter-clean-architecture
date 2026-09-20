import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import 'packages.dart';

/// Whether [node] carries an `@Injectable` from the `injectify` package.
///
/// Resolved, so a different `Injectable` — another package's, or one the
/// project declares itself — does not count: that annotation registers nothing.
bool isAnnotatedInjectable(ClassDeclaration node) {
  for (final annotation in node.metadata) {
    final element = annotation.name.element;
    if (element is InterfaceElement &&
        element.name == 'Injectable' &&
        isInPackage(element, 'injectify')) {
      return true;
    }
  }

  return false;
}

import 'package:analyzer/dart/ast/ast.dart';

/// Whether [declaration] extends, implements or mixes in any of [baseNames],
/// directly or through one of its own supertypes.
///
/// Resolved, so the whole chain counts rather than the written clause:
/// `implements ViewModel` and `extends PostViewModel` (which itself extends
/// `ViewModel`) both match `ViewModel`.
bool hasAnySupertype(ClassDeclaration declaration, Set<String> baseNames) {
  final element = declaration.declaredFragment?.element;
  if (element == null) return false;

  return element.allSupertypes.any(
    (type) => baseNames.contains(type.element.name),
  );
}

/// The class [node] sits inside, if any.
ClassDeclaration? enclosingClass(AstNode node) {
  for (
    AstNode? current = node.parent;
    current != null;
    current = current.parent
  ) {
    if (current is ClassDeclaration) return current;
  }
  return null;
}

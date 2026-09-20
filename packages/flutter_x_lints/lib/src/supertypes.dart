import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

/// Whether [declaration]'s superclass chain includes any of [baseNames].
bool extendsAnyBase(ClassDeclaration declaration, Set<String> baseNames) {
  final superclass = declaration.extendsClause?.superclass.type;
  if (superclass is! InterfaceType) return false;

  return baseNames.contains(superclass.element.name) ||
      superclass.allSupertypes.any(
        (type) => baseNames.contains(type.element.name),
      );
}

/// The class [node] sits inside, if any.
ClassDeclaration? enclosingClass(AstNode node) {
  for (AstNode? current = node.parent; current != null; current = current.parent) {
    if (current is ClassDeclaration) return current;
  }
  return null;
}

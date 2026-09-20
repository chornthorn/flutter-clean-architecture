/// Reading a Dart AST without resolving it (used by the annotation and manifest
/// parsers).
///
/// A call parses as a `MethodInvocation` unless it is written with `new` or
/// `const` — Dart 3.10+ parses a bare `Foo()` either way — so every reader here
/// takes both forms.
library;

import 'package:analyzer/dart/ast/ast.dart';

/// The annotation [name] in [metadata], or `null` when it is not there.
Annotation? annotationNamed(List<Annotation> metadata, String name) {
  for (final annotation in metadata) {
    if (annotation.name.name == name) {
      return annotation;
    }
  }
  return null;
}

/// The class's name.
///
/// `namePart` wraps either the name with its type parameters or a primary
/// constructor, so the name is read from the token that follows `class` — the one
/// position every declaration form agrees on.
String? classNameOf(ClassDeclaration node) => node.classKeyword.next?.lexeme;

/// The type name behind an expression that names a type: a plain identifier
/// (`ShopRouteCodec`), an invocation of one (`ShopRouteCodec()`, `const
/// ShopRouteCodec()`), or a generic type literal.
String? typeNameOf(AstNode? expression) =>
    calledName(expression) ??
    switch (expression) {
      TypeLiteral(:final type) => type.name.lexeme,
      SimpleIdentifier(:final name) => name,
      PrefixedIdentifier(:final identifier) => identifier.name,
      _ => null,
    };

/// The name of the class or function an expression calls, without its type
/// arguments or prefix.
String? calledName(AstNode? expression) => switch (expression) {
      MethodInvocation(:final methodName) => methodName.name,
      InstanceCreationExpression(:final constructorName) =>
        constructorName.type.name.lexeme,
      _ => null,
    };

/// The arguments of a call, in either of the forms [calledName] reads.
ArgumentList? callArguments(AstNode? expression) => switch (expression) {
      MethodInvocation(:final argumentList) => argumentList,
      InstanceCreationExpression(:final argumentList) => argumentList,
      _ => null,
    };

/// The named arguments of an annotation or constructor call, by name.
Map<String, Expression> namedArguments(ArgumentList? arguments) {
  final result = <String, Expression>{};
  for (final argument in arguments?.arguments ?? const <Argument>[]) {
    if (argument is NamedArgument) {
      result[argument.name.lexeme] = argument.argumentExpression;
    }
  }
  return result;
}

/// The string behind a named argument, or `null` when it is not a literal.
String? stringArgument(Map<String, Expression> arguments, String name) {
  final expression = arguments[name];
  return expression is StringLiteral ? expression.stringValue : null;
}

/// The bool behind a named argument, or `null` when it is not a literal.
bool? boolArgument(Map<String, Expression> arguments, String name) {
  final expression = arguments[name];
  return expression is BooleanLiteral ? expression.value : null;
}

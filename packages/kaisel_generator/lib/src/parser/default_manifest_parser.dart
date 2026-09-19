import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:spi/spi.dart';

import '../model/micro_package.dart';
import '../spi/parser.dart';

/// The built-in [ManifestParser]: reads the mounts a generated manifest
/// declares.
///
/// A host composes another package's manifest without resolving it, so the
/// manifest's declarations are read from its AST: one `static const
/// KaiselMicroMount<...>` field per mount the package contributes.
class DefaultManifestParser implements ManifestParser {
  const DefaultManifestParser();

  @override
  void close() {}

  @override
  MicroPackageManifest? parse(String source) {
    final unit = parseString(content: source, throwIfDiagnostics: false).unit;

    for (final declaration in unit.declarations) {
      // The registry the generator writes is `abstract final class
      // <Name>KaiselModule`; anything else is not a manifest this can compose.
      if (declaration is! ClassDeclaration ||
          declaration.abstractKeyword == null ||
          declaration.finalKeyword == null) {
        continue;
      }

      final className = declaration.classKeyword.next?.lexeme;
      if (className == null || !className.endsWith('KaiselModule')) {
        continue;
      }

      return MicroPackageManifest(
        className: className,
        mounts: _mountsOf(declaration),
      );
    }

    return null;
  }

  List<MicroPackageMountInfo> _mountsOf(ClassDeclaration declaration) {
    final mounts = <MicroPackageMountInfo>[];

    for (final member in declaration.body.members) {
      if (member is! FieldDeclaration || !member.isStatic) {
        continue;
      }
      for (final variable in member.fields.variables) {
        final initializer = variable.initializer;
        if (_calledName(initializer) != 'KaiselMicroMount') {
          continue;
        }

        final arguments = _namedArguments(_callArguments(initializer));
        mounts.add(
          MicroPackageMountInfo(
            fieldName: variable.name.lexeme,
            isRouted: arguments.containsKey('prefix'),
            isInitial: _boolArgument(arguments, 'isInitial') ?? false,
          ),
        );
      }
    }

    return mounts;
  }
}

/// The name of the class or function an expression calls, without its type
/// arguments or prefix.
///
/// A call parses as a `MethodInvocation` unless it is written with `new` or
/// `const`, so both forms have to be read.
String? _calledName(AstNode? expression) => switch (expression) {
      MethodInvocation(:final methodName) => methodName.name,
      InstanceCreationExpression(:final constructorName) =>
        constructorName.type.name.lexeme,
      _ => null,
    };

/// The arguments of a call, in either of the forms [_calledName] reads.
ArgumentList? _callArguments(AstNode? expression) => switch (expression) {
      MethodInvocation(:final argumentList) => argumentList,
      InstanceCreationExpression(:final argumentList) => argumentList,
      _ => null,
    };

Map<String, Expression> _namedArguments(ArgumentList? arguments) {
  final result = <String, Expression>{};
  for (final argument in arguments?.arguments ?? const <Argument>[]) {
    if (argument is NamedArgument) {
      result[argument.name.lexeme] = argument.argumentExpression;
    }
  }
  return result;
}

bool? _boolArgument(Map<String, Expression> arguments, String name) {
  final expression = arguments[name];
  return expression is BooleanLiteral ? expression.value : null;
}

/// Creates the built-in [ManifestParser].
class DefaultManifestParserFactory implements ManifestParserFactory {
  const DefaultManifestParserFactory();

  @override
  String get id => 'default';

  @override
  int get order => defaultProviderOrder;

  @override
  ProviderScope get scope => ProviderScope.session;

  @override
  ManifestParser create(ProviderSession session) => const DefaultManifestParser();
}

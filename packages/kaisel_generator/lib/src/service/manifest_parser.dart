import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../helper/ast.dart';
import '../models/scan.dart';

/// Reads the mounts a generated manifest declares.
abstract interface class ManifestParser {
  /// Reads the manifest [source] declares, or `null` when it was not produced by
  /// a compatible generator — the caller then reports that the manifest must be
  /// regenerated rather than composing a package that would silently contribute
  /// no mounts.
  MicroPackageManifest? parse(String source);
}

/// The default [ManifestParser]: reads the mounts a generated manifest declares.
///
/// A host composes another package's manifest without resolving it, so the
/// manifest's declarations are read from its AST: one `static const
/// KaiselMicroMount<...>` field per mount the package contributes.
class DefaultManifestParser implements ManifestParser {
  const DefaultManifestParser();

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

      final className = classNameOf(declaration);
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
        if (calledName(initializer) != 'KaiselMicroMount') {
          continue;
        }

        final arguments = namedArguments(callArguments(initializer));
        mounts.add(
          MicroPackageMountInfo(
            fieldName: variable.name.lexeme,
            isRouted: arguments.containsKey('prefix'),
            isInitial: boolArgument(arguments, 'isInitial') ?? false,
          ),
        );
      }
    }

    return mounts;
  }
}

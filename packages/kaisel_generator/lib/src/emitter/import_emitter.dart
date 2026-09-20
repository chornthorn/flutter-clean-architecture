/// Writes the imports a generated file opens with.
///
/// Implement this to change how generated files import what they compose — a
/// different alias scheme, relative imports, a fixed header.
abstract interface class ImportEmitter {
  /// The aliases for [keys], numbered `1..n` in the order given.
  Map<String, String> aliasesFor(List<String> keys, String prefix);

  /// Writes `import '<uri>' as <alias>;` for each of [aliasedImports].
  void writeImports(
    StringBuffer buffer,
    List<({String uri, String alias})> aliasedImports,
  );

  /// A `package:` import for a file inside the package.
  String packageUri({
    required String packageName,
    required String libDir,
    required String file,
  });
}

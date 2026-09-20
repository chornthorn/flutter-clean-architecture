import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

/// The directory a feature's layers live under.
const _featuresDirectory = 'features';

/// The layers a feature is made of.
const _layers = {'domain', 'infrastructure', 'presentation'};

/// What each layer may depend on.
///
/// Clean architecture points every dependency inward: `presentation` and
/// `infrastructure` may use `domain`, and `domain` may use neither of them. The
/// shared `core/` is a kernel both sides sit on, so it is outside this rule.
const _mayDependOn = <String, Set<String>>{
  'domain': {'domain'},
  'infrastructure': {'domain', 'infrastructure'},
  'presentation': {'domain', 'presentation'},
};

/// The feature layer [path] sits in, or `null` when it sits in none.
String? layerOf(String path) {
  final segments = path.replaceAll(r'\', '/').split('/');
  final index = segments.indexOf(_featuresDirectory);
  if (index < 0 || index + 2 >= segments.length) return null;

  final layer = segments[index + 2];
  return _layers.contains(layer) ? layer : null;
}

/// Reports a dependency that points at a layer outside the depending one.
class LayerDependencyDirectionVisitor extends SimpleAstVisitor<void> {
  LayerDependencyDirectionVisitor(this.rule, this.from);

  final AnalysisRule rule;

  /// The layer of the file being visited.
  final String from;

  @override
  void visitImportDirective(ImportDirective node) {
    _check(node, node.libraryImport?.importedLibrary);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _check(node, node.libraryExport?.exportedLibrary);
  }

  void _check(AstNode node, LibraryElement? library) {
    if (library == null) return;

    final to = layerOf(library.firstFragment.source.fullName);
    if (to == null) return;
    if (_mayDependOn[from]!.contains(to)) return;

    rule.reportAtNode(node, arguments: [from, to]);
  }
}

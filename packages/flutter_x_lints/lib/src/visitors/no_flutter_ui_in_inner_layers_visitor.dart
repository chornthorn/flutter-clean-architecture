import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// The Flutter libraries that are UI: the widget packages, and the layer they
/// are built on.
///
/// `dart:ui` is included because it is where `Color`, `Size` and the engine
/// bindings live — the same dependency by a shorter name.
const _uiLibraries = {
  'package:flutter/widgets.dart',
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
  'package:flutter/rendering.dart',
  'package:flutter/painting.dart',
  'package:flutter/animation.dart',
  'package:flutter/semantics.dart',
  'package:flutter/scheduler.dart',
  'dart:ui',
};

/// Reports an import of a UI library from a layer that must stay free of it.
class NoFlutterUiInInnerLayersVisitor extends SimpleAstVisitor<void> {
  NoFlutterUiInInnerLayersVisitor(this.rule, this.layer);

  final AnalysisRule rule;

  /// The layer the file belongs to, named in the message.
  final String layer;

  @override
  void visitImportDirective(ImportDirective node) =>
      _check(node, node.uri.stringValue);

  @override
  void visitExportDirective(ExportDirective node) =>
      _check(node, node.uri.stringValue);

  void _check(AstNode node, String? uri) {
    if (uri == null) return;
    if (!_uiLibraries.contains(uri)) return;

    rule.reportAtNode(node, arguments: [layer]);
  }
}

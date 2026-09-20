import 'package:analyzer/dart/ast/ast.dart';

import 'supertypes.dart';

/// The Flutter bases a widget library declares. `State` is included because a
/// `State` class is where a widget's work would most plausibly hide.
const widgetBases = {'Widget', 'State', 'StatefulWidget', 'StatelessWidget'};

/// Whether [unit] declares a Flutter widget, or the state class beside one.
bool declaresWidget(CompilationUnit unit) => unit.declarations
    .whereType<ClassDeclaration>()
    .any((declaration) => hasAnySupertype(declaration, widgetBases));

import 'package:analyzer/dart/element/element.dart';

import 'packages.dart';

/// Whether [uri] addresses the `get_it` package.
bool isGetItUri(String? uri) => isPackageUri(uri, 'get_it');

/// Whether [element] is declared inside the `get_it` package.
bool isInGetIt(Element element) => isInPackage(element, 'get_it');

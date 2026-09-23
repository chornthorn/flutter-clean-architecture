import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/no_cqrs_dispatch_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoCqrsDispatchTest);
  });
}

@reflectiveTest
class NoCqrsDispatchTest extends AnalysisRuleTest {
  /// The one directory a publish is allowed from.
  String get _usecasesDir =>
      '$testPackageLibPath/features/shop/domain/usecases';

  @override
  void setUp() {
    rule = NoCqrsDispatchRule();
    // Mirrors the real package: the calls are declared on the dispatcher
    // interfaces, and `CqrsDispatcher` only implements them.
    newPackage('cqrs')..addFile('lib/cqrs.dart', '''
abstract interface class CommandDispatcher {
  Future<void> command(Object command);
}

abstract interface class QueryDispatcher {
  Future<void> query(Object query);
}

abstract interface class EventPublisher {
  Future<void> publish(Object event);

  Future<void> publishAll(Iterable<Object> events);
}

abstract interface class CqrsDispatcher
    implements CommandDispatcher, QueryDispatcher, EventPublisher {}
''');
    super.setUp();
  }

  void test_a_view_model_that_dispatches_a_query() async {
    final source = '''
import 'package:cqrs/cqrs.dart';

class ShopHomeViewModel {
  ShopHomeViewModel(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.query(0);
}
''';

    const call = 'dispatcher.query(0)';
    await assertDiagnostics(source, [lint(source.indexOf(call), call.length)]);
  }

  void test_a_view_model_that_dispatches_a_command() async {
    final source = '''
import 'package:cqrs/cqrs.dart';

class ShopProductViewModel {
  ShopProductViewModel(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> add() async => dispatcher.command(0);
}
''';

    const call = 'dispatcher.command(0)';
    await assertDiagnostics(source, [lint(source.indexOf(call), call.length)]);
  }

  void test_a_repository_that_dispatches() async {
    final source = '''
import 'package:cqrs/cqrs.dart';

class PostRepository {
  PostRepository(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.query(0);
}
''';

    const call = 'dispatcher.query(0)';
    await assertDiagnostics(source, [lint(source.indexOf(call), call.length)]);
  }

  void test_a_call_declared_on_a_dispatcher_interface() async {
    // `command` is declared on `CommandDispatcher`, not on `CqrsDispatcher`, so
    // a rule that matches only the concrete name never fires against the real
    // package.
    final source = '''
import 'package:cqrs/cqrs.dart';

class PostRepository {
  PostRepository(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.command(0);
}
''';

    const call = 'dispatcher.command(0)';
    await assertDiagnostics(source, [lint(source.indexOf(call), call.length)]);
  }

  void test_a_use_case_that_publishes() async {
    // The module-to-module call the dispatcher is kept for.
    final path = '$_usecasesDir/add_product_to_cart_use_case.dart';
    newFile(path, '''
import 'package:cqrs/cqrs.dart';

class AddProductToCartUseCase {
  AddProductToCartUseCase(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  Future<void> call() async => _dispatcher.publish(0);
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_a_use_case_that_publishes_a_batch() async {
    final path = '$_usecasesDir/add_product_to_cart_use_case.dart';
    newFile(path, '''
import 'package:cqrs/cqrs.dart';

class AddProductToCartUseCase {
  AddProductToCartUseCase(this._dispatcher);

  final CqrsDispatcher _dispatcher;

  Future<void> call() async => _dispatcher.publishAll(const []);
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_a_publish_outside_a_use_case() async {
    final source = '''
import 'package:cqrs/cqrs.dart';

class ShopProductViewModel {
  ShopProductViewModel(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> add() async => dispatcher.publish(0);
}
''';

    const call = 'dispatcher.publish(0)';
    await assertDiagnostics(source, [lint(source.indexOf(call), call.length)]);
  }

  void test_a_look_alike_dispatcher_is_not_the_cqrs_one() async {
    await assertNoDiagnostics('''
class CqrsDispatcher {
  Future<void> query(Object query) async {}
}

class PostRepository {
  PostRepository(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.query(0);
}
''');
  }

  void test_a_test_that_dispatches() async {
    final path = '$testPackageTestPath/post_repository_test.dart';
    newFile(path, '''
import 'package:cqrs/cqrs.dart';

class PostRepository {
  PostRepository(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.query(0);
}
''');

    await assertDiagnosticsInFile(path, []);
  }
}

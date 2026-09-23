import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/usecase_must_be_injectable_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UsecaseMustBeInjectableTest);
  });
}

/// What every test source opens with: the handler and message contracts.
const _cqrs = "import 'package:cqrs/cqrs.dart';";

/// The same, with the container's annotation in scope.
const _withInjectify =
    "import 'package:cqrs/cqrs.dart';\nimport 'package:injectify/injectify.dart';";

@reflectiveTest
class UsecaseMustBeInjectableTest extends AnalysisRuleTest {
  /// The directory a use case is recognised by, under the test package's `lib/`.
  String get _usecasesDir =>
      '$testPackageLibPath/features/posts/domain/usecases';

  @override
  void setUp() {
    rule = UsecaseMustBeInjectableRule();
    newPackage('cqrs')..addFile('lib/cqrs.dart', '''
class Command<T> {
  const Command();
}

class Query<T> {
  const Query();
}

class Event {
  const Event();
}

abstract interface class CommandHandler<TCommand, TResult> {
  TResult execute(TCommand command);
}

abstract interface class QueryHandler<TQuery, TResult> {
  TResult execute(TQuery query);
}

abstract interface class EventHandler<TEvent> {
  void handle(TEvent event);
}
''');
    newPackage('injectify')..addFile('lib/injectify.dart', '''
class Scope {
  static const factory = Scope();
}

class Injectable {
  const Injectable({this.scope, this.as});

  final Scope? scope;
  final Object? as;
}
''');
    // A same-named contract from elsewhere, for the look-alike test.
    newPackage('not_cqrs')..addFile('lib/not_cqrs.dart', '''
abstract interface class QueryHandler<TQuery, TResult> {
  TResult execute(TQuery query);
}
''');
    super.setUp();
  }

  void test_command_handler_without_the_annotation() async {
    final source =
        '''
$_cqrs
class CreatePostCommandHandler implements CommandHandler<Object, Object> {
  const CreatePostCommandHandler();

  @override
  Object execute(Object command) => command;
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('CreatePostCommandHandler'),
        'CreatePostCommandHandler'.length,
      ),
    ]);
  }

  void test_query_handler_without_the_annotation() async {
    final source =
        '''
$_cqrs
class GetPostsQueryHandler implements QueryHandler<Object, Object> {
  const GetPostsQueryHandler();

  @override
  Object execute(Object query) => query;
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('GetPostsQueryHandler'),
        'GetPostsQueryHandler'.length,
      ),
    ]);
  }

  void test_event_handler_without_the_annotation() async {
    final source =
        '''
$_cqrs
class AuditHandler implements EventHandler<Object> {
  const AuditHandler();

  @override
  void handle(Object event) {}
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('AuditHandler'), 'AuditHandler'.length),
    ]);
  }

  void test_handler_with_the_annotation() async {
    await assertNoDiagnostics('''
$_withInjectify
@Injectable(scope: Scope.factory)
class GetPostsQueryHandler implements QueryHandler<Object, Object> {
  const GetPostsQueryHandler();

  @override
  Object execute(Object query) => query;
}
''');
  }

  void test_a_class_that_is_not_a_handler() async {
    await assertNoDiagnostics('''
$_cqrs
class GetPostsQuery extends Query<Object> {
  const GetPostsQuery();
}
''');
  }

  void test_an_abstract_base_handler() async {
    // The container builds the concrete handlers, not the base.
    await assertNoDiagnostics('''
$_cqrs
abstract class PostsHandler implements QueryHandler<Object, Object> {
  const PostsHandler();
}
''');
  }

  void test_a_look_alike_contract_is_not_the_cqrs_one() async {
    // Implementing another package's `QueryHandler` registers nothing with
    // cqrs, so the class is not a use case handler.
    await assertNoDiagnostics('''
import 'package:not_cqrs/not_cqrs.dart';

class GetPostsQueryHandler implements QueryHandler<Object, Object> {
  const GetPostsQueryHandler();

  @override
  Object execute(Object query) => query;
}
''');
  }

  void test_a_use_case_without_the_annotation() async {
    final path = '$_usecasesDir/get_posts_use_case.dart';
    final source = '''
class GetPostsUseCase {
  const GetPostsUseCase();
}
''';

    newFile(path, source);
    await assertDiagnosticsInFile(path, [
      lint(source.indexOf('GetPostsUseCase'), 'GetPostsUseCase'.length),
    ]);
  }

  void test_a_use_case_with_the_annotation() async {
    final path = '$_usecasesDir/get_posts_use_case.dart';
    newFile(path, '''
import 'package:injectify/injectify.dart';

@Injectable(scope: Scope.factory)
class GetPostsUseCase {
  const GetPostsUseCase();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_a_message_in_usecases_is_not_a_use_case() async {
    // A message is the data a handler takes, not something the container builds.
    final path = '$_usecasesDir/get_posts_query.dart';
    newFile(path, '''
$_cqrs
class GetPostsQuery extends Query<Object> {
  const GetPostsQuery();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_a_private_helper_in_usecases() async {
    final path = '$_usecasesDir/get_posts_use_case.dart';
    newFile(path, '''
class _Page {
  const _Page();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_an_abstract_base_in_usecases() async {
    final path = '$_usecasesDir/get_posts_use_case.dart';
    newFile(path, '''
abstract class PostsUseCase {
  const PostsUseCase();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_a_class_outside_usecases() async {
    // Recognised by where it is declared: a class elsewhere is not a use case,
    // whatever it sounds like.
    final path = '$testPackageLibPath/features/posts/domain/entities/post.dart';
    newFile(path, '''
class GetPostsUseCase {
  const GetPostsUseCase();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_a_use_case_declared_in_a_test_directory() async {
    final path =
        '$testPackageTestPath/features/posts/domain/usecases/get_posts_use_case_test.dart';
    newFile(path, '''
class FakeGetPostsUseCase {
  const FakeGetPostsUseCase();
}
''');

    await assertDiagnosticsInFile(path, []);
  }
}

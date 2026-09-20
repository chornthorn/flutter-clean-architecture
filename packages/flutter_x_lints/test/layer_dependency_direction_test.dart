import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/layer_dependency_direction_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(LayerDependencyDirectionTest);
  });
}

@reflectiveTest
class LayerDependencyDirectionTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = LayerDependencyDirectionRule();
    super.setUp();
  }

  /// Writes [declaration] at [path], so an import of it resolves and its
  /// symbols are real.
  void _library(String path, String declaration) {
    newFile('$testPackageLibPath/$path', declaration);
  }

  /// Writes [source] at [path] and asserts the rule reports at [directive],
  /// the source's first line.
  Future<void> _assertReports(
    String path,
    String directive,
    String source,
  ) async {
    newFile('$testPackageLibPath/$path', source);
    await assertDiagnosticsInFile('$testPackageLibPath/$path', [
      lint(source.indexOf(directive), directive.length),
    ]);
  }

  /// Writes [source] at [path] and asserts the rule is silent.
  Future<void> _assertClean(String path, String source) async {
    newFile('$testPackageLibPath/$path', source);
    await assertDiagnosticsInFile('$testPackageLibPath/$path', []);
  }

  void test_domain_importing_infrastructure() async {
    _library(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      'class RemotePostRepository {}\n',
    );

    const directive =
        "import '../../infrastructure/repositories/remote_post_repository.dart';";
    await _assertReports(
      'features/posts/domain/usecases/get_posts_query.dart',
      directive,
      '''
$directive

class GetPostsQuery {
  const GetPostsQuery(this.repository);

  final RemotePostRepository repository;
}
''',
    );
  }

  void test_domain_importing_presentation() async {
    _library(
      'features/posts/presentation/view_models/post_view_model.dart',
      'class PostViewModel {}\n',
    );

    const directive =
        "import '../../presentation/view_models/post_view_model.dart';";
    await _assertReports(
      'features/posts/domain/entities/post.dart',
      directive,
      '''
$directive

class Post {
  const Post(this.viewModel);

  final PostViewModel viewModel;
}
''',
    );
  }

  void test_infrastructure_importing_presentation() async {
    _library(
      'features/posts/presentation/views/posts_home_view.dart',
      'class PostsHomeView {}\n',
    );

    const directive = "import '../../presentation/views/posts_home_view.dart';";
    await _assertReports(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      directive,
      '''
$directive

class RemotePostRepository {
  const RemotePostRepository(this.view);

  final PostsHomeView view;
}
''',
    );
  }

  void test_presentation_importing_infrastructure() async {
    _library(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      'class RemotePostRepository {}\n',
    );

    const directive =
        "import '../../infrastructure/repositories/remote_post_repository.dart';";
    await _assertReports(
      'features/posts/presentation/view_models/post_view_model.dart',
      directive,
      '''
$directive

class PostViewModel {
  const PostViewModel(this.repository);

  final RemotePostRepository repository;
}
''',
    );
  }

  void test_domain_exporting_infrastructure() async {
    _library(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      'class RemotePostRepository {}\n',
    );

    const directive =
        "export '../infrastructure/repositories/remote_post_repository.dart';";
    await _assertReports(
      'features/posts/domain/posts_domain.dart',
      directive,
      '$directive\n',
    );
  }

  void test_domain_importing_domain() async {
    _library('features/posts/domain/entities/post.dart', 'class Post {}\n');

    await _assertClean(
      'features/posts/domain/repositories/post_repository.dart',
      '''
import '../entities/post.dart';

abstract class PostRepository {
  Future<Post> getPost(int id);
}
''',
    );
  }

  void test_infrastructure_importing_domain() async {
    _library(
      'features/posts/domain/repositories/post_repository.dart',
      'abstract class PostRepository {\n  Object getPost(int id);\n}\n',
    );

    await _assertClean(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      '''
import '../../domain/repositories/post_repository.dart';

class RemotePostRepository implements PostRepository {
  const RemotePostRepository();

  @override
  Object getPost(int id) => Object();
}
''',
    );
  }

  void test_presentation_importing_domain() async {
    _library(
      'features/posts/domain/usecases/get_posts_query.dart',
      'class GetPostsQuery {}\n',
    );

    await _assertClean(
      'features/posts/presentation/view_models/post_view_model.dart',
      '''
import '../../domain/usecases/get_posts_query.dart';

class PostViewModel {
  const PostViewModel(this.query);

  final GetPostsQuery query;
}
''',
    );
  }

  void test_presentation_importing_presentation() async {
    _library(
      'features/posts/presentation/views/posts_home_view.dart',
      'class PostsHomeView {}\n',
    );

    await _assertClean(
      'features/posts/presentation/view_models/post_view_model.dart',
      '''
import '../views/posts_home_view.dart';

class PostViewModel {
  const PostViewModel(this.view);

  final PostsHomeView view;
}
''',
    );
  }

  void
  test_presentation_of_one_feature_importing_another_features_domain() async {
    _library(
      'features/shop/domain/entities/product.dart',
      'class Product {}\n',
    );

    await _assertClean(
      'features/posts/presentation/widgets/product_tile.dart',
      '''
import '../../../shop/domain/entities/product.dart';

class ProductTile {
  const ProductTile(this.product);

  final Product product;
}
''',
    );
  }

  void test_a_test_file_is_outside_the_layering() async {
    // `test/` mirrors the feature layout, and a test wires the real layers
    // together on purpose.
    final path =
        '$testPackageTestPath/features/posts/presentation/view_models/post_view_model_test.dart';
    newFile(
      '$testPackageTestPath/features/posts/infrastructure/repositories/remote_post_repository.dart',
      'class RemotePostRepository {}\n',
    );
    newFile(path, '''
import '../../infrastructure/repositories/remote_post_repository.dart';

final repository = RemotePostRepository();
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_a_feature_module_file_is_outside_the_layering() async {
    _library(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      'class RemotePostRepository {}\n',
    );

    await _assertClean('features/posts/posts_module.dart', '''
import 'infrastructure/repositories/remote_post_repository.dart';

final repository = RemotePostRepository();
''');
  }

  void test_a_core_file_is_outside_the_layering() async {
    _library(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      'class RemotePostRepository {}\n',
    );

    await _assertClean('core/networking/repository.dart', '''
import '../../features/posts/infrastructure/repositories/remote_post_repository.dart';

final repository = RemotePostRepository();
''');
  }
}

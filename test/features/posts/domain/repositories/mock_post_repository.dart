import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door. Stub the domain contract, never the adapter:
// `when(() => repository.allPosts()).thenAnswer((_) async => const [post]);`
class MockPostRepository extends Mock implements PostRepository {}

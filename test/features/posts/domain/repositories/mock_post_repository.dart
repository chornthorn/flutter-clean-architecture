import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door: stub the domain contract, never the adapter.
class MockPostRepository extends Mock implements PostRepository {}

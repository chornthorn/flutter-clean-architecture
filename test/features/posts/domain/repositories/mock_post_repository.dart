import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door. Stub the domain contract, never the adapter.
// Reads carry the screen's way out, so a read is stubbed with it:
// `when(() => repository.allPosts(cancellation: any(named: 'cancellation')))`
class MockPostRepository extends Mock implements PostRepository {}

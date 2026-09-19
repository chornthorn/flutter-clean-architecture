import 'package:flutter_x/features/posts/domain/repositories/comment_repository.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door: stub the domain contract, never the adapter.
class MockCommentRepository extends Mock implements CommentRepository {}

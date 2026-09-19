import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';

// The local adapter: an in-memory store that really keeps what it is given.
@Environment(Environment.dev)
@Environment(Environment.test)
@Injectable(as: CommentRepository, scope: Scope.lazySingleton)
class InMemoryCommentRepository implements CommentRepository {
  final List<Comment> _comments = [
    const Comment(
      id: 1,
      postId: 1,
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      body: 'The first comment on the first post.',
    ),
    const Comment(
      id: 2,
      postId: 1,
      name: 'Grace Hopper',
      email: 'grace@example.com',
      body: 'The second comment on the first post.',
    ),
    const Comment(
      id: 3,
      postId: 2,
      name: 'Alan Turing',
      email: 'alan@example.com',
      body: 'The only comment on the second post.',
    ),
  ];

  // Nothing is ever in flight here, so the token is taken to honour the contract and ignored.
  @override
  Future<List<Comment>> commentsForPost(
    int postId, {
    Cancellation? cancellation,
  }) async => List.unmodifiable(
    _comments.where((comment) => comment.postId == postId),
  );

  @override
  Future<Comment> createComment({
    required int postId,
    required String name,
    required String email,
    required String body,
    Cancellation? cancellation,
  }) async {
    final created = Comment(
      id: _nextId(),
      postId: postId,
      name: name,
      email: email,
      body: body,
    );
    _comments.add(created);
    return created;
  }

  int _nextId() {
    var highest = 0;
    for (final comment in _comments) {
      if (comment.id > highest) highest = comment.id;
    }
    return highest + 1;
  }
}

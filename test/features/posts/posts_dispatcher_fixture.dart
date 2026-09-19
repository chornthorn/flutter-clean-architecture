import 'package:cqrs/cqrs.dart';
import 'package:flutter_x/features/posts/domain/repositories/comment_repository.dart';
import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_comment_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_post_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/delete_post_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_comments_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_post_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/update_post_command.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_comment_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/posts_handler.dart';

// A real dispatcher over the generated handler module; see `test/README.md`.
// Returns a `TestCqrsDispatcher` to support stub overrides and dispatch tracking in tests.
// A side the test does not hand in falls back to its in-memory store: the
// generated module binds every message the feature declares, so both handlers
// have to be constructible.
TestCqrsDispatcher postsDispatcher([
  PostRepository? posts,
  CommentRepository? comments,
]) {
  final postStore = posts ?? InMemoryPostRepository();
  final commentStore = comments ?? InMemoryCommentRepository();

  return TestCqrsDispatcher()
    ..registry.registerModule(
      PostsCqrsModule(
        createPostCommandHandler: () => CreatePostCommandHandler(postStore),
        deletePostCommandHandler: () => DeletePostCommandHandler(postStore),
        getPostQueryHandler: () => GetPostQueryHandler(postStore),
        getPostsQueryHandler: () => GetPostsQueryHandler(postStore),
        updatePostCommandHandler: () => UpdatePostCommandHandler(postStore),
        createCommentCommandHandler: () =>
            CreateCommentCommandHandler(commentStore),
        getCommentsQueryHandler: () => GetCommentsQueryHandler(commentStore),
      ),
    );
}

// The comment side on its own; the post side is only there because the module
// binds the whole feature.
TestCqrsDispatcher commentsDispatcher(CommentRepository comments) =>
    postsDispatcher(null, comments);

import 'package:cqrs/cqrs.dart';
import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_post_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/delete_post_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_post_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/update_post_command.dart';
import 'package:flutter_x/features/posts/posts_handler.dart';

// A real dispatcher over the posts' generated handler module — the query path the
// container builds at runtime, with the repository passed in instead of resolved.
// Built from the generated module, so a handler the generator misses fails here
// rather than in the app.
CqrsDispatcher postsDispatcher(PostRepository posts) {
  final dispatcher = CqrsDispatcher();

  dispatcher.registry.registerModule(
    PostsCqrsModule(
      createPostCommandHandler: () => CreatePostCommandHandler(posts),
      deletePostCommandHandler: () => DeletePostCommandHandler(posts),
      getPostQueryHandler: () => GetPostQueryHandler(posts),
      getPostsQueryHandler: () => GetPostsQueryHandler(posts),
      updatePostCommandHandler: () => UpdatePostCommandHandler(posts),
    ),
  );

  return dispatcher;
}

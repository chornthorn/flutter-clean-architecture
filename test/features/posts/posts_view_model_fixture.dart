import 'package:flutter_x/features/posts/domain/repositories/comment_repository.dart';
import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_comment_use_case.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_post_use_case.dart';
import 'package:flutter_x/features/posts/domain/usecases/delete_post_use_case.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_comments_use_case.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_post_use_case.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_use_case.dart';
import 'package:flutter_x/features/posts/domain/usecases/update_post_use_case.dart';
import 'package:flutter_x/features/posts/presentation/view_models/comment_view_model.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_view_model.dart';

// What the container wires up for the two posts screens: the screen's use cases
// over whichever store a test hands in. The view model is built directly, so a
// test exercises the same graph the container does without reaching for it.

PostViewModel postsViewModel(PostRepository posts) => PostViewModel(
  getPosts: GetPostsUseCase(posts),
  getPost: GetPostUseCase(posts),
  createPost: CreatePostUseCase(posts),
  updatePost: UpdatePostUseCase(posts),
  deletePost: DeletePostUseCase(posts),
);

CommentViewModel commentsViewModel(CommentRepository comments) =>
    CommentViewModel(
      getComments: GetCommentsUseCase(comments),
      createComment: CreateCommentUseCase(comments),
    );

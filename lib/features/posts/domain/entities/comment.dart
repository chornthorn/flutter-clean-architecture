import 'package:equatable/equatable.dart';

import '../../../../core/error/app_exception.dart';

// A comment on a post, from the catalog at jsonplaceholder.typicode.com.
class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;

  @override
  List<Object?> get props => [id, postId, name, email, body];

  @override
  String toString() => 'Comment($id, $name)';
}

// One rule per field, beside the entity so create cannot drift from it. Each
// field error is keyed by the form field it is shown against.

String cleanedCommentName(String name) {
  final cleaned = name.trim();
  const message = 'A comment needs a name.';
  if (cleaned.isEmpty) {
    throw const ValidationException(
      message: message,
      fieldErrors: {'name': message},
    );
  }
  return cleaned;
}

String cleanedCommentEmail(String email) {
  final cleaned = email.trim();
  const message = 'A comment needs an email address.';
  if (cleaned.isEmpty) {
    throw const ValidationException(
      message: message,
      fieldErrors: {'email': message},
    );
  }
  // Loose on purpose: enough for the catalog to have an address to record, not
  // an RFC check — a stricter rule would reject addresses that work.
  if (!cleaned.contains('@')) {
    const invalid = 'Enter an email address like ada@example.com.';
    throw const ValidationException(
      message: invalid,
      fieldErrors: {'email': invalid},
    );
  }
  return cleaned;
}

String cleanedCommentBody(String body) {
  final cleaned = body.trim();
  const message = 'A comment needs a body.';
  if (cleaned.isEmpty) {
    throw const ValidationException(
      message: message,
      fieldErrors: {'body': message},
    );
  }
  return cleaned;
}

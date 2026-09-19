import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/presentation/widgets/comment_tile.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/comment_fixture.dart';

void main() {
  group('CommentTile', () {
    testWidgets('should render who wrote the comment and what it says', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostShell(const Scaffold(body: CommentTile(comment: comment))),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.text('The first comment on the first post.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

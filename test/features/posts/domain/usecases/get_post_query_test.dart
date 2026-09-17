import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_post_query.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/post_fixture.dart';
import '../repositories/mock_post_repository.dart';

void main() {
  group('GetPostQueryHandler', () {
    test('should return the post for the id the query carries', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);

      final found = await GetPostQueryHandler(repository)
          .execute(const GetPostQuery(1));

      expect(found, post);
    });

    test('should resolve an unknown id to null, not a failure', () async {
      final repository = MockPostRepository();
      when(
        () =>
            repository.postById(999, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => null);

      final found = await GetPostQueryHandler(repository)
          .execute(const GetPostQuery(999));

      expect(found, isNull);
    });

    test('should carry the reader\'s way out down to the repository', () async {
      final repository = MockPostRepository();
      final walkedAway = Completer<void>();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);

      await GetPostQueryHandler(repository)
          .execute(GetPostQuery(1, cancellation: walkedAway.future));

      verify(() => repository.postById(1, cancellation: walkedAway.future))
          .called(1);
    });
  });
}

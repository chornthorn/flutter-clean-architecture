import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

void main() {
  test('ProfileRouteCodec encodes and decodes correctly', () {
    const codec = ProfileRouteCodec();

    final decodedOverview = codec.decode(const []);
    expect(decodedOverview, const [ProfileOverviewRoute()]);

    final decodedEdit = codec.decode(const ['edit']);
    expect(decodedEdit, const [ProfileOverviewRoute(), ProfileEditRoute()]);

    expect(codec.encode(const [ProfileOverviewRoute()]), const []);
    expect(
      codec.encode(const [ProfileOverviewRoute(), ProfileEditRoute()]),
      const ['edit'],
    );
  });
}

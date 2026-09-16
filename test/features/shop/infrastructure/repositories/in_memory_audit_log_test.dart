import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_audit_log.dart';

void main() {
  group('InMemoryAuditLog', () {
    test('should start empty', () async {
      expect(await InMemoryAuditLog().entries(), isEmpty);
    });

    test('should keep entries in the order they were appended', () async {
      final auditLog = InMemoryAuditLog();

      await auditLog.append('first');
      await auditLog.append('second');

      expect(await auditLog.entries(), ['first', 'second']);
    });

    test(
      'should not let a reader append through the list it returns',
      () async {
        final auditLog = InMemoryAuditLog();

        final entries = await auditLog.entries();

        expect(() => entries.add('not mine'), throwsUnsupportedError);
        expect(await auditLog.entries(), isEmpty);
      },
    );
  });
}

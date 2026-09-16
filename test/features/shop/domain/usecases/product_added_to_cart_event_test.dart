import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/usecases/product_added_to_cart_event.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_audit_log.dart';

void main() {
  group('ProductAddedToCartAuditHandler', () {
    test('should record what the event carries', () async {
      final auditLog = MockAuditLog();
      when(() => auditLog.append(any())).thenAnswer((_) async {});

      await ProductAddedToCartAuditHandler(
        auditLog,
      ).handle(const ProductAddedToCartEvent('sku-42', 2));

      verify(() => auditLog.append('product.added sku-42 items=2')).called(1);
    });
  });
}

import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/audit_log.dart';

// Raised once a product is in the cart.
class ProductAddedToCartEvent extends Event {
  const ProductAddedToCartEvent(this.productId, this.itemCount);

  final String productId;
  final int itemCount;
}

// The audit reaction to the event.
@Injectable(scope: Scope.factory)
class ProductAddedToCartAuditHandler
    implements EventHandler<ProductAddedToCartEvent> {
  const ProductAddedToCartAuditHandler(this._auditLog);

  final AuditLog _auditLog;

  @override
  Future<void> handle(ProductAddedToCartEvent event) => _auditLog.append(
    'product.added ${event.productId} items=${event.itemCount}',
  );
}

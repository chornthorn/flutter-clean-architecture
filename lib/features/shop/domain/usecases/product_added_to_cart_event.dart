import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/audit_log.dart';

// Raised after a product is in the cart, for whoever cares about that. Past
// tense by convention: an event is something that already happened.
class ProductAddedToCartEvent extends Event {
  const ProductAddedToCartEvent(this.productId, this.itemCount);

  final String productId;
  final int itemCount;
}

// Named for its role, not for the event: a second reaction to the same event is
// another handler beside this one, and the dispatcher runs them all.
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

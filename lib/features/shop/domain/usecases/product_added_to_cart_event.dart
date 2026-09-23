import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/audit_log.dart';

// The one message the app still sends through `cqrs`: an event a module raises
// for whoever cares, rather than a read or a write aimed at a handler.
//
// Raised once a product is in the cart.
class ProductAddedToCartEvent extends Event {
  const ProductAddedToCartEvent(this.productId, this.itemCount);

  final String productId;
  final int itemCount;
}

// The audit reaction to the event. A listener is free to ignore it, which is
// what makes this a module boundary rather than a call.
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

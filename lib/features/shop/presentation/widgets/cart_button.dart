import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../../shop_module.dart';

// AppBar action that opens the cart. `ShopCart` is a `ShopRoute`, so this pushes
// inside the feature, the way a product tile does.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: () => context.push(const ShopCart()),
    icon: const Icon(Icons.shopping_cart_outlined),
    tooltip: 'Cart',
  );
}

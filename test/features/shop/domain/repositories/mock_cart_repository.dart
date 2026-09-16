import 'package:flutter_x/features/shop/domain/repositories/cart_repository.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door.
class MockCartRepository extends Mock implements CartRepository {}

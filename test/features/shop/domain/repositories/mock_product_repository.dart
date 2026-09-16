import 'package:flutter_x/features/shop/domain/repositories/product_repository.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door.
class MockProductRepository extends Mock implements ProductRepository {}

import 'package:flutter_x/features/shop/domain/repositories/product_repository.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door. Stub the domain contract, never the adapter:
// `when(() => repository.allProducts()).thenAnswer((_) async => const [product]);`
class MockProductRepository extends Mock implements ProductRepository {}

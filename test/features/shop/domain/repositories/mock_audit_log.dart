import 'package:flutter_x/features/shop/domain/repositories/audit_log.dart';
import 'package:mocktail/mocktail.dart';

// Doubles the contract next door. Stub the domain contract, never the adapter.
class MockAuditLog extends Mock implements AuditLog {}

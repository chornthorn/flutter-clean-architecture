import 'package:injectify/injectify.dart';

import '../../domain/repositories/audit_log.dart';

// Appends to a list that lives as long as the app does. `entries()` hands back a
// copy, so a reader cannot append through it.
@Injectable(as: AuditLog, scope: Scope.lazySingleton)
class InMemoryAuditLog implements AuditLog {
  final List<String> _entries = [];

  @override
  Future<List<String>> entries() async => List.unmodifiable(_entries);

  @override
  Future<void> append(String entry) async => _entries.add(entry);
}

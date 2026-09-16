// The audit trail; event handlers write here and nothing else does.
abstract interface class AuditLog {
  Future<List<String>> entries();

  Future<void> append(String entry);
}

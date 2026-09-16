// A trail of what happened, in the order it happened. Event handlers write
// here; nothing else does.
abstract interface class AuditLog {
  Future<List<String>> entries();

  Future<void> append(String entry);
}

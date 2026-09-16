import 'package:injectify/injectify.dart';
import 'package:signals/signals_core.dart';

// The feature's "a write above you made the list wrong" signal.
//
// kaisel keeps a page mounted while another is pushed over it, so a write made on
// the page above never remounts the one below — nothing would otherwise ask again.
// The write bumps this; the reader's subscription is what reads again.
//
// A signal and not a stream of events: it carries one fact — how many writes have
// landed — so the value *is* the state, a reader that mounts later reads it, and
// neither side keeps listener bookkeeping. See `docs/architecture.md`.
@Injectable(scope: Scope.lazySingleton)
class PostsRevision {
  final _revision = signal(0);

  // How many writes have landed above the list so far. A reader compares it
  // against the revision it last read at, which is what makes it a counter and
  // not a flag: two writes read the same as one.
  ReadonlySignal<int> get revision => _revision;

  // Called by a page that has just written.
  void markStale() => _revision.value++;
}

import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

// Tells the feature's readers that the list they hold is out of date.
//
// kaisel keeps a page mounted while another is pushed over it, so a write made on
// the page above never remounts the one below — nothing would otherwise ask again.
// The write announces itself here; the reader listens and re-reads.
@Injectable(scope: Scope.lazySingleton)
class PostsWatch extends ChangeNotifier {
  void markStale() => notifyListeners();
}

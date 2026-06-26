import 'package:flutter/foundation.dart';

/// Tracks whether a catalog-item-triggered function call (a widget's
/// `action.functionCall`, e.g. a button tap) is currently in flight, so the
/// screen can show the same busy indicator it shows while waiting on the
/// model.
///
/// This is a small shared notifier rather than something threaded through
/// [CatalogItemContext]: that context doesn't carry a reference back to the
/// session, and catalog item widgets don't know about [GenUiSession]. With
/// one user and one active session at a time, a shared notifier is the
/// simplest way for the two sides to agree on "is something happening right
/// now" without wiring a session reference through every catalog item.
class CatalogActivity {
  CatalogActivity._();

  static final ValueNotifier<bool> isCallInProgress = ValueNotifier(false);
}

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

/// Where a session is in the lifecycle of a group order.
///
/// [browsing] and [ordering] are entered automatically by [OrderState] as
/// items are added; [reviewing] and [confirmed] are only entered when a
/// catalog widget explicitly calls [OrderState.setStatus].
enum SessionStatus { browsing, ordering, reviewing, confirmed }

/// One dish a diner has added to their order.
class OrderItem {
  OrderItem({
    required this.id,
    required this.dishName,
    required this.quantity,
    required this.unitCost,
  });

  final String id;
  final String dishName;
  final int quantity;
  final double unitCost;

  JsonMap toJson() => {
    'id': id,
    'dishName': dishName,
    'quantity': quantity,
    'unitCost': unitCost,
  };
}

/// One diner's allergies and in-progress items within a session.
class DinerOrder {
  final Set<String> allergies = {};
  final List<OrderItem> items = [];

  JsonMap toJson() => {
    'allergies': allergies.toList(),
    'items': [for (final item in items) item.toJson()],
  };
}

/// Tracks session/order status across a conversation and exposes mutation
/// methods that catalog [ClientFunction]s call when widgets are interacted
/// with.
///
/// State changes here are local only — they don't notify the model directly.
/// Instead, the session checks [isDirty] before each turn and, if true,
/// serializes the current state via [toJson] into that turn's context so the
/// model picks up the change on its next response.
class OrderState extends ChangeNotifier {
  SessionStatus _status = SessionStatus.browsing;
  final Map<String, DinerOrder> _diners = {};
  String? _browsingCategory;
  String? _confirmedOrderId;
  bool _dirty = false;
  int _nextItemId = 0;

  SessionStatus get status => _status;

  /// The menu category currently being browsed (e.g. "Appetizer"), as set by
  /// the category-selection catalog item. Null until a category is picked.
  String? get browsingCategory => _browsingCategory;

  /// The pickup/reference id for the current order, assigned when [status]
  /// transitions to [SessionStatus.confirmed] and cleared by
  /// [startNewOrder]. Null at every other time.
  String? get confirmedOrderId => _confirmedOrderId;

  /// Read-only view of diners and their orders, keyed by diner name.
  Map<String, DinerOrder> get diners => Map.unmodifiable(_diners);

  /// True if state has changed since the last [takeSnapshotIfDirty] call.
  bool get isDirty => _dirty;

  /// Records which menu category the user is currently browsing.
  ///
  /// Purely informational — it doesn't affect [status] — but it's included
  /// in [toJson] so the model knows what the user is looking at without
  /// having to re-ask.
  void setBrowsingCategory(String category) {
    if (_browsingCategory == category) return;
    _browsingCategory = category;
    _markDirty();
  }

  /// Adds [quantity] of [dishName] to [dinerName]'s order at [unitCost].
  ///
  /// Creates the diner if they haven't been seen before. Moves [status] from
  /// [SessionStatus.browsing] to [SessionStatus.ordering] on the first item
  /// added to the session; later transitions are manual via [setStatus].
  /// Returns the generated id of the new item, so it can be targeted later
  /// by [removeItem].
  String addItem({
    required String dinerName,
    required String dishName,
    required double unitCost,
    int quantity = 1,
  }) {
    final diner = _diners.putIfAbsent(dinerName, DinerOrder.new);
    final id = 'item_${_nextItemId++}';
    diner.items.add(
      OrderItem(
        id: id,
        dishName: dishName,
        quantity: quantity,
        unitCost: unitCost,
      ),
    );
    if (_status == SessionStatus.browsing) {
      _status = SessionStatus.ordering;
    }
    _markDirty();
    return id;
  }

  /// Removes the item with [itemId] from [dinerName]'s order, if present.
  void removeItem({required String dinerName, required String itemId}) {
    final items = _diners[dinerName]?.items;
    if (items == null) return;
    final countBefore = items.length;
    items.removeWhere((item) => item.id == itemId);
    if (items.length != countBefore) _markDirty();
  }

  /// Sets the quantity of the item with [itemId] in [dinerName]'s order.
  ///
  /// Used by the cart view's quantity stepper. A [quantity] of 0 or less
  /// removes the item, same as [removeItem].
  void updateItemQuantity({
    required String dinerName,
    required String itemId,
    required int quantity,
  }) {
    if (quantity <= 0) {
      removeItem(dinerName: dinerName, itemId: itemId);
      return;
    }
    final items = _diners[dinerName]?.items;
    if (items == null) return;
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    items[index] = OrderItem(
      id: itemId,
      dishName: items[index].dishName,
      quantity: quantity,
      unitCost: items[index].unitCost,
    );
    _markDirty();
  }

  /// Replaces [dinerName]'s allergy set with [allergies].
  ///
  /// Creates the diner if they haven't been seen before, so allergies can be
  /// recorded before any item is added.
  void setDinerAllergies({
    required String dinerName,
    required List<String> allergies,
  }) {
    final diner = _diners.putIfAbsent(dinerName, DinerOrder.new);
    diner.allergies
      ..clear()
      ..addAll(allergies);
    _markDirty();
  }

  /// Manually advances [status], e.g. to [SessionStatus.reviewing] or
  /// [SessionStatus.confirmed].
  ///
  /// Transitioning to [SessionStatus.confirmed] also assigns a random
  /// pickup id ([confirmedOrderId]) the user can quote when they show up
  /// to collect the order, so the model has a real id to surface on the
  /// confirmation screen instead of making one up.
  void setStatus(SessionStatus status) {
    if (_status == status) return;
    _status = status;
    if (status == SessionStatus.confirmed) {
      _confirmedOrderId ??= _generateOrderId();
    }
    _markDirty();
  }

  /// Clears every diner's order and the browsing category, and resets
  /// [status] back to [SessionStatus.browsing].
  ///
  /// Used when the user returns to the menu after confirming an order, so a
  /// fresh order can start without dragging the previous one along. Less
  /// drastic than recreating the whole session via the toolbar reset button
  /// — the conversation history is preserved.
  void startNewOrder() {
    _diners.clear();
    _browsingCategory = null;
    _confirmedOrderId = null;
    _status = SessionStatus.browsing;
    _markDirty();
  }

  /// Generates a short, human-pronounceable pickup id. Format: `DINO-XXXX`
  /// where X is an uppercase alphanumeric. Collisions are theoretically
  /// possible but irrelevant for a single-user demo.
  static String _generateOrderId() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final suffix = List.generate(
      4,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
    return 'DINO-$suffix';
  }

  void _markDirty() {
    _dirty = true;
    notifyListeners();
  }

  /// Returns the current state as JSON if it changed since the last call,
  /// or null if nothing changed. Clears [isDirty] either way it's called
  /// with intent to send, so callers should only call this once per turn.
  JsonMap? takeSnapshotIfDirty() {
    if (!_dirty) return null;
    _dirty = false;
    // The CartView's "Update order" button is bound to [isDirty], so flip
    // back to false needs a notify too — otherwise the button stays
    // enabled visually after the snapshot is sent.
    notifyListeners();
    return toJson();
  }

  JsonMap toJson() => {
    'status': _status.name,
    if (_browsingCategory != null) 'browsingCategory': _browsingCategory,
    if (_confirmedOrderId != null) 'confirmedOrderId': _confirmedOrderId,
    'diners': {
      for (final entry in _diners.entries) entry.key: entry.value.toJson(),
    },
  };
}

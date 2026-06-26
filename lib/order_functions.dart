import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'order_state.dart';

/// The [ClientFunction]s catalog widgets call to mutate [OrderState].
///
/// Registered on the [Catalog] via `newFunctions`, these run locally when a
/// widget's `action.functionCall` resolves — no LLM round-trip. The model
/// only learns the result on its next turn, via the state snapshot the
/// session injects into context when [OrderState.isDirty].
List<ClientFunction> orderFunctions(OrderState orderState) => [
  // Category catalog item.
  SetBrowsingCategoryFunction(orderState),
  // Dish-card catalog item.
  AddOrderItemFunction(orderState),
  // Cart-view catalog item.
  UpdateOrderItemQuantityFunction(orderState),
  RemoveOrderItemFunction(orderState),
  SetDinerAllergiesFunction(orderState),
  // Cart-view and payment-card catalog items (e.g. "review order" /
  // "confirm and pay" buttons).
  SetSessionStatusFunction(orderState),
];

class SetBrowsingCategoryFunction extends SynchronousClientFunction {
  SetBrowsingCategoryFunction(this._orderState);

  final OrderState _orderState;

  @override
  String get name => 'setBrowsingCategory';

  @override
  String get description =>
      'Records which menu category the user is currently browsing (e.g. '
      'after they tap a category in the category catalog item). Purely '
      'informational for the next turn — does not affect order status.';

  @override
  Schema get argumentSchema => S.object(
    properties: {
      'category': S.string(
        description: 'The category name, matching a "category" value in '
            'the menu data.',
      ),
    },
    required: ['category'],
  );

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.empty;

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    _orderState.setBrowsingCategory(args['category'] as String);
    return null;
  }
}

class AddOrderItemFunction extends SynchronousClientFunction {
  AddOrderItemFunction(this._orderState);

  final OrderState _orderState;

  @override
  String get name => 'addOrderItem';

  @override
  String get description =>
      "Adds a dish to a diner's order. dishName and unitCost must match an "
      'item from the menu data provided in context.';

  @override
  Schema get argumentSchema => S.object(
    properties: {
      'dinerName': S.string(
        description: 'Name of the diner this item is for.',
      ),
      'dishName': S.string(description: 'Exact dish name from the menu.'),
      'unitCost': S.number(description: 'Per-unit cost, from the menu.'),
      'quantity': S.integer(description: 'Number of units. Defaults to 1.'),
    },
    required: ['dinerName', 'dishName', 'unitCost'],
  );

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.string;

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    return _orderState.addItem(
      dinerName: args['dinerName'] as String,
      dishName: args['dishName'] as String,
      unitCost: (args['unitCost'] as num).toDouble(),
      quantity: (args['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class RemoveOrderItemFunction extends SynchronousClientFunction {
  RemoveOrderItemFunction(this._orderState);

  final OrderState _orderState;

  @override
  String get name => 'removeOrderItem';

  @override
  String get description =>
      "Removes a previously added item from a diner's order by its id.";

  @override
  Schema get argumentSchema => S.object(
    properties: {
      'dinerName': S.string(description: 'Name of the diner.'),
      'itemId': S.string(
        description: 'The id returned by addOrderItem for this item.',
      ),
    },
    required: ['dinerName', 'itemId'],
  );

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.empty;

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    _orderState.removeItem(
      dinerName: args['dinerName'] as String,
      itemId: args['itemId'] as String,
    );
    return null;
  }
}

class UpdateOrderItemQuantityFunction extends SynchronousClientFunction {
  UpdateOrderItemQuantityFunction(this._orderState);

  final OrderState _orderState;

  @override
  String get name => 'updateOrderItemQuantity';

  @override
  String get description =>
      "Sets the quantity of an item already in a diner's order, e.g. from "
      "the cart view's quantity stepper. A quantity of 0 removes the item.";

  @override
  Schema get argumentSchema => S.object(
    properties: {
      'dinerName': S.string(description: 'Name of the diner.'),
      'itemId': S.string(
        description: 'The id returned by addOrderItem for this item.',
      ),
      'quantity': S.integer(description: 'New quantity. 0 removes the item.'),
    },
    required: ['dinerName', 'itemId', 'quantity'],
  );

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.empty;

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    _orderState.updateItemQuantity(
      dinerName: args['dinerName'] as String,
      itemId: args['itemId'] as String,
      quantity: (args['quantity'] as num).toInt(),
    );
    return null;
  }
}

class SetDinerAllergiesFunction extends SynchronousClientFunction {
  SetDinerAllergiesFunction(this._orderState);

  final OrderState _orderState;

  @override
  String get name => 'setDinerAllergies';

  @override
  String get description =>
      "Replaces a diner's recorded allergies. Call this as soon as a diner "
      'states an allergy, before adding items for them.';

  @override
  Schema get argumentSchema => S.object(
    properties: {
      'dinerName': S.string(description: 'Name of the diner.'),
      'allergies': S.list(
        description: "Full list of the diner's allergies.",
        items: S.string(),
      ),
    },
    required: ['dinerName', 'allergies'],
  );

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.empty;

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    _orderState.setDinerAllergies(
      dinerName: args['dinerName'] as String,
      allergies: (args['allergies'] as List).cast<String>(),
    );
    return null;
  }
}

class SetSessionStatusFunction extends SynchronousClientFunction {
  SetSessionStatusFunction(this._orderState);

  final OrderState _orderState;

  @override
  String get name => 'setSessionStatus';

  @override
  String get description =>
      'Manually advances the session, e.g. once the group is ready to '
      'review the order or has confirmed it. browsing/ordering are set '
      'automatically and should not be passed here.';

  @override
  Schema get argumentSchema => S.object(
    properties: {
      'status': S.string(
        description: 'The status to move the session to.',
        enumValues: ['reviewing', 'confirmed'],
      ),
    },
    required: ['status'],
  );

  @override
  ClientFunctionReturnType get returnType => ClientFunctionReturnType.empty;

  @override
  Object? executeSync(JsonMap args, ExecutionContext context) {
    final status = SessionStatus.values.byName(args['status'] as String);
    _orderState.setStatus(status);
    return null;
  }
}

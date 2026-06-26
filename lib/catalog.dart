import 'package:dino/order_functions.dart';
import 'package:dino/order_state.dart';
import 'package:genui/genui.dart';

/// Builds the catalog of widgets the model is allowed to generate.
///
/// A [Catalog] is the model's vocabulary: each entry is a widget the model can
/// request by name. The same catalog drives both the rendered surfaces and the
/// system prompt, so the model only ever emits components this client can
/// actually build.
///
/// [BasicCatalogItems] is a ready-made set of common widgets (text, buttons,
/// lists, and so on) — enough to start without defining anything. `copyWith`
/// keeps those basics and adds your own widgets on top.
///
/// [orderState] is the session's order/session-status state machine. Its
/// [orderFunctions] are registered as [ClientFunction]s, so a widget (e.g. a
/// `Button`) can mutate it locally via `action.functionCall` without a model
/// round-trip — see [OrderState] for how those mutations reach the model.
Catalog buildCatalog(OrderState orderState) =>
    BasicCatalogItems.asCatalog().copyWith(
      newItems: [
        // Add your own widgets here to grow what the model can build. Each is
        // a `CatalogItem` with a `name` the model refers to, a `dataSchema`
        // describing its properties (so the model knows how to fill them in),
        // and a `widgetBuilder` that renders it. Once listed here, the widget
        // is automatically described to the model in the system prompt.
        //
        // Planned catalog items (see order_functions.dart for the
        // ClientFunctions each one should wire its buttons/controls to via
        // `action: {"functionCall": {"call": "...", "args": {...}}}`):
        //
        // 1. CategoryCatalog — lets the user pick a menu category to browse.
        //    Wire category selection to `setBrowsingCategory`.
        //
        // 2. DishCard — shows one dish's detail with a quantity picker and
        //    an "add to order" action. Wire the add action to
        //    `addOrderItem`.
        //
        // 3. CartView — lists items across diners with quantity steppers and
        //    a remove action, plus a "review order" action. Wire quantity
        //    changes to `updateOrderItemQuantity`, removal to
        //    `removeOrderItem`, and "review order" to `setSessionStatus`
        //    (status: "reviewing").
        //
        // 4. PaymentCard — checkout/confirmation screen. Wire the
        //    confirm/pay action to `setSessionStatus` (status: "confirmed").
      ],
      newFunctions: orderFunctions(orderState),
    );

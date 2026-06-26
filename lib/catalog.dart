import 'package:dino/dish_catalog_items.dart';
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
        // `dishCatalogItems` below are placeholder/dummy implementations of
        // the four planned widgets (category picker, dish card, cart view,
        // payment card) — see dish_catalog_items.dart. They're wired to the
        // ClientFunctions in order_functions.dart end-to-end, so they're
        // usable for testing right now. Replace each one's widgetBuilder (or
        // the whole CatalogItem) with the real design whenever it's ready —
        // nothing else depends on their visuals, only on the function calls
        // they make.
        ...dishCatalogItems,
      ],
      newFunctions: orderFunctions(orderState),
    );

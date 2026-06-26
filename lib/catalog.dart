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
Catalog buildCatalog(OrderState orderState) {
  final base = BasicCatalogItems.asCatalog();
  return base.copyWith(
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
    // The basics (Button, ChoicePicker, Text, etc.) can satisfy almost any
    // request, so the model will reach for them unless told otherwise.
    // These rules steer it toward our custom widgets when the intent
    // matches one directly, instead of recreating it from generic pieces.
    systemPromptFragments: [
      ...base.systemPromptFragments,
      'You always respond with A2UI JSON, never plain text. If you are '
          'unsure which component fits, use a Column of Text + Button '
          'components rather than answering in prose.',
      'Prefer CategoryPicker when the user wants to browse or pick a menu '
          'category — its `categories` array should be the distinct '
          '`category` values from the menu data.',
      'Prefer DishCard for showing one dish with an add-to-order action; '
          "its properties (`dishName`, `description`, `unitCost`, `image`) "
          'come straight from the matching item in the menu data.',
      'Prefer CartView for showing the current order across diners, and '
          'PaymentCard for the checkout/confirmation step. CartView renders '
          'its items directly from the local order state — do not pass '
          'items in its data, an empty `{"component": "CartView"}` is '
          'enough.',
      'When the user triggers a `categoryPicked` event, respond with a '
          'Column of DishCard components for every menu item whose '
          '`category` matches the picked category.',
      'When the user triggers a `cartUpdateRequested` event, acknowledge '
          'with a short Text noting the order is up to date (the CartView '
          'itself already reflects the new totals), or re-render a fresh '
          'CartView if no surface is currently showing.',
      'When the user triggers a `reviewOrderRequested` event, render a '
          'PaymentCard with `totalCost` equal to the sum of '
          '`quantity * unitCost` across all items in the order state.',
      'When the user triggers an `orderItemAdded` event, render a CartView '
          'so they can see the dish was added (the cart reads items from '
          'local state, so just `{"component": "CartView"}` is enough).',
      'When the user triggers an `orderConfirmed` event, render a brief '
          'caveman-style confirmation message (Text component) thanking '
          'them for their order, plus a Button labeled "Return to menu" '
          'whose action dispatches the event `returnToMenu`.',
      'When the user triggers a `returnToMenu` event, render a fresh '
          'CategoryPicker with the menu categories — the same surface you '
          'would have shown to start browsing.',
    ],
  );
}

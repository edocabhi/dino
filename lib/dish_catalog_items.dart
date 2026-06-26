import 'package:dino/widgets/torn_paper_card.dart';
import 'package:dino/catalog_activity.dart';
import 'package:dino/order_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Dummy/placeholder catalog items for the four planned widgets (category
/// picker, dish card, cart view, payment card).
///
/// These exist so the order-state functions in `order_functions.dart` have
/// something to call end-to-end while the real widgets are built. They're
/// intentionally minimal — replace or extend them freely; nothing else in
/// the orchestration layer depends on their visuals, only on the
/// `ClientFunction` calls they make.
List<CatalogItem> get dishCatalogItems => [
  categoryPicker,
  dishCard,
  cartView,
  paymentCard,
];

/// Calls a registered [ClientFunction] by [name] with [args], reporting any
/// error through [itemContext] instead of letting it escape silently.
///
/// Flips [CatalogActivity.isCallInProgress] for the call's duration so the
/// screen can show a busy indicator, the same way it does while waiting on
/// the model.
Future<void> _callFunction(
  CatalogItemContext itemContext,
  String name,
  JsonMap args,
) async {
  CatalogActivity.isCallInProgress.value = true;
  try {
    await itemContext.dataContext.resolve({'call': name, 'args': args}).first;
  } on Object catch (exception, stackTrace) {
    itemContext.reportError(exception, stackTrace);
  } finally {
    CatalogActivity.isCallInProgress.value = false;
  }
}

/// Mutates [OrderState] locally via [functionName] and then notifies the
/// model immediately via a [UserActionEvent], so it can render a follow-up
/// surface in response.
///
/// Use this for any button whose effect isn't already self-evidently
/// reflected on screen — which in practice is most of them, since visible
/// data (cart quantities, totals, etc.) comes from the model's last
/// rendered surface and doesn't update until a new surface is generated.
/// One LLM round-trip per tap is the cost of keeping the UI honest.
Future<void> _callFunctionAndNotify(
  CatalogItemContext itemContext, {
  required String functionName,
  required JsonMap functionArgs,
  required String eventName,
  JsonMap? eventContext,
}) async {
  await _callFunction(itemContext, functionName, functionArgs);
  itemContext.dispatchEvent(
    UserActionEvent(
      name: eventName,
      sourceComponentId: itemContext.id,
      context: eventContext ?? functionArgs,
    ),
  );
}

/// Adds an item to the current session's order without notifying the model.
///
/// Used by DishCard's "Add to order" so the tap acknowledges with a
/// snackbar and the user can keep browsing instead of being whisked off to
/// the cart on every add. The model finds out about the new item via the
/// state snapshot on the user's next message (e.g. when they ask to see
/// their cart).
void _addToOrderLocally(
  BuildContext context, {
  required String dinerName,
  required String dishName,
  required double unitCost,
  required int quantity,
}) {
  final orderState = CatalogActivity.currentOrderState;
  if (orderState == null) return;
  orderState.addItem(
    dinerName: dinerName,
    dishName: dishName,
    unitCost: unitCost,
    quantity: quantity,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          quantity > 1
              ? 'Yabba dabba dish! $quantity × $dishName added for $dinerName.'
              : 'Yabba dabba dish! $dishName added for $dinerName.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
}

// 1. Category picker — shows one button per category. Tapping one calls
// `setBrowsingCategory`. Placeholder for your teammate's category catalog
// item.
final categoryPicker = CatalogItem(
  name: 'CategoryPicker',
  dataSchema: S.object(
    description: 'Lets the user pick a menu category to browse.',
    properties: {
      'categories': S.list(
        description: 'The menu categories to show as options.',
        items: S.string(),
      ),
    },
    required: ['categories'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final categories = (data['categories']! as List).cast<String>();
    return TornPaperCard(
      child: SizedBox(
        height: 70,
        child: Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in categories)
                ElevatedButton(
                  onPressed: () => _callFunctionAndNotify(
                    itemContext,
                    functionName: 'setBrowsingCategory',
                    functionArgs: {'category': category},
                    eventName: 'categoryPicked',
                  ),
                  child: Text(category),
                ),
            ],
          ),
        ),
      ),
    );
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "CategoryPicker",
          "categories": ["Appetizer", "Main Course", "Dessert"]
        }
      ]
    ''',
  ],
);

// 2. Dish card — dish detail with a quantity stepper and an "add to order"
// button that calls `addOrderItem`. Placeholder for your teammate's dish
// card.
final dishCard = CatalogItem(
  name: 'DishCard',
  dataSchema: S.object(
    description: "Shows one dish's detail with a quantity picker.",
    properties: {
      'dinerName': S.string(description: 'Who this card is for.'),
      'dishName': S.string(description: 'Exact dish name from the menu.'),
      'description': S.string(description: "The dish's description."),
      'unitCost': S.number(description: 'Per-unit cost, from the menu.'),
      'image': S.string(description: 'Asset path for the dish image.'),
    },
    required: ['dinerName', 'dishName', 'unitCost'],
  ),
  widgetBuilder: (itemContext) => _DishCard(itemContext: itemContext),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "DishCard",
          "dinerName": "Abhishek",
          "dishName": "Pterodactyl Wings",
          "description": "Giant jumbo turkey wings, dry-rubbed with wild herbs.",
          "unitCost": 18.99,
          "image": "assets/images/pterodactyl_wings.jpg"
        }
      ]
    ''',
  ],
);

class _DishCard extends StatefulWidget {
  const _DishCard({required this.itemContext});

  final CatalogItemContext itemContext;

  @override
  State<_DishCard> createState() => _DishCardState();
}

class _DishCardState extends State<_DishCard> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final data = widget.itemContext.data as JsonMap;
    final dinerName = data['dinerName']! as String;
    final dishName = data['dishName']! as String;
    final description = data['description'] as String?;
    final unitCost = (data['unitCost']! as num).toDouble();
    final image = data['image'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TornPaperCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (image != null)
                    Flexible(
                      flex: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          image,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  const SizedBox(
                    width: 16,
                  ),
                  Flexible(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          dishName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),

                        if (description != null) const SizedBox(height: 8),
                        if (description != null) Text(description),

                        const SizedBox(height: 8),
                        Text('\$${unitCost.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  IconButton(
                    icon: SizedBox(
                      height: 48,
                      width: 48,
                      child: SvgPicture.asset(
                        'assets/icons/bone_minus.svg',
                      ),
                    ),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Text('$_quantity'),
                  IconButton(
                    icon: SizedBox(
                      height: 48,
                      width: 48,
                      child: SvgPicture.asset(
                        'assets/icons/bone_plus.svg',
                      ),
                    ),
                    onPressed: () => setState(() => _quantity++),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _addToOrderLocally(
                      context,
                      dinerName: dinerName,
                      dishName: dishName,
                      unitCost: unitCost,
                      quantity: _quantity,
                    ),
                    child: const Text('Add to order'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. Cart view — lists items across diners with a quantity stepper, a
// remove action, an "Update order" button that pushes pending changes to
// the model, and a "Checkout" button that advances the session. Placeholder
// for your teammate's cart view.
//
// Unlike the other catalog items, this one renders directly from
// [OrderState] rather than from the data the model passes in. That lets
// `+`/`-`/delete mutate state and reflect immediately on screen without a
// model round-trip per tap. The model is told about the changes only when
// the user explicitly taps "Update order".
final cartView = CatalogItem(
  name: 'CartView',
  dataSchema: S.object(
    description:
        "Lists the current order's items across diners. Items are read "
        'from the local OrderState; you do not need to pass them in.',
    properties: {},
  ),
  widgetBuilder: (itemContext) => _CartView(itemContext: itemContext),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "CartView"
        }
      ]
    ''',
  ],
);

class _CartView extends StatelessWidget {
  const _CartView({required this.itemContext});

  final CatalogItemContext itemContext;

  @override
  Widget build(BuildContext context) {
    final orderState = CatalogActivity.currentOrderState;
    if (orderState == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: orderState,
      builder: (context, _) {
        final rows = <_CartRowData>[
          for (final dinerEntry in orderState.diners.entries)
            for (final item in dinerEntry.value.items)
              _CartRowData(dinerName: dinerEntry.key, item: item),
        ];
        final total = rows.fold<double>(
          0,
          (sum, row) => sum + row.item.unitCost * row.item.quantity,
        );

        return TornPaperCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cart',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Your cart is empty.'),
                  )
                else
                  for (final row in rows)
                    _CartRow(orderState: orderState, row: row),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: \$${total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Enabled only when there are local-only changes the
                    // model hasn't seen yet. The dirty flag clears as soon
                    // as a snapshot is sent on the next model turn, so
                    // this button auto-disables once changes are in sync.
                    OutlinedButton(
                      onPressed: orderState.isDirty
                          ? () => _callFunctionAndNotify(
                              itemContext,
                              functionName: 'setSessionStatus',
                              // No-op status change just to fit through
                              // the existing helper; the real signal here
                              // is the cartUpdateRequested event plus the
                              // state snapshot it carries.
                              functionArgs: {'status': orderState.status.name},
                              eventName: 'cartUpdateRequested',
                            )
                          : null,
                      child: const Text('Update order'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: rows.isEmpty
                          ? null
                          : () => _callFunctionAndNotify(
                              itemContext,
                              functionName: 'setSessionStatus',
                              functionArgs: {'status': 'reviewing'},
                              eventName: 'reviewOrderRequested',
                            ),
                      child: const Text('Checkout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CartRowData {
  _CartRowData({required this.dinerName, required this.item});

  final String dinerName;
  final OrderItem item;
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.orderState, required this.row});

  final OrderState orderState;
  final _CartRowData row;

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final lineTotal = item.unitCost * item.quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text('${item.dishName} (${row.dinerName})')),
          // Local-only mutations. No event dispatch, no LLM round-trip.
          // The model finds out about these only when the user taps
          // "Update order" (or any other notify-style button).
          IconButton(
            icon: SizedBox(
              height: 48,
              width: 48,
              child: SvgPicture.asset(
                'assets/icons/bone_minus.svg',
              ),
            ),
            onPressed: () => orderState.updateItemQuantity(
              dinerName: row.dinerName,
              itemId: item.id,
              quantity: item.quantity - 1,
            ),
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: SizedBox(
              height: 48,
              width: 48,
              child: SvgPicture.asset(
                'assets/icons/bone_add.svg',
              ),
            ),
            onPressed: () => orderState.updateItemQuantity(
              dinerName: row.dinerName,
              itemId: item.id,
              quantity: item.quantity + 1,
            ),
          ),
          Text('\$${lineTotal.toStringAsFixed(2)}'),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => orderState.removeItem(
              dinerName: row.dinerName,
              itemId: item.id,
            ),
          ),
        ],
      ),
    );
  }
}

// 4. Payment card — checkout/confirmation. Calls `setSessionStatus` with
// status "confirmed". Placeholder for your teammate's payment card.
final paymentCard = CatalogItem(
  name: 'PaymentCard',
  dataSchema: S.object(
    description: 'Checkout/confirmation screen showing the order total.',
    properties: {
      'totalCost': S.number(description: 'The total cost of the order.'),
    },
    required: ['totalCost'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final totalCost = (data['totalCost']! as num).toDouble();

    return TornPaperCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: \$${totalCost.toStringAsFixed(2)}',
              style: Theme.of(itemContext.buildContext).textTheme.titleMedium,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _callFunctionAndNotify(
                  itemContext,
                  functionName: 'setSessionStatus',
                  functionArgs: {'status': 'confirmed'},
                  eventName: 'orderConfirmed',
                ),
                child: const Text('Confirm & Pay'),
              ),
            ),
          ],
        ),
      ),
    );
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "PaymentCard",
          "totalCost": 56.97
        }
      ]
    ''',
  ],
);

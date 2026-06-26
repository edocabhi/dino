import 'package:dino/widgets/torn_paper_card.dart';
import 'package:dino/catalog_activity.dart';
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
/// Use this for buttons where doing nothing visible would be confusing
/// (e.g. picking a category should immediately show dishes in that
/// category). Buttons whose effect is already obvious on-screen (e.g.
/// adjusting a cart row's quantity) don't need this — let the state-snapshot
/// injection on the user's next typed turn carry the change.
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
    return Wrap(
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
                  SizedBox(
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
                    onPressed: () => _callFunction(
                      widget.itemContext,
                      'addOrderItem',
                      {
                        'dinerName': dinerName,
                        'dishName': dishName,
                        'unitCost': unitCost,
                        'quantity': _quantity,
                      },
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
// remove action, and a "review order" button that advances the session.
// Placeholder for your teammate's cart view.
final cartView = CatalogItem(
  name: 'CartView',
  dataSchema: S.object(
    description: "Lists the current order's items across diners.",
    properties: {
      'items': S.list(
        description: 'The order items to display.',
        items: S.object(
          properties: {
            'dinerName': S.string(),
            'itemId': S.string(),
            'dishName': S.string(),
            'quantity': S.integer(),
            'unitCost': S.number(),
          },
          required: [
            'dinerName',
            'itemId',
            'dishName',
            'quantity',
            'unitCost',
          ],
        ),
      ),
    },
    required: ['items'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final items = (data['items']! as List).cast<JsonMap>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cart',
              style: Theme.of(itemContext.buildContext).textTheme.titleMedium,
            ),
            for (final item in items)
              _CartRow(itemContext: itemContext, item: item),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () =>
                    _callFunction(itemContext, 'setSessionStatus', {
                      'status': 'reviewing',
                    }),
                child: const Text('Review order'),
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
          "component": "CartView",
          "items": [
            {
              "dinerName": "Abhishek",
              "itemId": "item_0",
              "dishName": "Pterodactyl Wings",
              "quantity": 2,
              "unitCost": 18.99
            }
          ]
        }
      ]
    ''',
  ],
);

class _CartRow extends StatelessWidget {
  const _CartRow({required this.itemContext, required this.item});

  final CatalogItemContext itemContext;
  final JsonMap item;

  @override
  Widget build(BuildContext context) {
    final dinerName = item['dinerName']! as String;
    final itemId = item['itemId']! as String;
    final dishName = item['dishName']! as String;
    final quantity = (item['quantity']! as num).toInt();
    final unitCost = (item['unitCost']! as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text('$dishName ($dinerName)')),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => _callFunction(
              itemContext,
              'updateOrderItemQuantity',
              {
                'dinerName': dinerName,
                'itemId': itemId,
                'quantity': quantity - 1,
              },
            ),
          ),
          Text('$quantity'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _callFunction(
              itemContext,
              'updateOrderItemQuantity',
              {
                'dinerName': dinerName,
                'itemId': itemId,
                'quantity': quantity + 1,
              },
            ),
          ),
          Text('\$${(unitCost * quantity).toStringAsFixed(2)}'),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _callFunction(itemContext, 'removeOrderItem', {
              'dinerName': dinerName,
              'itemId': itemId,
            }),
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

    return Card(
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
                onPressed: () =>
                    _callFunction(itemContext, 'setSessionStatus', {
                      'status': 'confirmed',
                    }),
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

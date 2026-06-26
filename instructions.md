# Continuing work on Dino

This is a working note for picking this project back up — what's been
decided, what's built, and what's next. Read [`README.md`](README.md) first
for the high-level architecture; this file is the more granular "where did
we leave off" doc.

## Team split (as of this writing)

- You (Abhishek): orchestration layer — persona, model client, state
  machine, catalog plumbing.
- Teammate: custom catalog item widgets (the actual dish cards, cart UI,
  etc.) and assets.
- Third teammate: unconfirmed scope.

Because of this split, the orchestration side (this codebase's `lib/*.dart`
outside `lib/widgets/`) should stay **widget-agnostic** — don't hardcode
specific widget names or assume what a catalog item looks like. Expose
behavior through `ClientFunction`s and let the catalog item wire up to them.

## What's built

- **Persona** ([`lib/prompt.dart`](lib/prompt.dart)) — caveman health-coach
  voice, group-ordering rules, allergy-as-hard-constraint, no-medical-advice
  guardrail, menu-data-is-truth rule, order-confirmation rule, off-topic
  redirect.
- **Order/session state machine** ([`lib/order_state.dart`](lib/order_state.dart))
  — `SessionStatus` enum, per-diner `DinerOrder`/`OrderItem`, dirty-tracking
  for context injection.
- **ClientFunctions** ([`lib/order_functions.dart`](lib/order_functions.dart))
  — `setBrowsingCategory`, `addOrderItem`, `updateOrderItemQuantity`,
  `removeOrderItem`, `setDinerAllergies`, `setSessionStatus`. Registered on
  the catalog via `newFunctions:` in [`lib/catalog.dart`](lib/catalog.dart).
- **Per-turn state injection** ([`lib/conversation.dart`](lib/conversation.dart),
  `_promptWithOrderState`) — appends a JSON snapshot of `OrderState` to the
  outgoing prompt only when it changed since the last turn.
- **Reset button** ([`lib/home_page.dart`](lib/home_page.dart)) — top-left
  app bar icon button; disposes and recreates the whole `GenUiSession`
  (conversation + state machine together). Discards any in-flight request
  rather than cancelling it gracefully.

## Key decisions made (and why), so you don't re-litigate them

- **Widget interactions are local-only (`functionCall`), not `UserActionEvent`.**
  State mutations don't round-trip through the model immediately; the model
  only learns on its *next* turn via the injected snapshot. Chosen for speed
  (no extra LLM call per cart edit) at the cost of the model not reacting
  instantly. If a future feature needs the model to react the moment
  something changes (e.g. live-updating an order summary surface), that
  widget's button should use `action.event` instead, not `functionCall`.
- **`OrderState` lives one-per-`GenUiSession`, in-memory only.** No
  persistence layer. The reset button is the "I want a clean slate"
  mechanism, so disk persistence was treated as unnecessary scope for now.
- **Diners are free-text names, no fixed roster.** A diner exists the
  moment their name is mentioned. If a roster/auth system gets added later,
  `OrderState`'s `Map<String, DinerOrder>` keying would need to change from
  name-keyed to id-keyed.
- **`status` auto-advances only for `browsing -> ordering`** (on first item
  added). Every other transition (`-> reviewing`, `-> confirmed`) is a
  manual `setSessionStatus` call from a widget — deliberately, so "review"
  and "confirm" are explicit user actions, not inferred.
- **Item identity is a generated id** (`item_0`, `item_1`, ...), not
  `(dinerName, dishName)`. Returned by `addOrderItem`, required by
  `removeOrderItem`/`updateOrderItemQuantity`. This means whatever renders
  the cart needs to carry that id through (e.g. bind it into the cart
  widget's data so the remove/quantity buttons' `args` can reference it).
- **Menu data is injected as static context, not fetched via a tool call.**
  `assets/data/menu.json` is loaded once in `home_page.dart` and passed as
  `additionalPromptContext`. Revisit only if the menu becomes dynamic
  (per-location, admin-editable, or large enough to waste tokens resending).
- **Images are pure pass-through.** The model never interprets image bytes
  — it just relays the `image` asset-path string from menu data into a
  widget's `image` property unchanged.

## What's next

1. **Build the four catalog items** (none exist yet — only placeholders in
   `lib/catalog.dart`):
   - Category catalog → wire to `setBrowsingCategory`
   - Dish card → wire "add to order" to `addOrderItem`
   - Cart view → wire quantity stepper to `updateOrderItemQuantity`, remove
     to `removeOrderItem`, "review order" to `setSessionStatus("reviewing")`
   - Payment card → wire confirm/pay to `setSessionStatus("confirmed")`

   Each should be a `CatalogItem` with a `dataSchema` and `widgetBuilder`,
   added to the `newItems:` list in `buildCatalog()`. Buttons inside them
   use:
   ```json
   {"action": {"functionCall": {"call": "<functionName>", "args": {...}}}}
   ```

2. **Decide how the cart/order surfaces actually render.** Right now
   `home_page.dart` only ever shows the *latest* surface. Once a cart view
   exists, check whether that's still the right model — e.g. does adding an
   item from a dish card need to keep that surface visible, or does the
   model need to be nudged (via prompt or event) to re-render a cart
   surface after an add?

3. **Tool-calling for the model itself is still unbuilt.** `FeatherlessModelClient`
   ([`lib/model/featherless_model_client.dart`](lib/model/featherless_model_client.dart))
   only does plain text streaming (`createStream`) — no `tools`/
   `function_call` parameter wired up. This hasn't blocked anything yet
   because all `ClientFunction`s are invoked by widgets locally, not by the
   model directly. Only build this if a future feature needs the *model*
   to autonomously call something (vs. a button triggering it).

4. **`gemini_model_client.dart` is presumably dead code** — the Featherless
   migration plan in `docs/plan/2026-06-24-feat-replace-gemini-with-featherless-model-client-plan.md`
   suggests it's being replaced. Confirm with the team before deleting it.

## Verifying changes

```sh
fvm flutter pub get
fvm flutter analyze
```

No errors are expected; pre-existing style-level `info`s (line length,
`cast_nullable_to_non_nullable`, etc.) match patterns already used by the
`genui` package itself and the rest of this codebase, so they're not worth
chasing down.

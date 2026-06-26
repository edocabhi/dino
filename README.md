# Dino 🦖 — Yabba Dabba Dish!

Dino is an AI-powered food court app that brings healthy, modern dining to
the stone age. Built with Flutter **Generative UI** (GenUI), it lets a group
order from multiple virtual stalls through one chat: users state their
health goals or cravings, and the AI generates interactive,
prehistoric-themed widgets to customize vitamin-rich, caveman-sized portions
cooked with clean, modern techniques.

Instead of replying with plain text, the model replies with a *user
interface* — buttons, lists, cards — rendered live as real Flutter widgets
via the [`genui`](https://pub.dev/packages/genui) package's A2UI
("agent-to-UI") protocol.

---

## Architecture

This is a single Flutter client app — there is no separate backend server.
The "backend" is the orchestration layer inside `lib/`: it talks directly to
an LLM (hosted on [Featherless.ai](https://featherless.ai), an
OpenAI-compatible API) and constrains its output to a **catalog** of widgets
the Flutter side knows how to render.

Three pieces work together:

1. **Catalog** ([`lib/catalog.dart`](lib/catalog.dart)) — the widget
   vocabulary the model is allowed to use, plus the `ClientFunction`s
   widgets can call locally (see [State machine](#order--session-state-machine)
   below).
2. **Persona / system prompt** ([`lib/prompt.dart`](lib/prompt.dart)) —
   Dino's caveman health-coach voice, group-ordering rules, allergy
   handling, and the menu-data contract.
3. **Model client** ([`lib/model/featherless_model_client.dart`](lib/model/featherless_model_client.dart))
   — talks to Featherless via `package:openai_dart`, currently model
   `Qwen/Qwen2.5-72B-Instruct`, streaming raw text chunks that the `genui`
   transport parses as A2UI JSON.

Because the same catalog is fed to the model *and* used to render, the model
can never ask for a widget the app can't draw.

---

## Persona

Dino's full personality, behavioral rules, and domain constraints live in
[`lib/prompt.dart`](lib/prompt.dart). In summary:

- Friendly, nutrition-savvy caveman voice; "Yabba Dabba Dish!" used sparingly
  for genuine moments of delight.
- Health-coach first: asks about goals, cravings, dietary limits — not
  preachy, doesn't refuse reasonable indulgences.
- **Group ordering**: one chat can represent several diners. Their goals,
  allergies, and picks are tracked separately and never merged.
- **Allergies** are hard constraints, not preferences.
- **Not a doctor**: encourages healthy choices but doesn't diagnose or give
  medical advice.
- **Menu data is the only source of truth** — the model never invents
  dishes, stalls, or prices. The real menu (`assets/data/menu.json`) is
  loaded at runtime and injected into context by
  [`lib/home_page.dart`](lib/home_page.dart).
- **Order confirmation**: orders are summarized and explicitly confirmed
  before being treated as final, broken out per diner.

---

## Order / session state machine

Session and order progress is tracked outside the model, in
[`lib/order_state.dart`](lib/order_state.dart):

```
SessionStatus: browsing -> ordering -> reviewing -> confirmed
```

- `browsing` → `ordering` happens automatically on the first item added.
- `ordering` → `reviewing` → `confirmed` are manual, triggered by a catalog
  widget.

`OrderState` tracks each diner's allergies and items, plus which menu
category is currently being browsed. It's owned by one `GenUiSession`
(disposed/recreated with it), is in-memory only, and identifies diners by
free-text name as they're mentioned in chat — no fixed roster.

**How widgets reach it:** mutation methods are wrapped as `ClientFunction`s
in [`lib/order_functions.dart`](lib/order_functions.dart) and registered on
the `Catalog`. A widget's `action` can resolve a `functionCall` *locally*
(no LLM round-trip):

```json
{"action": {"functionCall": {"call": "addOrderItem", "args": {"dinerName": "Abhishek", "dishName": "Pterodactyl Wings", "unitCost": 18.99}}}}
```

**How the model finds out:** state changes are local-only. Before each
outgoing turn, [`lib/conversation.dart`](lib/conversation.dart) checks
`OrderState.isDirty` and, if true, appends a fresh JSON snapshot to that
turn's prompt — so the model picks up the change on its *next* response,
without every interaction needing a round-trip.

Available functions today:

| Function                  | Used by               | Mutates                                  |
| -------------------------- | ---------------------- | ----------------------------------------- |
| `setBrowsingCategory`      | Category catalog       | `OrderState.browsingCategory` (informational) |
| `addOrderItem`             | Dish card               | Adds an item to a diner's order; auto-advances `browsing -> ordering` |
| `updateOrderItemQuantity`  | Cart view               | Sets/removes an item's quantity            |
| `removeOrderItem`          | Cart view               | Removes an item                            |
| `setDinerAllergies`        | (any onboarding widget) | Replaces a diner's allergy set             |
| `setSessionStatus`         | Cart view / Payment card | Manually advances to `reviewing`/`confirmed` |

A restart button in the app bar (top-left) tears down and recreates the
whole `GenUiSession`, resetting the conversation and `OrderState` together.

---

## Catalog items — status

[`lib/catalog.dart`](lib/catalog.dart) currently ships only
`BasicCatalogItems` (text, buttons, lists) plus the `ClientFunction`s above.
Four custom catalog items are planned but **not yet implemented**
(placeholder comments mark where they go):

1. **Category catalog** — pick a menu category to browse. Wire to
   `setBrowsingCategory`.
2. **Dish card** — dish detail with a quantity picker and "add to order".
   Wire to `addOrderItem`.
3. **Cart view** — items across diners, quantity steppers, remove, "review
   order". Wire to `updateOrderItemQuantity`, `removeOrderItem`,
   `setSessionStatus("reviewing")`.
4. **Payment card** — checkout/confirmation. Wire to
   `setSessionStatus("confirmed")`.

See [`instructions.md`](instructions.md) for how to pick this up.

---

## Running the app

### 1. Install Flutter

This project uses [FVM](https://fvm.app) — see [`.fvmrc`](.fvmrc) for the
pinned version. With FVM installed:

```sh
fvm flutter pub get
```

Without FVM, any Flutter SDK satisfying `sdk: ^3.12.1` (see
[`pubspec.yaml`](pubspec.yaml)) will work — just drop the `fvm` prefix from
the commands below.

### 2. Get a Featherless API key

1. Go to [featherless.ai](https://featherless.ai) and sign in.
2. Create an API key in your account settings.

The key is **not** stored in the project — it's passed in at run time via
`--dart-define` so it never reaches source control.

### 3. Run

```sh
fvm flutter run -d macos --dart-define=FEATHERLESS_API_KEY=your_key_here
```

(swap `macos` for `windows`/`linux`/a connected device id as needed.)

Type a request into the box at the bottom — e.g. *"I want something hearty
but healthy, no nuts"*. Toggle the debug switch in the app bar to see the
raw A2UI JSON alongside the rendered UI.

---

## Project layout

| File                                                                     | What it's for                                                             |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| [`lib/catalog.dart`](lib/catalog.dart)                                   | Widget vocabulary + registered `ClientFunction`s.                        |
| [`lib/prompt.dart`](lib/prompt.dart)                                     | Dino's persona and behavioral rules.                                     |
| [`lib/order_state.dart`](lib/order_state.dart)                           | The order/session state machine.                                         |
| [`lib/order_functions.dart`](lib/order_functions.dart)                   | `ClientFunction`s exposing `OrderState` mutations to catalog widgets.     |
| [`lib/conversation.dart`](lib/conversation.dart)                         | `GenUiSession` — wires catalog, model client, transport, and `OrderState` together; injects state snapshots into prompts. |
| [`lib/model/model_client.dart`](lib/model/model_client.dart)             | Model-agnostic `ModelClient` interface (history + streaming contract).   |
| [`lib/model/featherless_model_client.dart`](lib/model/featherless_model_client.dart) | Featherless/Qwen implementation of `ModelClient`.       |
| [`lib/model/gemini_model_client.dart`](lib/model/gemini_model_client.dart) | Earlier Gemini-based implementation, being phased out (see `docs/plan/`). |
| [`lib/home_page.dart`](lib/home_page.dart)                               | Main screen; loads `menu.json`, builds the session, holds the restart button and debug-panel toggle. |
| [`lib/app.dart`](lib/app.dart) / [`lib/main.dart`](lib/main.dart)        | App root and entry point.                                                |
| [`assets/data/menu.json`](assets/data/menu.json)                        | The real, fixed menu — sole source of truth for dishes/prices.           |

---

## Docs

- [`instructions.md`](instructions.md) — pick up where this session left
  off: what's done, what's next, conventions to follow.
- [`docs/plan/`](docs/plan/) and [`docs/brainstorm/`](docs/brainstorm/) —
  design notes from the Featherless migration.

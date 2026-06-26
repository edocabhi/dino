---
title: Replace Gemini with Featherless model client
type: feat
date: 2026-06-24
---

## Replace Gemini with Featherless model client - Standard

## Overview

Add a `FeatherlessModelClient` that subclasses the model-agnostic `ModelClient`
([lib/model/model_client.dart](../../lib/model/model_client.dart)) and drives GenUI's A2UI
rendering from a model hosted on [featherless.ai](https://featherless.ai) instead of Gemini.
Featherless exposes an OpenAI-compatible `/v1/chat/completions` API, so the new client streams
A2UI JSON chunks out of `generateResponse()` exactly like the current Gemini client does. Nothing
downstream (`conversation.dart`, the catalog, the A2UI transport) changes its contract.

Gemini is removed entirely: [lib/model/gemini_model_client.dart](../../lib/model/gemini_model_client.dart)
and the `googleai_dart` dependency are deleted, and [home_page.dart](../../lib/home_page.dart)
instantiates `FeatherlessModelClient` instead.

Beyond the brainstorm's one-line swap, this plan also adds a **visible error surface**. The GenUI
pipeline already catches model exceptions and emits a `ConversationError` event, but `home_page.dart`
never listens to `_conversation.events`, so today every failure (bad key, cold-start, capacity) shows
a blank screen with no feedback. Featherless makes those failures routine (401, 400 cold-start, 503
capacity), so surfacing them is necessary for the demo to be usable. README run/build instructions are
updated to reference `FEATHERLESS_API_KEY` in the same PR.

Source brainstorm: [docs/brainstorm/2026-06-24-featherless-model-client-brainstorm-doc.md](../brainstorm/2026-06-24-featherless-model-client-brainstorm-doc.md)

## Problem Statement / Motivation

`ModelClient` was designed to be swapped by writing a new subclass, and the README calls this out as
the template's main extension point. The task is to demonstrate that swap by replacing Gemini with a
model hosted on Featherless. Because Featherless speaks the OpenAI protocol, we can lean on
`package:openai_dart` with a custom `baseUrl`, keeping `generateResponse()` as small as the Gemini
version and reusing its typed SSE streaming rather than hand-parsing `data:` lines. The system prompt
is still built by GenUI's `PromptBuilder.chat(catalog:, systemPromptFragments:)`, so the model receives
the same A2UI schema and behavioral instructions. Only the transport and provider differ.

## Proposed Solution

### Architecture

```
ModelClient (abstract, unchanged)
  └── FeatherlessModelClient (new)
        ├── OpenAIClient.withApiKey(apiKey, baseUrl: 'https://api.featherless.ai/v1')
        ├── _systemPrompt  = PromptBuilder.chat(catalog:, systemPromptFragments:[systemPrompt]).systemPromptJoined()
        └── generateResponse() → client.chat.completions.createStream(...) → yields event.textDelta
```

The data flow downstream is untouched:

```
HomePage.sendMessage → GenUiSession.sendMessage → Conversation.sendRequest
  → A2uiTransportAdapter.onSend → FeatherlessModelClient.sendMessage (base class)
  → generateResponse() yields raw A2UI JSON chunks → transport.addChunk → SurfaceController → Surface
```

### Key implementation decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider | Replace Gemini entirely | Matches the request; single client keeps the tree as one reference impl |
| SDK | `package:openai_dart` ^1.4.0 | Typed requests, built-in SSE streaming; keeps `generateResponse()` small |
| Base URL | `https://api.featherless.ai/v1` | Confirmed via Featherless quickstart docs; SDK appends `/chat/completions` |
| Default model | `Qwen/Qwen2.5-72B-Instruct` | Strong instruction-following / JSON reliability; confirmed valid slug |
| JSON mode | Prompt only, no `response_format` | Model-agnostic; Featherless JSON-mode support varies by model |
| API key | `String.fromEnvironment('FEATHERLESS_API_KEY')` | Same compile-time `--dart-define` pattern Gemini used |
| Constructor | `FeatherlessModelClient({required catalog, String? apiKey, String? model})` | Mirrors `GeminiModelClient` → one-line swap in `home_page.dart` |
| Error UX | Listen to `_conversation.events`, show SnackBar on `ConversationError` | Featherless 401/400/503 are routine; silent blank screen is a regression |
| Retry/backoff | Out of scope | Keeps `generateResponse()` small; cold-start/capacity surface as a visible error instead |

### Verified API surface (`openai_dart` 1.4.0)

Read directly from `~/.pub-cache/hosted/pub.dev/openai_dart-1.4.0/`. SDK constraint
`>=3.9.0 <4.0.0` is compatible with this repo's `sdk: ^3.12.1`.

```dart
// Construction — withApiKey is a factory that takes baseUrl directly.
final client = OpenAIClient.withApiKey(
  apiKey,
  baseUrl: 'https://api.featherless.ai/v1', // SDK strips trailing slash, appends /chat/completions
);

// Messages — sealed ChatMessage with static factories (NOT ChatCompletionMessage.*):
ChatMessage.system(String content)        // system prompt, prepended each turn
ChatMessage.user(Object content)          // user turn (String accepted)
ChatMessage.assistant(content: String)    // model turn (named param)

// Streaming — model is a plain String; pass the slug directly:
final stream = client.chat.completions.createStream(
  ChatCompletionCreateRequest(
    model: 'Qwen/Qwen2.5-72B-Instruct',
    messages: [...],
  ),
);
await for (final event in stream) {
  final delta = event.textDelta; // String? convenience getter = choices?.first.delta.content
  if (delta == null || delta.isEmpty) continue;
  yield delta;
}

// Disposal:
client.close(); // idempotent; closes the owned http.Client
```

### File changes

**New: [lib/model/featherless_model_client.dart](../../lib/model/featherless_model_client.dart)**

```dart
import 'package:genui/genui.dart';
import 'package:genui_template/model/model_client.dart';
import 'package:genui_template/prompt.dart';
import 'package:openai_dart/openai_dart.dart';

/// A [ModelClient] backed by a model hosted on Featherless.ai.
///
/// Featherless exposes an OpenAI-compatible API, so this client drives it with
/// [package:openai_dart] pointed at the Featherless base URL. Owns the client,
/// the running conversation history, and the A2UI system prompt derived from the
/// widget [Catalog]. Streams the raw text chunks of each model turn.
class FeatherlessModelClient extends ModelClient {
  FeatherlessModelClient({required Catalog catalog, String? apiKey, String? model})
    : _model = model ?? _defaultModel,
      _client = OpenAIClient.withApiKey(
        apiKey ?? _defaultApiKey,
        baseUrl: _baseUrl,
      ),
      _systemPrompt = PromptBuilder.chat(
        catalog: catalog,
        systemPromptFragments: [systemPrompt],
      ).systemPromptJoined();

  static const String _baseUrl = 'https://api.featherless.ai/v1';

  // HuggingFace-style org/model slug. Strong instruction-following for A2UI's
  // structured output. Override via constructor or --dart-define.
  static const String _defaultModel = 'Qwen/Qwen2.5-72B-Instruct';

  // API key supplied at build time via
  // `flutter run --dart-define=FEATHERLESS_API_KEY=...`.
  static const String _defaultApiKey =
      String.fromEnvironment('FEATHERLESS_API_KEY');

  final String _model;
  final OpenAIClient _client;
  final String _systemPrompt;

  @override
  Stream<String> generateResponse() async* {
    final stream = _client.chat.completions.createStream(
      ChatCompletionCreateRequest(
        model: _model,
        messages: [
          ChatMessage.system(_systemPrompt),
          ...history.map(_toMessage),
        ],
      ),
    );

    await for (final event in stream) {
      final delta = event.textDelta;
      if (delta == null || delta.isEmpty) continue;
      yield delta;
    }
  }

  // Maps a model-agnostic history entry to an OpenAI-compatible ChatMessage.
  ChatMessage _toMessage(ModelMessage message) => switch (message.role) {
    MessageRole.user => ChatMessage.user(message.text),
    MessageRole.model => ChatMessage.assistant(content: message.text),
  };

  @override
  void dispose() {
    latestResponse.dispose();
    _client.close();
  }
}
```

> Note: the system prompt is prepended on every turn and is NOT stored in `history`; the full
> `history` list is mapped dynamically so multi-turn conversations work (not a hardcoded
> `[system, user, assistant]` array).

**Edit: [lib/home_page.dart](../../lib/home_page.dart)**

- Swap import `gemini_model_client.dart` → `featherless_model_client.dart`; swap
  `GeminiModelClient(catalog: catalog)` → `FeatherlessModelClient(catalog: catalog)`.
- Add the error surface: subscribe to conversation events in `initState`, cancel in `dispose`,
  and show a SnackBar on `ConversationError`.

```dart
// in _HomePageState
StreamSubscription<ConversationEvent>? _eventsSub;

@override
void initState() {
  super.initState();
  final catalog = buildCatalog();
  _session = GenUiSession(
    catalog: catalog,
    modelClient: FeatherlessModelClient(catalog: catalog),
  );
  // Surface model/transport failures the GenUI pipeline would otherwise swallow.
  _eventsSub = _session.events.listen((event) {
    if (event is ConversationError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: ${event.error}')),
      );
    }
  });
}

@override
void dispose() {
  _eventsSub?.cancel();
  textController.dispose();
  _session.dispose();
  super.dispose();
}
```

**Edit: [lib/conversation.dart](../../lib/conversation.dart)** — expose the events stream from the session
so `home_page.dart` can listen without reaching into private fields:

```dart
/// A stream of conversation events (surface changes, content, errors).
Stream<ConversationEvent> get events => _conversation.events;
```

**Edit: [pubspec.yaml](../../pubspec.yaml)** — remove `googleai_dart: ^8.0.0`, add `openai_dart: ^1.4.0`.

**Delete: [lib/model/gemini_model_client.dart](../../lib/model/gemini_model_client.dart)**

**Edit: [README.md](../../README.md)** — replace Gemini references at lines 8, 25, 54, 56, 80, 83, 88, 92, 114, 134:
- `GEMINI_API_KEY` → `FEATHERLESS_API_KEY` (lines 83, 88, 92).
- "Get a Gemini API key" / "Google's Gemini model" → Featherless equivalents (lines 8, 25, 54, 56).
- File table + customization rows point to `featherless_model_client.dart` (lines 114, 134).
- Rewrite the misleading line 88 note: a missing key no longer "fails silently" — with the new
  error surface the user sees a SnackBar. Update the text to reflect the visible error.

## Technical Considerations

- **Architecture**: No layer boundaries change. `FeatherlessModelClient` lives in the same `lib/model/`
  layer as the old client and implements the same `generateResponse()` / `dispose()` contract. The
  error-surface change is presentation-only (`home_page.dart` + one passthrough getter on the session).
- **Streaming correctness**: `event.textDelta` is `String?` and is null on role-only and finish events;
  the `if (delta == null || delta.isEmpty) continue;` guard mirrors the Gemini client's null/empty skip.
- **Truncated turns**: a stream finishing with `finish_reason: length` yields partial (invalid) A2UI JSON
  that the base class records into `history`, poisoning the next turn. Out of scope for this PR (Gemini
  has the same exposure); noted as a risk. If it bites in practice, set a generous `maxTokens` and/or
  discard non-`stop` turns in a follow-up.
- **Security**: API key stays a compile-time constant via `--dart-define`, never committed. The
  SnackBar prints `event.error.toString()`; Featherless error bodies are OpenAI-shaped messages and do
  not echo the key, so this is safe to display.
- **Performance**: Single streamed request per turn; no added overhead vs. Gemini.
- **Concurrency**: `MessageInput` already disables send while `isProcessing`
  ([message_input.dart:29,34,39](../../lib/widgets/message_input.dart#L29)), so concurrent requests
  racing `history` mutation are already prevented. No change needed.

## Acceptance Criteria

- [ ] `lib/model/featherless_model_client.dart` exists, subclasses `ModelClient`, and implements
      `generateResponse()` and `dispose()`.
- [ ] `FeatherlessModelClient` constructor signature is `({required Catalog catalog, String? apiKey, String? model})`.
- [ ] Default model is `Qwen/Qwen2.5-72B-Instruct`; default base URL is `https://api.featherless.ai/v1`.
- [ ] API key is read from `String.fromEnvironment('FEATHERLESS_API_KEY')` and overridable via constructor.
- [ ] `generateResponse()` maps the full `history` dynamically (`user`→`.user`, `model`→`.assistant`)
      with the system prompt prepended each turn, and skips null/empty `textDelta` chunks.
- [ ] `lib/model/gemini_model_client.dart` is deleted and `googleai_dart` is removed from `pubspec.yaml`.
- [ ] `openai_dart: ^1.4.0` is added to `pubspec.yaml` and `flutter pub get` resolves.
- [ ] `home_page.dart` instantiates `FeatherlessModelClient` and shows a SnackBar on `ConversationError`,
      with the events subscription cancelled in `dispose()`.
- [ ] `GenUiSession` exposes a `Stream<ConversationEvent> get events` getter.
- [ ] README run/build instructions reference `FEATHERLESS_API_KEY`; no `GEMINI_API_KEY`/`googleai_dart`
      references remain (`grep -ri "gemini\|googleai" lib/ README.md pubspec.yaml` is empty).
- [ ] `flutter analyze` passes with `very_good_analysis`.
- [ ] **Tests** (new `test/` directory):
  - [ ] `test/model/featherless_model_client_test.dart`: constructor wiring (default vs. override model),
        history role mapping (`user`→`.user`, `model`→`.assistant`), system prompt prepended, null/empty
        `textDelta` chunks skipped, non-empty chunks yielded in order, `dispose()` closes the client and
        disposes `latestResponse`. Mock the `OpenAIClient` (or its `chat.completions`) with `mocktail`.
  - [ ] `test/widgets/home_page_test.dart`: a `ConversationError` event drives a visible SnackBar;
        normal flow renders a surface. Use a fake/mock `ModelClient` so no network is hit.
  - [ ] App builds and runs against Featherless with a valid `FEATHERLESS_API_KEY` (manual smoke test).

## Success Metrics

- One-line provider swap in `home_page.dart` (proves the `ModelClient` extension point works).
- `generateResponse()` stays comparable in size to the Gemini implementation (~15 lines of stream logic).
- A user with a bad/missing key or a cold model sees an explanatory SnackBar instead of a blank screen.
- Zero remaining Gemini references in code, deps, or docs.

## Dependencies & Risks

- **`openai_dart` 1.4.0 API**: Verified against the local pub cache source — `OpenAIClient.withApiKey`,
  `client.chat.completions.createStream`, `ChatMessage.system/.user/.assistant`,
  `ChatCompletionCreateRequest`, `event.textDelta`, `client.close()`. This is the davidmigloz package
  (now in the `ai_clients_dart` monorepo); its API differs from older `langchain_dart`-era examples, so
  follow the snippets in this plan, not older `ChatCompletionModel.modelId(...)` / `endSession()` patterns.
- **Model slug / license**: `Qwen/Qwen2.5-72B-Instruct` is confirmed valid. Some Featherless models
  return 403 until unlocked on their model page; Qwen2.5 does not require this, but the error surface
  will make any 403 legible.
- **Cold start (400) / capacity (503)**: routine on Featherless. No retry in this PR — they surface as a
  SnackBar. A retry-with-backoff for 503 and a "model warming up" message for 400 are a possible follow-up.
- **Truncated A2UI on `finish_reason: length`**: pre-existing exposure (Gemini too); not addressed here.
- **No existing test infra**: `test/` is created from scratch; add `mocktail` to `dev_dependencies` if
  not already transitively available.

## References & Research

- Base class to subclass: [lib/model/model_client.dart](../../lib/model/model_client.dart) (empty-stream
  guard at [model_client.dart:55](../../lib/model/model_client.dart#L55))
- Pattern to mirror: [lib/model/gemini_model_client.dart](../../lib/model/gemini_model_client.dart)
  (role mapping at [lines 58-61](../../lib/model/gemini_model_client.dart#L58-L61), dispose at
  [63-67](../../lib/model/gemini_model_client.dart#L63-L67))
- Session wiring: [lib/conversation.dart](../../lib/conversation.dart) (transport `onSend` at
  [lines 27-33](../../lib/conversation.dart#L27))
- Error event (caught, currently unsurfaced): `genui-0.9.2/lib/src/facade/conversation.dart` —
  `Stream<ConversationEvent> get events` (line 178), `ConversationError(error, stackTrace)` (lines 65-72),
  emission in `sendRequest` (line 190)
- Send-while-processing guard: [lib/widgets/message_input.dart:29](../../lib/widgets/message_input.dart#L29)
- `openai_dart` 1.4.0 source: `~/.pub-cache/hosted/pub.dev/openai_dart-1.4.0/lib/src/` — `client/openai_client.dart`
  (`withApiKey:161`), `resources/chat_resource.dart` (`createStream`), `models/chat/chat_message.dart`
  (`system:46`, `user:59`, `assistant:74`), `models/streaming/chat_stream_event.dart` (`textDelta:108`)
- Featherless docs: [Quickstart](https://featherless.ai/docs/quickstart-guide),
  [Completions](https://featherless.ai/docs/completions),
  [Error codes](https://featherless.ai/docs/api-reference-error-codes),
  [Qwen2.5-72B-Instruct](https://featherless.ai/models/Qwen/Qwen2.5-72B-Instruct)
</content>
</invoke>

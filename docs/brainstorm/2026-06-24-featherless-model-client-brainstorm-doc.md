---
date: 2026-06-24
topic: featherless-model-client
---

# Featherless.ai Model Client

## What We're Building

A `FeatherlessModelClient` that subclasses the existing model-agnostic `ModelClient`
([lib/model/model_client.dart](../../lib/model/model_client.dart)) and drives GenUI's
A2UI rendering from a model hosted on [featherless.ai](https://featherless.ai) instead of
Gemini. Featherless exposes an OpenAI-compatible `/v1/chat/completions` API, so the new
client streams A2UI JSON chunks out of `generateResponse()` exactly like the current Gemini
client does — nothing downstream (`conversation.dart`, `home_page.dart`, the catalog, or the
A2UI transport) changes its contract.

This replaces Gemini entirely: `gemini_model_client.dart` and the `googleai_dart` dependency
are removed, and `home_page.dart` instantiates `FeatherlessModelClient` instead.

## Why This Approach

`ModelClient` was designed to be swapped by writing a new subclass, and the README explicitly
calls this out. Featherless speaking the OpenAI protocol means we can lean on `package:openai_dart`
with a custom `baseUrl`, keeping `generateResponse()` as small as the Gemini version and reusing
its typed SSE streaming rather than hand-parsing `data:` lines. The system prompt is still built by
GenUI's `PromptBuilder.chat(catalog:, systemPromptFragments:)`, so the model receives the same A2UI
schema and behavioral instructions — only the transport and provider differ.

Alternatives considered: keeping Gemini alongside Featherless (rejected — request was to use
Featherless instead of Gemini, and a single client keeps the tree simple); raw `package:http` + manual
SSE parsing (rejected — more parsing code to write and test for no benefit when an OpenAI-compatible
SDK exists); forcing `response_format: json_object` (rejected — support varies by model on Featherless
and the PromptBuilder instructions already drive the format, matching how Gemini works today).

## Key Decisions

- **Replace Gemini entirely**: Remove `lib/model/gemini_model_client.dart` and the `googleai_dart`
  dependency from `pubspec.yaml`. Featherless is the only client. Rationale: matches the request and
  keeps a single reference implementation.
- **`openai_dart` with custom `baseUrl`**: Add `package:openai_dart`, construct `OpenAIClient` with
  `baseUrl: 'https://api.featherless.ai/v1'` and the API key. Rationale: typed requests, built-in SSE
  streaming, and `generateResponse()` stays as small as the Gemini implementation.
- **Default model `Qwen/Qwen2.5-72B-Instruct`**: Strong instruction-following and JSON reliability among
  open models, well-suited to A2UI's structured output. Overridable via constructor / `--dart-define`.
- **JSON via prompt only**: No `response_format` — rely on `PromptBuilder` instructions exactly as the
  Gemini client does. Rationale: model-agnostic, avoids per-model `response_format` support gaps, keeps
  parity with current behavior.
- **API key via `String.fromEnvironment('FEATHERLESS_API_KEY')`**: Same compile-time `--dart-define`
  pattern the Gemini client used for `GEMINI_API_KEY`. Rationale: consistency, no new config mechanism.
- **Constructor signature parity**: `FeatherlessModelClient({required catalog, String? apiKey, String? model})`
  mirroring `GeminiModelClient`, so wiring in `home_page.dart` is a one-line swap.

## Open Questions

- Confirm the exact Featherless base URL and that `openai_dart`'s `OpenAIClient` accepts a custom `baseUrl`
  (verify against the package version chosen during planning).
- Confirm `Qwen/Qwen2.5-72B-Instruct` is the correct Featherless model identifier string (slug format).
- README updates: the build/run instructions reference `GEMINI_API_KEY`; these need to point to
  `FEATHERLESS_API_KEY`. Decide whether that doc change is in scope for this PR or a follow-up.
- Error handling for auth/rate-limit failures from Featherless — keep current pass-through behavior or add
  a friendlier surface? Defer to planning.

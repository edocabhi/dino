import 'dart:convert';

import 'package:dino/catalog.dart';
import 'package:dino/catalog_activity.dart';
import 'package:dino/model/model_client.dart';
import 'package:dino/order_state.dart';
import 'package:dino/prompt.dart';
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

/// Owns the GenUI pipeline for a single screen and disposes it as a unit.
///
/// The pipeline pieces — the [SurfaceController], the A2UI transport, the
/// [Conversation] that combines them, and the [ModelClient] — have independent
/// lifecycles, and [Conversation.dispose] does not cascade to the controller
/// or transport. This holder keeps them together so the UI can construct and
/// tear everything down with a single call, instead of tracking four disposable
/// objects itself.
///
/// It deliberately stays thin: surface tracking and waiting state are read
/// straight from [Conversation]'s [Conversation.state], not re-implemented
/// here. The session takes ownership of [modelClient] and disposes it too.
class GenUiSession {
  GenUiSession({
    required ModelClient Function({required String systemPrompt})
    modelClientBuilder,
    String? additionalPromptContext,
  }) {
    /// Tracks session/order status as the user interacts with widgets. Its
    /// mutation methods are exposed to the catalog as ClientFunctions below.
    _orderState = OrderState();
    // Expose the per-session state to catalog item widgets that need to
    // read or mutate it directly (e.g. CartView's optimistic +/- updates).
    CatalogActivity.currentOrderState = _orderState;

    /// The catalog defines the surfaces the model can render and how to
    /// render them.
    final catalog = buildCatalog(_orderState);

    // The controller renders surfaces from the catalog and tracks which ones
    // currently exist.
    _controller = SurfaceController(catalogs: [catalog]);

    /// Combining the system prompt (which teaches the model how to produce
    /// valid A2UI JSON) with the catalog and the user defined system prompt
    /// (which guides the overall interaction) into a single system prompt for
    /// the LLM
    final combinedPrompt = PromptBuilder.chat(
      catalog: catalog,
      systemPromptFragments: [
        systemPrompt,
        ?additionalPromptContext,
      ],
    ).systemPromptJoined();

    _modelClient = modelClientBuilder(systemPrompt: combinedPrompt);
    // The transport is the bridge between the model and GenUI. When the
    // conversation has a message to send, `onSend` forwards it to the model and
    // feeds each streamed text chunk back via `addChunk`. The transport parses
    // those chunks as A2UI and the controller turns them into live surfaces, so
    // the UI updates as the JSON streams in.
    _transport = A2uiTransportAdapter(
      onSend: (message) async {
        await _modelClient
            .sendMessage(_promptWithOrderState(message))
            .forEach(_transport.addChunk);
      },
    );
    // The conversation ties the controller and transport together and exposes
    // the combined state (active surfaces, waiting status) the UI listens to.
    _conversation = Conversation(
      controller: _controller,
      transport: _transport,
    );
  }

  late final SurfaceController _controller;
  late final ModelClient _modelClient;
  late final A2uiTransportAdapter _transport;
  late final Conversation _conversation;
  late final OrderState _orderState;

  /// The raw A2UI JSON of the current (or most recent) model turn, updated live
  /// as the response streams in.
  ValueListenable<String> get a2uiSource => _modelClient.latestResponse;

  /// The current state of the conversation, including active surfaces and
  /// waiting status.
  ValueListenable<ConversationState> get conversationState =>
      _conversation.state;

  /// A stream of conversation events (surface changes, content, errors).
  Stream<ConversationEvent> get events => _conversation.events;

  /// Sends a user message to the model and starts the conversation.
  void sendMessage(String text) =>
      _conversation.sendRequest(ChatMessage.user(text));

  /// Builds the text turn sent to the model from a conversation message.
  ///
  /// Typed messages carry their content as text. Messages from surface
  /// interactions (e.g. a button tap) instead carry their payload as a
  /// [UiInteractionPart] whose JSON describes the action, and have no text.
  /// Forwarding only [ChatMessage.text] would send the model an empty turn,
  /// so it loses all context for the interaction and replies with plain text
  /// instead of new A2UI. Falling back to the interaction JSON keeps the model
  /// aware of what the user did.
  static String _promptFor(ChatMessage message) {
    if (message.text.trim().isNotEmpty) return message.text;
    return message.parts.uiInteractionParts
        .map((part) => part.interaction)
        .join('\n');
  }

  /// Appends the current order/session state to [message]'s prompt text, but
  /// only if it changed since the last turn.
  ///
  /// Widget-driven state mutations (e.g. a "remove item" button) happen
  /// locally via ClientFunctions and never reach the model directly. This is
  /// how the model finds out: each outgoing turn carries a fresh snapshot
  /// when [OrderState.isDirty], so the model's next response reflects what
  /// changed without needing every interaction to round-trip through it.
  String _promptWithOrderState(ChatMessage message) {
    final prompt = _promptFor(message);

    // The model dispatches `returnToMenu` via a generic Button on the
    // confirmation surface (it can't both functionCall and event in one
    // tap). Intercept it here so the order is cleared before we snapshot
    // — that way the model sees a freshly-cleared state in the same turn
    // it's asked to re-render the CategoryPicker, and a new order can
    // start cleanly.
    if (prompt.contains('"name":"returnToMenu"')) {
      _orderState.startNewOrder();
    }

    final snapshot = _orderState.takeSnapshotIfDirty();
    if (snapshot == null) return prompt;
    return '$prompt\n\n[Current order/session state: ${jsonEncode(snapshot)}]';
  }

  /// Looks up the render context for a surface by its id.
  ///
  /// Pass the result to a [Surface] widget to render that surface. Surface ids
  /// come from [ConversationState.surfaces].
  SurfaceContext contextFor(String surfaceId) =>
      _conversation.controller.contextFor(surfaceId);

  /// Disposes the whole pipeline. Cancels conversation subscriptions, closes
  /// the transport and controller, and releases the model client's resources.
  void dispose() {
    if (identical(CatalogActivity.currentOrderState, _orderState)) {
      CatalogActivity.currentOrderState = null;
    }
    _conversation.dispose();
    _transport.dispose();
    _controller.dispose();
    _modelClient.dispose();
    _orderState.dispose();
  }
}

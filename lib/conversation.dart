import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/catalog.dart';
import 'package:genui_template/model/model_client.dart';
import 'package:genui_template/prompt.dart';

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
  }) {
    /// The catalog defines the surfaces the model can render and how to
    /// render them.
    final catalog = buildCatalog();

    // The controller renders surfaces from the catalog and tracks which ones
    // currently exist.
    _controller = SurfaceController(catalogs: [catalog]);

    /// Combining the system prompt (which teaches the model how to produce
    /// valid A2UI JSON) with the catalog and the user defined system prompt
    /// (which guides the overall interaction) into a single system prompt for
    /// the LLM
    final combinedPrompt = PromptBuilder.chat(
      catalog: catalog,
      systemPromptFragments: [systemPrompt],
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
            .sendMessage(_promptFor(message))
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

  /// Looks up the render context for a surface by its id.
  ///
  /// Pass the result to a [Surface] widget to render that surface. Surface ids
  /// come from [ConversationState.surfaces].
  SurfaceContext contextFor(String surfaceId) =>
      _conversation.controller.contextFor(surfaceId);

  /// Disposes the whole pipeline. Cancels conversation subscriptions, closes
  /// the transport and controller, and releases the model client's resources.
  void dispose() {
    _conversation.dispose();
    _transport.dispose();
    _controller.dispose();
    _modelClient.dispose();
  }
}

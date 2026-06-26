import 'package:flutter/foundation.dart';

/// The author of a single conversation turn.
enum MessageRole { user, model }

/// One turn of conversation history, independent of any model SDK.
class ModelMessage {
  const ModelMessage.user(this.text) : role = MessageRole.user;
  const ModelMessage.model(this.text) : role = MessageRole.model;

  final MessageRole role;
  final String text;
}

/// Talks to a generative model and streams its responses.
///
/// This base class owns the bookkeeping shared by every implementation: it
/// records each conversation turn in [history] and drives [latestResponse] as a
/// response streams in. Subclasses only implement [generateResponse], which
/// knows how to call a specific model SDK and stream back its raw text chunks.
abstract class ModelClient {
  ModelClient({required this.systemPrompt});

  /// The running conversation history sent to the model on each turn.
  final List<ModelMessage> history = [];

  /// The original system prompt for guiding the interaction and teaching the
  /// model how to produce valid A2UI JSON.
  final String systemPrompt;

  /// The raw text of the most recent (or in-progress) model turn.
  ///
  /// For GenUI this is the raw A2UI JSON the model produced to drive the
  /// rendering. It updates live as the response streams in, so the UI can
  /// display the source alongside the rendered surface.
  final ValueNotifier<String> latestResponse = ValueNotifier('');

  /// Sends [text] as the user's turn and streams the model's response chunks.
  ///
  /// Records the user turn before calling the model and the model turn once the
  /// stream completes, so the full conversation context is sent on every turn
  /// and later requests create new surfaces instead of colliding with existing
  /// ones. Subclasses don't touch [history] or [latestResponse]; they only
  /// produce chunks in [generateResponse].
  Stream<String> sendMessage(String text) async* {
    // Record the user's turn so the model has the full conversation context.
    history.add(ModelMessage.user(text));

    // Clear the previous turn's source so the panel reflects this turn only.
    latestResponse.value = '';

    final responseBuffer = StringBuffer();
    await for (final chunk in generateResponse()) {
      responseBuffer.write(chunk);
      // Expose the raw A2UI JSON live so the UI can render it as it streams.
      latestResponse.value = responseBuffer.toString();
      yield chunk;
    }

    // Persist the model turn so later requests know which surfaces exist.
    if (responseBuffer.isNotEmpty) {
      history.add(ModelMessage.model(responseBuffer.toString()));
    }
  }

  /// Streams the raw text chunks of the model's response to the current
  /// [history].
  ///
  /// Implementations send [history] to their model SDK and yield each chunk as
  /// it arrives. History and [latestResponse] are managed by [sendMessage], so
  /// implementations should not modify them.
  @protected
  Stream<String> generateResponse();

  /// Releases any resources held by the client.
  void dispose();
}

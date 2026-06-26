import 'package:genui/genui.dart';
import 'package:genui_template/model/model_client.dart';
import 'package:googleai_dart/googleai_dart.dart';

/// A [ModelClient] backed by Google's Gemini models.
///
/// Owns the Gemini client, the running conversation history, and the A2UI
/// system prompt derived from the widget [Catalog]. Streams the raw text
/// chunks of each model turn so the caller can feed them to its transport.
class GeminiModelClient extends ModelClient {
  GeminiModelClient({
    required super.systemPrompt,
    String? apiKey,
    String? model,
  }) : _model = model ?? _defaultModel,
       _client = GoogleAIClient.withApiKey(apiKey ?? _defaultApiKey);

  // The Gemini model to drive the conversation.
  static const String _defaultModel = 'gemini-3.5-flash';

  // API key supplied at build time via
  // `flutter run --dart-define=GEMINI_API_KEY=...`.
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY');

  final String _model;
  final GoogleAIClient _client;

  /// Streams the Gemini response to the current conversation [history].
  ///
  /// The full history is sent on every turn. Yields each non-empty text chunk
  /// (the raw A2UI JSON) as it arrives; recording the turn and updating
  /// `latestResponse` is handled by the base class.
  @override
  Stream<String> generateResponse() async* {
    final stream = _client.models.streamGenerateContent(
      model: _model,
      request: GenerateContentRequest(
        systemInstruction: Content.text(systemPrompt),
        contents: history.map(_toContent).toList(),
      ),
    );

    await for (final chunk in stream) {
      final chunkText = chunk.text;
      if (chunkText == null || chunkText.isEmpty) continue;
      yield chunkText;
    }
  }

  // Maps a model-agnostic history entry to Gemini's [Content] representation.
  Content _toContent(ModelMessage message) => switch (message.role) {
    MessageRole.user => Content.text(message.text),
    MessageRole.model => Content.fromParts([message.text], role: 'model'),
  };

  @override
  void dispose() {
    latestResponse.dispose();
    _client.close();
  }
}

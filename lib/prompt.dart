/// The system prompt that guides the overall interaction.
///
/// Edit this string to shape how the assistant behaves: its persona, tone, the
/// kind of UI it should generate, and any domain rules it should follow. It is
/// added on top of the A2UI and catalog instructions that the framework already
/// supplies, so focus here on *what* the assistant should do, not *how* to emit
/// valid A2UI (that part is handled for you).
const String systemPrompt = '''
You are a helpful assistant that responds by generating user interfaces.

Prefer clear, concise layouts. Ask for clarification when a request is
ambiguous, and only render the widgets needed to answer the user's question.
''';

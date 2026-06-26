import 'dart:async';

import 'package:dino/conversation.dart';
import 'package:dino/model/featherless_model_client.dart';
import 'package:dino/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:genui/genui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GenUiSession? _session;
  final _textController = TextEditingController();
  StreamSubscription<ConversationEvent>? _eventsSub;
  bool _shouldShowDebugPanel = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initSession());
  }

  Future<void> _initSession() async {
    // Load the menu data dynamically at runtime
    final menuJson = await rootBundle.loadString('assets/data/menu.json');
    final additionalContext =
        'Here is the menu data for the restaurant "Dino" that you have available to recommend:\n$menuJson';

    if (!mounted) return;

    // The session owns the whole GenUI pipeline (model client, controller,
    // transport, and conversation) and disposes it as a unit.
    _session = GenUiSession(
      modelClientBuilder: FeatherlessModelClient.new,
      additionalPromptContext: additionalContext,
    );

    // Surface model/transport failures the GenUI pipeline would otherwise
    // swallow. Featherless 401/400/503 errors are routine during development.
    _eventsSub = _session!.events.listen((event) {
      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${event.error}')),
        );
      }
    });

    setState(() {});
  }

  @override
  void dispose() {
    unawaited(_eventsSub?.cancel());
    _textController.dispose();
    _session?.dispose();
    super.dispose();
  }

  // Tears down the current session (discarding any in-flight request along
  // with it) and starts a fresh one, resetting both the conversation and the
  // order/session state machine it owns.
  void _resetSession() {
    unawaited(_eventsSub?.cancel());
    _session?.dispose();
    setState(() {
      _session = null;
    });
    unawaited(_initSession());
  }

  // Send a message containing the user's text to the model. Blank input is
  // ignored.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _session?.sendMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: Tooltip(
          message: 'Restart order',
          child: IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: _session == null ? null : _resetSession,
          ),
        ),
        title: const Text('Dino : Yabba Dabba Dish!'),
        actions: [
          Tooltip(
            message: _shouldShowDebugPanel
                ? 'Hide debug panel'
                : 'Show debug panel',
            child: Switch(
              value: _shouldShowDebugPanel,
              onChanged: (value) {
                setState(() {
                  _shouldShowDebugPanel = value;
                });
              },
            ),
          ),
        ],
      ),
      body: _session == null
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<ConversationState>(
              valueListenable: _session!.conversationState,
              builder: (context, state, _) {
                final isProcessing = state.isWaiting;
                // A "surface" is one generated UI the model produced. The model can
                // create several over a conversation; this demo renders only the
                // most recent one. `state.surfaces` is the list of their ids, in
                // creation order, so the last is the latest.
                final latestSurfaceId = state.surfaces.isNotEmpty
                    ? state.surfaces.last
                    : null;

                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: .stretch,
                        children: [
                          // The rendered GenUI surface (latest only). `Surface` is
                          // the widget that turns the model's A2UI into real widgets;
                          // it just needs the render context for the surface to show.
                          Expanded(
                            child: latestSurfaceId == null || isProcessing
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: ListView(
                                      children: [
                                        Surface(
                                          surfaceContext: _session!.contextFor(
                                            latestSurfaceId,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          if (_shouldShowDebugPanel) ...[
                            const VerticalDivider(width: 1),
                            // The raw A2UI JSON the model produced for this surface.
                            Expanded(
                              child: isProcessing
                                  ? const SizedBox.shrink()
                                  : A2uiSourceView(
                                      source: _session!.a2uiSource,
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Show a thinking indicator while the model streams its response.
                    if (isProcessing)
                      const LinearProgressIndicator(minHeight: 2),
                    MessageInput(
                      controller: _textController,
                      isProcessing: isProcessing,
                      onSend: sendMessage,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

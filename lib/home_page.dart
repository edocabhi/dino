import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/model/featherless_model_client.dart';
import 'package:genui_template/widgets/widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final GenUiSession _session;
  final _textController = TextEditingController();
  StreamSubscription<ConversationEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();

    // The session owns the whole GenUI pipeline (model client, controller,
    // transport, and conversation) and disposes it as a unit.
    _session = GenUiSession(modelClientBuilder: FeatherlessModelClient.new);

    // Surface model/transport failures the GenUI pipeline would otherwise
    // swallow. Featherless 401/400/503 errors are routine during development.
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
    unawaited(_eventsSub?.cancel());
    _textController.dispose();
    _session.dispose();
    super.dispose();
  }

  // Send a message containing the user's text to the model. Blank input is
  // ignored.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _session.sendMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('GenUI'),
      ),
      body: ValueListenableBuilder<ConversationState>(
        valueListenable: _session.conversationState,
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
                              child: Surface(
                                surfaceContext: _session.contextFor(
                                  latestSurfaceId,
                                ),
                              ),
                            ),
                    ),
                    const VerticalDivider(width: 1),
                    // The raw A2UI JSON the model produced for this surface.
                    Expanded(
                      child: isProcessing
                          ? const SizedBox.shrink()
                          : A2uiSourceView(source: _session.a2uiSource),
                    ),
                  ],
                ),
              ),
              // Show a thinking indicator while the model streams its response.
              if (isProcessing) const LinearProgressIndicator(minHeight: 2),
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

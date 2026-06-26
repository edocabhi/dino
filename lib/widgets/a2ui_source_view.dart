import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A read-only panel showing the raw A2UI JSON the model produced for the
/// current surface. Updates live as the response streams in.
class A2uiSourceView extends StatelessWidget {
  const A2uiSourceView({required this.source, super.key});

  final ValueListenable<String> source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('A2UI source', style: theme.textTheme.titleSmall),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: source,
              builder: (context, source, _) {
                if (source.isEmpty) {
                  return Center(
                    child: Text(
                      'Send a message to see the generated A2UI JSON.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    source,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

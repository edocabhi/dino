import 'package:flutter/material.dart';

/// The message composer: a text field and send button.
///
/// While [isProcessing], input is disabled and the button shows a spinner.
/// Submitting via the keyboard or the button calls [onSend] with the text.
class MessageInput extends StatelessWidget {
  const MessageInput({
    required this.controller,
    required this.isProcessing,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isProcessing,
                decoration: const InputDecoration(
                  hintText: 'Enter a message',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: isProcessing ? null : onSend,
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: isProcessing ? null : () => onSend(controller.text),
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class EventLog extends StatelessWidget {
  const EventLog({
    required this.entries,
    required this.onClear,
    super.key,
  });

  final List<String> entries;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Event Log',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton.icon(
              onPressed: entries.isEmpty ? null : onClear,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text(
                    'No events yet.\nInteract with the topology to see callbacks.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 8),
                      child: SelectableText(
                        entry,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

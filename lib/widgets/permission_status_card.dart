import 'package:flutter/material.dart';

class PermissionStatusCard extends StatelessWidget {
  final String title;
  final String description;
  final bool granted;
  final String actionLabel;
  final VoidCallback onAction;

  const PermissionStatusCard({
    super.key,
    required this.title,
    required this.description,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = granted ? Colors.green : Theme.of(context).colorScheme.error;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(granted ? Icons.check_circle : Icons.error_outline, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description, style: Theme.of(context).textTheme.bodySmall),
                  if (!granted) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

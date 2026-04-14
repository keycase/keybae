import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Display a long base64 public key truncated with a copy affordance.
class TruncatedKey extends StatelessWidget {
  final String value;
  final String label;

  const TruncatedKey({
    super.key,
    required this.value,
    this.label = 'Public key',
  });

  String get _truncated {
    if (value.length <= 24) return value;
    return '${value.substring(0, 10)}…${value.substring(value.length - 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label copied to clipboard')),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _truncated,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy, size: 16, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

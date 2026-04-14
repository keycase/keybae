import 'package:flutter/material.dart';
import 'package:keycase_core/keycase_core.dart';

class ProofStatusChip extends StatelessWidget {
  final ProofStatus status;
  const ProofStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      ProofStatus.verified => ('Verified', Colors.green, Icons.check_circle),
      ProofStatus.pending => ('Pending', Colors.amber.shade700, Icons.schedule),
      ProofStatus.failed => ('Failed', Colors.red, Icons.error_outline),
      ProofStatus.revoked => ('Revoked', Colors.red, Icons.block),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

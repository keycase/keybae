import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase_core/keycase_core.dart';
import 'package:keybae/widgets/proof_status_chip.dart';

void main() {
  testWidgets('ProofStatusChip renders each status', (tester) async {
    for (final status in ProofStatus.values) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ProofStatusChip(status: status))),
      );
      expect(find.byType(Chip), findsOneWidget);
    }
  });
}

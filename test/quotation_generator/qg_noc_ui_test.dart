// test/quotation_generator/qg_noc_ui_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/ui/screens/noc_builder_screen.dart';
import 'package:salesapp/features/quotation_generator/ui/screens/noc_hub_screen.dart';

void main() {
  group('Milestone N4: NOC UI Integration Tests', () {
    testWidgets('NocHubScreen renders app bar, search bar, and Generate NOC action', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NocHubScreen(),
          ),
        ),
      );

      // Verify app bar title
      expect(find.text('Installation & Commissioning NOC Hub'), findsOneWidget);

      // Verify search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Statuses'), findsOneWidget);

      // Verify Generate NOC button
      expect(find.text('Generate NOC'), findsOneWidget);
    });

    testWidgets('NocBuilderScreen renders profile selection, customer info, and actions', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NocBuilderScreen(),
          ),
        ),
      );

      // Let initial microtasks settle
      await tester.pump();

      // Verify title & buttons
      expect(find.text('Generate New NOC'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Finalize & Issue NOC'), findsOneWidget);

      // Verify section titles
      expect(find.text('Certificate Date'), findsOneWidget);
      expect(find.text('Customer & Site Information'), findsOneWidget);
      expect(find.text('Equipment & Scope Details'), findsOneWidget);
      expect(find.text('Confirmations & Terms'), findsOneWidget);
    });
  });
}

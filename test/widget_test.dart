import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Quotation app basic widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('IZYHEAT SALES APP'),
          ),
        ),
      ),
    );

    expect(find.text('IZYHEAT SALES APP'), findsOneWidget);
  });
}

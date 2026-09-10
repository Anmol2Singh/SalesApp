import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salesapp/features/auth/screens/splash_screen.dart';
import 'package:salesapp/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('Splash Screen Renders Correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    expect(find.text('IZYHEAT'), findsOneWidget);
    expect(find.text('SALES MANAGEMENT'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

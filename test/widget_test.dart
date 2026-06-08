import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avto_test_mobil/screens/landing_screen.dart';

void main() {
  testWidgets('shows landing screen text', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LandingScreen(onLogin: _noop, onRegister: _noop),
      ),
    );

    expect(find.text('Testlarga kirish'), findsOneWidget);
    expect(find.text('Mavzu bo‘yicha testlar'), findsOneWidget);
    expect(find.text('Video darsliklar'), findsOneWidget);
    expect(
      find.text('Haydovchilikka\ntayyormisiz?'),
      findsOneWidget,
    );
  });
}

void _noop() {}

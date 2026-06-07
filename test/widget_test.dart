import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avto_test_mobil/main.dart';

void main() {
  testWidgets('shows landing screen text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LandingScreen(onLogin: _noop, onRegister: _noop),
      ),
    );

    expect(find.text('Road Test Mobil Ilova'), findsWidgets);
    expect(find.text('Kirish'), findsOneWidget);
    expect(find.text("Ro'yxatdan o'tish"), findsOneWidget);
  });
}

void _noop() {}

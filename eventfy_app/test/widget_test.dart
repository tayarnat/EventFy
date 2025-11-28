// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eventfy_app/screens/company/create_event_screen.dart';

void main() {
  testWidgets('Smoke: CreateEventScreen renders basic form', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CreateEventScreen(
            showMapPreview: false,
            skipInitialLoad: true,
          ),
        ),
      ),
    );
    expect(find.text('Título do Evento'), findsOneWidget);
    expect(find.text('Endereço'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });
}

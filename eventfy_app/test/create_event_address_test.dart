import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventfy_app/screens/company/create_event_screen.dart';

void main() {
  testWidgets('Busca de endereço atualiza localização selecionada', (WidgetTester tester) async {
    Future<Map<String, double>?> fakeGeocode(String address) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return {'lat': -23.561, 'lng': -46.655};
    }

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          geocodeFn: fakeGeocode,
          showMapPreview: false,
          skipInitialLoad: true,
        ),
      ),
    );

    final enderecoField = find.widgetWithText(TextFormField, 'Endereço');
    expect(enderecoField, findsOneWidget);

    await tester.enterText(enderecoField, 'Av. Paulista, São Paulo');
    await tester.pump();

    final buscarButton = find.byTooltip('Buscar endereço');
    expect(buscarButton, findsOneWidget);

    await tester.ensureVisible(buscarButton);
    await tester.tap(buscarButton);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Lat: -23.561'), findsOneWidget);
  });

  testWidgets('Endereço inválido mostra mensagem de erro', (WidgetTester tester) async {
    Future<Map<String, double>?> fakeGeocode(String address) async {
      await Future.delayed(const Duration(milliseconds: 50));
      return null; // simulando endereço não encontrado
    }

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          geocodeFn: fakeGeocode,
          showMapPreview: false,
          skipInitialLoad: true,
        ),
      ),
    );

    final enderecoField2 = find.widgetWithText(TextFormField, 'Endereço');
    await tester.enterText(enderecoField2, 'Endereco inexistente');
    await tester.pump();

    final buscar = find.byTooltip('Buscar endereço');
    await tester.ensureVisible(buscar);
    await tester.tap(buscar);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Endereço não encontrado'), findsOneWidget);
    expect(find.text('Selecionar no mapa'), findsOneWidget);
  });
}

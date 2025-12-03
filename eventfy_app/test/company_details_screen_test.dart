import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:eventfy_app/screens/company/company_details_screen.dart';
import 'package:eventfy_app/providers/favorites_provider.dart';
import 'package:eventfy_app/models/company_model.dart';
import 'package:eventfy_app/models/event_model.dart';

class FakeFavoritesProvider extends FavoritesProvider {
  final CompanyDetailsInfo info;
  FakeFavoritesProvider(this.info);

  @override
  Future<CompanyDetailsInfo> fetchCompanyDetailsInfo(String companyId) async {
    return info;
  }

  @override
  Future<bool> isCompanyFavorited(String companyId) async {
    return false;
  }
}

EventModel makeEvent({
  required String id,
  required double? averageRating,
  required int totalReviews,
}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    companyId: 'c1',
    titulo: 'Evento $id',
    descricao: null,
    endereco: 'Rua Teste',
    latitude: 0,
    longitude: 0,
    dataInicio: now.subtract(const Duration(days: 10)),
    dataFim: now.subtract(const Duration(days: 9)),
    valor: null,
    isGratuito: true,
    capacidade: null,
    capacidadeAtual: 0,
    idadeMinima: 0,
    fotoPrincipalUrl: null,
    linkExterno: null,
    linkStreaming: null,
    status: 'finalizado',
    isOnline: false,
    isPresencial: true,
    requiresApproval: false,
    totalViews: 0,
    totalInterested: 0,
    totalConfirmed: 0,
    totalAttended: 0,
    averageRating: averageRating,
    totalReviews: totalReviews,
    createdAt: now,
    updatedAt: now,
  );
}

CompanyModel makeCompany() {
  final now = DateTime.now();
  return CompanyModel(
    id: 'c1',
    email: 'c@t.com',
    cnpj: '00.000.000/0000-00',
    nomeFantasia: 'Empresa Teste',
    endereco: 'Endereço',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('computeAveragePastEventRating exclui eventos sem avaliações', () {
    final provider = FavoritesProvider();
    final events = [
      makeEvent(id: 'e1', averageRating: 5.0, totalReviews: 3),
      makeEvent(id: 'e2', averageRating: 4.2, totalReviews: 1),
      makeEvent(id: 'e3', averageRating: null, totalReviews: 0),
    ];
    final avg = provider.computeAveragePastEventRating(events);
    expect(avg.toStringAsFixed(1), '4.6');
  });

  testWidgets('Exibe quantidade de avaliações e Sem avaliações corretamente', (WidgetTester tester) async {
    final company = makeCompany();
    final events = [
      makeEvent(id: 'e1', averageRating: 5.0, totalReviews: 3),
      makeEvent(id: 'e2', averageRating: null, totalReviews: 0),
    ];
    final provider = FakeFavoritesProvider(
      CompanyDetailsInfo(
        company: company,
        recentReviews: const [],
        pastEvents: events,
        categoryCounts: const {},
        averagePastEventRating: FavoritesProvider().computeAveragePastEventRating(events),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FavoritesProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: CompanyDetailsScreen(companyId: 'c1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('(3 avaliações)'), findsOneWidget);
    expect(find.textContaining('Sem avaliações'), findsOneWidget);
    // Média geral calculada corretamente é coberta pelo teste unitário acima
  });
}

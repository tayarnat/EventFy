import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorites_provider.dart';
import '../../models/company_model.dart';
import '../../models/event_model.dart';
import '../../models/event_review_model.dart';
import '../../services/notification_service.dart';
import '../event/event_details_screen.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final String companyId;
  const CompanyDetailsScreen({Key? key, required this.companyId}) : super(key: key);

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  bool _loading = true;
  String? _error;
  CompanyDetailsInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = Provider.of<FavoritesProvider>(context, listen: false);
      final info = await provider.fetchCompanyDetailsInfo(widget.companyId);
      // Pré-carrega estado de favorito
      await provider.isCompanyFavorited(info.company.id);
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar detalhes da empresa: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final CompanyModel? company = _info?.company;
    return Scaffold(
      appBar: AppBar(
        title: Text(company?.nomeFantasia ?? 'Empresa'),
        actions: [
          if (_info != null)
            Consumer<FavoritesProvider>(
              builder: (context, favs, _) {
                final isFav = favs.isCompanyFavoritedCached(_info!.company.id);
                return IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                  color: isFav ? Colors.redAccent : null,
                  tooltip: isFav ? 'Desfavoritar' : 'Favoritar',
                  onPressed: () async {
                    try {
                      await favs.toggleCompanyFavorite(_info!.company);
                      NotificationService.instance.showSuccess(
                        isFav ? 'Empresa removida dos favoritos' : 'Empresa adicionada aos favoritos',
                      );
                    } catch (e) {
                      NotificationService.instance.showError('Não foi possível atualizar favorito: $e');
                    }
                  },
                );
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    final info = _info!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(info.company),
          const SizedBox(height: 16),
          _buildCategorySummary(info.categoryCounts, info.averagePastEventRating),
          const SizedBox(height: 16),
          _buildPastEvents(info.pastEvents),
          const SizedBox(height: 16),
          _buildRecentReviews(info.recentReviews),
        ],
      ),
    );
  }

  Widget _buildHeader(CompanyModel c) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: c.logoUrl != null && c.logoUrl!.isNotEmpty ? NetworkImage(c.logoUrl!) : null,
                  child: (c.logoUrl == null || c.logoUrl!.isEmpty)
                      ? const Icon(Icons.store, size: 28, color: Colors.deepPurple)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.nomeFantasia,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.verificada == true)
                            Tooltip(
                              message: 'Empresa verificada',
                              child: Icon(Icons.verified, color: Colors.blue.shade600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber.shade700, size: 18),
                          const SizedBox(width: 4),
                          Text((c.averageRating ?? 0.0).toStringAsFixed(1)),
                          const SizedBox(width: 12),
                          Icon(Icons.event, color: Colors.deepPurple, size: 18),
                          const SizedBox(width: 4),
                          Text('${c.totalEventsCreated ?? 0} eventos'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(c.endereco ?? 'Endereço não informado')),
              ],
            ),
            if (c.website != null && c.website!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.link, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(c.website!)),
              ]),
            ],
            if (c.instagram != null && c.instagram!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.photo_camera, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(c.instagram!)),
              ]),
            ],
            if (c.facebook != null && c.facebook!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.facebook, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(c.facebook!)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySummary(Map<String, int> categoryCounts, double avgRating) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo de categorias', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (categoryCounts.isEmpty)
              const Text('Sem dados de categorias')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryCounts.entries.map((e) {
                  return Chip(
                    label: Text('${e.key} (${e.value})'),
                    backgroundColor: Colors.deepPurple.shade50,
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Média avaliações eventos passados: ${avgRating.toStringAsFixed(1)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastEvents(List<EventModel> events) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Eventos passados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Text('Nenhum evento passado encontrado')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = events[i];
                  return ListTile(
                    leading: const Icon(Icons.event, color: Colors.deepPurple),
                    title: Text(e.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber.shade700, size: 18),
                        const SizedBox(width: 4),
                        Text((e.averageRating ?? 0.0).toStringAsFixed(1)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EventDetailsScreen(event: e)),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReviews(List<EventReviewModel> reviews) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avaliações recentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (reviews.isEmpty)
              const Text('Nenhuma avaliação encontrada')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = reviews[i];
                  return ListTile(
                    leading: Icon(Icons.star, color: Colors.amber.shade700),
                    title: Text(r.titulo ?? 'Sem título', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nota: ${r.rating.toStringAsFixed(1)}'),
                        if (r.comentario != null && r.comentario!.isNotEmpty)
                          Text(r.comentario!, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (r.userName != null)
                          Text('por ${r.userName!}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
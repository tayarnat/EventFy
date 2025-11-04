import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorites_provider.dart';
import '../../models/event_model.dart';
import '../../models/company_model.dart';
import '../event/event_details_screen.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingEvents = true;
  bool _loadingCompanies = true;
  List<EventModel> _events = [];
  List<CompanyModel> _companies = [];
  String? _errorEvents;
  String? _errorCompanies;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
    _loadCompanies();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
      _errorEvents = null;
    });
    try {
      final provider = Provider.of<FavoritesProvider>(context, listen: false);
      final list = await provider.fetchFavoriteEvents();
      setState(() {
        _events = list;
        _loadingEvents = false;
      });
    } catch (e) {
      setState(() {
        _errorEvents = 'Erro ao carregar eventos favoritos: $e';
        _loadingEvents = false;
      });
    }
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _errorCompanies = null;
    });
    try {
      final provider = Provider.of<FavoritesProvider>(context, listen: false);
      final list = await provider.fetchFavoriteCompanies();
      setState(() {
        _companies = list;
        _loadingCompanies = false;
      });
    } catch (e) {
      setState(() {
        _errorCompanies = 'Erro ao carregar empresas favoritas: $e';
        _loadingCompanies = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Eventos', icon: Icon(Icons.event)),
            Tab(text: 'Empresas', icon: Icon(Icons.store)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventsTab(),
          _buildCompaniesTab(),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_loadingEvents) return const Center(child: CircularProgressIndicator());
    if (_errorEvents != null) return Center(child: Text(_errorEvents!, style: const TextStyle(color: Colors.red)));
    if (_events.isEmpty) return const Center(child: Text('Nenhum evento favoritado'));
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: _events.length,
        itemBuilder: (context, i) {
          final e = _events[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
                child: const Icon(Icons.event, color: Colors.deepPurple),
              ),
              title: Text(e.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(e.endereco, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventDetailsScreen(event: e)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompaniesTab() {
    if (_loadingCompanies) return const Center(child: CircularProgressIndicator());
    if (_errorCompanies != null) return Center(child: Text(_errorCompanies!, style: const TextStyle(color: Colors.red)));
    if (_companies.isEmpty) return const Center(child: Text('Nenhuma empresa favoritada'));
    return RefreshIndicator(
      onRefresh: _loadCompanies,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: _companies.length,
        itemBuilder: (context, i) {
          final c = _companies[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: c.logoUrl != null && c.logoUrl!.isNotEmpty ? NetworkImage(c.logoUrl!) : null,
                child: (c.logoUrl == null || c.logoUrl!.isEmpty)
                    ? const Icon(Icons.store, color: Colors.deepPurple)
                    : null,
              ),
              title: Text(c.nomeFantasia, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(c.endereco ?? 'Sem endereço'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 4),
                  Text(c.averageRating.toStringAsFixed(1)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                context.pushNamed('company_details', queryParameters: {'id': c.id});
              },
            ),
          );
        },
      ),
    );
  }
}
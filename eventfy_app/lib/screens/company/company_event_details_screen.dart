import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event_model.dart';
import '../../providers/events_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../map/map_screen.dart';
import 'create_event_screen.dart';

class CompanyEventDetailsScreen extends StatefulWidget {
  final EventModel event;
  const CompanyEventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<CompanyEventDetailsScreen> createState() => _CompanyEventDetailsScreenState();
}

class _CompanyEventDetailsScreenState extends State<CompanyEventDetailsScreen> {
  late EventModel _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  Future<void> _refreshEvent() async {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    final updated = eventsProvider.events.firstWhere(
      (e) => e.id == _event.id,
      orElse: () => _event,
    );
    setState(() {
      _event = updated;
    });
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editEvent() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(initialEvent: _event),
      ),
    );
    if (result == true && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
      await eventsProvider.loadCompanyEvents(auth.currentCompany!.id);
      await _refreshEvent();
    }
  }

  Future<void> _cancelEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar evento'),
        content: const Text('Tem certeza de que deseja cancelar este evento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
        ],
      ),
    );
    if (confirm != true) return;

    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    final ok = await eventsProvider.cancelEvent(_event.id);
    if (ok && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await eventsProvider.loadCompanyEvents(auth.currentCompany!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCanceled = _event.status == 'cancelado';
    final isFinished = _event.status == 'finalizado';
    return Scaffold(
      appBar: AppBar(
        title: Text(_event.titulo),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _event.fotoPrincipalUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(_event.fotoPrincipalUrl!, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 16),

            // Status
            Row(
              children: [
                Chip(
                  label: Text(_event.status.toUpperCase()),
                  backgroundColor: isCanceled
                      ? Colors.red.shade100
                      : isFinished
                          ? Colors.grey.shade300
                          : Colors.green.shade100,
                ),
                const SizedBox(width: 8),
                if (_event.requiresApproval)
                  const Chip(
                    label: Text('Requer Aprovação'),
                    backgroundColor: Color(0xFFEDE7F6),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Datas
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Início'),
              subtitle: Text(_formatDateTime(_event.dataInicio)),
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Fim'),
              subtitle: Text(_formatDateTime(_event.dataFim)),
            ),
            const Divider(),

            // Local
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Local'),
              subtitle: Text(_event.endereco),
            ),
            const Divider(),

            // Estatísticas simples
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatCard(label: 'Interessados', value: _event.totalInterested.toString()),
                _StatCard(label: 'Confirmados', value: _event.totalConfirmed.toString()),
                _StatCard(label: 'Compareceram', value: _event.totalAttended.toString()),
                _StatCard(label: 'Avaliações', value: _event.totalReviews.toString()),
              ],
            ),
            const SizedBox(height: 16),

            // Categorias
            if (_event.categorias != null && _event.categorias!.isNotEmpty) ...[
              Text('Categorias', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _event.categorias!
                    .map((c) => Chip(label: Text(c)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Descrição
            if (_event.descricao != null && _event.descricao!.isNotEmpty) ...[
              Text('Descrição', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_event.descricao!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: Text(_event.titulo),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          body: MapScreen(
                            initialLat: _event.latitude,
                            initialLng: _event.longitude,
                            eventId: _event.id,
                          ),
                        ),
                      ),
                    );
                  },
                  color: Theme.of(context).primaryColor.withOpacity(0.15),
                  child: const Text('Ver no Mapa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  onPressed: (isCanceled || isFinished) ? null : _editEvent,
                  child: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  onPressed: (isCanceled || isFinished) ? null : _cancelEvent,
                  color: Colors.red,
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
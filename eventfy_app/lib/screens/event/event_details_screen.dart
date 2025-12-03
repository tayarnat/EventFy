import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../services/notification_service.dart';
import '../../models/event_model.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/event_reviews_sheet.dart';
import '../../widgets/rate_event_sheet.dart';
import '../map/map_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);
  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late Future<String?> _attendanceStatusFuture;
  EventModel get event => widget.event;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _attendanceStatusFuture = _getMyAttendanceStatus(context);
      Provider.of<FavoritesProvider>(context, listen: false).isEventFavorited(event.id);
      setState(() {});
    });
  }


  Future<void> _registerAttendance(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) return;

    try {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Registrar presença')),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: const Text('Você foi ao evento?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('nao_compareceu'),
                child: const Text('Não fui'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('compareceu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Fui'),
              ),
            ],
          );
        },
      );
      if (choice == null) return;
      final payload = {
        'user_id': auth.currentUser!.id,
        'event_id': event.id,
        'status': choice,
        'checked_in_at': choice == 'compareceu' ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('event_attendances').upsert(payload);
      if (choice == 'compareceu') {
        try {
          await supabase.from('notifications').insert({
            'user_id': auth.currentUser!.id,
            'tipo': 'attendance_confirmed',
            'titulo': 'Presença confirmada',
            'mensagem': 'Sua presença foi confirmada com sucesso.',
            'related_event_id': event.id,
            'is_read': false,
            'is_active': true,
            'sent_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
      NotificationService.instance.showSuccess('Presença registrada');
      setState(() {
        _attendanceStatusFuture = _getMyAttendanceStatus(context);
      });
    } catch (e) {
      NotificationService.instance.showError('Não foi possível registrar sua presença: $e');
    }
  }

  Future<void> _registerParticipationIntent(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) return;

    try {
      // Não permitir confirmação se já houver presença registrada
      final existing = await supabase
          .from('event_attendances')
          .select('status')
          .eq('user_id', auth.currentUser!.id)
          .eq('event_id', event.id)
          .maybeSingle();
      if (existing != null && (existing['status'] as String?) == 'compareceu') {
        NotificationService.instance.showError('Você já registrou presença neste evento.');
        return;
      }

      final payload = {
        'user_id': auth.currentUser!.id,
        'event_id': event.id,
        'status': 'confirmado',
        'checked_in_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('event_attendances').upsert(payload);

      try {
        await supabase.from('notifications').insert({
          'user_id': auth.currentUser!.id,
          'tipo': 'participation_confirmed',
          'titulo': 'Participação confirmada',
          'mensagem': 'Sua participação foi confirmada com sucesso.',
          'related_event_id': event.id,
          'is_read': false,
          'is_active': true,
          'sent_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        NotificationService.instance.showError('Erro ao criar notificação de participação: $e');
      }

      try {
        await supabase.from('notifications').insert({
          'user_id': auth.currentUser!.id,
          'tipo': 'event_start',
          'titulo': 'Lembrete: ${event.titulo}',
          'mensagem': 'Seu evento começa em breve. Faça o check-in quando chegar.',
          'related_event_id': event.id,
          'is_read': false,
          'is_active': false,
          'sent_at': event.dataInicio.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      NotificationService.instance.showSuccess('Participação confirmada! Você receberá um lembrete no horário do evento.');
      NotificationService.instance.showInfo('Participação confirmada');
      setState(() {
        _attendanceStatusFuture = _getMyAttendanceStatus(context);
      });
    } catch (e) {
      NotificationService.instance.showError('Não foi possível confirmar sua participação: $e');
    }
  }

  Future<String?> _getMyAttendanceStatus(BuildContext context) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser == null) return null;
      final existing = await supabase
          .from('event_attendances')
          .select('status')
          .eq('user_id', auth.currentUser!.id)
          .eq('event_id', event.id)
          .maybeSingle();
      return existing != null ? existing['status'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cancelParticipation(BuildContext context) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser == null) return;

      // Bloquear cancelamento se já compareceu
      final status = await _getMyAttendanceStatus(context);
      if (status == 'compareceu') {
        NotificationService.instance.showError('Não é possível cancelar após registrar presença.');
        return;
      }

      await supabase
          .from('event_attendances')
          .delete()
          .eq('user_id', auth.currentUser!.id)
          .eq('event_id', event.id);

      NotificationService.instance.showSuccess('Participação cancelada.');
      setState(() {
        _attendanceStatusFuture = _getMyAttendanceStatus(context);
      });
    } catch (e) {
      NotificationService.instance.showError('Erro ao cancelar participação: $e');
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Column(
        children: [
          // Header com foto menor
          Container(
            height: 200, // Reduzido de 300 para 200
            width: double.infinity,
            child: Stack(
              children: [
                // Foto do evento ou placeholder
                event.fotoPrincipalUrl != null && event.fotoPrincipalUrl!.isNotEmpty
                    ? Image.network(
                        event.fotoPrincipalUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Sem foto disponível',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Sem foto disponível',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                // Botão de voltar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Botão de favoritar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favs, _) {
                      final isFav = favs.isEventFavoritedCached(event.id);
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.redAccent : Colors.white,
                          ),
                          onPressed: () async {
                            try {
                              await favs.toggleEventFavorite(event);
                              NotificationService.instance.showSuccess(
                                isFav ? 'Removido dos favoritos' : 'Adicionado aos favoritos',
                              );
                            } catch (e) {
                              NotificationService.instance.showError('Não foi possível atualizar favorito: $e');
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Área scrollável
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título e preço
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.titulo,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: event.isGratuito ? Colors.green : Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.formattedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Tags/Categorias
                  if (event.categorias != null && event.categorias!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categorias',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: event.categorias!.map((categoria) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                categoria,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                    // Empresa responsável
                    if (event.empresaNome != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Organizado por',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (event.empresaLogo != null && event.empresaLogo!.isNotEmpty)
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(event.empresaLogo!),
                                )
                              else
                                const CircleAvatar(
                                  radius: 16,
                                  child: Icon(Icons.business, size: 16),
                                ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  context.pushNamed(
                                    'company_details',
                                    queryParameters: {
                                      'id': event.companyId,
                                    },
                                  );
                                },
                                child: Text(
                                  event.empresaNome!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).primaryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (event.empresaRating != null)
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 2),
                                    Text(
                                      event.empresaRating!.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                  
                  // Data e hora
                  _buildInfoSection(
                    'Data e Hora',
                    '${DateFormat('dd/MM/yyyy').format(event.dataInicio)} às ${DateFormat('HH:mm').format(event.dataInicio)}',
                    Icons.calendar_today,
                    context,
                  ),
                  
                  // Localização
                  _buildInfoSection(
                    'Localização',
                    event.endereco,
                    Icons.location_on,
                    context,
                  ),
                  
                  // Distância (se disponível)
                  if (event.distanceFromUser != null)
                    _buildInfoSection(
                      'Distância',
                      '${event.distanceFromUser!.toStringAsFixed(1)} km de você',
                      Icons.directions_walk,
                      context,
                    ),
                  
                  // Idade mínima
                  if (event.idadeMinima != null && event.idadeMinima! > 0)
                    _buildInfoSection(
                      'Idade Mínima',
                      '${event.idadeMinima} anos',
                      Icons.person,
                      context,
                    ),
                  
                  // Capacidade máxima
                    if (event.capacidade != null)
                      _buildInfoSection(
                        'Capacidade máxima',
                        '${event.capacidade} pessoas',
                        Icons.group,
                        context,
                      ),
                  
                  // Descrição
                  if (event.descricao != null && event.descricao!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.descricao!,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  
                  // Espaço extra para não ficar colado nos botões
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Botões fixos na parte inferior
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(flex: 1,
                    child: CustomButton(
                      onPressed: () {
                        // Navegar para o mapa com a localização do evento mantendo a barra inferior
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: Text(event.titulo),
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              body: MapScreen(
                                initialLat: event.latitude,
                                initialLng: event.longitude,
                                eventId: event.id,
                              ),
                            ),
                          ),
                        );
                      },
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      child: Text(
                        'Ver no Mapa',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 2,
                    child: event.status == 'finalizado'
                        ? FutureBuilder<String?>(
                            future: _getMyAttendanceStatus(context),
                            builder: (context, snapshot) {
                              final myStatus = snapshot.data;
                              final now = DateTime.now();
                              final withinOneMonth = now.isBefore(event.dataFim.add(const Duration(days: 30)));
                              if (myStatus == 'compareceu') {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: CustomButton(
                                        onPressed: () async {
                                          final auth = Provider.of<AuthProvider>(context, listen: false);
                                          final userId = auth.currentUser?.id;
                                          if (userId == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Faça login para avaliar')),
                                            );
                                            return;
                                          }
                                          final existing = await supabase
                                              .from('event_reviews')
                                              .select('id')
                                              .eq('user_id', userId)
                                              .eq('event_id', event.id)
                                              .limit(1);
                                          final already = existing is List && existing.isNotEmpty;
                                          if (already || !withinOneMonth) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(already ? 'Você já avaliou este evento' : 'Período de avaliação encerrado')),
                                            );
                                            return;
                                          }
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => DraggableScrollableSheet(
                                              initialChildSize: 0.6,
                                              minChildSize: 0.4,
                                              maxChildSize: 0.9,
                                              builder: (context, scrollController) {
                                                return SingleChildScrollView(
                                                  controller: scrollController,
                                                  child: RateEventSheet(event: event),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        color: Theme.of(context).primaryColor,
                                        child: const Text('Avaliar evento', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomButton(
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => DraggableScrollableSheet(
                                              initialChildSize: 0.7,
                                              minChildSize: 0.4,
                                              maxChildSize: 0.95,
                                              builder: (context, scrollController) {
                                                return SingleChildScrollView(
                                                  controller: scrollController,
                                                  child: EventReviewsSheet(event: event),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        color: Theme.of(context).primaryColor,
                                        child: const Text('Ver avaliações', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (myStatus == 'nao_compareceu') {
                                return CustomButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => DraggableScrollableSheet(
                                        initialChildSize: 0.7,
                                        minChildSize: 0.4,
                                        maxChildSize: 0.95,
                                        builder: (context, scrollController) {
                                          return SingleChildScrollView(
                                            controller: scrollController,
                                            child: EventReviewsSheet(event: event),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  color: Theme.of(context).primaryColor,
                                  child: const Text('Ver avaliações', style: TextStyle(color: Colors.white)),
                                );
                              }
                              if (myStatus == 'confirmado') {
                                return CustomButton(
                                  onPressed: () async {
                                    await _registerAttendance(context);
                                  },
                                  color: Theme.of(context).primaryColor,
                                  child: const Text('Registrar Presença', style: TextStyle(color: Colors.white)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          )
                  : FutureBuilder<String?>(
                            future: _attendanceStatusFuture,
                            builder: (context, snapshot) {
                              final myStatus = snapshot.data;
                              final now = DateTime.now();
                              final isActiveWindow = event.status == 'ativo' &&
                                  now.isAfter(event.dataInicio.subtract(const Duration(minutes: 15))) &&
                                  now.isBefore(event.dataFim.add(const Duration(hours: 12)));

                              if (myStatus == 'compareceu') {
                                final withinOneMonth = now.isBefore(event.dataFim.add(const Duration(days: 30)));
                                return Row(
                                  children: [
                                    Expanded(
                                      child: CustomButton(
                                        onPressed: () async {
                                          final auth = Provider.of<AuthProvider>(context, listen: false);
                                          final userId = auth.currentUser?.id;
                                          if (userId == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Faça login para avaliar')),
                                            );
                                            return;
                                          }
                                          final existing = await supabase
                                              .from('event_reviews')
                                              .select('id')
                                              .eq('user_id', userId)
                                              .eq('event_id', event.id)
                                              .limit(1);
                                          final already = existing is List && existing.isNotEmpty;
                                          if (already || !withinOneMonth) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(already ? 'Você já avaliou este evento' : 'Período de avaliação encerrado')),
                                            );
                                            return;
                                          }
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => DraggableScrollableSheet(
                                              initialChildSize: 0.6,
                                              minChildSize: 0.4,
                                              maxChildSize: 0.9,
                                              builder: (context, scrollController) {
                                                return SingleChildScrollView(
                                                  controller: scrollController,
                                                  child: RateEventSheet(event: event),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        color: Theme.of(context).primaryColor,
                                        child: const Text('Avaliar evento', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomButton(
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => DraggableScrollableSheet(
                                              initialChildSize: 0.7,
                                              minChildSize: 0.4,
                                              maxChildSize: 0.95,
                                              builder: (context, scrollController) {
                                                return SingleChildScrollView(
                                                  controller: scrollController,
                                                  child: EventReviewsSheet(event: event),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        color: Theme.of(context).primaryColor,
                                        child: const Text('Ver avaliações', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (myStatus == 'nao_compareceu') {
                                return CustomButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => DraggableScrollableSheet(
                                        initialChildSize: 0.7,
                                        minChildSize: 0.4,
                                        maxChildSize: 0.95,
                                        builder: (context, scrollController) {
                                          return SingleChildScrollView(
                                            controller: scrollController,
                                            child: EventReviewsSheet(event: event),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  color: Theme.of(context).primaryColor,
                                  child: const Text('Ver avaliações', style: TextStyle(color: Colors.white)),
                                );
                              }

                              // Único botão principal, alternando entre "Registrar presença", "Vou participar" ou "Cancelar participação"
                              // conforme status do usuário e janela ativa.
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              if (auth.currentUser == null) {
                                return CustomButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Faça login para continuar')),
                                    );
                                  },
                                  color: Theme.of(context).primaryColor,
                                  child: const Text('Entrar', style: TextStyle(color: Colors.white)),
                                );
                              }

                              if (!event.isGratuito) {
                                return CustomButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Redirecionando para compra...'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  color: Theme.of(context).primaryColor,
                                  child: const Text('Comprar Ingresso', style: TextStyle(color: Colors.white)),
                                );
                              }

                              if (myStatus == 'confirmado') {
                                if (isActiveWindow) {
                                  return CustomButton(
                                    onPressed: () async {
                                      await _registerAttendance(context);
                                    },
                                    color: Theme.of(context).primaryColor,
                                    child: const Text('Registrar Presença', style: TextStyle(color: Colors.white)),
                                  );
                                } else {
                                  return CustomButton(
                                    onPressed: () async {
                                      await _cancelParticipation(context);
                                    },
                                    color: Theme.of(context).primaryColor,
                                    child: const Text('Cancelar participação', style: TextStyle(color: Colors.white)),
                                  );
                                }
                              }

                              return CustomButton(
                                onPressed: () async {
                                  await _registerParticipationIntent(context);
                                },
                                color: Theme.of(context).primaryColor,
                                child: const Text('Vou Participar', style: TextStyle(color: Colors.white)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getButtonText() {
    if (!event.isGratuito) {
      return 'Comprar Ingresso';
    }
    
    final now = DateTime.now();
    final isActiveWindow = event.status == 'ativo' &&
        now.isAfter(event.dataInicio.subtract(const Duration(minutes: 15))) &&
        now.isBefore(event.dataFim.add(const Duration(hours: 12)));
    
    if (isActiveWindow) {
      return 'Registrar Presença';
    } else {
      return 'Vou Participar';
    }
  }
  
  Widget _buildInfoSection(String title, String content, IconData icon, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

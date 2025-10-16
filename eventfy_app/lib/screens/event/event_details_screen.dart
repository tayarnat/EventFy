import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../models/event_model.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/event_reviews_sheet.dart';
import '../../widgets/rate_event_sheet.dart';
import '../map/map_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  // Exibe um prompt único perguntando se o usuário participou do evento (apenas para usuários, não empresas)
  Future<void> _maybePromptAttendance(BuildContext context) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // Apenas usuários pessoas físicas
      if (auth.isCompany || auth.currentUser == null) return;

      // Verifica janela de atividade do evento: status ativo e dentro do período (ou logo após)
      final now = DateTime.now();
      final bool isInActiveWindow =
          event.status == 'ativo' &&
          now.isAfter(event.dataInicio.subtract(const Duration(minutes: 15))) &&
          now.isBefore(event.dataFim.add(const Duration(hours: 12)));
      if (!isInActiveWindow) return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'attendance_prompted_v1_${event.id}_${auth.currentUser!.id}';
      if (prefs.getBool(key) == true) return; // já perguntado

      // Se já houver registro de comparecimento, não perguntar e marcar como perguntado
      final existing = await supabase
          .from('event_attendances')
          .select('status')
          .eq('user_id', auth.currentUser!.id)
          .eq('event_id', event.id)
          .maybeSingle();
      if (existing != null && (existing['status'] as String?) == 'compareceu') {
        await prefs.setBool(key, true);
        return;
      }
      
      // Se o usuário já declarou que vai participar, perguntar se compareceu
      final willParticipate = existing != null && (existing['status'] as String?) == 'confirmado';
      if (!willParticipate) {
        // Se não há registro de intenção, não mostrar o prompt ainda
        return;
      }

      // Mostrar diálogo
      // ignore: use_build_context_synchronously
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Você participou deste evento?'),
            content: Text('Confirme sua presença em "${event.titulo}" para registrarmos no seu histórico.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Não'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sim, participei'),
              ),
            ],
          );
        },
      );

      // Marcar que já perguntamos independente da resposta
      await prefs.setBool(key, true);

      if (confirmed == true) {
        await _registerAttendance(context);
      }
    } catch (e) {
      NotificationService.instance.showError('Erro ao verificar presença: $e');
    }
  }

  Future<void> _registerAttendance(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) return;

    try {
      final payload = {
        'user_id': auth.currentUser!.id,
        'event_id': event.id,
        'status': 'compareceu',
        'checked_in_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // upsert para evitar duplicata pela PK (user_id, event_id)
      await supabase.from('event_attendances').upsert(payload);

      NotificationService.instance.showSuccess('Presença registrada com sucesso!');
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

      // upsert para evitar duplicata pela PK (user_id, event_id)
      await supabase.from('event_attendances').upsert(payload);

      NotificationService.instance.showSuccess('Participação confirmada! Você receberá uma notificação quando o evento começar.');
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
    } catch (e) {
      NotificationService.instance.showError('Erro ao cancelar participação: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dispara verificação pós-frame para evitar setState durante build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptAttendance(context);
    });

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
                  Expanded(
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
                  Expanded(
                    child: event.status == 'finalizado'
                        ? FutureBuilder<String?>(
                            future: _getMyAttendanceStatus(context),
                            builder: (context, snapshot) {
                              final myStatus = snapshot.data;
                              if (myStatus == 'compareceu') {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: CustomButton(
                                        onPressed: () async {
                                          // Abrir RateEventSheet (se usuário ainda não avaliou)
                                          final auth = Provider.of<AuthProvider>(context, listen: false);
                                          final userId = auth.currentUser?.id;
                                          if (userId == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Faça login para avaliar')),
                                            );
                                            return;
                                          }
                                          try {
                                            final existing = await supabase
                                                .from('event_reviews')
                                                .select('id')
                                                .eq('user_id', userId)
                                                .eq('event_id', event.id)
                                                .limit(1);
                                            if (existing is List && existing.isNotEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Você já avaliou este evento')),
                                              );
                                              return;
                                            }
                                          } catch (_) {}

                                          // ignore: use_build_context_synchronously
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
                              // Se não compareceu, mostrar apenas "Ver avaliações"
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
                            },
                          )
                        : FutureBuilder<String?>(
                            future: _getMyAttendanceStatus(context),
                            builder: (context, snapshot) {
                              final myStatus = snapshot.data;
                              final now = DateTime.now();
                              final isActiveWindow = event.status == 'ativo' &&
                                  now.isAfter(event.dataInicio.subtract(const Duration(minutes: 15))) &&
                                  now.isBefore(event.dataFim.add(const Duration(hours: 12)));

                              if (myStatus == 'compareceu') {
                                return CustomButton(
                                  onPressed: () {},
                                  color: Colors.grey,
                                  child: const Text('Presença registrada', style: TextStyle(color: Colors.white)),
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

                              if (isActiveWindow) {
                                return CustomButton(
                                  onPressed: () async {
                                    await _registerAttendance(context);
                                  },
                                  color: Theme.of(context).primaryColor,
                                  child: const Text('Registrar Presença', style: TextStyle(color: Colors.white)),
                                );
                              }

                              // Fora da janela ativa
                              if (myStatus == 'confirmado') {
                                return CustomButton(
                                  onPressed: () async {
                                    await _cancelParticipation(context);
                                  },
                                  color: Theme.of(context).primaryColor,
                                  child: const Text('Cancelar participação', style: TextStyle(color: Colors.white)),
                                );
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
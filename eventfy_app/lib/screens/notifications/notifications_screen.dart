import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/notifications_provider.dart';
import '../../providers/events_provider.dart';
import '../../models/notification_model.dart';
import '../../models/event_model.dart';
import '../../services/notification_service.dart';
import '../event/event_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotificationsProvider>(context, listen: false);
      provider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        centerTitle: true,
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Marcar todas como lidas',
                icon: const Icon(Icons.mark_email_read_outlined),
                onPressed: () => provider.markAllAsRead(),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(provider.errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadNotifications(),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Nenhuma notificação encontrada', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: provider.notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final notif = provider.notifications[index];
                return _NotificationTile(
                  notification: notif,
                  onTap: () async {
                    await provider.markAsRead(notif.id);
                    await _openRelatedIfAny(context, notif);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openRelatedIfAny(BuildContext context, NotificationModel notif) async {
    final eventId = notif.relatedEventId;
    if (eventId == null || eventId.isEmpty) return;

    // Tenta buscar no provider de eventos
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    EventModel? event;
    try {
      event = eventsProvider.events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      event = null;
    }

    // Se não encontrado, busca direto no Supabase
    if (event == null) {
      try {
        final res = await Supabase.instance.client
            .from('events')
            .select('*')
            .eq('id', eventId)
            .maybeSingle();
        if (res != null) {
          event = EventModel.fromJson(res as Map<String, dynamic>);
        }
      } catch (e) {
        NotificationService.instance.showError('Erro ao abrir evento relacionado: $e');
        return;
      }
    }

    if (event != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailsScreen(event: event!),
        ),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const _NotificationTile({Key? key, required this.notification, this.onTap}) : super(key: key);

  IconData _iconForTipo(String tipo) {
    switch (tipo) {
      case 'event_start':
        return Icons.event_available;
      case 'recommendation':
        return Icons.recommend;
      case 'rate_event':
        return Icons.star_rate_rounded;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final isUnread = !notification.isRead;
    return Card(
      elevation: isUnread ? 2 : 0,
      color: isUnread ? Colors.deepPurple.shade50 : Theme.of(context).cardColor,
      child: ListTile(
        leading: Icon(_iconForTipo(notification.tipo), color: Colors.deepPurple.shade700),
        title: Text(
          notification.titulo,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.mensagem),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(df.format(notification.sentAt), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Spacer(),
                if (isUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Novo', style: TextStyle(color: Colors.deepPurple, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_model.dart';
import '../widgets/rate_event_sheet.dart';
import 'notification_service.dart';

class RateEventNotificationsService {
  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('notifications')
          .select('id, titulo, mensagem, related_event_id, sent_at')
          .eq('user_id', userId)
          .eq('tipo', 'rate_event')
          .eq('is_read', false)
          .order('sent_at', ascending: false)
          .limit(1);

      if (response is List && response.isNotEmpty) {
        final notif = response.first as Map<String, dynamic>;
        final eventId = notif['related_event_id'] as String?;
        if (eventId == null) {
          // Marca como lida se estiver inconsistente
          await supabase.from('notifications').update({'is_read': true}).eq('id', notif['id']);
          return;
        }

        // Buscar dados mínimos do evento para montar a folha de avaliação
        final eventResp = await supabase
            .from('events')
            .select(
                'id, company_id, titulo, descricao, endereco, location, data_inicio, data_fim, valor, is_gratuito, capacidade, capacidade_atual, idade_minima, foto_principal_url, link_externo, link_streaming, status, is_online, is_presencial, requires_approval, total_views, total_interested, total_confirmed, total_attended, average_rating, total_reviews, created_at, updated_at')
            .eq('id', eventId)
            .limit(1);

        if (eventResp is List && eventResp.isNotEmpty) {
          final eventRow = eventResp.first as Map<String, dynamic>;
          final event = EventModel.fromJson(eventRow);

          // Mostrar aviso e abrir a folha de avaliação
          NotificationService.instance.showInfo('Temos uma avaliação pendente para: ${event.titulo}');

          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => RateEventSheet(event: event),
          );

          // Após abrir a folha, marcar como lida para não repetir
          await supabase
              .from('notifications')
              .update({'is_read': true})
              .eq('id', notif['id']);
        } else {
          // Não encontrou o evento, marcar como lida
          await supabase.from('notifications').update({'is_read': true}).eq('id', notif['id']);
        }
      }
    } catch (e) {
      NotificationService.instance.showError('Erro ao verificar notificações de avaliação: $e');
    }
  }
}
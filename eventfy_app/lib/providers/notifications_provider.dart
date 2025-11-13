import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'dart:convert';
import 'dart:async';

class NotificationsProvider with ChangeNotifier {
  final SupabaseClient _supabase = supabase;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  RealtimeChannel? _channel;
  Set<String> _shownDueIds = {};
  Timer? _dueTimer;

  // ===== Logger helpers (apenas em modo debug) =====
  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 8) return '***';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  String _json(dynamic data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[NotificationsProvider] $message');
  }

  void _logData(String label, dynamic data) {
    if (kDebugMode) debugPrint('[NotificationsProvider] $label: ${_json(data)}');
  }

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> initialize() async {
    _log('initialize()');
    _log('currentUserId: ${_supabase.auth.currentUser?.id}');
    _log('hasSession: ${_supabase.auth.currentSession != null}, token: ${_maskToken(_supabase.auth.currentSession?.accessToken)}');
    await loadNotifications();
    _subscribeToRealtime();
    _dueTimer?.cancel();
    _dueTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDueNotifications());
    await _backfillStartNotifications();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      _log('loadNotifications() for userId=$userId');
      if (userId == null) {
        _notifications = [];
        _isLoading = false;
        _log('No userId. Returning empty notifications list.');
        notifyListeners();
        return;
      }

      _log('Query -> from("notifications").select(explicit cols).eq("user_id", "$userId").order("sent_at" DESC).order("created_at" DESC)');
      // Seleciona colunas explicitamente para evitar problemas de mapeamento
      const selectedCols = 'id, user_id, tipo, titulo, mensagem, related_event_id, is_read, sent_at, created_at';
      var res = await _supabase
          .from('notifications')
          .select(selectedCols)
          .eq('user_id', userId)
          .order('sent_at', ascending: false)
          .order('created_at', ascending: false);

      if (res is List) {
        _log('Raw response length: ${res.length}');
        if (res.isNotEmpty) {
          _logData('Raw first item', res.first);
        }
        var list = res
            .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _notifications = list;
        _log('Mapped notifications length: ${_notifications.length}');
        if (_notifications.isNotEmpty) {
          _logData('First mapped notification', _notifications.first.toJson());
        }
        _checkDueNotifications();
      } else {
        _logData('Unexpected response type for select', res);
        _notifications = [];
      }
      // removed debug popup on loading notifications
    } catch (e) {
      _errorMessage = 'Erro ao carregar notificações: $e';
      _log('Erro ao carregar notificações: $e');
      NotificationService.instance.showError(_errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    _log('markAsRead($id)');
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        notifyListeners();
        _log('Marked as read locally: $id');
      }
    } catch (e) {
      _log('Erro ao marcar notificação como lida: $e');
      NotificationService.instance.showError('Erro ao marcar notificação como lida: $e');
    }
  }

  Future<void> markAllAsRead() async {
    _log('markAllAsRead()');
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
      _log('Marked all as read locally for userId=$userId');
    } catch (e) {
      _log('Erro ao marcar todas como lidas: $e');
      NotificationService.instance.showError('Erro ao marcar todas como lidas: $e');
    }
  }

  void _subscribeToRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      _log('Subscribing to realtime on channel public:notifications for userId=$userId');
      _channel?.unsubscribe();
      _channel = _supabase
          .channel('public:notifications')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            try {
              final newRecord = payload.newRecord;
              _logData('Realtime payload newRecord', newRecord);
              if (newRecord == null) return;
              if (newRecord['user_id'] != userId) return; // filtra por usuário
              _log('Realtime accepted for user. user_id=${newRecord['user_id']}');

              final notif = NotificationModel.fromJson(Map<String, dynamic>.from(newRecord));
              _log('Realtime mapped notification id=${notif.id}');
              _notifications.insert(0, notif);
              notifyListeners();

              _checkOneDue(notif);

              // Mostrar aviso em tempo real
              NotificationService.instance.showInfo(
                notif.titulo.isNotEmpty ? notif.titulo : 'Nova notificação recebida',
              );
            } catch (e) {
              if (kDebugMode) {
                print('Erro ao processar payload de notificação: $e');
              }
              _log('Erro ao processar payload de notificação: $e');
            }
          },
        )
        ..subscribe();
      _log('Realtime subscribed.');
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao se inscrever em notificações em tempo real: $e');
      }
      _log('Erro ao se inscrever em notificações em tempo real: $e');
    }
  }

  @override
  void dispose() {
    _log('dispose(): unsubscribing channel');
    _channel?.unsubscribe();
    _dueTimer?.cancel();
    super.dispose();
  }

  void _checkDueNotifications() {
    final now = DateTime.now().toUtc();
    for (final n in _notifications) {
      if (!n.isRead && n.sentAt.isBefore(now) && !_shownDueIds.contains(n.id)) {
        _shownDueIds.add(n.id);
        NotificationService.instance.showInfo(n.titulo.isNotEmpty ? n.titulo : 'Nova notificação');
      }
    }
  }

  void _checkOneDue(NotificationModel n) {
    final now = DateTime.now().toUtc();
    if (!n.isRead && n.sentAt.isBefore(now) && !_shownDueIds.contains(n.id)) {
      _shownDueIds.add(n.id);
      NotificationService.instance.showInfo(n.titulo.isNotEmpty ? n.titulo : 'Nova notificação');
    }
  }

  Future<void> _backfillStartNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final res = await _supabase
          .from('event_attendances')
          .select('event_id, events!inner(data_inicio, titulo)')
          .eq('user_id', userId)
          .eq('status', 'confirmado');
      if (res is! List || res.isEmpty) return;
      final toInsert = <Map<String, dynamic>>[];
      for (final row in res) {
        final eventId = row['event_id']?.toString();
        final ev = row['events'] as Map<String, dynamic>?;
        if (eventId == null || ev == null) continue;
        final dataInicio = ev['data_inicio']?.toString();
        if (dataInicio == null) continue;
        final already = _notifications.any((n) => n.relatedEventId == eventId && n.tipo == 'event_start');
        if (!already) {
          toInsert.add({
            'user_id': userId,
            'tipo': 'event_start',
            'titulo': 'Lembrete: ${ev['titulo'] ?? 'Evento'}',
            'mensagem': 'Seu evento começa em breve. Faça o check-in quando chegar.',
            'related_event_id': eventId,
            'is_read': false,
            'sent_at': dataInicio,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
      if (toInsert.isNotEmpty) {
        await _supabase.from('notifications').insert(toInsert);
        await loadNotifications();
      }
    } catch (_) {}
  }
}

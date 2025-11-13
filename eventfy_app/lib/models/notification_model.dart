import 'package:flutter/foundation.dart';

/// Modelo para representar uma notificação da tabela `notifications` no Supabase
class NotificationModel {
  final String id;
  final String? userId;
  final String tipo; // e.g. 'event_start', 'recommendation', 'rate_event', 'generic'
  final String titulo;
  final String mensagem;
  final String? relatedEventId;
  final DateTime sentAt;
  final bool isRead;
  final Map<String, dynamic>? extraData;

  NotificationModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    required this.sentAt,
    required this.isRead,
    this.userId,
    this.relatedEventId,
    this.extraData,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime _parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value.toUtc();
      if (value is String) {
        var s = value.trim();
        // Normaliza separador de data/hora
        if (s.contains(' ') && !s.contains('T')) {
          s = s.replaceFirst(' ', 'T');
        }
        // Normaliza offset sem dois-pontos (ex.: +0000 -> +00:00)
        final m1 = RegExp(r'([+-]\d{2})(\d{2})$').firstMatch(s);
        if (m1 != null) {
          s = s.replaceRange(m1.start, m1.end, '${m1.group(1)}:${m1.group(2)}');
        }
        // Normaliza offset apenas com hora (ex.: +00 -> +00:00)
        final m2 = RegExp(r'([+-]\d{2})$').firstMatch(s);
        if (m2 != null) {
          s = s.replaceRange(m2.start, m2.end, '${m2.group(1)}:00');
        }
        // Garante Z se nada foi informado
        if (!RegExp(r'[+-]\d{2}:?\d{2}|Z').hasMatch(s)) {
          s = '${s}Z';
        }
        return DateTime.tryParse(s)?.toUtc() ?? DateTime.now().toUtc();
      }
      return DateTime.now().toUtc();
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      tipo: json['tipo']?.toString() ?? 'generic',
      titulo: json['titulo']?.toString() ?? '',
      mensagem: json['mensagem']?.toString() ?? '',
      relatedEventId: json['related_event_id']?.toString(),
      sentAt: _parseTimestamp(json['sent_at'] ?? json['created_at']),
      isRead: (json['is_read'] is bool)
          ? json['is_read'] as bool
          : json['is_read']?.toString().toLowerCase() == 'true',
      extraData: json['extra_data'] is Map<String, dynamic>
          ? json['extra_data'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'tipo': tipo,
        'titulo': titulo,
        'mensagem': mensagem,
        'related_event_id': relatedEventId,
        'sent_at': sentAt.toIso8601String(),
        'is_read': isRead,
        'extra_data': extraData,
      };

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? tipo,
    String? titulo,
    String? mensagem,
    String? relatedEventId,
    DateTime? sentAt,
    bool? isRead,
    Map<String, dynamic>? extraData,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tipo: tipo ?? this.tipo,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      relatedEventId: relatedEventId ?? this.relatedEventId,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      extraData: extraData ?? this.extraData,
    );
  }

  /// Representação amigável para debug
  @override
  String toString() {
    return 'NotificationModel(id=$id, tipo=$tipo, titulo=$titulo, relatedEventId=$relatedEventId, sentAt=$sentAt, isRead=$isRead)';
  }
}
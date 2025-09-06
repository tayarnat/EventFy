import 'package:json_annotation/json_annotation.dart';

part 'event_model.g.dart';

@JsonSerializable()
class EventModel {
  final String id;
  final String companyId;
  final String titulo;
  final String? descricao;
  final String endereco;
  final double latitude;
  final double longitude;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double? valor;
  final bool isGratuito;
  final int? capacidade;
  final int capacidadeAtual;
  final int idadeMinima;
  final String? fotoPrincipalUrl;
  final String? linkExterno;
  final String? linkStreaming;
  final String status; // 'ativo', 'cancelado', 'finalizado', 'rascunho'
  final bool isOnline;
  final bool isPresencial;
  final bool requiresApproval;
  final int totalViews;
  final int totalInterested;
  final int totalConfirmed;
  final int totalAttended;
  final double? averageRating;
  final int totalReviews;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Dados da empresa (join)
  final String? empresaNome;
  final String? empresaLogo;
  final double? empresaRating;
  
  // Categorias do evento
  final List<String>? categorias;

  EventModel({
    required this.id,
    required this.companyId,
    required this.titulo,
    this.descricao,
    required this.endereco,
    required this.latitude,
    required this.longitude,
    required this.dataInicio,
    required this.dataFim,
    this.valor,
    this.isGratuito = true,
    this.capacidade,
    this.capacidadeAtual = 0,
    this.idadeMinima = 0,
    this.fotoPrincipalUrl,
    this.linkExterno,
    this.linkStreaming,
    this.status = 'ativo',
    this.isOnline = false,
    this.isPresencial = true,
    this.requiresApproval = false,
    this.totalViews = 0,
    this.totalInterested = 0,
    this.totalConfirmed = 0,
    this.totalAttended = 0,
    this.averageRating,
    this.totalReviews = 0,
    required this.createdAt,
    required this.updatedAt,
    this.empresaNome,
    this.empresaLogo,
    this.empresaRating,
    this.categorias,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Converter coordenadas do PostGIS se necessário
    double lat = 0.0;
    double lng = 0.0;
    
    // Primeiro, tentar extrair do campo location (PostGIS)
    if (json['location'] != null) {
      try {
        // O Supabase retorna o campo geography como um objeto com coordenadas
        final location = json['location'];
        print('DEBUG: Campo location recebido: $location (tipo: ${location.runtimeType})');
        
        if (location is Map<String, dynamic>) {
          print('DEBUG: Location é um Map: $location');
          if (location['coordinates'] != null && location['coordinates'] is List) {
            final coords = location['coordinates'] as List;
            print('DEBUG: Coordenadas encontradas: $coords');
            if (coords.length >= 2) {
              lng = (coords[0] as num).toDouble(); // longitude vem primeiro no GeoJSON
              lat = (coords[1] as num).toDouble(); // latitude vem segundo
              print('DEBUG: Coordenadas extraídas - lat: $lat, lng: $lng');
            }
          }
        } else if (location is String) {
          print('DEBUG: Location é uma String: $location');
          // Se vier como string WKT (Well-Known Text), exemplo: "POINT(-46.123 -23.456)"
          final pointMatch = RegExp(r'POINT\(([\-\d\.]+)\s+([\-\d\.]+)\)').firstMatch(location);
          if (pointMatch != null) {
            lng = double.parse(pointMatch.group(1)!);
            lat = double.parse(pointMatch.group(2)!);
            print('DEBUG: Coordenadas extraídas do WKT - lat: $lat, lng: $lng');
          }
        }
      } catch (e) {
        print('Erro ao processar coordenadas do location: $e');
      }
    }
    
    // Fallback para campos latitude/longitude separados (se existirem)
    if (lat == 0.0 && lng == 0.0) {
      if (json['latitude'] != null) {
        lat = (json['latitude'] as num).toDouble();
      }
      if (json['longitude'] != null) {
        lng = (json['longitude'] as num).toDouble();
      }
    }
    
    // Converter categorias se vier como string separada por vírgula
    List<String>? categoriasList;
    if (json['categorias'] != null) {
      if (json['categorias'] is List) {
        categoriasList = List<String>.from(json['categorias']);
      } else if (json['categorias'] is String) {
        categoriasList = json['categorias'].split(',').map((e) => e.trim()).toList();
      }
    }
    
    return EventModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      titulo: json['titulo'] as String,
      descricao: json['descricao'] as String?,
      endereco: json['endereco'] as String,
      latitude: lat,
      longitude: lng,
      dataInicio: DateTime.parse(json['data_inicio'] as String),
      dataFim: DateTime.parse(json['data_fim'] as String),
      valor: json['valor'] != null ? (json['valor'] as num).toDouble() : null,
      isGratuito: json['is_gratuito'] as bool? ?? true,
      capacidade: json['capacidade'] as int?,
      capacidadeAtual: json['capacidade_atual'] as int? ?? 0,
      idadeMinima: json['idade_minima'] as int? ?? 0,
      fotoPrincipalUrl: json['foto_principal_url'] as String?,
      linkExterno: json['link_externo'] as String?,
      linkStreaming: json['link_streaming'] as String?,
      status: json['status'] as String? ?? 'ativo',
      isOnline: json['is_online'] as bool? ?? false,
      isPresencial: json['is_presencial'] as bool? ?? true,
      requiresApproval: json['requires_approval'] as bool? ?? false,
      totalViews: json['total_views'] as int? ?? 0,
      totalInterested: json['total_interested'] as int? ?? 0,
      totalConfirmed: json['total_confirmed'] as int? ?? 0,
      totalAttended: json['total_attended'] as int? ?? 0,
      averageRating: json['average_rating'] != null ? (json['average_rating'] as num).toDouble() : null,
      totalReviews: json['total_reviews'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      empresaNome: json['empresa_nome'] as String?,
      empresaLogo: json['empresa_logo'] as String?,
      empresaRating: json['empresa_rating'] != null ? (json['empresa_rating'] as num).toDouble() : null,
      categorias: categoriasList,
    );
  }

  Map<String, dynamic> toJson() => {
    'company_id': companyId,
    'titulo': titulo,
    'descricao': descricao,
    'endereco': endereco,
    'location': 'POINT($longitude $latitude)',
    'data_inicio': dataInicio.toIso8601String(),
    'data_fim': dataFim.toIso8601String(),
    'valor': valor,
    'is_gratuito': isGratuito,
    'capacidade': capacidade,
    'idade_minima': idadeMinima,
    'foto_principal_url': fotoPrincipalUrl,
    'link_externo': linkExterno,
    'link_streaming': linkStreaming,
    'status': status,
    'is_online': isOnline,
    'is_presencial': isPresencial,
    'requires_approval': requiresApproval,
  };

  // Método para criar um evento (para empresas)
  factory EventModel.create({
    required String companyId,
    required String titulo,
    String? descricao,
    required String endereco,
    required double latitude,
    required double longitude,
    required DateTime dataInicio,
    required DateTime dataFim,
    double? valor,
    bool isGratuito = true,
    int? capacidade,
    int idadeMinima = 0,
    String? fotoPrincipalUrl,
    String? linkExterno,
    String? linkStreaming,
    bool isOnline = false,
    bool isPresencial = true,
    bool requiresApproval = false,
  }) {
    final now = DateTime.now();
    return EventModel(
      id: '', // Será gerado pelo banco
      companyId: companyId,
      titulo: titulo,
      descricao: descricao,
      endereco: endereco,
      latitude: latitude,
      longitude: longitude,
      dataInicio: dataInicio,
      dataFim: dataFim,
      valor: valor,
      isGratuito: isGratuito,
      capacidade: capacidade,
      capacidadeAtual: 0,
      idadeMinima: idadeMinima,
      fotoPrincipalUrl: fotoPrincipalUrl,
      linkExterno: linkExterno,
      linkStreaming: linkStreaming,
      status: 'ativo',
      isOnline: isOnline,
      isPresencial: isPresencial,
      requiresApproval: requiresApproval,
      totalViews: 0,
      totalInterested: 0,
      totalConfirmed: 0,
      totalAttended: 0,
      averageRating: null,
      totalReviews: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Método para calcular distância do usuário (será usado no provider)
  double? distanceFromUser;
  
  EventModel copyWith({
    String? id,
    String? companyId,
    String? titulo,
    String? descricao,
    String? endereco,
    double? latitude,
    double? longitude,
    DateTime? dataInicio,
    DateTime? dataFim,
    double? valor,
    bool? isGratuito,
    int? capacidade,
    int? capacidadeAtual,
    int? idadeMinima,
    String? fotoPrincipalUrl,
    String? linkExterno,
    String? linkStreaming,
    String? status,
    bool? isOnline,
    bool? isPresencial,
    bool? requiresApproval,
    int? totalViews,
    int? totalInterested,
    int? totalConfirmed,
    int? totalAttended,
    double? averageRating,
    int? totalReviews,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? empresaNome,
    String? empresaLogo,
    double? empresaRating,
    List<String>? categorias,
    double? distanceFromUser,
  }) {
    return EventModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      endereco: endereco ?? this.endereco,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      valor: valor ?? this.valor,
      isGratuito: isGratuito ?? this.isGratuito,
      capacidade: capacidade ?? this.capacidade,
      capacidadeAtual: capacidadeAtual ?? this.capacidadeAtual,
      idadeMinima: idadeMinima ?? this.idadeMinima,
      fotoPrincipalUrl: fotoPrincipalUrl ?? this.fotoPrincipalUrl,
      linkExterno: linkExterno ?? this.linkExterno,
      linkStreaming: linkStreaming ?? this.linkStreaming,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      isPresencial: isPresencial ?? this.isPresencial,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      totalViews: totalViews ?? this.totalViews,
      totalInterested: totalInterested ?? this.totalInterested,
      totalConfirmed: totalConfirmed ?? this.totalConfirmed,
      totalAttended: totalAttended ?? this.totalAttended,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      empresaNome: empresaNome ?? this.empresaNome,
      empresaLogo: empresaLogo ?? this.empresaLogo,
      empresaRating: empresaRating ?? this.empresaRating,
      categorias: categorias ?? this.categorias,
    )..distanceFromUser = distanceFromUser ?? this.distanceFromUser;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'EventModel(id: $id, titulo: $titulo, endereco: $endereco, dataInicio: $dataInicio)';
  }

  // Getters úteis
  bool get isActive => status == 'ativo';
  bool get isFuture => dataInicio.isAfter(DateTime.now());
  bool get isToday => DateTime.now().difference(dataInicio).inDays == 0;
  bool get hasCapacityLimit => capacidade != null;
  bool get isFull => hasCapacityLimit && capacidadeAtual >= capacidade!;
  String get formattedPrice => isGratuito ? 'Gratuito' : 'R\$ ${valor?.toStringAsFixed(2) ?? '0,00'}';
}
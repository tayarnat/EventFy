// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventModel _$EventModelFromJson(Map<String, dynamic> json) => EventModel(
  id: json['id'] as String,
  companyId: json['companyId'] as String,
  titulo: json['titulo'] as String,
  descricao: json['descricao'] as String?,
  endereco: json['endereco'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  dataInicio: DateTime.parse(json['dataInicio'] as String),
  dataFim: DateTime.parse(json['dataFim'] as String),
  valor: (json['valor'] as num?)?.toDouble(),
  isGratuito: json['isGratuito'] as bool? ?? true,
  capacidade: (json['capacidade'] as num?)?.toInt(),
  capacidadeAtual: (json['capacidadeAtual'] as num?)?.toInt() ?? 0,
  idadeMinima: (json['idadeMinima'] as num?)?.toInt() ?? 0,
  fotoPrincipalUrl: json['fotoPrincipalUrl'] as String?,
  linkExterno: json['linkExterno'] as String?,
  linkStreaming: json['linkStreaming'] as String?,
  status: json['status'] as String? ?? 'ativo',
  isOnline: json['isOnline'] as bool? ?? false,
  isPresencial: json['isPresencial'] as bool? ?? true,
  requiresApproval: json['requiresApproval'] as bool? ?? false,
  totalViews: (json['totalViews'] as num?)?.toInt() ?? 0,
  totalInterested: (json['totalInterested'] as num?)?.toInt() ?? 0,
  totalConfirmed: (json['totalConfirmed'] as num?)?.toInt() ?? 0,
  totalAttended: (json['totalAttended'] as num?)?.toInt() ?? 0,
  averageRating: (json['averageRating'] as num?)?.toDouble(),
  totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  empresaNome: json['empresaNome'] as String?,
  empresaLogo: json['empresaLogo'] as String?,
  empresaRating: (json['empresaRating'] as num?)?.toDouble(),
  categorias: (json['categorias'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
)..distanceFromUser = (json['distanceFromUser'] as num?)?.toDouble();

Map<String, dynamic> _$EventModelToJson(EventModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'companyId': instance.companyId,
      'titulo': instance.titulo,
      'descricao': instance.descricao,
      'endereco': instance.endereco,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'dataInicio': instance.dataInicio.toIso8601String(),
      'dataFim': instance.dataFim.toIso8601String(),
      'valor': instance.valor,
      'isGratuito': instance.isGratuito,
      'capacidade': instance.capacidade,
      'capacidadeAtual': instance.capacidadeAtual,
      'idadeMinima': instance.idadeMinima,
      'fotoPrincipalUrl': instance.fotoPrincipalUrl,
      'linkExterno': instance.linkExterno,
      'linkStreaming': instance.linkStreaming,
      'status': instance.status,
      'isOnline': instance.isOnline,
      'isPresencial': instance.isPresencial,
      'requiresApproval': instance.requiresApproval,
      'totalViews': instance.totalViews,
      'totalInterested': instance.totalInterested,
      'totalConfirmed': instance.totalConfirmed,
      'totalAttended': instance.totalAttended,
      'averageRating': instance.averageRating,
      'totalReviews': instance.totalReviews,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'empresaNome': instance.empresaNome,
      'empresaLogo': instance.empresaLogo,
      'empresaRating': instance.empresaRating,
      'categorias': instance.categorias,
      'distanceFromUser': instance.distanceFromUser,
    };

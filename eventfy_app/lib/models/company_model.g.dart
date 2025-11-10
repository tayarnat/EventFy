// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompanyModel _$CompanyModelFromJson(Map<String, dynamic> json) => CompanyModel(
  id: json['id'] as String,
  // email não existe na tabela companies; usar valor padrão vazio quando não presente
  email: (json['email'] as String?) ?? '',
  cnpj: json['cnpj'] as String,
  // mapear snake_case para camelCase
  nomeFantasia: json['nome_fantasia'] as String,
  razaoSocial: json['razao_social'] as String?,
  telefone: json['telefone'] as String?,
  endereco: json['endereco'] as String?,
  // latitude/longitude não existem em companies (apenas location). Manter nulos.
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  logoUrl: json['logo_url'] as String?,
  website: json['website'] as String?,
  instagram: json['instagram'] as String?,
  facebook: json['facebook'] as String?,
  responsavelNome: json['responsavel_nome'] as String?,
  responsavelCpf: json['responsavel_cpf'] as String?,
  responsavelTelefone: json['responsavel_telefone'] as String?,
  responsavelEmail: json['responsavel_email'] as String?,
  verificada: json['verificada'] as bool? ?? false,
  verificadaEm: json['verificada_em'] == null
      ? null
      : DateTime.parse(json['verificada_em'] as String),
  totalEventsCreated: (json['total_events_created'] as num?)?.toInt() ?? 0,
  averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
  totalFollowers: (json['total_followers'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$CompanyModelToJson(CompanyModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'cnpj': instance.cnpj,
      'nomeFantasia': instance.nomeFantasia,
      'razaoSocial': instance.razaoSocial,
      'telefone': instance.telefone,
      'endereco': instance.endereco,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'logoUrl': instance.logoUrl,
      'website': instance.website,
      'instagram': instance.instagram,
      'facebook': instance.facebook,
      'responsavelNome': instance.responsavelNome,
      'responsavelCpf': instance.responsavelCpf,
      'responsavelTelefone': instance.responsavelTelefone,
      'responsavelEmail': instance.responsavelEmail,
      'verificada': instance.verificada,
      'verificadaEm': instance.verificadaEm?.toIso8601String(),
      'totalEventsCreated': instance.totalEventsCreated,
      'averageRating': instance.averageRating,
      'totalFollowers': instance.totalFollowers,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

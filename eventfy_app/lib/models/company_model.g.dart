// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompanyModel _$CompanyModelFromJson(Map<String, dynamic> json) => CompanyModel(
  id: json['id'] as String,
  email: json['email'] as String,
  cnpj: json['cnpj'] as String,
  nomeFantasia: json['nomeFantasia'] as String,
  razaoSocial: json['razaoSocial'] as String?,
  telefone: json['telefone'] as String?,
  endereco: json['endereco'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  logoUrl: json['logoUrl'] as String?,
  website: json['website'] as String?,
  instagram: json['instagram'] as String?,
  facebook: json['facebook'] as String?,
  responsavelNome: json['responsavelNome'] as String?,
  responsavelCpf: json['responsavelCpf'] as String?,
  responsavelTelefone: json['responsavelTelefone'] as String?,
  responsavelEmail: json['responsavelEmail'] as String?,
  verificada: json['verificada'] as bool? ?? false,
  verificadaEm: json['verificadaEm'] == null
      ? null
      : DateTime.parse(json['verificadaEm'] as String),
  totalEventsCreated: (json['totalEventsCreated'] as num?)?.toInt() ?? 0,
  averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
  totalFollowers: (json['totalFollowers'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
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

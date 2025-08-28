// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  email: json['email'] as String,
  nome: json['nome'] as String,
  telefone: json['telefone'] as String?,
  endereco: json['endereco'] as String?,
  dataNascimento: json['dataNascimento'] == null
      ? null
      : DateTime.parse(json['dataNascimento'] as String),
  cpf: json['cpf'] as String?,
  genero: json['genero'] as String?,
  rangeDistancia: (json['rangeDistancia'] as num?)?.toInt() ?? 10000,
  avatarUrl: json['avatarUrl'] as String?,
  locationLat: (json['locationLat'] as num?)?.toDouble(),
  locationLng: (json['locationLng'] as num?)?.toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'nome': instance.nome,
  'telefone': instance.telefone,
  'endereco': instance.endereco,
  'dataNascimento': instance.dataNascimento?.toIso8601String(),
  'cpf': instance.cpf,
  'genero': instance.genero,
  'rangeDistancia': instance.rangeDistancia,
  'avatarUrl': instance.avatarUrl,
  'locationLat': instance.locationLat,
  'locationLng': instance.locationLng,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

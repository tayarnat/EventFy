// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryModel _$CategoryModelFromJson(Map<String, dynamic> json) =>
    CategoryModel(
      id: json['id'] as String,
      codigoInterno: json['codigoInterno'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      corHex: json['corHex'] as String?,
      icone: json['icone'] as String?,
      categoriaPai: json['categoriaPai'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$CategoryModelToJson(CategoryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'codigoInterno': instance.codigoInterno,
      'nome': instance.nome,
      'descricao': instance.descricao,
      'corHex': instance.corHex,
      'icone': instance.icone,
      'categoriaPai': instance.categoriaPai,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
    };

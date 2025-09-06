import 'package:json_annotation/json_annotation.dart';

part 'category_model.g.dart';

@JsonSerializable()
class CategoryModel {
  final String id;
  final String codigoInterno;
  final String nome;
  final String? descricao;
  final String? corHex;
  final String? icone;
  final String? categoriaPai;
  final bool isActive;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.codigoInterno,
    required this.nome,
    this.descricao,
    this.corHex,
    this.icone,
    this.categoriaPai,
    this.isActive = true,
    required this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => _$CategoryModelFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryModelToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String email;
  final String nome;
  final String? telefone;
  final String? endereco;
  final DateTime? dataNascimento;
  final String? cpf;
  final String? genero;
  final int rangeDistancia;
  final String? avatarUrl;
  final double? locationLat;
  final double? locationLng;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.nome,
    this.telefone,
    this.endereco,
    this.dataNascimento,
    this.cpf,
    this.genero,
    this.rangeDistancia = 10000,
    this.avatarUrl,
    this.locationLat,
    this.locationLng,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
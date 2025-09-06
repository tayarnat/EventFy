import 'package:json_annotation/json_annotation.dart';

part 'company_model.g.dart';

@JsonSerializable()
class CompanyModel {
  final String id;
  final String email;
  final String cnpj;
  final String nomeFantasia;
  final String? razaoSocial;
  final String? telefone;
  final String? endereco;
  final double? latitude;
  final double? longitude;
  final String? logoUrl;
  final String? website;
  final String? instagram;
  final String? facebook;
  final String? responsavelNome;
  final String? responsavelCpf;
  final String? responsavelTelefone;
  final String? responsavelEmail;
  final bool verificada;
  final DateTime? verificadaEm;
  final int totalEventsCreated;
  final double averageRating;
  final int totalFollowers;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyModel({
    required this.id,
    required this.email,
    required this.cnpj,
    required this.nomeFantasia,
    this.razaoSocial,
    this.telefone,
    this.endereco,
    this.latitude,
    this.longitude,
    this.logoUrl,
    this.website,
    this.instagram,
    this.facebook,
    this.responsavelNome,
    this.responsavelCpf,
    this.responsavelTelefone,
    this.responsavelEmail,
    this.verificada = false,
    this.verificadaEm,
    this.totalEventsCreated = 0,
    this.averageRating = 0.0,
    this.totalFollowers = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) => _$CompanyModelFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyModelToJson(this);

  CompanyModel copyWith({
    String? id,
    String? email,
    String? cnpj,
    String? nomeFantasia,
    String? razaoSocial,
    String? telefone,
    String? endereco,
    double? latitude,
    double? longitude,
    String? logoUrl,
    String? website,
    String? instagram,
    String? facebook,
    String? responsavelNome,
    String? responsavelCpf,
    String? responsavelTelefone,
    String? responsavelEmail,
    bool? verificada,
    DateTime? verificadaEm,
    int? totalEventsCreated,
    double? averageRating,
    int? totalFollowers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      email: email ?? this.email,
      cnpj: cnpj ?? this.cnpj,
      nomeFantasia: nomeFantasia ?? this.nomeFantasia,
      razaoSocial: razaoSocial ?? this.razaoSocial,
      telefone: telefone ?? this.telefone,
      endereco: endereco ?? this.endereco,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      logoUrl: logoUrl ?? this.logoUrl,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      responsavelNome: responsavelNome ?? this.responsavelNome,
      responsavelCpf: responsavelCpf ?? this.responsavelCpf,
      responsavelTelefone: responsavelTelefone ?? this.responsavelTelefone,
      responsavelEmail: responsavelEmail ?? this.responsavelEmail,
      verificada: verificada ?? this.verificada,
      verificadaEm: verificadaEm ?? this.verificadaEm,
      totalEventsCreated: totalEventsCreated ?? this.totalEventsCreated,
      averageRating: averageRating ?? this.averageRating,
      totalFollowers: totalFollowers ?? this.totalFollowers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
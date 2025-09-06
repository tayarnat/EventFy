import 'package:json_annotation/json_annotation.dart';
import 'category_model.dart';

part 'user_preference_model.g.dart';

@JsonSerializable()
class UserPreferenceModel {
  final String userId;
  final String categoryId;
  final double preferenceScore; // 0.0 a 1.0
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Categoria relacionada (será preenchida quando necessário)
  @JsonKey(includeFromJson: false, includeToJson: false)
  CategoryModel? category;

  UserPreferenceModel({
    required this.userId,
    required this.categoryId,
    required this.preferenceScore,
    this.createdAt,
    this.updatedAt,
    this.category,
  });

  factory UserPreferenceModel.fromJson(Map<String, dynamic> json) {
    return UserPreferenceModel(
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      preferenceScore: (json['preference_score'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'preference_score': preferenceScore,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Método para criar uma nova preferência
  static UserPreferenceModel create({
    required String userId,
    required String categoryId,
    required double preferenceScore,
  }) {
    final now = DateTime.now();
    return UserPreferenceModel(
      userId: userId,
      categoryId: categoryId,
      preferenceScore: preferenceScore,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Método para atualizar o score
  UserPreferenceModel copyWith({
    String? userId,
    String? categoryId,
    double? preferenceScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferenceModel(
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      preferenceScore: preferenceScore ?? this.preferenceScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferenceModel &&
        other.userId == userId &&
        other.categoryId == categoryId &&
        other.preferenceScore == preferenceScore &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
        categoryId.hashCode ^
        preferenceScore.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preference_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPreferenceModel _$UserPreferenceModelFromJson(Map<String, dynamic> json) =>
    UserPreferenceModel(
      userId: json['userId'] as String,
      categoryId: json['categoryId'] as String,
      preferenceScore: (json['preferenceScore'] as num).toDouble(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$UserPreferenceModelToJson(
  UserPreferenceModel instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'categoryId': instance.categoryId,
  'preferenceScore': instance.preferenceScore,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_review_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventReviewModel _$EventReviewModelFromJson(Map<String, dynamic> json) =>
    EventReviewModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      eventId: json['eventId'] as String,
      rating: (json['rating'] as num).toInt(),
      titulo: json['titulo'] as String?,
      comentario: json['comentario'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      helpfulVotes: (json['helpfulVotes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userName: json['userName'] as String?,
      userPhoto: json['userPhoto'] as String?,
    );

Map<String, dynamic> _$EventReviewModelToJson(EventReviewModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'eventId': instance.eventId,
      'rating': instance.rating,
      'titulo': instance.titulo,
      'comentario': instance.comentario,
      'isAnonymous': instance.isAnonymous,
      'helpfulVotes': instance.helpfulVotes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'userName': instance.userName,
      'userPhoto': instance.userPhoto,
    };

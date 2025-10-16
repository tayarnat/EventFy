import 'package:json_annotation/json_annotation.dart';

part 'event_review_model.g.dart';

@JsonSerializable()
class EventReviewModel {
  final String id;
  final String userId;
  final String eventId;
  // Título do evento, presente em RPCs agregadas (ex.: get_company_reviews)
  final String? eventTitle;
  final int rating; // 1 a 5
  final String? titulo;
  final String? comentario;
  final bool isAnonymous;
  final int helpfulVotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Dados do usuário (join)
  final String? userName;
  final String? userPhoto;
  
  EventReviewModel({
    required this.id,
    required this.userId,
    required this.eventId,
    this.eventTitle,
    required this.rating,
    this.titulo,
    this.comentario,
    this.isAnonymous = false,
    this.helpfulVotes = 0,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userPhoto,
  });

  factory EventReviewModel.fromJson(Map<String, dynamic> json) {
    return EventReviewModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      eventTitle: json['event_title'] as String?,
      rating: json['rating'] as int,
      titulo: json['titulo'] as String?,
      comentario: json['comentario'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      helpfulVotes: json['helpful_votes'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userName: json['user_name'] as String?,
      userPhoto: json['user_photo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'event_id': eventId,
    'rating': rating,
    'titulo': titulo,
    'comentario': comentario,
    'is_anonymous': isAnonymous,
  };

  // Método para criar uma nova avaliação
  factory EventReviewModel.create({
    required String userId,
    required String eventId,
    required int rating,
    String? titulo,
    String? comentario,
    bool isAnonymous = false,
  }) {
    final now = DateTime.now();
    return EventReviewModel(
      id: '', // Será gerado pelo banco
      userId: userId,
      eventId: eventId,
      rating: rating,
      titulo: titulo,
      comentario: comentario,
      isAnonymous: isAnonymous,
      helpfulVotes: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  EventReviewModel copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? eventTitle,
    int? rating,
    String? titulo,
    String? comentario,
    bool? isAnonymous,
    int? helpfulVotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userPhoto,
  }) {
    return EventReviewModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      eventTitle: eventTitle ?? this.eventTitle,
      rating: rating ?? this.rating,
      titulo: titulo ?? this.titulo,
      comentario: comentario ?? this.comentario,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventReviewModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'EventReviewModel(id: $id, rating: $rating, titulo: $titulo)';
  }
}
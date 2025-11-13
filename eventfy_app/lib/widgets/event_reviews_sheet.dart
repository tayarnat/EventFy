import 'package:flutter/material.dart';
import '../core/config/supabase_config.dart';
import '../models/event_model.dart';
import '../models/event_review_model.dart';

class EventReviewsSheet extends StatefulWidget {
  final EventModel event;

  const EventReviewsSheet({Key? key, required this.event}) : super(key: key);

  @override
  State<EventReviewsSheet> createState() => _EventReviewsSheetState();
}

class _EventReviewsSheetState extends State<EventReviewsSheet> {
  List<EventReviewModel> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await supabase.rpc('get_event_reviews_with_user', params: {
        'p_event_id': widget.event.id,
        'p_limit': 100,
        'p_offset': 0,
      });
      final list = (res as List)
          .map((e) => EventReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _reviews = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar avaliações: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Avaliações',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.event.titulo,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(icon: Icons.star, title: 'Nota Média',
                      value: widget.event.averageRating?.toStringAsFixed(1) ?? '0.0'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(icon: Icons.rate_review, title: 'Avaliações',
                      value: '${widget.event.totalReviews}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _reviews.isEmpty
                        ? const Center(child: Text('Nenhuma avaliação ainda'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _reviews.length,
                            itemBuilder: (context, i) => _ReviewItem(review: _reviews[i]),
                          ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Stat({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final EventReviewModel review;
  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: review.userPhoto != null ? NetworkImage(review.userPhoto!) : null,
                  child: review.userPhoto == null
                      ? Text(
                          review.isAnonymous
                              ? 'A'
                              : (review.userName?.substring(0, 1).toUpperCase() ?? 'U'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.isAnonymous ? 'Usuário Anônimo' : (review.userName ?? 'Usuário'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: List.generate(5, (i) => Icon(
                              i < review.rating ? Icons.star : Icons.star_border,
                              size: 14,
                              color: Colors.amber,
                            )),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (review.titulo != null && review.titulo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.titulo!, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            if (review.comentario != null && review.comentario!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.comentario!, style: TextStyle(color: Colors.grey[700])),
            ],
          ],
        ),
      ),
    );
  }
}
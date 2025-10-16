import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/supabase_config.dart';
import '../models/event_model.dart';
import '../providers/auth_provider.dart';

class RateEventSheet extends StatefulWidget {
  final EventModel event;

  const RateEventSheet({Key? key, required this.event}) : super(key: key);

  @override
  State<RateEventSheet> createState() => _RateEventSheetState();
}

class _RateEventSheetState extends State<RateEventSheet> {
  int _rating = 0; // 1-5
  final TextEditingController _commentController = TextEditingController();
  bool _anonymous = false;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Selecione uma nota de 1 a 5 estrelas');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'Usuário não autenticado';
          _submitting = false;
        });
        return;
      }

      // Evitar avaliações duplicadas
      final existing = await supabase
          .from('event_reviews')
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', widget.event.id)
          .limit(1);

      if (existing is List && existing.isNotEmpty) {
        setState(() {
          _error = 'Você já avaliou este evento';
          _submitting = false;
        });
        return;
      }

      await supabase.from('event_reviews').insert({
        'user_id': userId,
        'event_id': widget.event.id,
        'rating': _rating,
        'titulo': null,
        'comentario': _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        'is_anonymous': _anonymous,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação enviada com sucesso')), 
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Erro ao enviar avaliação: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Avaliar Evento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.event.titulo,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Estrelas
            Row(
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _rating = starIndex),
                );
              }),
            ),
            const SizedBox(height: 8),
            // Comentário
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Comentário (opcional)',
                border: OutlineInputBorder(),
              ),
              enabled: !_submitting,
            ),
            const SizedBox(height: 8),
            // Anônimo
            Row(
              children: [
                Switch(
                  value: _anonymous,
                  onChanged: _submitting ? null : (v) => setState(() => _anonymous = v),
                ),
                const Text('Enviar como anônimo'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.send),
                label: _submitting
                    ? const Text('Enviando...')
                    : const Text('Enviar avaliação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
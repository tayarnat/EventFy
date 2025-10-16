import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/supabase_config.dart';
import '../../models/event_review_model.dart';
import '../../providers/auth_provider.dart';

class CompanyReviewsScreen extends StatefulWidget {
  const CompanyReviewsScreen({Key? key}) : super(key: key);

  @override
  State<CompanyReviewsScreen> createState() => _CompanyReviewsScreenState();
}

class _CompanyReviewsScreenState extends State<CompanyReviewsScreen> {
  bool _loading = true;
  String? _error;
  List<EventReviewModel> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final company = auth.currentCompany;
      if (company == null) {
        throw Exception('Empresa não encontrada');
      }

      final res = await supabase.rpc('get_company_reviews', params: {
        'p_company_id': company.id,
        'p_limit': 200,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliações dos meus eventos'),
        actions: [
          IconButton(onPressed: _loadReviews, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ))
              : _reviews.isEmpty
                  ? const Center(child: Text('Nenhuma avaliação encontrada'))
                  : ListView.separated(
                      itemCount: _reviews.length,
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = _reviews[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.eventTitle ?? 'Evento',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (i) => Icon(
                                            i < r.rating ? Icons.star : Icons.star_border,
                                            size: 16,
                                            color: Colors.amber,
                                          )),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(r.isAnonymous ? 'Usuário Anônimo' : (r.userName ?? 'Usuário'),
                                    style: TextStyle(color: Colors.grey[700])),
                                if (r.titulo != null && r.titulo!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(r.titulo!, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                if (r.comentario != null && r.comentario!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(r.comentario!),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
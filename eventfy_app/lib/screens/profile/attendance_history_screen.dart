import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/supabase_config.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/event_card.dart';
import '../../widgets/rate_event_sheet.dart';
import '../../widgets/event_reviews_sheet.dart';
import '../event/event_details_screen.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _eventData = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _eventData = [];
          _loading = false;
        });
        return;
      }

      // Buscar todas as participações (confirmadas e intenções) e juntar com eventos
      final response = await supabase
          .from('event_attendances')
          .select('''
            status,
            checked_in_at,
            updated_at,
            events!inner(*)
          ''')
          .eq('user_id', userId)
          .or('status.eq.compareceu,status.eq.confirmado,status.eq.nao_compareceu')
          .order('updated_at', ascending: false);

      final List<Map<String, dynamic>> parsed = [];
      for (final item in (response as List<dynamic>)) {
        final eventData = Map<String, dynamic>.from(item['events'] as Map);
        final attendanceStatus = item['status'] as String;
        final checkedInAt = item['checked_in_at'];
        final updatedAt = item['updated_at'];

        // Converter localização WKB (se vier como string hex) para lat/lng
        final locationData = eventData['location'];
        if (locationData is String && locationData.isNotEmpty) {
          final coords = _parseWkbPoint(locationData);
          if (coords != null) {
            eventData['latitude'] = coords['lat'];
            eventData['longitude'] = coords['lng'];
          }
        }

        parsed.add({
          'event': EventModel.fromJson(eventData),
          'status': attendanceStatus,
          'checked_in_at': checkedInAt,
          'updated_at': updatedAt,
        });
      }

      setState(() {
        _eventData = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar histórico: $e';
        _loading = false;
      });
    }
  }

  // Decodificador WKB POINT (hex) similar ao usado em EventsProvider
  Map<String, double>? _parseWkbPoint(String wkbHex) {
    try {
      if (wkbHex.startsWith('0x')) {
        wkbHex = wkbHex.substring(2);
      }
      if (wkbHex.length < 42) {
        return null;
      }
      if (!wkbHex.startsWith('0101000020')) {
        return null;
      }
      final coordsHex = wkbHex.substring(18);
      if (coordsHex.length < 32) {
        return null;
      }
      final lngHex = coordsHex.substring(0, 16);
      final latHex = coordsHex.substring(16, 32);
      final lng = _hexToDouble(lngHex);
      final lat = _hexToDouble(latHex);
      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }

  double _hexToDouble(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    final byteData = ByteData(8);
    for (int i = 0; i < 8; i++) {
      byteData.setUint8(i, bytes[i]);
    }
    return byteData.getFloat64(0, Endian.little);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Eventos'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_eventData.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.history, size: 72, color: Colors.grey),
                SizedBox(height: 12),
                Text('Você ainda não tem participações em eventos.'),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: _eventData.length,
      itemBuilder: (context, index) {
        final data = _eventData[index];
        final event = data['event'] as EventModel;
        final status = data['status'] as String;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              CompactEventCard(
                event: event,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: status == 'compareceu'
                      ? Colors.green.shade50
                      : status == 'nao_compareceu'
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'compareceu'
                              ? Icons.check_circle
                              : status == 'nao_compareceu'
                                  ? Icons.cancel
                                  : Icons.schedule,
                          size: 16,
                          color: status == 'compareceu'
                              ? Colors.green
                              : status == 'nao_compareceu'
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                        Flexible(
                          child: Text(
                            status == 'compareceu'
                                ? 'Presença confirmada'
                                : status == 'nao_compareceu'
                                    ? 'Não compareceu'
                                    : 'Vai participar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: status == 'compareceu'
                                  ? Colors.green.shade700
                                  : status == 'nao_compareceu'
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Builder(builder: (context) {
                          final now = DateTime.now();
                          final windowOpen = now.isBefore(event.dataFim.add(const Duration(days: 30)));
                          final userAttended = status == 'compareceu';
                          final showEvaluate = userAttended && windowOpen;
                          final showReviews = true; // disponível para qualquer evento concluído

                          return Row(children: [
                            if (showEvaluate)
                              FutureBuilder<List<dynamic>>(
                                future: () async {
                                  final auth = Provider.of<AuthProvider>(context, listen: false);
                                  final userId = auth.currentUser?.id;
                                  if (userId == null) return const [];
                                  final existing = await supabase
                                      .from('event_reviews')
                                      .select('event_id')
                                      .eq('user_id', userId)
                                      .eq('event_id', event.id)
                                      .limit(1);
                                  return existing is List ? existing : const [];
                                }(),
                                builder: (context, snapshot) {
                                  final alreadyReviewed = (snapshot.data ?? const []).isNotEmpty;
                                  final disabled = alreadyReviewed || (!windowOpen);
                                  return Tooltip(
                                    message: alreadyReviewed
                                        ? 'Você já avaliou este evento'
                                        : (!windowOpen)
                                            ? 'Período de avaliação encerrado'
                                            : 'Avaliar evento',
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.rate_review, size: 16),
                                      label: const Text('Avaliar'),
                                      onPressed: disabled
                                          ? null
                                          : () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                builder: (context) => DraggableScrollableSheet(
                                                  initialChildSize: 0.6,
                                                  minChildSize: 0.4,
                                                  maxChildSize: 0.9,
                                                  builder: (context, scrollController) {
                                                    return SingleChildScrollView(
                                                      controller: scrollController,
                                                      child: RateEventSheet(event: event),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                    ),
                                  );
                                },
                              ),
                            if (showEvaluate && showReviews) const SizedBox(width: 8),
                            if (showReviews)
                              TextButton.icon(
                                icon: const Icon(Icons.list_alt, size: 16),
                                label: const Text('Avaliações'),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => DraggableScrollableSheet(
                                      initialChildSize: 0.7,
                                      minChildSize: 0.4,
                                      maxChildSize: 0.95,
                                      builder: (context, scrollController) {
                                        return SingleChildScrollView(
                                          controller: scrollController,
                                          child: EventReviewsSheet(event: event),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                          ]);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

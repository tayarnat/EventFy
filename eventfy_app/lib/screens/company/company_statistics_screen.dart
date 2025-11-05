import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' as io;

import '../../core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../models/event_review_model.dart';
import 'company_reviews_screen.dart';
import 'company_period_report_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;

class CompanyStatisticsScreen extends StatefulWidget {
  @override
  _CompanyStatisticsScreenState createState() => _CompanyStatisticsScreenState();
}

class _CompanyStatisticsScreenState extends State<CompanyStatisticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  String? _errorMessage;
  List<EventReviewModel> _companyReviews = [];
  // Relatório por período
  DateTimeRange? _selectedRange;
  bool _reportLoading = false;
  Map<String, dynamic>? _periodReport; // resultado do RPC get_company_period_report
  List<Map<String, dynamic>> _monthlyStats = []; // resultado do RPC get_company_monthly_stats
  final GlobalKey _reportKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }
  
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final company = authProvider.currentCompany;
      
      if (company == null) {
        throw Exception('Empresa não encontrada');
      }
      
      // Buscar estatísticas dos eventos diretamente da tabela 'events'
      // Importante: a view events_complete filtra apenas status = 'ativo',
      // então não serve para contar finalizados/cancelados.
      final eventsResponse = await supabase
          .from('events')
          .select('id, status, total_attended, average_rating, total_reviews')
          .eq('company_id', company.id);
      
      final events = eventsResponse as List;
      debugPrint('CompanyStatistics: eventos retornados=${events.length}');
      
      // Calcular estatísticas
      int totalEvents = events.length;
      int activeEvents = events.where((e) => e['status'] == 'ativo').length;
      debugPrint('CompanyStatistics: activeEvents=$activeEvents');
      int finishedEvents = events.where((e) => e['status'] == 'finalizado').length;
      debugPrint('CompanyStatistics: finishedEvents=$finishedEvents');
      int cancelledEvents = events.where((e) => e['status'] == 'cancelado').length;
      debugPrint('CompanyStatistics: cancelledEvents=$cancelledEvents');
      
      // Total de participantes que compareceram: contar somente status 'compareceu'
      final eventIds = events.map((e) => e['id']).whereType<String>().toList();
      int totalParticipants = 0;
      if (eventIds.isNotEmpty) {
        var query = supabase
            .from('event_attendances')
            .select('event_id')
            .eq('status', 'compareceu');

        if (eventIds.length == 1) {
          // Compatível com qualquer versão do PostgrestFilterBuilder
          debugPrint('CompanyStatistics: usando eq para único event_id=${eventIds.first}');
          query = query.eq('event_id', eventIds.first);
        } else {
          // Fallback compatível: usar OR com múltiplos eq
          final orFilter = eventIds.map((id) => 'event_id.eq.$id').join(',');
          debugPrint('CompanyStatistics: usando or filter: $orFilter');
          query = query.or(orFilter);
        }

        final attendancesResponse = await query;
        totalParticipants = (attendancesResponse as List).length;
      }
      debugPrint('CompanyStatistics: totalParticipants(compareceu)=$totalParticipants');
      
      double averageRating = 0.0;
      int totalReviews = 0;
      
      if (events.isNotEmpty) {
        final eventsWithRating = events.where((e) => 
            e['average_rating'] != null && e['total_reviews'] != null && e['total_reviews'] > 0);
        
        if (eventsWithRating.isNotEmpty) {
          double totalRatingSum = 0.0;
          int totalReviewsSum = 0;
          
          for (var event in eventsWithRating) {
            final rating = event['average_rating'] as double? ?? 0.0;
            final reviews = event['total_reviews'] as int? ?? 0;
            
            totalRatingSum += rating * reviews;
            totalReviewsSum += reviews;
          }
          
          if (totalReviewsSum > 0) {
            averageRating = totalRatingSum / totalReviewsSum;
          }
          
          totalReviews = totalReviewsSum;
        }
      }
      
      // Buscar eventos por mês (últimos 6 meses)
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final monthlyEventsResponse = await supabase
          .from('events')
          .select('created_at')
          .eq('company_id', company.id)
          .gte('created_at', sixMonthsAgo.toIso8601String());
      
      final monthlyEvents = monthlyEventsResponse as List;
      Map<String, int> eventsByMonth = {};
      
      for (var event in monthlyEvents) {
        final createdAt = DateTime.parse(event['created_at']);
        final monthKey = '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
        eventsByMonth[monthKey] = (eventsByMonth[monthKey] ?? 0) + 1;
      }
      
      // Buscar avaliações recentes dos eventos da empresa via RPC SECURITY DEFINER
      try {
        final reviewsRes = await supabase.rpc('get_company_reviews', params: {
          'p_company_id': company.id,
          'p_limit': 50,
          'p_offset': 0,
        });
        final reviews = (reviewsRes as List)
            .map((e) => EventReviewModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _companyReviews = reviews;
      } catch (e) {
        debugPrint('CompanyStatistics: erro ao carregar reviews: $e');
        _companyReviews = [];
      }

      setState(() {
        _statistics = {
          'totalEvents': totalEvents,
          'activeEvents': activeEvents,
          'finishedEvents': finishedEvents,
          'cancelledEvents': cancelledEvents,
          'totalParticipants': totalParticipants,
          'averageRating': averageRating,
          'totalReviews': totalReviews,
          'eventsByMonth': eventsByMonth,
        };
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar estatísticas: $e';
        _isLoading = false;
      });
      
      NotificationService.instance.showError(
        'Erro ao carregar estatísticas: $e'
      );
    }
  }

  // Seletor de faixa de datas
  Future<void> _pickDateRange() async {
    final initialDateRange = _selectedRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialDateRange,
      saveText: 'Aplicar',
      helpText: 'Selecione o período do relatório',
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  void _setQuickRange(Duration duration, {bool alignToMonth = false}) {
    final now = DateTime.now();
    DateTime start = now.subtract(duration);
    DateTime end = now;
    if (alignToMonth) {
      start = DateTime(now.year, now.month, 1);
      // fim do mês inclusive (23:59:59.999999 do último dia)
      end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));
    }
    setState(() {
      _selectedRange = DateTimeRange(start: start, end: end);
    });
  }

  Future<void> _generatePeriodReport() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final company = authProvider.currentCompany;
    if (company == null) {
      NotificationService.instance.showError('Empresa não encontrada');
      return;
    }
    final range = _selectedRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    setState(() {
      _reportLoading = true;
    });
    try {
      final startIso = range.start.toUtc().toIso8601String();
      final endIso = range.end.toUtc().toIso8601String();

      // RPC: relatório por período
      final reportRes = await supabase.rpc('get_company_period_report', params: {
        'p_company_id': company.id,
        'p_start': startIso,
        'p_end': endIso,
      });

      Map<String, dynamic> periodData;
      if (reportRes is List && reportRes.isNotEmpty) {
        periodData = reportRes.first as Map<String, dynamic>;
      } else if (reportRes is Map<String, dynamic>) {
        periodData = reportRes;
      } else {
        periodData = {};
      }

      // RPC: estatísticas mensais (últimos 6 meses)
      final monthlyRes = await supabase.rpc('get_company_monthly_stats', params: {
        'p_company_id': company.id,
        'p_months': 6,
      });
      final monthlyList = (monthlyRes as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

      setState(() {
        _periodReport = periodData;
        _monthlyStats = monthlyList;
      });
    } catch (e) {
      NotificationService.instance.showError('Erro ao gerar relatório: $e');
    } finally {
      setState(() {
        _reportLoading = false;
      });
    }
  }

  Future<Uint8List?> _captureReportImageBytes() async {
    try {
      final boundary = _reportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      NotificationService.instance.showError('Falha ao capturar imagem do relatório: $e');
      return null;
    }
  }

  Future<void> _downloadReportAsImage() async {
    final pngBytes = await _captureReportImageBytes();
    if (pngBytes == null) return;
    if (kIsWeb) {
      // No web, usar Printing.sharePdf para PDF; imagem download direto requer lógica web específica
      NotificationService.instance.showWarning('Download de imagem não é suportado no Web por enquanto. Use PDF.');
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/relatorio_eventfy_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = io.File(filePath);
      await file.writeAsBytes(pngBytes);
      NotificationService.instance.showSuccess('Imagem salva em: $filePath');
    } catch (e) {
      NotificationService.instance.showError('Erro ao salvar imagem: $e');
    }
  }

  Future<void> _downloadReportAsPdf() async {
    try {
      // Gera imagem do bloco e embute em PDF
      final pngBytes = await _captureReportImageBytes();
      if (pngBytes == null) return;
      final doc = pw.Document();
      final image = pw.MemoryImage(pngBytes);
      doc.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(children: [
              pw.Text('Relatório de Estatísticas da Empresa', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Image(image, fit: pw.BoxFit.contain),
            ]);
          },
        ),
      );

      if (kIsWeb) {
        await Printing.sharePdf(bytes: await doc.save(), filename: 'relatorio_eventfy.pdf');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/relatorio_eventfy_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = io.File(filePath);
      await file.writeAsBytes(await doc.save());
      NotificationService.instance.showSuccess('PDF salvo em: $filePath');
    } catch (e) {
      NotificationService.instance.showError('Erro ao gerar/salvar PDF: $e');
    }
  }

  Future<void> _printReport() async {
    try {
      final pngBytes = await _captureReportImageBytes();
      if (pngBytes == null) return;
      await Printing.layoutPdf(onLayout: (pdf.PdfPageFormat format) async {
        final doc = pw.Document();
        final image = pw.MemoryImage(pngBytes);
        doc.addPage(
          pw.Page(pageFormat: format, build: (pw.Context context) {
            return pw.Image(image, fit: pw.BoxFit.contain);
          }),
        );
        return await doc.save();
      });
    } catch (e) {
      NotificationService.instance.showError('Erro ao imprimir: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatistics,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatistics,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Resumo geral com botão de acesso ao relatório por período
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Resumo Geral',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Relatório por período'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CompanyPeriodReportScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Cards de estatísticas principais
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.event,
                              title: 'Total de Eventos',
                              value: '${_statistics['totalEvents'] ?? 0}',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.people,
                              title: 'Participantes',
                              value: '${_statistics['totalParticipants'] ?? 0}',
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.star,
                              title: 'Avaliação Média',
                              value: '${(_statistics['averageRating'] as double? ?? 0.0).toStringAsFixed(1)}',
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.rate_review,
                              title: 'Total Avaliações',
                              value: '${_statistics['totalReviews'] ?? 0}',
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      // Avaliações recentes
                      const Text(
                        'Avaliações Recentes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _companyReviews.isEmpty
                              ? const Text('Nenhuma avaliação encontrada', style: TextStyle(color: Colors.grey))
                              : Column(
                                  children: _companyReviews.take(10).map((r) => _ReviewRow(review: r)).toList(),
                                ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Ver todas as avaliações'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CompanyReviewsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Status dos eventos
                      const Text(
                        'Status dos Eventos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _StatusRow(
                                label: 'Eventos Ativos',
                                value: _statistics['activeEvents'] ?? 0,
                                color: Colors.green,
                                icon: Icons.play_circle,
                              ),
                              const Divider(),
                              _StatusRow(
                                label: 'Eventos Finalizados',
                                value: _statistics['finishedEvents'] ?? 0,
                                color: Colors.blue,
                                icon: Icons.check_circle,
                              ),
                              const Divider(),
                              _StatusRow(
                                label: 'Eventos Cancelados',
                                value: _statistics['cancelledEvents'] ?? 0,
                                color: Colors.red,
                                icon: Icons.cancel,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Eventos por mês
                      const Text(
                        'Eventos Criados (Últimos 6 Meses)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if ((_statistics['eventsByMonth'] as Map<String, int>? ?? {}).isEmpty)
                                const Text(
                                  'Nenhum evento criado nos últimos 6 meses',
                                  style: TextStyle(color: Colors.grey),
                                )
                              else
                                ...(_statistics['eventsByMonth'] as Map<String, int>)
                                    .entries
                                    .map((entry) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                entry.key,
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${entry.value}',
                                                  style: TextStyle(
                                                    color: Theme.of(context).primaryColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

// Widget para card de estatística
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para linha de status
class _StatusRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// Linha de avaliação resumida
class _ReviewRow extends StatelessWidget {
  final EventReviewModel review;
  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor,
            backgroundImage: review.userPhoto != null ? NetworkImage(review.userPhoto!) : null,
            child: review.userPhoto == null
                ? Text(
                    review.isAnonymous ? 'A' : (review.userName?.substring(0, 1).toUpperCase() ?? 'U'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.isAnonymous ? 'Usuário Anônimo' : (review.userName ?? 'Usuário'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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
                if (review.eventTitle != null && review.eventTitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      review.eventTitle!,
                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                if (review.titulo != null && review.titulo!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(review.titulo!, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                if (review.comentario != null && review.comentario!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(review.comentario!, style: TextStyle(color: Colors.grey[700])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Chip que mostra valor e delta (aumento/diminuição)
class _DeltaChip extends StatelessWidget {
  final String label;
  final dynamic value; // pode ser int ou String (double formatado)
  final dynamic delta; // int ou double
  final bool isDouble;

  const _DeltaChip({
    required this.label,
    required this.value,
    required this.delta,
    this.isDouble = false,
  });

  @override
  Widget build(BuildContext context) {
    final double deltaVal = (delta is num) ? (delta as num).toDouble() : double.tryParse('$delta') ?? 0.0;
    final bool up = deltaVal > 0.0001;
    final bool down = deltaVal < -0.0001;
    final Color color = up
        ? Colors.green
        : (down ? Colors.red : Colors.grey);
    final IconData icon = up
        ? Icons.trending_up
        : (down ? Icons.trending_down : Icons.horizontal_rule);
    final String deltaStr = isDouble ? deltaVal.toStringAsFixed(2) : deltaVal.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: $value', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 2),
          Text(deltaStr, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
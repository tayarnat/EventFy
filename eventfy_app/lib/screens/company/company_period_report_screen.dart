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
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;

class CompanyPeriodReportScreen extends StatefulWidget {
  const CompanyPeriodReportScreen({Key? key}) : super(key: key);

  @override
  State<CompanyPeriodReportScreen> createState() => _CompanyPeriodReportScreenState();
}

class _CompanyPeriodReportScreenState extends State<CompanyPeriodReportScreen> {
  DateTimeRange? _selectedRange;
  bool _reportLoading = false;
  Map<String, dynamic>? _periodReport; // resultado do RPC get_company_period_report
  List<Map<String, dynamic>> _monthlyStats = []; // resultado do RPC get_company_monthly_progress
  List<Map<String, dynamic>> _monthlyStatsFiltered = []; // mesma lista sem o mês atual
  final GlobalKey _reportKey = GlobalKey();
  int _selectedMonthIndex = 0;
  bool _monthlyLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMonthlyStats();
  }

  Future<void> _loadMonthlyStats({DateTimeRange? range}) async {
    setState(() {
      _monthlyLoading = true;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final company = authProvider.currentCompany;
      if (company == null) {
        NotificationService.instance.showError('Empresa não encontrada');
        return;
      }
      // Se um período estiver selecionado, alinhar meses ao intervalo selecionado
      String? startIso;
      String? endIso;
      if (range != null) {
        final startMonth = _firstDayOfMonth(range.start).toUtc();
        final endMonth = _firstDayOfMonth(range.end).toUtc();
        startIso = startMonth.toIso8601String();
        endIso = endMonth.toIso8601String();
      } else if (_selectedRange != null) {
        final startMonth = _firstDayOfMonth(_selectedRange!.start).toUtc();
        final endMonth = _firstDayOfMonth(_selectedRange!.end).toUtc();
        startIso = startMonth.toIso8601String();
        endIso = endMonth.toIso8601String();
      }

      final Map<String, dynamic> params = {
        'p_company_id': company.id,
        'p_start_month': startIso, // sempre envia, mesmo null, para desambiguar overload
        'p_end_month': endIso,     // sempre envia, mesmo null
        'p_months': 12, // fallback quando não houver eventos e nenhum período: usa últimos 12 meses
        'p_from_first_event': true,
      };

      final monthlyRes = await supabase.rpc('get_company_monthly_progress', params: params);
      final monthlyList = (monthlyRes as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      // Filtrar para não mostrar o mês atual no comparativo APENAS se o período terminar no mês corrente.
      final now = DateTime.now();
      final nowLabel = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      final bool endsInCurrentMonth = (() {
        final r = range ?? _selectedRange;
        if (r == null) return true; // quando não há período, manter comportamento anterior e ocultar mês corrente
        return r.end.year == now.year && r.end.month == now.month;
      })();
      List<Map<String, dynamic>> filtered = endsInCurrentMonth
          ? monthlyList.where((m) => (m['month_label'] as String?) != nowLabel).toList()
          : monthlyList;
      // Caso o filtro remova todos os meses (ex.: selecionar apenas o mês corrente), mantenha a lista original
      if (filtered.isEmpty && monthlyList.isNotEmpty) {
        filtered = monthlyList;
      }

      setState(() {
        _monthlyStats = monthlyList;
        _monthlyStatsFiltered = filtered;
        _selectedMonthIndex = filtered.isNotEmpty ? filtered.length - 1 : 0; // último mês disponível (mais recente, sem o atual)
      });
    } catch (e) {
      NotificationService.instance.showError('Erro ao carregar comparativo mensal: $e');
    } finally {
      setState(() {
        _monthlyLoading = false;
      });
    }
  }

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
      // Gera automaticamente ao escolher o período, para uma UX mais fluida
      await _generatePeriodReport();
      await _loadMonthlyStats(range: picked);
    }
  }

  // Helpers de mês
  DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _lastDayOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 1).subtract(const Duration(microseconds: 1));

  void _setQuickRangeMonths(int monthsCount) {
    final now = DateTime.now();
    final startMonth = DateTime(now.year, now.month - (monthsCount - 1), 1);
    final start = _firstDayOfMonth(startMonth);
    final end = _lastDayOfMonth(now);
    setState(() {
      _selectedRange = DateTimeRange(start: start, end: end);
    });
    // Atualiza relatório e progresso mensal com o novo período
    _generatePeriodReport();
    _loadMonthlyStats(range: _selectedRange);
  }

  Future<void> _pickMonthRangeQuick() async {
    final now = DateTime.now();
    int startYear = now.year;
    int startMonth = now.month;
    int endYear = now.year;
    int endMonth = now.month;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecionar intervalo por meses'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              Widget buildMonthDropdown(int currentValue, void Function(int?) onChanged) {
                return DropdownButton<int>(
                  value: currentValue,
                  items: List.generate(12, (i) {
                    final m = i + 1;
                    return DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')));
                  }),
                  onChanged: onChanged,
                );
              }

              Widget buildYearDropdown(int currentValue, void Function(int?) onChanged) {
                final years = List.generate(6, (i) => now.year - i);
                return DropdownButton<int>(
                  value: currentValue,
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                  onChanged: onChanged,
                );
              }

              final isValid = (DateTime(startYear, startMonth).compareTo(DateTime(endYear, endMonth)) <= 0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Início'),
                  Row(
                    children: [
                      buildMonthDropdown(startMonth, (v) => setStateDialog(() => startMonth = v ?? startMonth)),
                      const SizedBox(width: 12),
                      buildYearDropdown(startYear, (v) => setStateDialog(() => startYear = v ?? startYear)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Fim'),
                  Row(
                    children: [
                      buildMonthDropdown(endMonth, (v) => setStateDialog(() => endMonth = v ?? endMonth)),
                      const SizedBox(width: 12),
                      buildYearDropdown(endYear, (v) => setStateDialog(() => endYear = v ?? endYear)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isValid) const Text('O fim deve ser igual ou após o início', style: TextStyle(color: Colors.red)),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final start = _firstDayOfMonth(DateTime(startYear, startMonth));
                final end = _lastDayOfMonth(DateTime(endYear, endMonth));
                setState(() {
                  _selectedRange = DateTimeRange(start: start, end: end);
                });
                Navigator.of(context).pop();
                _generatePeriodReport();
                _loadMonthlyStats(range: _selectedRange);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
  }

  // A soma cumulativa agora é fornecida pelo RPC (events_cumulative, confirmed_cumulative, attended_cumulative, reviews_cumulative)

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

      setState(() {
        _periodReport = periodData;
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
        title: const Text('Relatório por Período'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Este mês'),
                onPressed: () => _setQuickRangeMonths(1),
              ),
              ActionChip(
                label: const Text('Últimos 6 meses'),
                onPressed: () => _setQuickRangeMonths(6),
              ),
              ActionChip(
                label: const Text('Personalizar rápido (meses)'),
                onPressed: _pickMonthRangeQuick,
              ),
              ActionChip(
                label: const Text('Personalizar período (dias)'),
                onPressed: _pickDateRange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedRange == null
                      ? 'Período não selecionado'
                      : 'Período: ${_selectedRange!.start.day.toString().padLeft(2, '0')}/${_selectedRange!.start.month.toString().padLeft(2, '0')}/${_selectedRange!.start.year} - ${_selectedRange!.end.day.toString().padLeft(2, '0')}/${_selectedRange!.end.month.toString().padLeft(2, '0')}/${_selectedRange!.end.year}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _reportLoading ? null : _generatePeriodReport,
                icon: const Icon(Icons.analytics_outlined),
                label: _reportLoading ? const Text('Gerando...') : const Text('Gerar Relatório'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _reportKey,
            child: _periodReport == null
                ? const Text(
                    'Nenhum relatório gerado ainda. Selecione um período e clique em "Gerar Relatório".',
                    style: TextStyle(color: Colors.grey),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.event_available,
                              title: 'Eventos (período)',
                              value: '${_periodReport!['total_events'] ?? 0}',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.people_alt,
                              title: 'Confirmados',
                              value: '${_periodReport!['total_confirmed'] ?? 0}',
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.how_to_reg,
                              title: 'Compareceram',
                              value: '${_periodReport!['total_attended'] ?? 0}',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.star_half,
                              title: 'Média Avaliações',
                              value: '${(_periodReport!['average_rating'] ?? 0.0).toStringAsFixed(2)}',
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.reviews,
                              title: 'Total de Reviews',
                              value: '${_periodReport!['total_reviews'] ?? 0}',
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.cancel_outlined,
                              title: 'Cancelados (período)',
                              value: '${_periodReport!['events_cancelled'] ?? 0}',
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text(
                          'Progresso entre meses',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        children: [
                          if (_monthlyLoading)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_monthlyStatsFiltered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Sem dados mensais disponíveis', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Mês anterior',
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: _selectedMonthIndex > 0 ? () => setState(() => _selectedMonthIndex--) : null,
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            '${_monthlyStatsFiltered[_selectedMonthIndex]['month_label']}',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Próximo mês',
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: _selectedMonthIndex < _monthlyStatsFiltered.length - 1 ? () => setState(() => _selectedMonthIndex++) : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      // Valores cumulativos (base -> atual) e delta mês-a-mês (positivos ou negativos)
                                      final Map<String, dynamic> current = _monthlyStatsFiltered[_selectedMonthIndex];
                                      final Map<String, dynamic>? prev = _selectedMonthIndex > 0 ? _monthlyStatsFiltered[_selectedMonthIndex - 1] : null;

                                      // Cumulativos para exibição base → atual
                                      final int baseEvents = prev != null ? (((prev['events_cumulative'] as num?) ?? 0).toInt()) : 0;
                                      final int currEvents = ((current['events_cumulative'] as num?) ?? 0).toInt();

                                      final int baseConfirmed = prev != null ? (((prev['confirmed_cumulative'] as num?) ?? 0).toInt()) : 0;
                                      final int currConfirmed = ((current['confirmed_cumulative'] as num?) ?? 0).toInt();

                                      final int baseAttended = prev != null ? (((prev['attended_cumulative'] as num?) ?? 0).toInt()) : 0;
                                      final int currAttended = ((current['attended_cumulative'] as num?) ?? 0).toInt();

                                      final int baseReviews = prev != null ? (((prev['reviews_cumulative'] as num?) ?? 0).toInt()) : 0;
                                      final int currReviews = ((current['reviews_cumulative'] as num?) ?? 0).toInt();

                                      // Deltas mês-a-mês
                                      final int eventsDelta = _selectedMonthIndex > 0
                                          ? (((current['events_month'] as num?) ?? 0).toInt() - (((prev?['events_month'] as num?) ?? 0).toInt()))
                                          : 0;
                                      final int confirmedDelta = _selectedMonthIndex > 0
                                          ? (((current['confirmed_month'] as num?) ?? 0).toInt() - (((prev?['confirmed_month'] as num?) ?? 0).toInt()))
                                          : 0;
                                      final int attendedDelta = _selectedMonthIndex > 0
                                          ? (((current['attended_month'] as num?) ?? 0).toInt() - (((prev?['attended_month'] as num?) ?? 0).toInt()))
                                          : 0;
                                      final int reviewsDelta = _selectedMonthIndex > 0
                                          ? (((current['reviews_month'] as num?) ?? 0).toInt() - (((prev?['reviews_month'] as num?) ?? 0).toInt()))
                                          : 0;

                                      // Média: mês atual vs mês anterior
                                      final double prevAvgRating = (((current['average_rating_prev'] as num?) ?? 0.0).toDouble());
                                      final double currAvgRating = (((current['average_rating_month'] as num?) ?? 0.0).toDouble());
                                      final double avgDelta = _selectedMonthIndex > 0 ? (currAvgRating - prevAvgRating) : 0.0;

                                      return Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _ProgressChip(label: 'Eventos', baseValue: baseEvents, currentValue: currEvents, overrideDelta: eventsDelta),
                                          _ProgressChip(label: 'Confirmados', baseValue: baseConfirmed, currentValue: currConfirmed, overrideDelta: confirmedDelta),
                                          _ProgressChip(label: 'Compareceram', baseValue: baseAttended, currentValue: currAttended, overrideDelta: attendedDelta),
                                          _ProgressChip(label: 'Reviews', baseValue: baseReviews, currentValue: currReviews, overrideDelta: reviewsDelta),
                                          _ProgressChip(label: 'Média ★', baseValue: prevAvgRating, currentValue: currAvgRating, isDouble: true, overrideDelta: avgDelta),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: const Text('Baixar como Imagem'),
                onPressed: _downloadReportAsImage,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Baixar PDF'),
                onPressed: _downloadReportAsPdf,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Imprimir'),
                onPressed: _printReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                ),  
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _StatCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final String label;
  final dynamic value; // int ou string
  final num delta; // int ou double
  final bool isDouble;
  const _DeltaChip({
    Key? key,
    required this.label,
    required this.value,
    required this.delta,
    this.isDouble = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isPositive = delta >= 0;
    final Color textColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final String deltaText = isDouble ? (delta as num).toDouble().toStringAsFixed(2) : '${delta as num}';

    return Chip(
      backgroundColor: Colors.grey.shade200, // fundo neutro
      side: BorderSide(color: Colors.grey.shade400),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: $value', style: const TextStyle(color: Colors.black87)),
          const SizedBox(width: 8),
          Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: textColor, size: 16),
          const SizedBox(width: 4),
          Text(deltaText, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}

class _CompareChip extends StatelessWidget {
  final String label;
  final num monthValue; // valor do mês selecionado
  final num periodValue; // valor do período selecionado
  final bool isDouble;
  const _CompareChip({
    Key? key,
    required this.label,
    required this.monthValue,
    required this.periodValue,
    this.isDouble = false,
  }) : super(key: key);

  String _fmt(num v) => isDouble ? (v as num).toDouble().toStringAsFixed(2) : v.toInt().toString();

  @override
  Widget build(BuildContext context) {
    final num delta = periodValue - monthValue; // variação do período em relação ao mês
    final bool isPositive = delta >= 0;
    final Color textColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final String deltaText = isDouble ? (delta as num).toDouble().toStringAsFixed(2) : delta.toInt().toString();

    return Chip(
      backgroundColor: Colors.grey.shade200,
      side: BorderSide(color: Colors.grey.shade400),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ${_fmt(monthValue)} → ${_fmt(periodValue)}', style: const TextStyle(color: Colors.black87)),
          const SizedBox(width: 8),
          Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: textColor, size: 16),
          const SizedBox(width: 4),
          Text(deltaText, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  final String label;
  final num baseValue; // valor cumulativo até o mês anterior (ou valor anterior)
  final num currentValue; // valor cumulativo do mês atual (ou valor atual)
  final bool isDouble;
  final num? overrideDelta; // quando fornecido, usa delta mês-a-mês (pode ser negativo)
  const _ProgressChip({
    Key? key,
    required this.label,
    required this.baseValue,
    required this.currentValue,
    this.isDouble = false,
    this.overrideDelta,
  }) : super(key: key);

  String _fmt(num v) => isDouble ? (v as num).toDouble().toStringAsFixed(2) : v.toInt().toString();

  @override
  Widget build(BuildContext context) {
    final num computedDelta = currentValue - baseValue;
    final num delta = overrideDelta ?? computedDelta;
    final bool hasChange = delta != 0;
    final bool isPositive = delta > 0;
    final Color arrowColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final String deltaText = isDouble ? (delta as num).toDouble().toStringAsFixed(2) : delta.toInt().toString();

    return Chip(
      backgroundColor: Colors.grey.shade200,
      side: BorderSide(color: Colors.grey.shade400),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ${_fmt(baseValue)} → ${_fmt(currentValue)}', style: const TextStyle(color: Colors.black87)),
          if (hasChange) ...[
            const SizedBox(width: 8),
            Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: arrowColor, size: 16),
            const SizedBox(width: 4),
            Text(deltaText, style: TextStyle(color: arrowColor)),
          ],
        ],
      ),
    );
  }
}
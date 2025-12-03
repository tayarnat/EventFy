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
import 'package:share_plus/share_plus.dart';
// Removidos exports CSV/JSON
import 'package:open_filex/open_filex.dart';

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
  Map<String, Map<String, num>> _validatedMonthly = {};

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
      // Incluir SEMPRE o mês final do período (inclusive mês corrente), para consistência com o período selecionado.
      List<Map<String, dynamic>> filtered = monthlyList;

      setState(() {
        _monthlyStats = monthlyList;
        _monthlyStatsFiltered = filtered;
        _selectedMonthIndex = filtered.isNotEmpty ? filtered.length - 1 : 0;
      });

      await _loadValidatedMonthly(range: range ?? _selectedRange);
    } catch (e) {
      NotificationService.instance.showError('Erro ao carregar comparativo mensal: $e');
    } finally {
      setState(() {
        _monthlyLoading = false;
      });
    }
  }

  Future<void> _loadValidatedMonthly({DateTimeRange? range}) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final company = authProvider.currentCompany;
      if (company == null) return;
      final DateTimeRange r = range ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 365)),
        end: DateTime.now(),
      );
      final eventsRes = await supabase
          .from('events')
          .select('id,data_inicio')
          .eq('company_id', company.id)
          .gte('data_inicio', r.start.toUtc().toIso8601String())
          .lte('data_inicio', r.end.toUtc().toIso8601String());
      final List events = (eventsRes as List? ?? []);
      final Map<String, String> idToMonth = {};
      for (final e in events) {
        final id = e['id'] as String?;
        final di = DateTime.tryParse(e['data_inicio'] as String? ?? '')?.toLocal();
        if (id != null && di != null) {
          final label = '${di.year.toString().padLeft(4, '0')}-${di.month.toString().padLeft(2, '0')}';
          idToMonth[id] = label;
        }
      }
      final eventIds = idToMonth.keys.toList();
      final Map<String, Map<String, num>> agg = {};
      for (final m in _monthlyStatsFiltered) {
        final label = m['month_label'] as String?;
        if (label != null) {
          agg[label] = {
            'events_total': 0,
            'confirmed_total': 0,
            'attended_total': 0,
            'reviews_total': 0,
            'avg_rating_sum': 0.0,
          };
        }
      }
      for (final id in eventIds) {
        final label = idToMonth[id];
        if (label != null && agg.containsKey(label)) {
          agg[label]!['events_total'] = (agg[label]!['events_total'] ?? 0) + 1;
        }
      }
      if (eventIds.isNotEmpty) {
        var confirmsQuery = supabase
            .from('event_attendances')
            .select('event_id,status');
        if (eventIds.length == 1) {
          confirmsQuery = confirmsQuery.eq('event_id', eventIds.first);
        } else {
          final orFilter = eventIds.map((id) => 'event_id.eq.$id').join(',');
          confirmsQuery = confirmsQuery.or(orFilter);
        }
        final confirmsRes = await confirmsQuery;
        final List confirms = (confirmsRes as List? ?? []);
        for (final a in confirms) {
          final eid = a['event_id'] as String?;
          final label = eid != null ? idToMonth[eid] : null;
          if (label != null && agg.containsKey(label)) {
            final status = a['status'] as String?;
            if (status == 'confirmado') {
              agg[label]!['confirmed_total'] = (agg[label]!['confirmed_total'] ?? 0) + 1;
            }
            if (status == 'compareceu') {
              agg[label]!['attended_total'] = (agg[label]!['attended_total'] ?? 0) + 1;
            }
          }
        }
        var reviewsQuery = supabase
            .from('event_reviews')
            .select('event_id,rating');
        if (eventIds.length == 1) {
          reviewsQuery = reviewsQuery.eq('event_id', eventIds.first);
        } else {
          final orFilter = eventIds.map((id) => 'event_id.eq.$id').join(',');
          reviewsQuery = reviewsQuery.or(orFilter);
        }
        final reviewsRes = await reviewsQuery;
        final List reviews = (reviewsRes as List? ?? []);
        for (final rj in reviews) {
          final eid = rj['event_id'] as String?;
          final label = eid != null ? idToMonth[eid] : null;
          if (label != null && agg.containsKey(label)) {
            final rating = (rj['rating'] as num?)?.toDouble() ?? 0.0;
            agg[label]!['reviews_total'] = (agg[label]!['reviews_total'] ?? 0) + 1;
            agg[label]!['avg_rating_sum'] = (agg[label]!['avg_rating_sum'] ?? 0.0) + rating;
          }
        }
      }
      setState(() {
        _validatedMonthly = agg;
      });
    } catch (_) {}
  }

  Future<void> _pickDateRange() async {
    final initialDateRange = _selectedRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: (initialDateRange.end.isAfter(DateTime.now())
              ? initialDateRange.end
              : DateTime.now())
          .add(const Duration(days: 1)),
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
    try {
      if (kIsWeb) {
        final doc = pw.Document();
        final image = pw.MemoryImage(pngBytes);
        doc.addPage(pw.Page(build: (context) => pw.Image(image)));
        await Printing.sharePdf(bytes: await doc.save(), filename: 'relatorio_eventfy.pdf');
        return;
      }
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/relatorio_eventfy_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = io.File(filePath);
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(filePath, mimeType: 'image/png')], text: 'Relatório EventFy');
    } catch (e) {
      NotificationService.instance.showError('Erro ao compartilhar imagem: $e');
    }
  }

  Future<void> _saveImageToAppDir() async {
    try {
      final pngBytes = await _captureReportImageBytes();
      if (pngBytes == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/relatorio_eventfy_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = io.File(filePath);
      await file.writeAsBytes(pngBytes);
      NotificationService.instance.showSuccess('Imagem salva em: $filePath');
      await OpenFilex.open(filePath);
    } catch (e) {
      NotificationService.instance.showError('Erro ao salvar/abrir imagem: $e');
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();
    final period = _selectedRange;
    final periodLabel = period == null
        ? 'Período não selecionado'
        : '${period.start.day.toString().padLeft(2, '0')}/${period.start.month.toString().padLeft(2, '0')}/${period.start.year} - ${period.end.day.toString().padLeft(2, '0')}/${period.end.month.toString().padLeft(2, '0')}/${period.end.year}';
    final stats = _periodReport ?? {};

    List<pw.TableRow> monthRows = [];
    double cumSum = 0.0;
    int cumCount = 0;
    double prevCumAvg = 0.0;
    int cumEv = 0;
    int cumConf = 0;
    int cumAtt = 0;
    int cumRev = 0;
    for (final m in _monthlyStatsFiltered) {
      final label = m['month_label'] as String?;
      if (label != null && _validatedMonthly.containsKey(label)) {
        final v = _validatedMonthly[label]!;
        final vEvents = (v['events_total'] ?? 0).toInt();
        final vConfirmed = (v['confirmed_total'] ?? 0).toInt();
        final vAttended = (v['attended_total'] ?? 0).toInt();
        final vReviews = (v['reviews_total'] ?? 0).toInt();
        final vAvgSum = (v['avg_rating_sum'] ?? 0.0).toDouble();
        final avgMonth = vReviews > 0 ? (vAvgSum / vReviews) : 0.0;
        final monthCount = vReviews;
        final monthSum = avgMonth * monthCount;
        cumSum += monthSum;
        cumCount += monthCount;
        final cumAvg = cumCount > 0 ? (cumSum / cumCount) : 0.0;
        final avgDelta = cumAvg - prevCumAvg;
        final sign = avgDelta >= 0 ? '+' : '';
        cumEv += vEvents;
        cumConf += vConfirmed;
        cumAtt += vAttended;
        cumRev += vReviews;
        monthRows.add(pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(label)),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$cumEv (+$vEvents)')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$cumConf (+$vConfirmed)')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$cumAtt (+$vAttended)')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$cumRev (+$vReviews)')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${cumAvg.toStringAsFixed(2)} (${sign}${avgDelta.toStringAsFixed(2)})')),
        ]));
        prevCumAvg = cumAvg;
      } else {
        final evTotal = ((m['events_cumulative'] as num?) ?? 0).toInt();
        final evDelta = ((m['events_month'] as num?) ?? 0).toInt();
        final confTotal = ((m['confirmed_cumulative'] as num?) ?? 0).toInt();
        final confDelta = ((m['confirmed_month'] as num?) ?? 0).toInt();
        final attTotal = ((m['attended_cumulative'] as num?) ?? 0).toInt();
        final attDelta = ((m['attended_month'] as num?) ?? 0).toInt();
        final revTotal = ((m['reviews_cumulative'] as num?) ?? 0).toInt();
        final revDelta = ((m['reviews_month'] as num?) ?? 0).toInt();
        final avgMonth = ((m['average_rating_month'] as num?) ?? 0).toDouble();
        final monthSum = avgMonth * (revDelta < 0 ? 0 : revDelta);
        cumSum += monthSum;
        cumCount += (revDelta < 0 ? 0 : revDelta);
        final cumAvg = cumCount > 0 ? (cumSum / cumCount) : 0.0;
        final avgDelta = cumAvg - prevCumAvg;
        final sign = avgDelta >= 0 ? '+' : '';
        monthRows.add(pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${m['month_label']}')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$evTotal (+${evDelta < 0 ? 0 : evDelta})')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$confTotal (+${confDelta < 0 ? 0 : confDelta})')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$attTotal (+${attDelta < 0 ? 0 : attDelta})')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$revTotal (+${revDelta < 0 ? 0 : revDelta})')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${cumAvg.toStringAsFixed(2)} (${sign}${avgDelta.toStringAsFixed(2)})')),
        ]));
        prevCumAvg = cumAvg;
      }
    }

    doc.addPage(pw.MultiPage(build: (context) {
      return [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Relatório de Estatísticas da Empresa', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 12))
        ]),
        pw.SizedBox(height: 12),
        pw.Table(columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
        }, children: [
          pw.TableRow(children: [
            pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
              pw.Text('Eventos (período)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${(stats['total_events'] ?? 0)}')
            ])),
            pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
              pw.Text('Confirmados', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${(stats['total_confirmed'] ?? 0)}')
            ])),
          ]),
          pw.TableRow(children: [
            pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
              pw.Text('Compareceram', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${(stats['total_attended'] ?? 0)}')
            ])),
            pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
              pw.Text('Média Avaliações', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${(((stats['average_rating'] ?? 0.0) as num).toDouble()).toStringAsFixed(2)}')
            ])),
          ]),
          pw.TableRow(children: [
            pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
              pw.Text('Total de Reviews', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${(stats['total_reviews'] ?? 0)}')
            ])),
            pw.Container(padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
              pw.Text('Cancelados (período)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${(stats['events_cancelled'] ?? 0)}')
            ])),
          ]),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('Progresso entre meses', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(border: pw.TableBorder.all(), children: [
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mês', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Eventos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Confirmados', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Compareceram', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Reviews', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Média cumulativa ★', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ]),
          ...monthRows,
        ]),
      ];
    }));
    return await doc.save();
  }

  Future<void> _shareReportAsPdf() async {
    try {
      final bytes = await _buildPdfBytes();
      await Printing.sharePdf(bytes: bytes, filename: 'relatorio_eventfy.pdf');
    } catch (e) {
      NotificationService.instance.showError('Erro ao compartilhar PDF: $e');
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

  Future<void> _savePdfToAppDir() async {
    try {
      final bytes = await _buildPdfBytes();
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/relatorio_eventfy_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = io.File(filePath);
      await file.writeAsBytes(bytes);
      NotificationService.instance.showSuccess('PDF salvo em: $filePath');
      await OpenFilex.open(filePath);
    } catch (e) {
      NotificationService.instance.showError('Erro ao salvar/abrir PDF: $e');
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
                onPressed: (_selectedRange == null || _reportLoading) ? null : _generatePeriodReport,
                icon: const Icon(Icons.analytics_outlined),
                label: _reportLoading
                    ? const Text('Gerando...')
                    : Text(_selectedRange == null ? 'Selecione um período' : 'Gerar Relatório'),
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
                      IntrinsicHeight(
                        child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.event_available,
                              title: 'Eventos (período)',
                              value: '${_periodReport!['total_events'] ?? 0}',
                              color: const ui.Color.fromARGB(255, 54, 134, 204),
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
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
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
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
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
                              child: Builder(
                                builder: (context) {
                                  double cumSum = 0.0;
                                  int cumCount = 0;
                                  double prevCumAvg = 0.0;
                                  int cumEv = 0;
                                  int cumConf = 0;
                                  int cumAtt = 0;
                                  int cumRev = 0;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _monthlyStatsFiltered.map((m) {
                                      final evTotal = ((m['events_cumulative'] as num?) ?? 0).toInt();
                                      final confTotal = ((m['confirmed_cumulative'] as num?) ?? 0).toInt();
                                      final attTotal = ((m['attended_cumulative'] as num?) ?? 0).toInt();
                                      final revTotal = ((m['reviews_cumulative'] as num?) ?? 0).toInt();
                                      final evDelta = ((m['events_month'] as num?) ?? 0).toInt();
                                      final confDelta = ((m['confirmed_month'] as num?) ?? 0).toInt();
                                      final attDelta = ((m['attended_month'] as num?) ?? 0).toInt();
                                      final revDelta = ((m['reviews_month'] as num?) ?? 0).toInt();
                                      final label = m['month_label'] as String?;
                                      if (label != null && _validatedMonthly.containsKey(label)) {
                                        final v = _validatedMonthly[label]!;
                                        final vEvents = (v['events_total'] ?? 0).toInt();
                                        final vReviews = (v['reviews_total'] ?? 0).toInt();
                                        final vAvgSum = (v['avg_rating_sum'] ?? 0.0).toDouble();
                                        final vConfirmed = (v['confirmed_total'] ?? 0).toInt();
                                        final vAttended = (v['attended_total'] ?? 0).toInt();
                                        final avgMonth = vReviews > 0 ? (vAvgSum / vReviews) : 0.0;
                                        final monthCount = vReviews;
                                        final monthSum = avgMonth * monthCount;
                                        cumSum += monthSum;
                                        cumCount += monthCount;
                                        final cumAvg = cumCount > 0 ? (cumSum / cumCount) : 0.0;
                                        final avgDelta = cumAvg - prevCumAvg;
                                        final sign = avgDelta >= 0 ? '+' : '';
                                        cumEv += vEvents;
                                        cumConf += vConfirmed;
                                        cumAtt += vAttended;
                                        cumRev += vReviews;
                                        prevCumAvg = cumAvg;
                                        return Card(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                                    Text('Média: ${cumAvg.toStringAsFixed(2)}  (${sign}${avgDelta.toStringAsFixed(2)})', style: const TextStyle(fontSize: 12)),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    Chip(label: Text('Eventos: $cumEv (+$vEvents)')),
                                                    Chip(label: Text('Confirmados: $cumConf (+$vConfirmed)')),
                                                    Chip(label: Text('Compareceram: $cumAtt (+$vAttended)')),
                                                    Chip(label: Text('Reviews: $cumRev (+$vReviews)')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      final avgMonth = ((m['average_rating_month'] as num?) ?? 0).toDouble();
                                      final monthCount = revDelta > 0 ? revDelta : 0;
                                      final monthSum = avgMonth * monthCount;
                                      cumSum += monthSum;
                                      cumCount += monthCount;
                                      final cumAvg = cumCount > 0 ? (cumSum / cumCount) : 0.0;
                                      final avgDelta = cumAvg - prevCumAvg;
                                      final sign = avgDelta >= 0 ? '+' : '';
                                      prevCumAvg = cumAvg;
                                      return Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('${m['month_label']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                                  Text('Média: ${cumAvg.toStringAsFixed(2)}  (${sign}${avgDelta.toStringAsFixed(2)})', style: const TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  Chip(label: Text('Eventos: $evTotal (+${evDelta < 0 ? 0 : evDelta})')),
                                                  Chip(label: Text('Confirmados: $confTotal (+${confDelta < 0 ? 0 : confDelta})')),
                                                  Chip(label: Text('Compareceram: $attTotal (+${attDelta < 0 ? 0 : attDelta})')),
                                                  Chip(label: Text('Reviews: $revTotal (+${revDelta < 0 ? 0 : revDelta})')),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
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
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'share_image') {
                    _downloadReportAsImage();
                  } else if (value == 'share_pdf') {
                    _shareReportAsPdf();
                  } else if (value == 'print_pdf') {
                    _printReport();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'share_image', child: ListTile(leading: Icon(Icons.image_outlined), title: Text('Compartilhar Imagem'))),
                  const PopupMenuItem(value: 'share_pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf), title: Text('Compartilhar PDF'))),
                ],
                child: const Chip(
                  avatar: Icon(Icons.share),
                  label: Text('Compartilhar'),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'save_image') {
                    _saveImageToAppDir();
                  } else if (value == 'save_pdf') {
                    _savePdfToAppDir();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'save_image', child: ListTile(leading: Icon(Icons.save), title: Text('Salvar Imagem'))),
                  const PopupMenuItem(value: 'save_pdf', child: ListTile(leading: Icon(Icons.save), title: Text('Salvar PDF'))),
                ],
                child: const Chip(
                  avatar: Icon(Icons.save_alt),
                  label: Text('Salvar'),
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
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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

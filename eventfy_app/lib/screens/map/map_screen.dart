import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../providers/events_provider.dart';
import '../../models/event_model.dart';
import '../../widgets/event_card.dart';
import '../event/event_details_screen.dart';

class MapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? eventId;
  
  const MapScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.eventId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  EventModel? _selectedEvent;
  bool _showingEventDetails = false;
  Map<String, BitmapDescriptor> _customMarkers = {};
  // NOVOS CONTROLES DE ZOOM/ESCALA PARA MARCADORES
  double _currentZoom = 14.0;
  double _currentScale = 1.5;
  
  // Localização padrão (São Paulo) caso não consiga obter a localização
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(-23.5505, -46.6333),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    
    // Inicializar o provider se ainda não foi inicializado
    if (eventsProvider.currentPosition == null && !eventsProvider.isLoadingLocation) {
      await eventsProvider.initialize();
    }
    
    // Carregar todos os eventos e usar filteredEvents
    await eventsProvider.loadEvents();
    
    await _loadCustomMarkers();
    _updateMarkers();
    _moveToInitialLocation();
  }
  
  void _moveToInitialLocation() {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    
    if (_mapController != null) {
      // Se temos coordenadas iniciais (vindo de um evento), usar elas
      if (widget.initialLat != null && widget.initialLng != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(widget.initialLat!, widget.initialLng!),
            16.0, // Zoom maior para focar no evento
          ),
        );
        // Atualiza escala conforme o zoom inicial
        _currentZoom = 16.0;
        _currentScale = _getScaleForZoom(_currentZoom);
        
        // Se temos um eventId, destacar o evento
        if (widget.eventId != null) {
          _highlightEvent(widget.eventId!);
        }
      } else {
        // Usar localização do usuário como fallback
        final userPosition = eventsProvider.currentPosition;
        if (userPosition != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(userPosition.latitude, userPosition.longitude),
              14.0,
            ),
          );
          // Atualiza escala conforme o zoom inicial
          _currentZoom = 14.0;
          _currentScale = _getScaleForZoom(_currentZoom);
        }
      }
    }
  }

  Future<void> _loadCustomMarkers() async {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    final events = eventsProvider.filteredEvents;
    
    for (final event in events) {
      if (!_customMarkers.containsKey(event.id)) {
        try {
          final customMarker = await _createCustomMarker(
            event.fotoPrincipalUrl,
            eventTitle: event.titulo,
            isGratuito: event.isGratuito,
            scaleFactor: _currentScale,
          );
          _customMarkers[event.id] = customMarker;
        } catch (e) {
          // Se falhar ao criar marcador personalizado, usar marcador padrão
          print('Erro ao criar marcador personalizado do evento ${event.id}: $e');
        }
      }
    }
  }

  Future<BitmapDescriptor> _createCustomMarker(String? imageUrl, {required String eventTitle, bool isGratuito = true, double scaleFactor = 1.5}) async {
    try {
      // Criar um canvas para desenhar o marcador personalizado
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      // Tamanho base do desenho (será escalado via canvas.scale)
      const Size baseSize = Size(100, 120);
      final double s = scaleFactor <= 0 ? 1.0 : scaleFactor;
      // Escalar todo o desenho para que o objeto cresça de fato com o zoom
      canvas.scale(s);

      // Cor laranja padrão para todos os pins
      final Color pinColor = Colors.orange;
      
      // Desenhar sombra
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
      canvas.drawCircle(const Offset(52, 52), 28, shadowPaint);
      canvas.drawPath(
        Path()
          ..moveTo(50, 75)
          ..lineTo(42, 95)
          ..lineTo(58, 95)
          ..close(),
        shadowPaint,
      );

      // Desenhar o pin principal
      final Paint pinPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(const Offset(50, 50), 25, pinPaint);
      canvas.drawPath(
        Path()
          ..moveTo(50, 75)
          ..lineTo(42, 95)
          ..lineTo(58, 95)
          ..close(),
        pinPaint,
      );

      // Desenhar borda laranja
      final Paint borderPaint = Paint()
        ..color = pinColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawCircle(const Offset(50, 50), 25, borderPaint);

      // Tentar carregar e desenhar a imagem do evento
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            final Uint8List imageBytes = response.bodyBytes;
            final ui.Codec codec = await ui.instantiateImageCodec(
              imageBytes,
              targetWidth: 100,
              targetHeight: 100,
            );
            final ui.FrameInfo frameInfo = await codec.getNextFrame();
            final ui.Image image = frameInfo.image;

            // Desenhar a imagem circular
            final Rect imageRect = const Rect.fromLTWH(30, 30, 40, 40);
            final Path clipPath = Path()
              ..addOval(imageRect);
            
            canvas.save();
            canvas.clipPath(clipPath);
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
              imageRect,
              Paint(),
            );
            canvas.restore();
          } else {
            throw Exception('Falha ao baixar imagem');
          }
        } catch (e) {
          // Se falhar ao carregar imagem, usar inicial do título
          _drawEventInitial(canvas, eventTitle, pinColor);
        }
      } else {
        // Se não há URL de imagem, usar inicial do título
        _drawEventInitial(canvas, eventTitle, pinColor);
      }

      // Adicionar ícone de preço no canto se não for gratuito
      if (!isGratuito) {
        final Paint pricePaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(const Offset(70, 30), 8, pricePaint);
        
        // Desenhar símbolo de dinheiro
        final TextPainter textPainter = TextPainter(
          text: const TextSpan(
            text: '\$',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, const Offset(66, 26));
      }

      // Finalizar o desenho
      final ui.Picture picture = recorder.endRecording();
      // Renderizar a imagem com dimensões proporcionalmente maiores
      final ui.Image markerImage = await picture.toImage(
        (baseSize.width * s).toInt(),
        (baseSize.height * s).toInt(),
      );
      
      // Converter para bytes
      final ByteData? byteData = await markerImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List markerBytes = byteData!.buffer.asUint8List();

      return BitmapDescriptor.fromBytes(markerBytes);
    } catch (e) {
      // Retornar marcador padrão laranja em caso de erro
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  void _drawEventInitial(Canvas canvas, String eventTitle, Color pinColor) {
    // Obter a primeira letra do título
    String initial = eventTitle.isNotEmpty ? eventTitle[0].toUpperCase() : 'E';
    
    // Desenhar fundo circular para a inicial
    final Paint initialBgPaint = Paint()
      ..color = pinColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(50, 50), 20, initialBgPaint);
    
    // Desenhar a inicial
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          color: pinColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Centralizar o texto
    final double textX = 50 - (textPainter.width / 2);
    final double textY = 50 - (textPainter.height / 2);
    textPainter.paint(canvas, Offset(textX, textY));
  }

  void _updateMarkers() {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    final events = eventsProvider.filteredEvents;
    final userPosition = eventsProvider.currentPosition;
    
    Set<Marker> markers = {};
    
    // Removido marcador da localização do usuário
    
    // Adicionar marcadores dos eventos
    for (final event in events) {
      // Usar marcador personalizado se disponível, senão usar padrão laranja maior
      BitmapDescriptor markerIcon;
      if (_customMarkers.containsKey(event.id)) {
        markerIcon = _customMarkers[event.id]!;
      } else {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }
      
      // Criar snippet sem descrição
      String snippet = '';
      if (event.categorias != null && event.categorias!.isNotEmpty) {
        snippet += 'Tags: ${event.categorias!.take(2).join(', ')}';
        if (event.categorias!.length > 2) {
          snippet += '...';
        }
        snippet += '\n';
      }
      snippet += '${event.formattedPrice} • ${event.endereco}';
      
      markers.add(
        Marker(
          markerId: MarkerId(event.id),
          position: LatLng(event.latitude, event.longitude),
          icon: markerIcon,
          anchor: _customMarkers.containsKey(event.id)
              ? const Offset(0.5, 0.79) // ancora na ponta do pin personalizado
              : const Offset(0.5, 1.0), // default para ícone padrão
          infoWindow: InfoWindow(
            title: event.titulo,
            snippet: snippet,
            onTap: () => _showEventDetails(event),
          ),
          onTap: () => _showEventDetails(event),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _moveToUserLocation() {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    
    if (_mapController != null) {
      // Sempre usar a localização atual do usuário
      final userPosition = eventsProvider.currentPosition;
      if (userPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(userPosition.latitude, userPosition.longitude),
            14.0,
          ),
        );
      }
    }
  }

  void _showEventDetails(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(event: event),
      ),
    );
  }

  void _hideEventDetails() {
    setState(() {
      _selectedEvent = null;
      _showingEventDetails = false;
    });
  }
  
  void _highlightEvent(String eventId) {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    final event = eventsProvider.filteredEvents.firstWhere(
      (e) => e.id == eventId,
      orElse: () => eventsProvider.filteredEvents.first,
    );
    
    // Mostrar detalhes do evento automaticamente
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _selectedEvent = event;
        _showingEventDetails = true;
      });
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _moveToUserLocation();
  }

  Timer? _searchTimer;
  Timer? _resizeTimer;
  
  void _onCameraMove(CameraPosition position) {
    // Cancelar timer anterior se existir
    _searchTimer?.cancel();

    // Atualiza o zoom corrente
    _currentZoom = position.zoom;

    // Atualizar escala dos ícones dos eventos de forma contínua conforme o zoom
    final double newScale = _getScaleForZoom(position.zoom);
    if ((newScale - _currentScale).abs() >= 0.05) {
      _currentScale = newScale;
      // Debounce curto para não recriar ícones a cada frame
      _resizeTimer?.cancel();
      _resizeTimer = Timer(const Duration(milliseconds: 150), () {
        _rescaleMarkersForZoom(_currentZoom);
      });
    }
    
    // Criar novo timer com debounce de 1 segundo
    _searchTimer = Timer(const Duration(seconds: 1), () {
      _searchInCurrentArea();
    });
  }

  double _getScaleForZoom(double zoom) {
    // Escala contínua para os ícones dos eventos: de 1.0 (zoom <= 10) até 2.0 (zoom >= 18)
    const double minZoom = 10.0;
    const double maxZoom = 18.0;
    const double minScale = 1.0;
    const double maxScale = 2.0; // chegar ao dobro do tamanho
    if (zoom <= minZoom) return minScale;
    if (zoom >= maxZoom) return maxScale;
    final double t = (zoom - minZoom) / (maxZoom - minZoom);
    return minScale + (maxScale - minScale) * t; // mapeamento linear
  }

  Future<void> _rescaleMarkersForZoom(double zoom) async {
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    final events = eventsProvider.filteredEvents;

    for (final event in events) {
      try {
        final customMarker = await _createCustomMarker(
          event.fotoPrincipalUrl,
          eventTitle: event.titulo,
          isGratuito: event.isGratuito,
          scaleFactor: _currentScale,
        );
        _customMarkers[event.id] = customMarker;
      } catch (_) {
        // Se falhar, mantemos o ícone anterior
      }
    }

    _updateMarkers();
  }
  
  void _searchInCurrentArea() {
    if (_mapController != null) {
      _mapController!.getVisibleRegion().then((bounds) async {
        final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
        
        // Recarregar todos os eventos e usar filteredEvents
        await eventsProvider.loadEvents();
        
        // Recarregar marcadores personalizados para novos eventos
        await _loadCustomMarkers();
        _updateMarkers();
      });
    }
  }

  void _searchInThisArea() {
    // Cancelar busca automática e fazer busca manual imediata
    _searchTimer?.cancel();
    _searchInCurrentArea();
    
    // Mostrar feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buscando eventos nesta área...'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Método para recarregar marcadores quando eventos mudarem
  void _onEventsChanged() async {
    // Recarregar eventos com base nos filtros atuais
    final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
    
    // Carregar todos os eventos e usar filteredEvents
    await eventsProvider.loadEvents();
    
    await _loadCustomMarkers();
    _updateMarkers();
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  void _showFiltersBottomSheet(BuildContext context, EventsProvider eventsProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        eventsProvider.clearFilters();
                        _onEventsChanged();
                      },
                      child: const Text('Limpar Tudo'),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Distância
                    const Text(
                      'Distância Máxima',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<EventsProvider>(
                      builder: (context, provider, child) => Column(
                        children: [
                          Slider(
                            value: provider.maxDistance,
                            min: 1.0,
                            max: 100.0,
                            divisions: 99,
                            label: '${provider.maxDistance.toInt()} km',
                            onChanged: (value) {
                              provider.setMaxDistance(value);
                            },
                            onChangeEnd: (value) {
                              _onEventsChanged();
                            },
                          ),
                          Text(
                            '${provider.maxDistance.toInt()} km',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Eventos gratuitos
                  Consumer<EventsProvider>(
                      builder: (context, provider, child) => CheckboxListTile(
                        title: const Text('Apenas eventos gratuitos'),
                        subtitle: const Text('Mostrar somente eventos sem custo'),
                        value: provider.showOnlyFreeEvents,
                        onChanged: (value) {
                          provider.setShowOnlyFreeEvents(value ?? false);
                          _onEventsChanged();
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Filtro por Data (intervalo)
                    const Text(
                      'Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<EventsProvider>(
                      builder: (context, provider, child) {
                        final hasDateFilter = provider.startDateFilter != null || provider.endDateFilter != null;
                        final startLabel = provider.startDateFilter != null ? _formatDate(provider.startDateFilter!) : 'Início';
                        final endLabel = provider.endDateFilter != null ? _formatDate(provider.endDateFilter!) : 'Fim';
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.date_range),
                                label: Text(hasDateFilter ? '$startLabel - $endLabel' : 'Selecionar intervalo'),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final initialRange = (provider.startDateFilter != null && provider.endDateFilter != null)
                                      ? DateTimeRange(start: provider.startDateFilter!, end: provider.endDateFilter!)
                                      : DateTimeRange(start: now, end: now.add(const Duration(days: 7)));
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: now.subtract(const Duration(days: 365)),
                                    lastDate: now.add(const Duration(days: 365 * 2)),
                                    initialDateRange: initialRange,
                                    helpText: 'Selecione o intervalo de datas',
                                  );
                                  if (picked != null) {
                                    provider.setDateRange(picked.start, picked.end);
                                    _onEventsChanged();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Limpar filtro de data',
                              icon: const Icon(Icons.clear),
                              onPressed: hasDateFilter
                                  ? () {
                                      provider.clearDateFilter();
                                      _onEventsChanged();
                                    }
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Categorias
                    const Text(
                      'Categorias',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<EventsProvider>(
                      builder: (context, provider, child) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Música',
                          'Esportes',
                          'Tecnologia',
                          'Arte',
                          'Gastronomia',
                          'Educação',
                          'Negócios',
                          'Saúde',
                          'Entretenimento',
                          'Cultura',
                        ].map((category) => FilterChip(
                          label: Text(category),
                          selected: provider.selectedCategories.contains(category),
                          onSelected: (selected) {
                            provider.toggleCategoryFilter(category);
                            _onEventsChanged();
                          },
                        )).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Consumer<EventsProvider>(
                        builder: (context, provider, child) => Text(
                          '${provider.filteredEvents.length} eventos encontrados',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventsProvider>(
        builder: (context, eventsProvider, child) {
          return Stack(
            children: [
              // Mapa
              GoogleMap(
                onMapCreated: _onMapCreated,
                onCameraMove: _onCameraMove,
                initialCameraPosition: eventsProvider.currentPosition != null
                    ? CameraPosition(
                        target: LatLng(
                          eventsProvider.currentPosition!.latitude,
                          eventsProvider.currentPosition!.longitude,
                        ),
                        zoom: 14.0,
                      )
                    : _defaultPosition,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // Usaremos nosso próprio botão
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                trafficEnabled: false,
                buildingsEnabled: true,
                indoorViewEnabled: true,
                mapType: MapType.normal,
              ),
              
              // Barra de busca e filtros no topo
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    // Barra de busca
                    Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Buscar eventos...',
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (query) {
                                  eventsProvider.setSearchQuery(query);
                                  _onEventsChanged();
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.filter_list),
                              onPressed: () => _showFiltersBottomSheet(context, eventsProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Indicadores de filtros ativos
                    if (eventsProvider.selectedCategories.isNotEmpty || 
                        eventsProvider.showOnlyFreeEvents ||
                        eventsProvider.maxDistance < 50.0 ||
                        eventsProvider.startDateFilter != null ||
                        eventsProvider.endDateFilter != null)
                      const SizedBox(height: 8),
                    if (eventsProvider.selectedCategories.isNotEmpty || 
                        eventsProvider.showOnlyFreeEvents ||
                        eventsProvider.maxDistance < 50.0 ||
                        eventsProvider.startDateFilter != null ||
                        eventsProvider.endDateFilter != null)
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (eventsProvider.showOnlyFreeEvents)
                                Chip(
                                  label: const Text('Gratuitos', style: TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.green.shade100,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    eventsProvider.setShowOnlyFreeEvents(false);
                                    _onEventsChanged();
                                  },
                                ),
                              if (eventsProvider.maxDistance < 50.0)
                                Chip(
                                  label: Text('${eventsProvider.maxDistance.toInt()}km', style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.blue.shade100,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    eventsProvider.setMaxDistance(50.0);
                                    _onEventsChanged();
                                  },
                                ),
                              if (eventsProvider.startDateFilter != null || eventsProvider.endDateFilter != null)
                                Chip(
                                  label: Text(
                                    '${eventsProvider.startDateFilter != null ? _formatDate(eventsProvider.startDateFilter!) : 'Início'} - ${eventsProvider.endDateFilter != null ? _formatDate(eventsProvider.endDateFilter!) : 'Fim'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.purple.shade100,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    eventsProvider.clearDateFilter();
                                    _onEventsChanged();
                                  },
                                ),
                              ...eventsProvider.selectedCategories.map((category) => 
                                Chip(
                                  label: Text(category, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.orange.shade100,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    eventsProvider.toggleCategoryFilter(category);
                                    _onEventsChanged();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Botões de controle
              Positioned(
                right: 16,
                bottom: _showingEventDetails ? 320 : 100,
                child: Column(
                  children: [
                    // Botão de localização
                    FloatingActionButton(
                      heroTag: 'location',
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      onPressed: () {
                        if (eventsProvider.currentPosition != null) {
                          _moveToUserLocation();
                        } else {
                          eventsProvider.getCurrentLocation().then((_) {
                            _moveToUserLocation();
                          });
                        }
                      },
                      child: eventsProvider.isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                    const SizedBox(height: 8),
                    
                    // Botão de buscar nesta área
                    FloatingActionButton(
                      heroTag: 'search_area',
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      onPressed: _searchInThisArea,
                      child: const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
              
              // Indicador de carregamento
              if (eventsProvider.isLoadingEvents)
                const Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text('Carregando eventos...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Legenda removida (não utilizada)
              
              // Detalhes do evento selecionado
              if (_showingEventDetails && _selectedEvent != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Card(
                    elevation: 8,
                    child: Container(
                      height: 280,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedEvent!.titulo,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: _hideEventDetails,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          Text(
                            _selectedEvent!.formattedPrice,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _selectedEvent!.isGratuito ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _selectedEvent!.endereco,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${_selectedEvent!.dataInicio.day}/${_selectedEvent!.dataInicio.month}/${_selectedEvent!.dataInicio.year}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          
                          if (_selectedEvent!.distanceFromUser != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.directions_walk, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${_selectedEvent!.distanceFromUser!.toStringAsFixed(1)} km de distância',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                          
                          const Spacer(),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailsScreen(
                                      event: _selectedEvent!,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade700,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Ver Detalhes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Mensagem de erro
              if (eventsProvider.errorMessage != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.red.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              eventsProvider.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            onPressed: eventsProvider.clearError,
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
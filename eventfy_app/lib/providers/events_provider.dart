import 'dart:convert';
import 'dart:io';
import 'dart:math' show cos, sin, sqrt, atan2, pi;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../core/config/supabase_config.dart';
import '../services/notification_service.dart';

class EventsProvider with ChangeNotifier {
  final SupabaseClient _supabase = supabase;
  
  List<EventModel> _events = [];
  Position? _currentPosition;
  bool _isLoadingEvents = false;
  bool _isLoadingLocation = false;
  String? _errorMessage;
  
  // Getters
  List<EventModel> get events => _events;
  Position? get currentPosition => _currentPosition;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isLoadingLocation => _isLoadingLocation;
  String? get errorMessage => _errorMessage;
  bool get hasLocationPermission => _currentPosition != null;
  
  // Filtros
  String _searchQuery = '';
  List<String> _selectedCategories = [];
  double _maxDistance = 50.0; // km
  bool _showOnlyFreeEvents = false;
  
  String get searchQuery => _searchQuery;
  List<String> get selectedCategories => _selectedCategories;
  double get maxDistance => _maxDistance;
  bool get showOnlyFreeEvents => _showOnlyFreeEvents;
  
  // Eventos filtrados
  List<EventModel> get filteredEvents {
    List<EventModel> filtered = List.from(_events);
    
    // Filtro por texto
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((event) {
        return event.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               event.descricao?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
               event.endereco.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               event.empresaNome?.toLowerCase().contains(_searchQuery.toLowerCase()) == true;
      }).toList();
    }
    
    // Filtro por categorias
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((event) {
        return event.categorias?.any((cat) => _selectedCategories.contains(cat)) == true;
      }).toList();
    }
    
    // Filtro por eventos gratuitos
    if (_showOnlyFreeEvents) {
      filtered = filtered.where((event) => event.isGratuito).toList();
    }
    
    // Filtro por distância (se temos localização)
    if (_currentPosition != null) {
      filtered = filtered.where((event) {
        final distance = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          event.latitude,
          event.longitude,
        );
        event.distanceFromUser = distance;
        return distance <= _maxDistance;
      }).toList();
      
      // Ordenar por distância
      filtered.sort((a, b) => (a.distanceFromUser ?? 0).compareTo(b.distanceFromUser ?? 0));
    }
    
    return filtered;
  }
  
  // Inicializar provider
  Future<void> initialize() async {
    await getCurrentLocation();
    await loadEvents();
  }
  
  // Gerenciamento de localização
  Future<void> getCurrentLocation() async {
    _isLoadingLocation = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Verificar se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Serviço de localização desabilitado');
      }
      
      // Verificar permissões
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permissão de localização negada');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização negada permanentemente');
      }
      
      // Obter localização atual
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (kDebugMode) {
        print('Localização obtida: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      }
      
    } catch (e) {
      _errorMessage = 'Erro ao obter localização: $e';
      NotificationService.instance.showError('Erro ao obter localização: $e');
      if (kDebugMode) {
        print('Erro ao obter localização: $e');
      }
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }
  
  // Carregar eventos do Supabase
  Future<void> loadEvents() async {
    _isLoadingEvents = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      print('DEBUG: Iniciando loadEvents via RPC get_events_complete...');

      final response = await supabase.rpc('get_events_complete', params: {
        'p_limit': 200,
        'p_offset': 0,
      });

      if (response != null) {
        final List data = response as List;
        print('DEBUG: Recebidos ${data.length} eventos do RPC');

        _events = data.map((row) {
          final eventData = Map<String, dynamic>.from(row as Map);
          // Os campos empresa_* já vêm no topo e latitude/longitude já vêm calculados no RPC
          final event = EventModel.fromJson(eventData);
          return event;
        }).toList();
      } else {
        _events = [];
      }

      if (kDebugMode) {
        print('Carregados ${_events.length} eventos (RPC)');
        if (_events.isEmpty) {
          print('Nenhum evento encontrado. O mapa permanecerá navegável.');
        }
      }

      _errorMessage = null;
    } catch (e) {
      _events = [];
      _errorMessage = 'Erro ao carregar eventos (RPC): $e';
      NotificationService.instance.showError('Erro ao carregar eventos (RPC): $e');
      if (kDebugMode) {
        print('Erro ao carregar eventos (RPC): $e');
      }
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }
  
  // Buscar eventos próximos a uma localização específica
  Future<void> searchEventsByLocation(double latitude, double longitude, {double radiusKm = 10.0}) async {
    _isLoadingEvents = true;
    notifyListeners();
    
    try {
      print('DEBUG: Iniciando busca de eventos por localização via RPC get_nearby_events...');
      print('DEBUG: Centro: $latitude, $longitude - Raio: ${radiusKm}km');

      final response = await supabase.rpc('get_nearby_events', params: {
        'user_lat': latitude,
        'user_lng': longitude,
        'radius_km': radiusKm,
      });

      if (response == null) {
        print('DEBUG: RPC retornou nulo');
        _events = [];
        _isLoadingEvents = false;
        notifyListeners();
        return;
      }

      final List data = response as List;
      print('DEBUG: Recebidos ${data.length} eventos próximos do RPC');

      final eventsInRadius = <EventModel>[];

      for (final row in data) {
        final eventData = Map<String, dynamic>.from(row as Map);
        // Campos empresa_* e latitude/longitude já vêm no retorno
        final event = EventModel.fromJson(eventData);
        // Distância calculada no servidor
        final distanceKm = (eventData['distance_km'] as num?)?.toDouble();
        event.distanceFromUser = distanceKm;
        eventsInRadius.add(event);
      }

      // Ordenar por distância
      eventsInRadius.sort((a, b) => (a.distanceFromUser ?? 0).compareTo(b.distanceFromUser ?? 0));

      print('DEBUG: Total de eventos na região: ${eventsInRadius.length}');
      _events = eventsInRadius;
      
    } catch (e) {
      _errorMessage = 'Erro ao buscar eventos próximos (RPC): $e';
      NotificationService.instance.showError('Erro ao buscar eventos próximos (RPC): $e');
      if (kDebugMode) {
        print('Erro ao buscar eventos próximos (RPC): $e');
      }
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }
  
  // Métodos de filtro
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  
  void setSelectedCategories(List<String> categories) {
    _selectedCategories = categories;
    notifyListeners();
  }
  
  void setMaxDistance(double distance) {
    _maxDistance = distance;
    notifyListeners();
  }
  
  void setShowOnlyFreeEvents(bool showOnly) {
    _showOnlyFreeEvents = showOnly;
    notifyListeners();
  }
  
  void toggleCategoryFilter(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }
  
  void clearFilters() {
    _searchQuery = '';
    _selectedCategories.clear();
    _maxDistance = 50.0;
    _showOnlyFreeEvents = false;
    notifyListeners();
  }
  
  // Método para decodificar WKB (Well-Known Binary) de um POINT
  Map<String, double>? _parseWkbPoint(String wkbHex) {
    try {
      // Remove o prefixo '0x' se existir
      if (wkbHex.startsWith('0x')) {
        wkbHex = wkbHex.substring(2);
      }
      
      // WKB para POINT tem estrutura:
      // - 1 byte: byte order (01 = little endian, 00 = big endian)
      // - 4 bytes: geometry type (01000000 = POINT para little endian)
      // - 4 bytes: SRID (E6100000 = 4326 para little endian)
      // - 8 bytes: X coordinate (longitude)
      // - 8 bytes: Y coordinate (latitude)
      
      if (wkbHex.length < 42) { // Mínimo para um POINT com SRID
        print('DEBUG: WKB muito curto: ${wkbHex.length} caracteres');
        return null;
      }
      
      // Verificar se é little endian (01) e POINT com SRID (0101000020)
      if (!wkbHex.startsWith('0101000020')) {
        print('DEBUG: WKB não é um POINT com SRID: ${wkbHex.substring(0, 10)}');
        return null;
      }
      
      // Pular os primeiros 18 caracteres (9 bytes): byte order + type + SRID
      final coordsHex = wkbHex.substring(18);
      
      if (coordsHex.length < 32) { // 16 bytes = 32 caracteres hex
        print('DEBUG: Coordenadas WKB insuficientes');
        return null;
      }
      
      // Extrair longitude (primeiros 8 bytes = 16 caracteres)
      final lngHex = coordsHex.substring(0, 16);
      // Extrair latitude (próximos 8 bytes = 16 caracteres)
      final latHex = coordsHex.substring(16, 32);
      
      // Converter de little endian hex para double
      final lng = _hexToDouble(lngHex);
      final lat = _hexToDouble(latHex);
      
      return {'lat': lat, 'lng': lng};
    } catch (e) {
      print('DEBUG: Erro ao decodificar WKB: $e');
      return null;
    }
  }
  
  // Converter hex little endian para double (IEEE 754)
  double _hexToDouble(String hex) {
    // Converter cada par de caracteres hex para bytes
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    
    // Criar ByteData e inserir os bytes em little endian
    final byteData = ByteData(8);
    for (int i = 0; i < 8; i++) {
      byteData.setUint8(i, bytes[i]);
    }
    
    // Ler como double em little endian
    return byteData.getFloat64(0, Endian.little);
  }

  // Método para calcular distância entre dois pontos (fórmula de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Raio da Terra em km
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
  
  // Criar novo evento
  Future<bool> createEvent(EventModel event, [File? imageFile, List<String>? categoryIds]) async {
    try {
      String? imageUrl;
      
      // Upload da imagem se fornecida
      if (imageFile != null) {
        final fileName = 'event_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final response = await _supabase.storage
            .from('event-images')
            .upload(fileName, imageFile);
        
        if (response.isNotEmpty) {
          imageUrl = _supabase.storage
              .from('event-images')
              .getPublicUrl(fileName);
        }
      }
      
      // Criar evento com URL da imagem
      final eventData = event.toJson();
      if (imageUrl != null) {
        eventData['foto_principal_url'] = imageUrl;
      }
      
      final response = await _supabase
          .from('events')
          .insert(eventData)
          .select()
          .single();
      
      if (response != null) {
        final eventId = response['id'];
        
        // Criar relações com categorias se fornecidas
        if (categoryIds != null && categoryIds.isNotEmpty) {
          final categoryRelations = categoryIds.map((categoryId) => {
            'event_id': eventId,
            'category_id': categoryId,
          }).toList();
          
          await _supabase
              .from('event_categories')
              .insert(categoryRelations);
        }
        
        // Recarregar eventos para incluir o novo evento
        await loadEvents();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao criar evento: $e';
      NotificationService.instance.showError('Erro ao criar evento: $e');
      notifyListeners();
      return false;
    }
  }

  // Carregar eventos de uma empresa específica
  Future<void> loadCompanyEvents(String companyId) async {
    _isLoadingEvents = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('DEBUG: Iniciando loadCompanyEvents via RPC get_company_events...');
      final response = await supabase.rpc('get_company_events', params: {
        'p_company_id': companyId,
        'p_limit': 200,
        'p_offset': 0,
      });

      if (response != null) {
        final List data = response as List;
        _events = data.map((row) {
          final eventData = Map<String, dynamic>.from(row as Map);
          return EventModel.fromJson(eventData);
        }).toList();
      } else {
        _events = [];
      }

      if (kDebugMode) {
        print('Carregados ${_events.length} eventos da empresa $companyId (RPC)');
      }

      _errorMessage = null;
      
    } catch (e) {
      _errorMessage = 'Erro ao carregar eventos da empresa (RPC): $e';
      NotificationService.instance.showError('Erro ao carregar eventos da empresa (RPC): $e');
      if (kDebugMode) {
        print('Erro ao carregar eventos da empresa (RPC): $e');
      }
    } finally {
      _isLoadingEvents = false;
      notifyListeners();
    }
  }

  // Limpar dados
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
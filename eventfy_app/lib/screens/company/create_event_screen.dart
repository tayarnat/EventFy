import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../models/event_model.dart';
import '../../models/category_model.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/error_notification.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _externalLinkController = TextEditingController();
  final _streamingLinkController = TextEditingController();
  
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  
  bool _isFree = true;
  bool _isOnline = false;
  bool _isPresential = true;
  bool _requiresApproval = false;
  
  double? _selectedLatitude;
  double? _selectedLongitude;
  
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  
  List<CategoryModel> _selectedCategories = [];
  List<CategoryModel> _availableCategories = [];
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
  }
  
  Future<void> _loadCategories() async {
    final preferencesProvider = Provider.of<PreferencesProvider>(context, listen: false);
    await preferencesProvider.loadCategories();
    setState(() {
      _availableCategories = preferencesProvider.categories;
    });
  }
  
  void _toggleCategory(CategoryModel category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        if (_selectedCategories.length < 5) {
          _selectedCategories.add(category);
        } else {
          ErrorNotification.show(
            context,
            'Você pode selecionar no máximo 5 categorias',
          );
        }
      }
    });
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _minAgeController.dispose();
    _externalLinkController.dispose();
    _streamingLinkController.dispose();
    super.dispose();
  }
  
  Future<void> _selectImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ErrorNotification.show(
        context,
        'Erro ao selecionar imagem: $e',
      );
    }
  }
  
  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }
  
  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }
  
  Future<void> _selectLocation() async {
    // Navegar para tela de seleção de localização no mapa
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'] as double?;
        _selectedLongitude = result['longitude'] as double?;
        if (result['address'] != null) {
          _addressController.text = result['address'] as String;
        }
      });
    }
  }
  
  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_startDate == null || _startTime == null) {
      ErrorNotification.show(
        context,
        'Por favor, selecione a data e hora de início',
      );
      return;
    }
    
    if (_endDate == null || _endTime == null) {
      ErrorNotification.show(
        context,
        'Por favor, selecione a data e hora de fim',
      );
      return;
    }
    
    if (_selectedLatitude == null || _selectedLongitude == null) {
      ErrorNotification.show(
        context,
        'Por favor, selecione a localização no mapa',
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
      
      // Combinar data e hora
      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );
      
      final endDateTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );
      
      // Validar datas
      if (endDateTime.isBefore(startDateTime)) {
        throw Exception('A data de fim deve ser posterior à data de início');
      }
      
      // Criar evento
      final event = EventModel.create(
        companyId: authProvider.currentCompany!.id,
        titulo: _titleController.text.trim(),
        descricao: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        endereco: _addressController.text.trim(),
        latitude: _selectedLatitude!,
        longitude: _selectedLongitude!,
        dataInicio: startDateTime,
        dataFim: endDateTime,
        valor: _isFree ? null : double.tryParse(_priceController.text),
        isGratuito: _isFree,
        capacidade: _capacityController.text.isEmpty 
            ? null 
            : int.tryParse(_capacityController.text),
        idadeMinima: _minAgeController.text.isEmpty 
            ? 0 
            : int.tryParse(_minAgeController.text) ?? 0,
        linkExterno: _externalLinkController.text.trim().isEmpty 
            ? null 
            : _externalLinkController.text.trim(),
        linkStreaming: _streamingLinkController.text.trim().isEmpty 
            ? null 
            : _streamingLinkController.text.trim(),
        isOnline: _isOnline,
        isPresencial: _isPresential,
        requiresApproval: _requiresApproval,
      );
      
      // Criar evento no backend
      final categoryIds = _selectedCategories.map((category) => category.id).toList();
      await eventsProvider.createEvent(event, _selectedImage, categoryIds);
      
      if (mounted) {
        ErrorNotification.showSuccess(
          context,
          'Evento criado com sucesso!',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ErrorNotification.show(
          context,
          'Erro ao criar evento: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Evento'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem do evento
              Center(
                child: GestureDetector(
                  onTap: _selectImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Adicionar foto do evento',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Título
              CustomTextField(
                controller: _titleController,
                label: 'Título do Evento',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira o título do evento';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Descrição
              CustomTextField(
                controller: _descriptionController,
                label: 'Descrição',
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              
              // Categorias
              Text(
                'Categorias do Evento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione até 5 categorias que melhor descrevem seu evento',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              if (_availableCategories.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableCategories.map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category.nome),
                      selected: isSelected,
                      onSelected: (_) => _toggleCategory(category),
                      backgroundColor: Colors.grey[100],
                      selectedColor: Color(int.parse('0xFF${category.corHex?.replaceAll('#', '') ?? 'FF6B6B'}')).withOpacity(0.2),
                      checkmarkColor: Color(int.parse('0xFF${category.corHex?.replaceAll('#', '') ?? 'FF6B6B'}')),
                      labelStyle: TextStyle(
                        color: isSelected 
                            ? Color(int.parse('0xFF${category.corHex?.replaceAll('#', '') ?? 'FF6B6B'}'))
                            : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                )
              else
                const Center(
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 16),
              
              // Endereço
              CustomTextField(
                controller: _addressController,
                label: 'Endereço',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira o endereço';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Botão de localização
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectLocation,
                  icon: const Icon(Icons.location_on),
                  label: Text(
                    _selectedLatitude != null && _selectedLongitude != null
                        ? 'Localização selecionada'
                        : 'Selecionar no mapa',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Data e hora de início
              Text(
                'Data e Hora de Início',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _startDate != null
                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                            : 'Selecionar data',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(true),
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _startTime != null
                            ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                            : 'Selecionar hora',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Data e hora de fim
              Text(
                'Data e Hora de Fim',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(false),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'Selecionar data',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(false),
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _endTime != null
                            ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                            : 'Selecionar hora',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Preço
              Row(
                children: [
                  Checkbox(
                    value: _isFree,
                    onChanged: (value) {
                      setState(() {
                        _isFree = value ?? true;
                        if (_isFree) {
                          _priceController.clear();
                        }
                      });
                    },
                  ),
                  const Text('Evento gratuito'),
                ],
              ),
              if (!_isFree) ...[
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _priceController,
                  label: 'Preço (R\$)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!_isFree && (value == null || value.trim().isEmpty)) {
                      return 'Por favor, insira o preço';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              
              // Capacidade
              CustomTextField(
                controller: _capacityController,
                label: 'Capacidade (opcional)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              // Idade mínima
              CustomTextField(
                controller: _minAgeController,
                label: 'Idade mínima',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              
              // Tipo de evento
              Text(
                'Tipo de Evento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Presencial'),
                value: _isPresential,
                onChanged: (value) {
                  setState(() {
                    _isPresential = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Online'),
                value: _isOnline,
                onChanged: (value) {
                  setState(() {
                    _isOnline = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Links
              if (_isOnline) ...[
                CustomTextField(
                  controller: _streamingLinkController,
                  label: 'Link de Streaming',
                ),
                const SizedBox(height: 16),
              ],
              
              CustomTextField(
                controller: _externalLinkController,
                label: 'Link Externo (opcional)',
              ),
              const SizedBox(height: 24),
              
              // Configurações
              CheckboxListTile(
                title: const Text('Requer aprovação para participar'),
                value: _requiresApproval,
                onChanged: (value) {
                  setState(() {
                    _requiresApproval = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 32),
              
              // Botão criar
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  onPressed: _isLoading ? null : _createEvent,
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Criando...'),
                          ],
                        )
                      : const Text('Criar Evento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tela para seleção de localização no mapa
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(-23.5505, -46.6333), // São Paulo
    zoom: 12.0,
  );
  
  Future<void> _getAddressFromCoordinates(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
    });
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
        
        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Endereço não encontrado';
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar Localização'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'latitude': _selectedLocation!.latitude,
                  'longitude': _selectedLocation!.longitude,
                  'address': _selectedAddress ?? '',
                });
              },
              child: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
            },
            initialCameraPosition: _defaultPosition,
            onTap: (LatLng location) {
              setState(() {
                _selectedLocation = location;
              });
              _getAddressFromCoordinates(location);
            },
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedLocation!,
                      infoWindow: const InfoWindow(
                        title: 'Localização selecionada',
                      ),
                    ),
                  }
                : {},
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedLocation == null)
                      const Text(
                        'Toque no mapa para selecionar a localização do evento',
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      const Text(
                        'Localização selecionada:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}\nLng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingAddress)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Buscando endereço...'),
                          ],
                        )
                      else if (_selectedAddress != null)
                        Text(
                          _selectedAddress!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
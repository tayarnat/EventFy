import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../core/config/supabase_config.dart';

class AuthProvider extends ChangeNotifier implements Listenable {
  UserModel? _currentUser;
  CompanyModel? _currentCompany;
  bool _isLoading = false;
  String? _errorMessage;
  String? _userType;

  UserModel? get currentUser => _currentUser;
  CompanyModel? get currentCompany => _currentCompany;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null || _currentCompany != null;
  bool get isCompany => _userType == 'company';
  String? get userType => _userType;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _loadUserProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _currentCompany = null;
        _userType = null;
        _errorMessage = null;
        notifyListeners();
      }
    });

    // Verificar se já está logado
    if (supabase.auth.currentUser != null) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Primeiro, verificar o tipo de usuário na tabela users_base
      final userBaseResponse = await supabase
          .from('users_base')
          .select('user_type')
          .eq('id', userId)
          .single();
      
      _userType = userBaseResponse['user_type'];
      
      if (_userType == 'company') {
        final response = await supabase
            .from('companies')
            .select()
            .eq('id', userId)
            .single();
        Map<String, dynamic>? location = response['location'] as Map<String, dynamic>?;
        double? lat;
        double? lng;
        if (location != null && location['coordinates'] is List) {
          final coords = location['coordinates'] as List;
          if (coords.length >= 2) {
            lng = (coords[0] as num?)?.toDouble();
            lat = (coords[1] as num?)?.toDouble();
          }
        } else if (response['location'] is String) {
          final s = response['location'] as String;
          final m = RegExp(r'POINT\(([-\d\.]+)\s+([-\d\.]+)\)').firstMatch(s);
          if (m != null) {
            lng = double.tryParse(m.group(1)!);
            lat = double.tryParse(m.group(2)!);
          }
        }
        final mappedResponse = {
          'id': response['id'],
          'email': supabase.auth.currentUser!.email ?? '',
          'cnpj': response['cnpj'],
          'nome_fantasia': response['nome_fantasia'],
          'razao_social': response['razao_social'],
          'telefone': response['telefone'],
          'endereco': response['endereco'],
          'latitude': lat,
          'longitude': lng,
          'logo_url': response['logo_url'],
          'website': response['website'],
          'instagram': response['instagram'],
          'facebook': response['facebook'],
          'responsavel_nome': response['responsavel_nome'],
          'responsavel_cpf': response['responsavel_cpf'],
          'responsavel_telefone': response['responsavel_telefone'],
          'responsavel_email': response['responsavel_email'],
          'verificada': response['verificada'] ?? false,
          'verificada_em': response['verificada_em'],
          'total_events_created': response['total_events_created'] ?? 0,
          'average_rating': response['average_rating'] ?? 0.0,
          'total_followers': response['total_followers'] ?? 0,
          'created_at': response['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': response['updated_at'] ?? DateTime.now().toIso8601String(),
        };

        _currentCompany = CompanyModel.fromJson(mappedResponse);
        _currentUser = null;
      } else {
        // Carregar perfil do usuário
        final response = await supabase
            .from('users')
            .select()
            .eq('id', userId)
            .single();
        
        // Mapear os campos do banco para o modelo do usuário
        final mappedResponse = {
          'id': response['id'],
          'email': supabase.auth.currentUser!.email ?? '',
          'nome': response['nome'] ?? '',
          'telefone': response['telefone'],
          'endereco': response['endereco'],
          'dataNascimento': response['data_nascimento'],
          'cpf': response['cpf'],
          'genero': response['genero'],
          'rangeDistancia': response['range_distancia'] ?? 10000,
          'avatarUrl': response['avatar_url'],
          'locationLat': null, // Será preenchido se location estiver disponível
          'locationLng': null, // Será preenchido se location estiver disponível
          'onboardingCompleted': response['onboarding_completed'] ?? false,
          'createdAt': response['created_at'] != null ? response['created_at'] : DateTime.now().toIso8601String(),
          'updatedAt': response['updated_at'] != null ? response['updated_at'] : DateTime.now().toIso8601String(),
        };

        _currentUser = UserModel.fromJson(mappedResponse);
        _currentCompany = null;
      }
      
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar perfil: $e');
      _setError('Erro ao carregar perfil: $e');
    }
  }

  // Cadastro de usuário (pessoa física)
  Future<bool> signUpUser({
    required String email,
    required String password,
    required String nome,
    String? telefone,
    String? cpf,
    DateTime? dataNascimento,
    String? genero,
  }) async {
    try {
      _setLoading(true);
      
      // 1. Criar conta no Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Erro ao criar conta');
      }

      // 2. Criar registro na tabela users_base
      await supabase.from('users_base').insert({
        'id': authResponse.user!.id,
        'email': email,
        'password_hash': password, // Incluindo o password_hash
        'user_type': 'user',
      });

      // 3. Criar perfil do usuário
      // Usando o método insert com opção de ignorar RLS
      await supabase.from('users').insert({
        'id': authResponse.user!.id,
        'nome': nome,
        'telefone': telefone,
        'cpf': cpf,
        'data_nascimento': dataNascimento?.toIso8601String(),
        'genero': genero,
      });

      return true;
    } catch (e) {
      _setError('Erro no cadastro: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Registro de empresa
  Future<bool> signUpCompany({
    required String email,
    required String password,
    required String nomeFantasia,
    required String cnpj,
    required String responsavelNome,
  }) async {
    try {
      _setLoading(true);
      
      // 1. Criar conta no Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Erro ao criar conta');
      }

      // 2. Criar registro na tabela users_base
      await supabase.from('users_base').insert({
        'id': authResponse.user!.id,
        'email': email,
        'password_hash': password, // Incluindo o password_hash
        'user_type': 'company',
      });

      // 3. Criar perfil da empresa
      await supabase.from('companies').insert({
        'id': authResponse.user!.id,
        'nome_fantasia': nomeFantasia,
        'cnpj': cnpj,
        'responsavel_nome': responsavelNome,
      });

      return true;
    } catch (e) {
      _setError('Erro no cadastro: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Login
  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Em ambiente de desenvolvimento (debug), não bloquear por email não confirmado
      if (response.user?.emailConfirmedAt == null && !kDebugMode) {
        _setError('Erro no login: Email não confirmado');
        return false;
      }

      if (response.user != null) {
        await _loadUserProfile();
        return true;
      } else {
        _setError('Erro no login: Usuário não encontrado');
        return false;
      }
    } catch (e) {
      _setError('Erro no login: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _captureAndSaveCompanyLocationSilently() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final companyId = supabase.auth.currentUser?.id;
      if (companyId == null) {
        return;
      }
      await supabase
          .from('companies')
          .update({
            'location': {
              'type': 'Point',
              'coordinates': [position.longitude, position.latitude],
            },
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', companyId);
      if (_currentCompany != null) {
        _currentCompany = _currentCompany!.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  // Método para verificar se é o primeiro login
  bool get isFirstLogin {
    return _currentUser?.onboardingCompleted == false;
  }

  // Método para atualizar o perfil do usuário
  Future<void> refreshUserProfile() async {
    if (supabase.auth.currentUser != null) {
      await _loadUserProfile();
    }
  }

  // Método para atualizar os dados da empresa no provider
  void updateCompany(CompanyModel updatedCompany) {
    _currentCompany = updatedCompany;
    notifyListeners();
  }

  // Método para atualizar os dados do usuário no provider
  void updateUser(UserModel updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }

  // Logout
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

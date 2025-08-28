import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../core/config/supabase_config.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _loadUserProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _currentUser = null;
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
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = UserModel.fromJson(response);
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar perfil: $e');
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
      
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      return true;
    } catch (e) {
      _setError('Erro no login: $e');
      return false;
    } finally {
      _setLoading(false);
    }
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
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';
import '../models/user_preference_model.dart';

class PreferencesProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<CategoryModel> _categories = [];
  List<UserPreferenceModel> _userPreferences = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CategoryModel> get categories => _categories;
  List<UserPreferenceModel> get userPreferences => _userPreferences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Carregar todas as categorias disponíveis
  Future<void> loadCategories() async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('nome');
      
      _categories = response.map<CategoryModel>((json) {
        return CategoryModel(
          id: json['id'],
          codigoInterno: json['codigo_interno'],
          nome: json['nome'],
          descricao: json['descricao'],
          corHex: json['cor_hex'],
          icone: json['icone'],
          categoriaPai: json['categoria_pai'],
          isActive: json['is_active'] ?? true,
          createdAt: DateTime.parse(json['created_at']),
        );
      }).toList();
      
      notifyListeners();
    } catch (e) {
      _setError('Erro ao carregar categorias: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Carregar preferências do usuário
  Future<void> loadUserPreferences(String userId) async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _supabase
          .from('user_preferences')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('preference_score', ascending: false);
      
      _userPreferences = response.map<UserPreferenceModel>((json) {
        final preference = UserPreferenceModel(
          userId: json['user_id'],
          categoryId: json['category_id'],
          preferenceScore: (json['preference_score'] as num).toDouble(),
          createdAt: DateTime.parse(json['created_at']),
          updatedAt: DateTime.parse(json['updated_at']),
        );
        
        // Adicionar categoria se disponível
        if (json['categories'] != null) {
          preference.category = CategoryModel(
            id: json['categories']['id'],
            codigoInterno: json['categories']['codigo_interno'],
            nome: json['categories']['nome'],
            descricao: json['categories']['descricao'],
            corHex: json['categories']['cor_hex'],
            icone: json['categories']['icone'],
            categoriaPai: json['categories']['categoria_pai'],
            isActive: json['categories']['is_active'] ?? true,
            createdAt: DateTime.parse(json['categories']['created_at']),
          );
        }
        
        return preference;
      }).toList();
      
      notifyListeners();
    } catch (e) {
      _setError('Erro ao carregar preferências: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Salvar preferências do usuário (para onboarding)
  Future<bool> saveUserPreferences(String userId, List<UserPreferenceModel> preferences) async {
    try {
      _setLoading(true);
      _setError(null);
      
      // Primeiro, remover preferências existentes
      await _supabase
          .from('user_preferences')
          .delete()
          .eq('user_id', userId);
      
      // Inserir novas preferências
      final preferencesData = preferences.map((pref) => {
        'user_id': pref.userId,
        'category_id': pref.categoryId,
        'preference_score': pref.preferenceScore,
      }).toList();
      
      await _supabase
          .from('user_preferences')
          .insert(preferencesData);
      
      // Atualizar onboarding_completed
      await _supabase
          .from('users')
          .update({'onboarding_completed': true})
          .eq('id', userId);
      
      // Recarregar preferências
      await loadUserPreferences(userId);
      
      return true;
    } catch (e) {
      _setError('Erro ao salvar preferências: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Método para atualizar preferências do usuário (usado na edição de perfil)
  Future<bool> updateUserPreferences(String userId, List<UserPreferenceModel> preferences) async {
    try {
      _setLoading(true);
      _setError(null);

      // Primeiro, deletar preferências existentes do usuário
      await _supabase
          .from('user_preferences')
          .delete()
          .eq('user_id', userId);

      // Inserir novas preferências
      final preferencesData = preferences.map((pref) => {
        'user_id': pref.userId,
        'category_id': pref.categoryId,
        'preference_score': pref.preferenceScore,
      }).toList();
      
      await _supabase
          .from('user_preferences')
          .insert(preferencesData);

      // Recarregar preferências do usuário
      await loadUserPreferences(userId);

      return true;
    } catch (e) {
      _setError('Erro ao atualizar preferências: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Atualizar uma preferência específica
  Future<bool> updateUserPreference(UserPreferenceModel preference) async {
    try {
      _setLoading(true);
      _setError(null);
      
      await _supabase
          .from('user_preferences')
          .update({
            'preference_score': preference.preferenceScore,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', preference.userId)
          .eq('category_id', preference.categoryId);
      
      // Atualizar localmente
      final index = _userPreferences.indexWhere(
        (p) => p.userId == preference.userId && p.categoryId == preference.categoryId,
      );
      
      if (index != -1) {
        _userPreferences[index] = preference;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('Erro ao atualizar preferência: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Obter categorias não selecionadas pelo usuário
  List<CategoryModel> getUnselectedCategories() {
    final selectedCategoryIds = _userPreferences.map((p) => p.categoryId).toSet();
    return _categories.where((cat) => !selectedCategoryIds.contains(cat.id)).toList();
  }

  // Obter preferências ordenadas por score (maior para menor)
  List<UserPreferenceModel> getPreferencesByScore() {
    final sortedPreferences = List<UserPreferenceModel>.from(_userPreferences);
    sortedPreferences.sort((a, b) => b.preferenceScore.compareTo(a.preferenceScore));
    return sortedPreferences;
  }

  // Limpar dados
  void clear() {
    _categories.clear();
    _userPreferences.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
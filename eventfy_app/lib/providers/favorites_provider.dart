import 'package:flutter/material.dart';
import '../core/config/supabase_config.dart';
import '../models/event_model.dart';
import '../models/company_model.dart';
import '../models/event_review_model.dart';

class CompanyDetailsInfo {
  final CompanyModel company;
  final List<EventReviewModel> recentReviews;
  final List<EventModel> pastEvents;
  final Map<String, int> categoryCounts;
  final double averagePastEventRating;

  CompanyDetailsInfo({
    required this.company,
    required this.recentReviews,
    required this.pastEvents,
    required this.categoryCounts,
    required this.averagePastEventRating,
  });
}

class FavoritesProvider with ChangeNotifier {
  final Set<String> _favoriteEventIds = {};
  final Set<String> _favoriteCompanyIds = {};

  final Map<String, bool> _eventFavCache = {};
  final Map<String, bool> _companyFavCache = {};

  // Getters síncronos baseados em cache para refletir estado no UI
  bool isEventFavoritedCached(String eventId) {
    return _favoriteEventIds.contains(eventId) || (_eventFavCache[eventId] ?? false);
  }

  bool isCompanyFavoritedCached(String companyId) {
    return _favoriteCompanyIds.contains(companyId) || (_companyFavCache[companyId] ?? false);
  }

  bool get hasAnyFavorites => _favoriteEventIds.isNotEmpty || _favoriteCompanyIds.isNotEmpty;

  // ===== Eventos =====
  Future<bool> isEventFavorited(String eventId) async {
    if (_eventFavCache.containsKey(eventId)) return _eventFavCache[eventId]!;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final res = await supabase
          .from('user_favorite_events')
          .select('event_id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();
      final favorited = res != null;
      _eventFavCache[eventId] = favorited;
      if (favorited) _favoriteEventIds.add(eventId);
      return favorited;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleEventFavorite(EventModel event) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final isFav = await isEventFavorited(event.id);
    try {
      if (isFav) {
        await supabase
            .from('user_favorite_events')
            .delete()
            .eq('user_id', userId)
            .eq('event_id', event.id);
        _favoriteEventIds.remove(event.id);
        _eventFavCache[event.id] = false;
        try {
          final attend = await supabase
              .from('event_attendances')
              .select('status')
              .eq('user_id', userId)
              .eq('event_id', event.id)
              .maybeSingle();
          if (attend != null && attend['status'] == 'interessado') {
            await supabase
                .from('event_attendances')
                .delete()
                .eq('user_id', userId)
                .eq('event_id', event.id);
          }
        } catch (_) {}
      } else {
        await supabase.from('user_favorite_events').insert({
          'user_id': userId,
          'event_id': event.id,
          'created_at': DateTime.now().toIso8601String(),
        });
        _favoriteEventIds.add(event.id);
        _eventFavCache[event.id] = true;
        try {
          final attend = await supabase
              .from('event_attendances')
              .select('status')
              .eq('user_id', userId)
              .eq('event_id', event.id)
              .maybeSingle();
          if (attend == null) {
            await supabase.from('event_attendances').upsert({
              'user_id': userId,
              'event_id': event.id,
              'status': 'interessado',
              'checked_in_at': null,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      // silencioso, UI pode mostrar erro via SnackBar
      rethrow;
    }
  }

  Future<List<EventModel>> fetchFavoriteEvents() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final favIdsRes = await supabase
        .from('user_favorite_events')
        .select('event_id')
        .eq('user_id', userId);
    final ids = (favIdsRes as List).map((e) => e['event_id'] as String).toList();
    _favoriteEventIds
      ..clear()
      ..addAll(ids);

    if (ids.isEmpty) return [];

    final eventsRes = await supabase.rpc('get_events_by_ids', params: {
      'p_ids': ids,
    });

    final List<dynamic> list = eventsRes as List<dynamic>;
    return list
        .map((e) => EventModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ===== Empresas =====
  Future<bool> isCompanyFavorited(String companyId) async {
    if (_companyFavCache.containsKey(companyId)) return _companyFavCache[companyId]!;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final res = await supabase
          .from('user_favorite_companies')
          .select('company_id')
          .eq('user_id', userId)
          .eq('company_id', companyId)
          .maybeSingle();
      final favorited = res != null;
      _companyFavCache[companyId] = favorited;
      if (favorited) _favoriteCompanyIds.add(companyId);
      return favorited;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleCompanyFavorite(CompanyModel company) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final isFav = await isCompanyFavorited(company.id);
    try {
      if (isFav) {
        await supabase
            .from('user_favorite_companies')
            .delete()
            .eq('user_id', userId)
            .eq('company_id', company.id);
        _favoriteCompanyIds.remove(company.id);
        _companyFavCache[company.id] = false;
      } else {
        await supabase.from('user_favorite_companies').insert({
          'user_id': userId,
          'company_id': company.id,
          'created_at': DateTime.now().toIso8601String(),
        });
        _favoriteCompanyIds.add(company.id);
        _companyFavCache[company.id] = true;
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CompanyModel>> fetchFavoriteCompanies() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final favIdsRes = await supabase
        .from('user_favorite_companies')
        .select('company_id')
        .eq('user_id', userId);
    final ids = (favIdsRes as List).map((e) => e['company_id'] as String).toList();
    _favoriteCompanyIds
      ..clear()
      ..addAll(ids);

    if (ids.isEmpty) return [];

    final companiesRes = await supabase
        .from('companies')
        .select('*')
        .or(ids.map((id) => 'id.eq.$id').join(','))
        .order('nome_fantasia', ascending: true);

    return (companiesRes as List)
        .map((e) => CompanyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ===== Detalhes da Empresa (para favoritos) =====
  Future<CompanyDetailsInfo> fetchCompanyDetailsInfo(String companyId) async {
    // Empresa
    final companyRes = await supabase
        .from('companies')
        .select('*')
        .eq('id', companyId)
        .maybeSingle();
    if (companyRes == null) {
      throw Exception('Empresa não encontrada');
    }
    final company = CompanyModel.fromJson(companyRes as Map<String, dynamic>);

    // Avaliações recentes (via RPC pública)
    final reviewsRes = await supabase.rpc('get_company_reviews_public', params: {
      'p_company_id': companyId,
      'p_limit': 10,
      'p_offset': 0,
    });
    final recentReviews = (reviewsRes as List)
        .map((e) => EventReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Eventos passados (finalizados)
    final eventsRes = await supabase
        .from('events')
        .select('*')
        .eq('company_id', companyId)
        .eq('status', 'finalizado')
        .order('data_inicio', ascending: false)
        .limit(20);
    final pastEvents = (eventsRes as List)
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Média de avaliações de eventos passados
    double avgRating = 0.0;
    final ratings = pastEvents.map((e) => e.averageRating ?? 0.0).toList();
    if (ratings.isNotEmpty) {
      avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
    }

    // Resumo de categorias dos eventos passados
    Map<String, int> categoryCounts = {};
    if (pastEvents.isNotEmpty) {
      final eventIds = pastEvents.map((e) => e.id).toList();
      final ecRes = await supabase
          .from('event_categories')
          .select('category_id, categories(nome)')
          .or(eventIds.map((id) => 'event_id.eq.$id').join(','));
      final list = (ecRes as List);
      for (var item in list) {
        final cat = item['categories'];
        if (cat != null && cat['nome'] != null) {
          final nome = cat['nome'] as String;
          categoryCounts[nome] = (categoryCounts[nome] ?? 0) + 1;
        }
      }
    }

    return CompanyDetailsInfo(
      company: company,
      recentReviews: recentReviews,
      pastEvents: pastEvents,
      categoryCounts: categoryCounts,
      averagePastEventRating: avgRating,
    );
  }
}

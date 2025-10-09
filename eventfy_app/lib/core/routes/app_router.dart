import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/company/company_home_screen.dart';
import '../../screens/company/create_event_screen.dart';
import '../../screens/onboarding/preferences_onboarding_screen.dart';
import '../../screens/profile/profile_edit_screen.dart';
import '../../screens/map/map_screen.dart';
import '../../screens/profile/attendance_history_screen.dart';

/// Classe responsável por gerenciar as rotas da aplicação usando GoRouter
class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final router = GoRouter(
    refreshListenable: authProvider,
    debugLogDiagnostics: true,
    initialLocation: '/',
    redirect: _handleRedirect,
    routes: [
      // Rota raiz que redireciona com base no estado de autenticação
      GoRoute(
        path: '/',
        builder: (context, state) => const SizedBox(), // Placeholder
      ),
      
      // Rotas de autenticação
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => RegisterScreen(),
      ),
      
      // Rota de onboarding
      GoRoute(
        path: '/onboarding/preferences',
        name: 'onboarding_preferences',
        builder: (context, state) => const PreferencesOnboardingScreen(),
      ),
      
      // Rotas protegidas (requerem autenticação)
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => HomeScreen(),
      ),
      GoRoute(
        path: '/company',
        name: 'company_home',
        builder: (context, state) => CompanyHomeScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'profile_edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/company/create-event',
        name: 'create_event',
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/map',
        name: 'map',
        builder: (context, state) {
          final lat = state.uri.queryParameters['lat'];
          final lng = state.uri.queryParameters['lng'];
          final eventId = state.uri.queryParameters['eventId'];
          
          return MapScreen(
            initialLat: lat != null ? double.tryParse(lat) : null,
            initialLng: lng != null ? double.tryParse(lng) : null,
            eventId: eventId,
          );
        },
      ),
      GoRoute(
        path: '/profile/history',
        name: 'attendance_history',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
    ],
  );

  /// Função que gerencia os redirecionamentos com base no estado de autenticação
  String? _handleRedirect(BuildContext context, GoRouterState state) {
    // Obtém o caminho atual
    final String location = state.uri.toString();
    
    // Verifica se o usuário está autenticado
    final bool isAuthenticated = authProvider.isAuthenticated;
    
    // Verifica se está em uma rota de autenticação
    final bool isAuthRoute = location == '/login' || location == '/register';
    
    // Verifica se está na rota de onboarding
    final bool isOnboardingRoute = location == '/onboarding/preferences';
    
    // Se não estiver autenticado e não estiver em uma rota de autenticação,
    // redireciona para a tela de login
    if (!isAuthenticated && !isAuthRoute) {
      return '/login';
    }
    
    // Se estiver autenticado
    if (isAuthenticated) {
      // Verifica se precisa fazer onboarding
      final bool needsOnboarding = authProvider.isFirstLogin;
      
      // Se precisa de onboarding e não está na rota de onboarding
      if (needsOnboarding && !isOnboardingRoute) {
        return '/onboarding/preferences';
      }
      
      // Se não precisa de onboarding e está em uma rota de autenticação ou onboarding
      if (!needsOnboarding && (isAuthRoute || isOnboardingRoute)) {
        return authProvider.isCompany ? '/company' : '/home';
      }
    }
    
    // Se estiver na rota raiz, redireciona com base no estado de autenticação
    if (location == '/') {
      if (isAuthenticated) {
        if (authProvider.isFirstLogin) {
          return '/onboarding/preferences';
        } else {
          return authProvider.isCompany ? '/company' : '/home';
        }
      } else {
        return '/login';
      }
    }
    
    // Não redireciona
    return null;
  }
}
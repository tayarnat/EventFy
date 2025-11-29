import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/config/supabase_config.dart';
import 'core/routes/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/events_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/notifications_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/notification_service.dart';

// Observer para manter o contexto do NotificationService atualizado
class NotificationNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateNotificationContext();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _updateNotificationContext();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateNotificationContext();
  }

  void _updateNotificationContext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigator?.context;
      if (context != null) {
        NotificationService().setContext(context);
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = Provider.of<AuthProvider>(context);
          final appRouter = AppRouter(authProvider);
          
          return MaterialApp.router(
            title: 'EventFy',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.deepPurple,
              fontFamily: GoogleFonts.poppins().fontFamily,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: Colors.deepPurple.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            routerConfig: appRouter.router,
            builder: (context, child) {
              NotificationService().setContext(context);
              return _AppBootstrap(child: child ?? const SizedBox());
            },
          );
        },
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  final Widget child;
  const _AppBootstrap({super.key, required this.child});
  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  String? _lastUserId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final notifications = Provider.of<NotificationsProvider>(context, listen: false);
    final uid = auth.currentUser?.id ?? auth.currentCompany?.id;
    if (uid != null && uid != _lastUserId) {
      _lastUserId = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifications.initialize();
      });
    }
    if (uid == null && _lastUserId != null) {
      _lastUserId = null;
      notifications.reset();
    }
  }
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// A classe AuthWrapper foi removida pois o GoRouter agora gerencia a navegação
// com base no estado de autenticação

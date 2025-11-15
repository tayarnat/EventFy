import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/event_card.dart';
import '../../models/event_model.dart';
import '../map/map_screen.dart';
import '../event/event_details_screen.dart';
import '../../services/rate_event_notifications_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeTab(),
    SearchTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Consumer<NotificationsProvider>(
        builder: (context, notifProvider, _) {
          final hasUnread = notifProvider.unreadCount > 0;
          return BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Início',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Buscar',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.person),
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Perfil',
              ),
            ],
          );
        },
      ),
    );
  }
}

// Aba Início
class HomeTab extends StatefulWidget {
  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Inicializar providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
      final preferencesProvider = Provider.of<PreferencesProvider>(context, listen: false);
      final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
      
      if (eventsProvider.events.isEmpty && !eventsProvider.isLoadingEvents) {
        eventsProvider.initialize();
      }
      
      if (preferencesProvider.categories.isEmpty) {
        preferencesProvider.loadCategories();
      }

      // Inicializar notificações (carregar e assinar em tempo real)
      notificationsProvider.initialize();

      // Verificar notificações de avaliação pós-evento e abrir a folha de avaliação se houver
      RateEventNotificationsService.checkAndPrompt(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/eventfy_logo.png', height: 120),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Eventos Próximos'),
            Tab(text: 'Eventos para Você'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          NearbyEventsTab(),
          RecommendedEventsTab(),
        ],
      ),
    );
  }
}

// Aba Buscar
class SearchTab extends StatefulWidget {
  @override
  _SearchTabState createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {


  @override
  void initState() {
    super.initState();
    // Inicializar o provider de eventos quando a aba for carregada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventsProvider = Provider.of<EventsProvider>(context, listen: false);
      if (eventsProvider.events.isEmpty && !eventsProvider.isLoadingEvents) {
        eventsProvider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa ocupando toda a tela
          const MapScreen(),
        ],
      ),
    );
  }
}

// Aba Perfil
class ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informações do usuário
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            user?.nome.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nome ?? 'Usuário',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user?.email ?? 'email@exemplo.com',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Opções do menu
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Editar Perfil'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    context.pushNamed('profile_edit');
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: const Text('Eventos e Empresas Favoritos'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    context.pushNamed('favorites');
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Histórico de Eventos'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    context.pushNamed('attendance_history');
                  },
                ),
                
                Consumer<NotificationsProvider>(
                  builder: (context, notifProvider, _) {
                    final unread = notifProvider.unreadCount;
                    return ListTile(
                      leading: const Icon(Icons.notifications),
                      title: const Text('Notificações'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios),
                        ],
                      ),
                      onTap: () {
                        context.pushNamed('notifications');
                      },
                    );
                  },
                ),
                
                const Spacer(),
                
                // Botão de logout
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await authProvider.signOut();
                      // O GoRouter redirecionará automaticamente para a tela de login
                      // com base no estado de autenticação
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sair'),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Aba de Eventos Próximos
class NearbyEventsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<EventsProvider>(
      builder: (context, eventsProvider, child) {
        if (eventsProvider.isLoadingEvents) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (eventsProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar eventos',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  eventsProvider.errorMessage!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => eventsProvider.initialize(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          );
        }

        // Filtrar e ordenar eventos por distância
        final nearbyEvents = _getNearbyEventsSorted(eventsProvider.filteredEvents);

        if (nearbyEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum evento próximo',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ative a localização para ver eventos próximos',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => eventsProvider.initialize(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: nearbyEvents.length,
            itemBuilder: (context, index) {
              final event = nearbyEvents[index];
              return CompactEventCard(
                event: event,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  List<EventModel> _getNearbyEventsSorted(List<EventModel> events) {
    // Filtrar eventos que têm distância calculada
    final eventsWithDistance = events
        .where((event) => event.distanceFromUser != null)
        .toList();
    
    // Ordenar por distância
    eventsWithDistance.sort((a, b) => 
        a.distanceFromUser!.compareTo(b.distanceFromUser!));
    
    return eventsWithDistance;
  }
}

// Aba de Eventos Recomendados
class RecommendedEventsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<EventsProvider, PreferencesProvider>(
      builder: (context, eventsProvider, preferencesProvider, child) {
        if (eventsProvider.isLoadingEvents) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (eventsProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar eventos',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => eventsProvider.initialize(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          );
        }

        // Obter eventos recomendados baseados nas preferências
        final recommendedEvents = _getRecommendedEvents(
          eventsProvider.events,
          preferencesProvider,
        );

        if (recommendedEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.recommend,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma recomendação disponível',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure suas preferências para receber recomendações personalizadas',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => eventsProvider.initialize(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: recommendedEvents.length,
            itemBuilder: (context, index) {
              final event = recommendedEvents[index];
              return CompactEventCard(
                event: event,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  List<EventModel> _getRecommendedEvents(
    List<EventModel> events,
    PreferencesProvider preferencesProvider,
  ) {
    final userPreferences = preferencesProvider.userPreferences;
    
    if (userPreferences.isEmpty) {
      // Se não há preferências, retornar eventos ordenados por popularidade
      final sortedEvents = List<EventModel>.from(events);
      sortedEvents.sort((a, b) => 
          (b.totalInterested + b.totalConfirmed).compareTo(
              a.totalInterested + a.totalConfirmed));
      return sortedEvents;
    }

    // Calcular score de recomendação para cada evento
    final eventsWithScore = events.map((event) {
      int score = 0;
      
      // Pontuação baseada nas categorias preferidas
      if (event.categorias != null) {
        for (String category in event.categorias!) {
          if (userPreferences.contains(category)) {
            score += 10; // Pontos por categoria correspondente
          }
        }
      }
      
      // Pontuação baseada na popularidade
      score += (event.totalInterested * 2); // Interessados valem 2 pontos
      score += (event.totalConfirmed * 3); // Confirmados valem 3 pontos
      
      // Pontuação baseada na avaliação
      if (event.averageRating != null) {
        score += (event.averageRating! * 2).round(); // Rating vale até 10 pontos
      }
      
      return MapEntry(event, score);
    }).toList();

    // Ordenar por score decrescente
    eventsWithScore.sort((a, b) => b.value.compareTo(a.value));
    
    return eventsWithScore.map((entry) => entry.key).toList();
  }
}

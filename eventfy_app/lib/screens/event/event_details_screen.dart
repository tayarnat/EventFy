import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/event_model.dart';
import '../../widgets/common/custom_button.dart';
import '../map/map_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header com foto menor
          Container(
            height: 200, // Reduzido de 300 para 200
            width: double.infinity,
            child: Stack(
              children: [
                // Foto do evento ou placeholder
                event.fotoPrincipalUrl != null && event.fotoPrincipalUrl!.isNotEmpty
                    ? Image.network(
                        event.fotoPrincipalUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Sem foto disponível',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Sem foto disponível',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                // Botão de voltar
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Área scrollável
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título e preço
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.titulo,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: event.isGratuito ? Colors.green : Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.formattedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Tags/Categorias
                  if (event.categorias != null && event.categorias!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categorias',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: event.categorias!.map((categoria) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                categoria,
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  
                  // Data e hora
                  _buildInfoSection(
                    'Data e Hora',
                    '${DateFormat('dd/MM/yyyy').format(event.dataInicio)} às ${DateFormat('HH:mm').format(event.dataInicio)}',
                    Icons.calendar_today,
                    context,
                  ),
                  
                  // Localização
                  _buildInfoSection(
                    'Localização',
                    event.endereco,
                    Icons.location_on,
                    context,
                  ),
                  
                  // Distância (se disponível)
                  if (event.distanceFromUser != null)
                    _buildInfoSection(
                      'Distância',
                      '${event.distanceFromUser!.toStringAsFixed(1)} km de você',
                      Icons.directions_walk,
                      context,
                    ),
                  
                  // Idade mínima
                  if (event.idadeMinima != null && event.idadeMinima! > 0)
                    _buildInfoSection(
                      'Idade Mínima',
                      '${event.idadeMinima} anos',
                      Icons.person,
                      context,
                    ),
                  
                  // Capacidade máxima
                    if (event.capacidade != null)
                      _buildInfoSection(
                        'Capacidade máxima',
                        '${event.capacidade} pessoas',
                        Icons.group,
                        context,
                      ),
                  
                  // Descrição
                  if (event.descricao != null && event.descricao!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descrição',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.descricao!,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  
                  // Espaço extra para não ficar colado nos botões
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Botões fixos na parte inferior
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        // Navegar para o mapa com a localização do evento mantendo a barra inferior
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: Text(event.titulo),
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              body: MapScreen(
                                initialLat: event.latitude,
                                initialLng: event.longitude,
                                eventId: event.id,
                              ),
                            ),
                          ),
                        );
                      },
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      child: Text(
                        'Ver no Mapa',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      onPressed: () {
                        // Aqui você pode adicionar lógica para participar/comprar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              event.isGratuito 
                                  ? 'Participação confirmada!' 
                                  : 'Redirecionando para compra...',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      color: Theme.of(context).primaryColor,
                      child: Text(
                        event.isGratuito ? 'Participar' : 'Comprar Ingresso',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection(String title, String content, IconData icon, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
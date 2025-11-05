import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/preferences_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/category_model.dart';
import '../../models/user_preference_model.dart';
import '../../widgets/common/custom_button.dart';

class PreferencesOnboardingScreen extends StatefulWidget {
  const PreferencesOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesOnboardingScreen> createState() => _PreferencesOnboardingScreenState();
}

class _PreferencesOnboardingScreenState extends State<PreferencesOnboardingScreen> {
  List<CategoryModel> _selectedCategories = [];
  // Removido _categoryRankings - usaremos apenas a ordem da lista
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
  }

  void _toggleCategory(CategoryModel category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        if (_selectedCategories.length < 10) {
          _selectedCategories.add(category);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você pode selecionar no máximo 10 preferências'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  // Removido _reorderRankings - não é mais necessário

  void _moveCategory(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final CategoryModel item = _selectedCategories.removeAt(oldIndex);
      _selectedCategories.insert(newIndex, item);
    });
  }

  Future<void> _savePreferences() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos uma preferência'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final preferencesProvider = Provider.of<PreferencesProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        throw Exception('Usuário não encontrado');
      }

      // Criar lista de preferências baseada na ordem (posição na lista)
      final preferences = <UserPreferenceModel>[];
      for (int i = 0; i < _selectedCategories.length; i++) {
        final category = _selectedCategories[i];
        // Calcular preference_score baseado na posição: 1º = 1.0, 2º = 0.9, etc.
        final preferenceScore = (10 - i) / 10.0;
        
        preferences.add(UserPreferenceModel.create(
          userId: userId,
          categoryId: category.id,
          preferenceScore: preferenceScore,
        ));
      }

      final success = await preferencesProvider.saveUserPreferences(userId, preferences);

      if (success) {
        // Recarregar perfil do usuário para atualizar onboarding_completed
        await authProvider.refreshUserProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferências salvas com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(preferencesProvider.errorMessage ?? 'Erro ao salvar preferências'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
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
        title: const Text('Suas Preferências'),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove botão de voltar
      ),
      body: Consumer<PreferencesProvider>(
        builder: (context, preferencesProvider, child) {
          if (preferencesProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (preferencesProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    preferencesProvider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCategories,
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instruções
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Como funciona?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Selecione até 10 categorias de seu interesse\n'
                          '2. Arraste para reordenar por prioridade\n'
                          '3. A primeira será sua maior preferência',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Contador de seleções
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categorias Disponíveis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedCategories.length}/10',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Lista de categorias disponíveis
                Expanded(
                  flex: 2,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: preferencesProvider.categories.length,
                    itemBuilder: (context, index) {
                      final category = preferencesProvider.categories[index];
                      final isSelected = _selectedCategories.contains(category);
                      final ranking = isSelected ? _selectedCategories.indexOf(category) + 1 : null;
                      
                      return GestureDetector(
                        onTap: () => _toggleCategory(category),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Theme.of(context).primaryColor.withOpacity(0.1)
                                : Colors.grey[100],
                            border: Border.all(
                              color: isSelected 
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (category.corHex != null)
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Color(int.parse(
                                            category.corHex!.replaceFirst('#', '0xFF'),
                                          )),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        category.nome,
                                        style: TextStyle(
                                          fontWeight: isSelected 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                          color: isSelected 
                                              ? Theme.of(context).primaryColor
                                              : Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected && ranking != null)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        ranking.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                if (_selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Suas Preferências (arraste para reordenar)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Lista reordenável de preferências selecionadas
                  Expanded(
                    flex: 1,
                    child: ReorderableListView.builder(
                      itemCount: _selectedCategories.length,
                      onReorder: _moveCategory,
                      itemBuilder: (context, index) {
                        final category = _selectedCategories[index];
                        final ranking = index + 1;
                        
                        return Container(
                          key: ValueKey(category.id),
                          margin: const EdgeInsets.only(bottom: 4),
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  ranking.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(category.nome),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.drag_handle,
                                    color: Colors.grey[400],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _toggleCategory(category),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Botão de salvar
                CustomButton(
                  onPressed: _isLoading ? null : _savePreferences,
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
                            Text('Salvando...'),
                          ],
                        )
                      : const Text('Salvar Preferências'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
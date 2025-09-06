import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/preferences_provider.dart';
import '../../models/category_model.dart';
import '../../models/user_preference_model.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({Key? key}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controladores para dados pessoais
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  
  // Variáveis para preferências
  List<UserPreferenceModel> _userPreferences = [];
  List<CategoryModel> _availableCategories = [];
  List<CategoryModel> _selectedCategories = [];
  // Removido _categoryRankings - usaremos apenas a ordem da lista
  
  bool _isLoading = false;
  bool _isLoadingPreferences = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _loadPreferences();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user != null) {
      _nomeController.text = user.nome ?? '';
      _telefoneController.text = user.telefone ?? '';
      _enderecoController.text = user.endereco ?? '';
    }
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoadingPreferences = true;
    });

    try {
      final preferencesProvider = Provider.of<PreferencesProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId != null) {
        // Carregar categorias e preferências do usuário
        await preferencesProvider.loadCategories();
        await preferencesProvider.loadUserPreferences(userId);
        
        setState(() {
          _availableCategories = preferencesProvider.categories;
          _userPreferences = preferencesProvider.userPreferences;
          
          // Configurar categorias selecionadas ordenadas por preference_score
          _selectedCategories = _userPreferences.map((pref) {
            return _availableCategories.firstWhere(
              (cat) => cat.id == pref.categoryId,
              orElse: () => CategoryModel(
                id: pref.categoryId,
                codigoInterno: '',
                nome: 'Categoria não encontrada',
                descricao: null,
                corHex: null,
                icone: null,
                categoriaPai: null,
                isActive: true,
                createdAt: DateTime.now(),
              ),
            );
          }).toList();
          
          // Ordenar por preference_score (maior para menor)
          _selectedCategories.sort((a, b) {
            final scoreA = _userPreferences.firstWhere((p) => p.categoryId == a.id).preferenceScore;
            final scoreB = _userPreferences.firstWhere((p) => p.categoryId == b.id).preferenceScore;
            return (scoreB ?? 0.0).compareTo(scoreA ?? 0.0);
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar preferências: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingPreferences = false;
      });
    }
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

  Future<void> _savePersonalData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implementar salvamento dos dados pessoais no Supabase
      // Por enquanto, apenas simular o salvamento
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados pessoais salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          preferenceScore: preferenceScore.clamp(0.1, 1.0),
        ));
      }

      // Atualizar preferências (isso vai substituir as existentes)
      final success = await preferencesProvider.updateUserPreferences(userId, preferences);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferências atualizadas com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(preferencesProvider.errorMessage ?? 'Erro ao atualizar preferências'),
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
        title: const Text('Editar Perfil'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: 'Dados Pessoais',
            ),
            Tab(
              icon: Icon(Icons.favorite),
              text: 'Preferências',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalDataTab(),
          _buildPreferencesTab(),
        ],
      ),
    );
  }

  Widget _buildPersonalDataTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações Pessoais',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          TextFormField(
            controller: _nomeController,
            decoration: const InputDecoration(
              labelText: 'Nome Completo',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor, insira seu nome completo';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _telefoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _enderecoController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Endereço',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
          
          const Spacer(),
          
          CustomButton(
            onPressed: _isLoading ? null : _savePersonalData,
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
                : const Text('Salvar Dados Pessoais'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab() {
    if (_isLoadingPreferences) {
      return const Center(
        child: CircularProgressIndicator(),
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
                        Icons.info_outline,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Suas Preferências',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecione até 10 categorias e organize por prioridade para personalizar sua experiência.',
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
              itemCount: _availableCategories.length,
              itemBuilder: (context, index) {
                final category = _availableCategories[index];
                final isSelected = _selectedCategories.contains(category);
                final position = _selectedCategories.indexOf(category) + 1;
                
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
                        if (isSelected)
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
                                  position.toString(),
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
          
          // Botão de salvar preferências
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
  }
}
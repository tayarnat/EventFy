import '../../core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/company_model.dart';
import '../../services/notification_service.dart';

class CompanyProfileEditScreen extends StatefulWidget {
  @override
  _CompanyProfileEditScreenState createState() => _CompanyProfileEditScreenState();
}

class _CompanyProfileEditScreenState extends State<CompanyProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _razaoSocialController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }
  
  void _loadCompanyData() {
    final company = Provider.of<AuthProvider>(context, listen: false).currentCompany;
    if (company != null) {
      _nomeController.text = company.nomeFantasia ?? '';
      _razaoSocialController.text = company.razaoSocial ?? '';
      _emailController.text = company.email ?? '';
      _telefoneController.text = company.telefone ?? '';
      _enderecoController.text = company.endereco ?? '';
      _websiteController.text = company.website ?? '';
      _instagramController.text = company.instagram ?? '';
      _facebookController.text = company.facebook ?? '';
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final company = authProvider.currentCompany;
      
      if (company == null) {
        throw Exception('Empresa não encontrada');
      }
      
      final updatedData = {
        'nome_fantasia': _nomeController.text.trim(),
        'razao_social': _razaoSocialController.text.trim().isEmpty ? null : _razaoSocialController.text.trim(),
        'email': _emailController.text.trim(),
        'telefone': _telefoneController.text.trim().isEmpty ? null : _telefoneController.text.trim(),
        'endereco': _enderecoController.text.trim().isEmpty ? null : _enderecoController.text.trim(),
        'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        'instagram': _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
        'facebook': _facebookController.text.trim().isEmpty ? null : _facebookController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await supabase
          .from('companies')
          .update(updatedData)
          .eq('id', company.id);
      
      // Atualizar o provider com os novos dados
      final updatedCompany = company.copyWith(
        nomeFantasia: _nomeController.text.trim(),
        razaoSocial: _razaoSocialController.text.trim().isEmpty ? null : _razaoSocialController.text.trim(),
        email: _emailController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty ? null : _telefoneController.text.trim(),
        endereco: _enderecoController.text.trim().isEmpty ? null : _enderecoController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        instagram: _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
        facebook: _facebookController.text.trim().isEmpty ? null : _facebookController.text.trim(),
        updatedAt: DateTime.now(),
      );
      
      authProvider.updateCompany(updatedCompany);
      
      NotificationService.instance.showSuccess(
        'Perfil atualizado com sucesso!'
      );
      
      Navigator.pop(context);
      
    } catch (e) {
      NotificationService.instance.showError(
        'Erro ao atualizar perfil: $e'
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Salvar',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar da empresa
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      _nomeController.text.isNotEmpty
                          ? _nomeController.text.substring(0, 1).toUpperCase()
                          : 'E',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Campos do formulário
            TextFormField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome Fantasia *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome fantasia é obrigatório';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {}); // Para atualizar o avatar
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _razaoSocialController,
              decoration: const InputDecoration(
                labelText: 'Razão Social',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_center),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: false, // Email não pode ser alterado
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _telefoneController,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _enderecoController,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.web),
              ),
              keyboardType: TextInputType.url,
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _instagramController,
              decoration: const InputDecoration(
                labelText: 'Instagram',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.camera_alt),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _facebookController,
              decoration: const InputDecoration(
                labelText: 'Facebook',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.facebook),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botão de salvar
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Salvar Alterações',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _nomeController.dispose();
    _razaoSocialController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    super.dispose();
  }
}
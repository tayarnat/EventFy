import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../services/notification_service.dart';
class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cpfController = TextEditingController();
  
  DateTime? _dataNascimento;
  String _genero = 'nao_informar';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUserType = true; // true = usuário, false = empresa
  
  // Campos específicos para empresa
  final _nomeFantasiaController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _responsavelNomeController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    _nomeFantasiaController.dispose();
    _cnpjController.dispose();
    _responsavelNomeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime.now().subtract(Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dataNascimento) {
      setState(() {
        _dataNascimento = picked;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      NotificationService.instance.showError('As senhas não coincidem');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = false;
    
    if (_isUserType) {
      // Cadastro de usuário pessoa física
      success = await authProvider.signUpUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nome: _nomeController.text.trim(),
        telefone: _telefoneController.text.trim(),
        cpf: _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        dataNascimento: _dataNascimento,
        genero: _genero,
      );
    } else {
      // Cadastro de empresa
      success = await authProvider.signUpCompany(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nomeFantasia: _nomeFantasiaController.text.trim(),
        cnpj: _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        responsavelNome: _responsavelNomeController.text.trim(),
      );
    }

    if (success && mounted) {
      NotificationService.instance.showSuccess(
        'Cadastro realizado com sucesso! Verifique seu e-mail.'
      );
      context.go('/login');
    } else if (mounted) {
      NotificationService.instance.showError(
        authProvider.errorMessage ?? 'Erro no cadastro'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tipo de cadastro
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _isUserType = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isUserType 
                              ? Colors.deepPurple.shade700
                              : Colors.grey[300],
                          foregroundColor: _isUserType 
                              ? Colors.white 
                              : Colors.black87,
                        ),
                        child: const Text('Pessoa Física'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _isUserType = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_isUserType 
                              ? Colors.deepPurple.shade700
                              : Colors.grey[300],
                          foregroundColor: !_isUserType 
                              ? Colors.white 
                              : Colors.black87,
                        ),
                        child: const Text('Empresa'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Campos comuns
                CustomTextField(
                  controller: _emailController,
                  label: 'E-mail',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'E-mail obrigatório';
                    if (!value!.contains('@')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                CustomTextField(
                  controller: _passwordController,
                  label: 'Senha',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Senha obrigatória';
                    if (value!.length < 6) return 'Senha deve ter pelo menos 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar Senha',
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Confirmação de senha obrigatória';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Campos específicos baseados no tipo de cadastro
                if (_isUserType) ..._buildUserFields() else ..._buildCompanyFields(),
                
                const SizedBox(height: 24),

                // Botão de cadastro
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return CustomButton(
                      onPressed: authProvider.isLoading ? null : _handleRegister,
                      child: authProvider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Cadastrar'),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Link para login
                TextButton(
                  onPressed: () {
                    context.go('/login');
                  },
                  child: const Text('Já tem conta? Faça login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUserFields() {
    return [
      CustomTextField(
        controller: _nomeController,
        label: 'Nome completo',
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Nome obrigatório';
          return null;
        },
      ),
      const SizedBox(height: 16),
      
      CustomTextField(
        controller: _telefoneController,
        label: 'Telefone',
        keyboardType: TextInputType.phone,
        validator: (value) {
          // Opcional
          return null;
        },
      ),
      const SizedBox(height: 16),
      
      CustomTextField(
        controller: _cpfController,
        label: 'CPF',
        keyboardType: TextInputType.number,
        validator: (value) {
          // Opcional
          return null;
        },
      ),
      const SizedBox(height: 16),
      
      // Data de nascimento
      InkWell(
        onTap: () => _selectDate(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Data de Nascimento',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dataNascimento == null
                    ? 'Selecione uma data'
                    : '${_dataNascimento!.day}/${_dataNascimento!.month}/${_dataNascimento!.year}',
              ),
              const Icon(Icons.calendar_today),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      
      // Gênero
      InputDecorator(
        decoration: InputDecoration(
          labelText: 'Gênero',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _genero,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'masculino', child: Text('Masculino')),
              DropdownMenuItem(value: 'feminino', child: Text('Feminino')),
              DropdownMenuItem(value: 'outro', child: Text('Outro')),
              DropdownMenuItem(value: 'nao_informar', child: Text('Prefiro não informar')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _genero = value;
                });
              }
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildCompanyFields() {
    return [
      CustomTextField(
        controller: _nomeFantasiaController,
        label: 'Nome Fantasia',
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Nome Fantasia obrigatório';
          return null;
        },
      ),
      const SizedBox(height: 16),
      
      CustomTextField(
        controller: _cnpjController,
        label: 'CNPJ',
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value?.isEmpty ?? true) return 'CNPJ obrigatório';
          return null;
        },
      ),
      const SizedBox(height: 16),
      
      CustomTextField(
        controller: _responsavelNomeController,
        label: 'Nome do Responsável',
        validator: (value) {
          if (value?.isEmpty ?? true) return 'Nome do Responsável obrigatório';
          return null;
        },
      ),
    ];
  }
}
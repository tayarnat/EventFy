import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    log(success.toString());
    if (success && mounted) {
      // Verificar se é o primeiro login
      if (authProvider.isFirstLogin) {
        context.go('/onboarding/preferences');
      } else {
        // Redirecionar baseado no tipo de usuário
        if (authProvider.isCompany) {
          context.go('/company');
        } else {
          context.go('/home');
        }
      }
    } else if (mounted) {
      NotificationService.instance.showError(
        authProvider.errorMessage ?? 'Erro no login'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Título
                Center(
                  child: Image.asset(
                    'assets/images/eventfy_logo.png',
                    height: 200,
                    width: 200,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 8),
                Text(
                  'Descubra eventos incríveis próximos de você',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Campos de entrada
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
                const SizedBox(height: 24),

                // Botão de login
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return CustomButton(
                      onPressed: authProvider.isLoading ? null : _handleLogin,
                      child: authProvider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Entrar'),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Link para registro
                TextButton(
                  onPressed: () {
                    context.go('/register');
                  },
                  child: const Text('Não tem conta? Cadastre-se'),
                ),

                const SizedBox(height: 16),
                
                // Esqueceu a senha
                TextButton(
                  onPressed: () {
                    // TODO: Implementar reset de senha
                  },
                  child: Text(
                    'Esqueceu sua senha?',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

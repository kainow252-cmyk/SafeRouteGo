import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLogin;
  final VoidCallback? onAdmin;
  const LoginScreen({super.key, required this.onBack, required this.onLogin, this.onAdmin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  String? _error;

  void _fillTestCredentials() {
    setState(() {
      _emailCtrl.text = 'gelci@saferoute.com.br';
      _passCtrl.text = '123456';
      _error = null;
    });
  }

  void _doLogin() {
    if (_emailCtrl.text == 'gelci@saferoute.com.br' && _passCtrl.text == '123456') {
      widget.onLogin();
    } else {
      setState(() {
        _error = 'E-mail ou senha inválidos. Use as credenciais de teste.';
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Entrar', onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo SafeRouteGo — escudo + nome
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/saferoutego_shield.png',
                          width: 32, height: 32,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'SafeRouteGo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Acesse sua conta',
                    style: TextStyle(
                      
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Credenciais de teste
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.science_rounded, color: AppTheme.primary, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Conta de Teste',
                              style: TextStyle(
                                
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('E-mail: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('gelci@saferoute.com.br',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Senha: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('123456',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _fillTestCredentials,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Preencher automaticamente',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Campo email
                  AppTextField(
                    label: 'CPF ou E-mail',
                    placeholder: 'gelci@saferoute.com.br',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  // Campo senha
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SENHA',
                        style: TextStyle(
                          
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.06,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _passCtrl,
                        obscureText: !_showPass,
                        style: const TextStyle(fontSize: 14, color: AppTheme.text),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          filled: true,
                          fillColor: AppTheme.surface,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _showPass = !_showPass),
                            child: Icon(
                              _showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppTheme.textLight,
                              size: 18,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            borderSide: const BorderSide(color: AppTheme.border, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            borderSide: const BorderSide(color: AppTheme.border, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textLight),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.red)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Esqueci minha senha',
                      style: TextStyle(
                        
                        fontSize: 13,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Entrar',
                    icon: Icons.login_rounded,
                    onTap: _doLogin,
                  ),
                  const SizedBox(height: 16),
                  // Divisor
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: AppTheme.border)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('ou entre com', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                      ),
                      Expanded(child: Container(height: 1, color: AppTheme.border)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Botão Google
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata_rounded, color: Color(0xFFDB4437), size: 22),
                        SizedBox(width: 10),
                        Text('Continuar com Google',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Biometria
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.surface2,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Icon(Icons.fingerprint_rounded, color: AppTheme.primary, size: 26),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.surface2,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Icon(Icons.face_rounded, color: AppTheme.primary, size: 26),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Acesso Admin (oculto, discreto)
                  GestureDetector(
                    onTap: widget.onAdmin,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0F1E).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, size: 14, color: AppTheme.textLight),
                          SizedBox(width: 6),
                          Text('Acesso Administrativo',
                              style: TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;
  const WelcomeScreen({super.key, required this.onCreateAccount, required this.onLogin});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _carController;

  @override
  void initState() {
    super.initState();
    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _carController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // Ilustração topo
          _buildIllustration(),
          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  // Logo SafeRouteGo — escudo pequeno + nome
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/saferoutego_shield.png',
                        width: 22, height: 22,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'SafeRouteGo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bem-vindo à nova\ngeração dos seguros.',
                    style: TextStyle(
                      
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pague somente quando utilizar.\nSem mensalidades obrigatórias.',
                    style: TextStyle(
                      
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _badge(Icons.bolt_rounded, 'Instantâneo'),
                      _badge(Icons.route_rounded, 'Por percurso'),
                      _badge(Icons.lock_rounded, 'Seguro'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Botão Criar Conta
                  GestureDetector(
                    onTap: widget.onCreateAccount,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Criar Conta',
                            style: TextStyle(
                              
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Botão Já tenho conta
                  GestureDetector(
                    onTap: widget.onLogin,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.primary, width: 2),
                      ),
                      child: const Text(
                        'Já possuo conta',
                        style: TextStyle(
                          
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppTheme.primary, size: 13),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Cobertura securitária emitida e garantida\npor seguradora autorizada pela SUSEP.',
                          style: const TextStyle(
                            
                            fontSize: 11,
                            color: AppTheme.textLight,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── HERO IMAGE: céu azul + nuvens + logo ─────────────────
          Image.asset(
            'assets/images/saferoutego_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          // ── GRADIENTE SUTIL NA BASE (blend com fundo do app) ─────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.surface.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // ── RUA + CARRO ANIMADO (sobreposto à imagem) ────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xCC0D1B4B),
              ),
              child: AnimatedBuilder(
                animation: _carController,
                builder: (context, child) {
                  final sw = MediaQuery.of(context).size.width;
                  final carX = _carController.value * (sw * 0.72) + sw * 0.08;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Linha tracejada da estrada
                      Positioned(
                        top: 21, left: 0, right: 0,
                        child: SizedBox(
                          height: 2,
                          child: Row(
                            children: List.generate(20, (i) => Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Container(
                                    color: const Color(0xFFFFCC00).withValues(alpha: 0.6),
                                  )),
                                  Expanded(child: Container()),
                                ],
                              ),
                            )),
                          ),
                        ),
                      ),
                      // Carro animado
                      Positioned(
                        left: carX,
                        top: 10,
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      // Escudinho teal flutuando sobre o carro
                      Positioned(
                        left: carX + 4,
                        top: -7,
                        child: Icon(
                          Icons.shield_rounded,
                          color: AppTheme.accent.withValues(alpha: 0.95),
                          size: 16,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore_for_file: prefer_single_quotes
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════════
// ONBOARDING SCREEN — 3 slides de apresentação do SafeRoute
// Exibido apenas na primeira vez que o app é aberto
// ══════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();

  /// Verifica se o onboarding já foi visto
  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool('onboarding_done') ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Marca como visto
  static Future<void> markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
  }
}

// ── Modelo de slide ─────────────────────────────────────────────
class _OnboardingSlide {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;

  const _OnboardingSlide({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.shield_rounded,
    iconColor: Colors.white,
    iconBg: Colors.transparent,
    title: 'Proteção Por Quilômetro',
    subtitle: 'Pague apenas pelo que dirigir. Ative a proteção antes de sair e o SafeRouteGo calcula o custo exato da sua viagem em tempo real.',
    gradientColors: [Color(0xFF1A56DB), Color(0xFF1343B0)],
  ),
  _OnboardingSlide(
    icon: Icons.gps_fixed_rounded,
    iconColor: Colors.white,
    iconBg: Colors.transparent,
    title: 'GPS Inteligente',
    subtitle: 'Monitora sua rota, detecta zonas de risco e sugere caminhos mais seguros. Quanto mais você dirige com segurança, mais desconto você ganha.',
    gradientColors: [Color(0xFF0E4D8A), Color(0xFF0A6B6B)],
  ),
  _OnboardingSlide(
    icon: Icons.star_rounded,
    iconColor: Colors.white,
    iconBg: Colors.transparent,
    title: 'Score & Benefícios',
    subtitle: 'Acumule pontos em cada viagem e troque por descontos na mensalidade, cashback em combustível, lavagens e muito mais.',
    gradientColors: [Color(0xFF1A56DB), Color(0xFF00C2A8)],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    await OnboardingScreen.markDone();
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _slides[_page].gradientColors,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Pular
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16),
                    child: TextButton(
                      onPressed: _complete,
                      child: Text(
                        'Pular',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                ),

                // Slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _page = i);
                    },
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => _SlideContent(slide: _slides[i]),
                  ),
                ),

                // Dots + botão
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    children: [
                      // Dots indicadores
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),

                      // Botão principal
                      GestureDetector(
                        onTap: _next,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _page == _slides.length - 1
                                  ? 'Começar Agora!'
                                  : 'Próximo',
                              key: ValueKey(_page),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _slides[_page].gradientColors.first,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _SlideContent extends StatelessWidget {
  final _OnboardingSlide slide;
  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone grande
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 40),

          // Título
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Subtítulo
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }
}

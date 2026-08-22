import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Botão Primário ───────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isFullWidth;
  final bool isSmall;
  const PrimaryButton({
    super.key,
    required this.text,
    this.onTap,
    this.icon,
    this.isFullWidth = true,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          vertical: isSmall ? 10 : 14,
          horizontal: isSmall ? 16 : 20,
        ),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: isSmall ? 14 : 16),
              SizedBox(width: isSmall ? 6 : 8),
            ],
            Text(
              text,
              style: TextStyle(
                
                fontSize: isSmall ? 13 : 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botão Outline ────────────────────────────────────────────────
class OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  const OutlineButton({super.key, required this.text, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primary, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botão Ghost ───────────────────────────────────────────────────
class GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  const GhostButton({super.key, required this.text, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppTheme.textMuted, size: 16),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header Bar com Voltar ────────────────────────────────────────
class AppHeaderBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? textColor;

  const AppHeaderBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (backgroundColor != null) 
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppTheme.surface2,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: textColor ?? AppTheme.text,
                  size: 18,
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor ?? AppTheme.text,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Bottom Navigation Bar ────────────────────────────────────────
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.directions_car_rounded, 'label': 'Viagens'},
      {'icon': Icons.list_alt_rounded, 'label': 'Histórico'},
      {'icon': Icons.card_giftcard_rounded, 'label': 'Benefícios'},
      {'icon': Icons.person_rounded, 'label': 'Perfil'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 6,
        top: 6,
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isActive = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[i]['icon'] as IconData,
                    color: isActive ? AppTheme.primary : AppTheme.textLight,
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i]['label'] as String,
                    style: TextStyle(
                      
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isActive ? AppTheme.primary : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Formulário de Input ──────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String label;
  final String placeholder;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool readOnly;
  final int? maxLines;

  const AppTextField({
    super.key,
    required this.label,
    required this.placeholder,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.06,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          style: const TextStyle(
            
            fontSize: 14,
            color: AppTheme.text,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.surface,
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
            hintStyle: const TextStyle(
              
              fontSize: 14,
              color: AppTheme.textLight,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step Indicator ───────────────────────────────────────────────
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Linha entre steps
            final lineIndex = i ~/ 2;
            final isActive = lineIndex < currentStep - 1;
            return Expanded(
              child: Container(
                height: 2,
                color: isActive ? AppTheme.primary : AppTheme.border,
                margin: const EdgeInsets.only(top: 15),
              ),
            );
          }
          final step = i ~/ 2;
          final isDone = step < currentStep - 1;
          final isActive = step == currentStep - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppTheme.green : isActive ? AppTheme.primary : AppTheme.border,
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ] : null,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : AppTheme.textLight,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[step],
                style: TextStyle(
                  
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppTheme.primary : isDone ? AppTheme.green : AppTheme.textLight,
                  letterSpacing: 0.02,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Mapa Simples (placeholder) ───────────────────────────────────
class SimpleMapWidget extends StatelessWidget {
  final bool animated;
  final double height;

  const SimpleMapWidget({
    super.key,
    this.animated = false,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC8D8F8), Color(0xFFA8C4F4), Color(0xFFC0DCE8)],
        ),
      ),
      child: Stack(
        children: [
          // Grid lines
          CustomPaint(
            size: Size(double.infinity, height),
            painter: _MapGridPainter(),
          ),
          // Rota
          Positioned(
            top: 40, left: 80, right: 60, bottom: 60,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.7),
                  width: 3,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(40)),
              ),
            ),
          ),
          // Marcador origem
          const Positioned(
            top: 38, left: 74,
            child: Icon(Icons.circle, color: AppTheme.green, size: 20),
          ),
          // Marcador destino
          const Positioned(
            bottom: 52, right: 54,
            child: Icon(Icons.location_on, color: AppTheme.red, size: 24),
          ),
          // Badge distância
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                boxShadow: AppTheme.shadowMd,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route_rounded, color: AppTheme.primary, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    '22 km',
                    style: TextStyle(
                      
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (animated) ...[
            // Carro animado
            _AnimatedCar(),
          ],
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _AnimatedCar extends StatefulWidget {
  @override
  State<_AnimatedCar> createState() => _AnimatedCarState();
}

class _AnimatedCarState extends State<_AnimatedCar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xAnim;
  late Animation<double> _yAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _xAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 55.0, end: 140.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 140.0, end: 220.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 220.0, end: 230.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 230.0, end: 55.0), weight: 25),
    ]).animate(_controller);
    _yAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 52.0, end: 30.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 30.0, end: 50.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 50.0, end: 130.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 130.0, end: 150.0), weight: 25),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Positioned(
        left: _xAnim.value,
        top: _yAnim.value,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(Icons.directions_car_rounded,
              color: AppTheme.primary, size: 22),
        ),
      ),
    );
  }
}

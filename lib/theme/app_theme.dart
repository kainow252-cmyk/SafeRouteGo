import 'package:flutter/material.dart';

class AppTheme {
  // ── Cores Primárias ──────────────────────────────────────────
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF1343B0);
  static const Color primaryLight = Color(0xFFEBF3FF);
  static const Color accent = Color(0xFF00C2A8);
  static const Color accentDark = Color(0xFF009E88);

  // ── Cores de Status ──────────────────────────────────────────
  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF16A34A);
  static const Color red = Color(0xFFEF4444);
  static const Color yellow = Color(0xFFF59E0B);
  static const Color blueLight = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);

  // ── Background & Surface ─────────────────────────────────────
  static const Color bg = Color(0xFFF0F4FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // ── Texto ────────────────────────────────────────────────────
  static const Color text = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // ── Dark Mode ────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surface2Dark = Color(0xFF162032);
  static const Color borderDark = Color(0xFF2D3748);

  // ── Gradientes ───────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient primaryAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment(0, -1),
    end: Alignment(1, 1),
    colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C), Color(0xFF0E4D8A), Color(0xFF0A6B6B)],
    stops: [0, 0.4, 0.7, 1],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF064E3B), Color(0xFF065F46)],
  );

  // ── Raios de borda ───────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  // ── Sombras ──────────────────────────────────────────────────
  static List<BoxShadow> shadowSm = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> shadowMd = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> shadowLg = [
    BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 32, offset: const Offset(0, 8)),
  ];

  // ── Tema Material ────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: red,
      ),
      scaffoldBackgroundColor: bg,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        labelStyle: const TextStyle(
          
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textMuted,
          letterSpacing: 0.06,
        ),
        hintStyle: const TextStyle(
          
          fontSize: 14,
          color: textLight,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: primary,
        secondary: accent,
        surface: surfaceDark,
      ),
    );
  }
}

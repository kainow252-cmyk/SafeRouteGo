import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screens.dart';
import 'screens/dashboard_screen.dart';
import 'screens/trip_flow_screens.dart';
import 'screens/active_trip_screens.dart';
import 'screens/secondary_screens.dart';
import 'screens/admin_screens.dart';
import 'screens/actuarial_dashboard_screen.dart';
import 'screens/safe_map_screen.dart';
import 'screens/atuario_ia_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/route_selection_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/frequent_routes_screen.dart';
import 'services/trip_history_service.dart';
import 'services/route_actuarial_service.dart';
import 'services/atuario_digital_core.dart';
import 'services/location_service.dart';
import 'providers/app_state.dart';

// ── Detecta acesso via /admin ou admin.html ──────────────────────
bool _isAdminUrl() {
  if (!kIsWeb) return false;
  try {
    final path  = html.window.location.pathname ?? '';
    final hash  = html.window.location.hash ?? '';
    final sess  = html.window.sessionStorage['saferoutego_start_route'] ?? '';
    final local = html.window.localStorage['saferoutego_start_route'] ?? '';
    // Limpar flags após leitura para não persistir entre navegações
    if (sess == 'admin' || local == 'admin') {
      html.window.sessionStorage.remove('saferoutego_start_route');
      html.window.localStorage.remove('saferoutego_start_route');
    }
    return path.contains('/admin') ||
        hash.contains('/admin') ||
        sess == 'admin' ||
        local == 'admin';
  } catch (_) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startAdmin = _isAdminUrl();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(SafeRouteApp(startAtAdmin: startAdmin));
}

// ── Gerenciador de dark mode (ValueNotifier global) ──────────────
class _ThemeManager {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool('dark_mode') ?? false;
      mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    mode.value = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', mode.value == ThemeMode.dark);
    } catch (_) {}
  }

  static bool get isDark => mode.value == ThemeMode.dark;
}

class SafeRouteApp extends StatefulWidget {
  final bool startAtAdmin;
  const SafeRouteApp({super.key, this.startAtAdmin = false});

  @override
  State<SafeRouteApp> createState() => _SafeRouteAppState();
}

class _SafeRouteAppState extends State<SafeRouteApp> {
  @override
  void initState() {
    super.initState();
    _ThemeManager.load().then((_) {
      if (mounted) setState(() {});
    });
    _ThemeManager.mode.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
    // Atualiza brightness da barra de status
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _ThemeManager.isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _ThemeManager.mode.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeRouteGo',
      debugShowCheckedModeBanner: false,
      themeMode: _ThemeManager.mode.value,
      theme: AppTheme.lightTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(AppTheme.lightTheme.textTheme),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(AppTheme.darkTheme.textTheme),
      ),
      home: AppNavigator(startAtAdmin: widget.startAtAdmin),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// NAVIGATOR PRINCIPAL — controla toda a navegação do app
// ═══════════════════════════════════════════════════════════
class AppNavigator extends StatefulWidget {
  final bool startAtAdmin;
  const AppNavigator({super.key, this.startAtAdmin = false});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  late String _screen;
  String _prevScreen = 'dashboard';

  @override
  void initState() {
    super.initState();
    _screen = widget.startAtAdmin ? 'admin-login' : 'splash';
  }
  int _navIndex = 0;
  // Dados da última viagem para o recibo
  TripHistoryRecord? _lastTripForReceipt;
  // Dados da rota selecionada para navegação
  RouteActuarialResult? _selectedRoute;
  String _navOrigin = 'Minha Localização';
  String _navDestination = 'Destino';

  void _goTo(String screen, {int navIndex = -1}) {
    HapticFeedback.selectionClick();
    setState(() {
      _prevScreen = _screen;
      _screen = screen;
      if (navIndex >= 0) _navIndex = navIndex;
    });
  }

  void _handleNavTap(int index) {
    final screens = ['dashboard', 'score', 'history', 'benefits', 'profile'];
    _goTo(screens[index], navIndex: index);
  }

  // ── Haversine: distância real entre dois pontos GPS ───────────
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_screen) {
      // ── Onboarding ──────────────────────────────────────────
      case 'splash':
        return SplashScreen(
          key: const ValueKey('splash'),
          onComplete: () async {
            final showOnboarding = await OnboardingScreen.shouldShow();
            if (mounted) _goTo(showOnboarding ? 'onboarding' : 'welcome');
          },
        );

      case 'onboarding':
        return OnboardingScreen(
          key: const ValueKey('onboarding'),
          onComplete: () => _goTo('welcome'),
        );

      case 'welcome':
        return WelcomeScreen(
          key: const ValueKey('welcome'),
          onCreateAccount: () => _goTo('register-personal'),
          onLogin: () => _goTo('login'),
        );

      case 'login':
        return LoginScreen(
          key: const ValueKey('login'),
          onBack: () => _goTo('welcome'),
          onLogin: () {
            // ── Atuário: inicializa motor oculto ao fazer login ──
            AtuarioDigitalCore.instance.init();
            _goTo('dashboard', navIndex: 0);
          },
          onAdmin: () => _goTo('admin-login'),
        );

      // ── Cadastro ─────────────────────────────────────────────
      case 'register-personal':
        return RegisterPersonalScreen(
          key: const ValueKey('register-personal'),
          onBack: () => _goTo('welcome'),
          onNext: () => _goTo('register-vehicle'),
        );

      case 'register-vehicle':
        return RegisterVehicleScreen(
          key: const ValueKey('register-vehicle'),
          onBack: () => _goTo('register-personal'),
          onNext: () => _goTo('register-biometric'),
        );

      case 'register-biometric':
        return RegisterBiometricScreen(
          key: const ValueKey('register-biometric'),
          onBack: () => _goTo('register-vehicle'),
          onNext: () => _goTo('register-payment'),
        );

      case 'register-payment':
        return RegisterPaymentScreen(
          key: const ValueKey('register-payment'),
          onBack: () => _goTo('register-biometric'),
          onComplete: () {
            // ── Atuário: inicializa após completar cadastro ──
            AtuarioDigitalCore.instance.init().then((_) {
              // Coleta localização inicial silenciosamente
              LocationService.instance.getCurrentPosition().then((loc) {
                if (loc.hasPosition) {
                  AtuarioDigitalCore.instance.onLocationDetected(
                    lat: loc.lat!, lon: loc.lon!,
                    city: loc.geo?.uf, // cidade aproximada pela UF
                    uf: loc.geo?.uf,
                    isHome: true,
                  );
                }
              });
            });
            _goTo('dashboard', navIndex: 0);
          },
        );

      // ── Dashboard ────────────────────────────────────────────
      case 'dashboard':
        return DashboardScreen(
          key: const ValueKey('dashboard'),
          navIndex: _navIndex,
          onNavTap: _handleNavTap,
          onSearchTap: () => _goTo('destination'),
          onProtectTap: () => _goTo('destination'),
          onNotifTap: () => _goTo('notifications'),
          onQuickDestination: () => _goTo('route-selection'),
          onManageFrequent: () => _goTo('frequent-routes'),
        );

      // ── Fluxo de Viagem ──────────────────────────────────────
      case 'destination':
        return DestinationScreen(
          key: const ValueKey('destination'),
          onBack: () => _goTo('dashboard'),
          onSelectDestination: () => _goTo('route-selection'),
        );

      case 'route-selection':
        {
          final sess = TripSession.current;
          final distKm = sess.hasCoords
              ? _haversineKm(
                  sess.originLat!, sess.originLon!,
                  sess.destLat!,   sess.destLon!)
              : 15.0;
          return RouteSelectionScreen(
            key: const ValueKey('route-selection'),
            origin: sess.originLat != null ? 'Minha Localização' : _navOrigin,
            destination: sess.destLabel ?? _navDestination,
            distanceKm: distKm,
            onBack: () => _goTo('destination'),
            onSelectRoute: (route) {
              setState(() => _selectedRoute = route);
              _goTo('navigation');
            },
          );
        }

      case 'navigation':
        {
          final sess = TripSession.current;
          return NavigationScreen(
            key: const ValueKey('navigation'),
            selectedRoute: _selectedRoute ?? RouteActuarialEngine.calculateRoutes(
              origin: sess.destLabel ?? _navOrigin,
              destination: sess.destLabel ?? _navDestination,
            )[2],
            origin: sess.originLat != null ? 'Minha Localização' : _navOrigin,
            destination: sess.destLabel ?? _navDestination,
            originLat: sess.originLat,
            originLon: sess.originLon,
            destLat: sess.destLat,
            destLon: sess.destLon,
            onBack: () => _goTo('route-selection'),
            onEnd: () {
              // ── Atuário: alimenta comportamento UBI ao encerrar viagem ──
              final route = _selectedRoute;
              if (route != null) {
                final now = DateTime.now();
                final isNight = now.hour >= 22 || now.hour < 6;
                final isWeekend = now.weekday >= 6;
                AtuarioDigitalCore.instance.onTripCompleted(
                  distanceKm: route.distanceKm,
                  avgSpeedKmh: route.distanceKm / math.max(route.estimatedMinutes / 60, 0.1),
                  durationSec: route.estimatedMinutes * 60,
                  isNight: isNight,
                  isWeekend: isWeekend,
                  highRiskZoneCount: 0, // expandir com dados reais da rota
                  tripDate: now,
                );
              }
              _goTo('trip-end');
            },
          );
        }

      case 'quote':
        return QuoteScreen(
          key: const ValueKey('quote'),
          onBack: () => _goTo('route-selection'),
          onActivate: () => _goTo('confirm'),
        );

      case 'confirm':
        return ConfirmScreen(
          key: const ValueKey('confirm'),
          onBack: () => _goTo('quote'),
          onStart: () => _goTo('navigation'),
        );

      case 'active-trip':
        return ActiveTripScreen(
          key: const ValueKey('active-trip'),
          onEmergency: () => _goTo('emergency'),
          onEnd: () => _goTo('trip-end'),
          onAI: () => _goTo('ai'),
        );

      // ── Emergência / Sinistro ────────────────────────────────
      case 'emergency':
        return EmergencyScreen(
          key: const ValueKey('emergency'),
          onBack: () => _goTo('active-trip'),
          onClaim: () => _goTo('claim'),
        );

      case 'claim':
        return ClaimScreen(
          key: const ValueKey('claim'),
          onBack: () => _goTo('emergency'),
          onSend: () => _goTo('claim-sent'),
        );

      case 'claim-sent':
        return ClaimSentScreen(
          key: const ValueKey('claim-sent'),
          onHome: () => _goTo('dashboard', navIndex: 0),
        );

      // ── Encerramento ─────────────────────────────────────────
      case 'trip-end':
        return TripEndScreen(
          key: const ValueKey('trip-end'),
          onReceipt: () => _goTo('receipt'),
          onNewTrip: () => _goTo('dashboard', navIndex: 0),
        );

      case 'receipt':
        return ReceiptScreen(
          key: const ValueKey('receipt'),
          onBack: () => _goTo('trip-end'),
        );

      // ── Notificações ─────────────────────────────────────────
      case 'notifications':
        return NotificationsScreen(
          key: const ValueKey('notifications'),
          onBack: () => _goTo(_prevScreen == 'dashboard' ? 'dashboard' : _prevScreen),
        );

      // ── Telas Principais (Bottom Nav) ────────────────────────
      case 'history':
        return HistoryScreen(
          key: const ValueKey('history'),
          navIndex: _navIndex,
          onNavTap: _handleNavTap,
          onBack: () => _goTo('dashboard', navIndex: 0),
          onReceiptTap: () => _goTo('receipt'),
        );

      case 'score':
        return ScoreScreen(
          key: const ValueKey('score'),
          navIndex: _navIndex,
          onNavTap: _handleNavTap,
          onBack: () => _goTo('dashboard', navIndex: 0),
        );

      case 'benefits':
        return BenefitsScreen(
          key: const ValueKey('benefits'),
          navIndex: _navIndex,
          onNavTap: _handleNavTap,
          onBack: () => _goTo('dashboard', navIndex: 0),
        );

      case 'profile':
        return ProfileScreen(
          key: const ValueKey('profile'),
          navIndex: _navIndex,
          onNavTap: _handleNavTap,
          onSettings: () => _goTo('settings'),
          onChangeVehicle: () => _goTo('register-vehicle'),
          onLogout: () => _goTo('welcome'),
          onFrequentRoutes: () => _goTo('frequent-routes'),
        );

      case 'frequent-routes':
        return FrequentRoutesScreen(
          key: const ValueKey('frequent-routes'),
          onBack: () => _goTo(_prevScreen),
        );

      case 'settings':
        return SettingsScreen(
          key: const ValueKey('settings'),
          onBack: () => _goTo('profile', navIndex: 4),
        );

      // ── IA Copiloto ──────────────────────────────────────────
      case 'ai':
        return AICopilotScreen(
          key: const ValueKey('ai'),
          onBack: () => _goTo('active-trip'),
        );

      // ── Admin ────────────────────────────────────────────────
      case 'admin-login':
        return AdminLoginScreen(
          key: const ValueKey('admin-login'),
          onSuccess: () => _goTo('admin'),
          onBack: () => _goTo('login'),
        );

      case 'admin':
        return AdminDashboardScreen(
          key: const ValueKey('admin'),
          onLogout: () => _goTo('login'),
          onActuarial: () => _goTo('actuarial'),
          onSafeMap: () => _goTo('safe-map'),
          onAtuarioIA: () => _goTo('atuario-ia'),
        );

      case 'actuarial':
        return ActuarialDashboardScreen(
          key: const ValueKey('actuarial'),
          onBack: () => _goTo('admin'),
        );

      case 'safe-map':
        return SafeMapScreen(
          key: const ValueKey('safe-map'),
          onBack: () => _goTo('admin'),
        );

      // ── Atuário IA v3 ────────────────────────────────────────
      case 'atuario-ia':
        return AtuarioIAScreen(
          key: const ValueKey('atuario-ia'),
          onBack: () => _goTo(_prevScreen == 'admin' ? 'admin' : 'dashboard', navIndex: 0),
        );

      default:
        return SplashScreen(
          key: const ValueKey('splash-default'),
          onComplete: () => _goTo('welcome'),
        );
    }
  }

}



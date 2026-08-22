// ignore_for_file: prefer_single_quotes
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/gamification_service.dart';
import '../services/user_profile_service.dart';
import '../services/trip_history_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import '../services/frequent_routes_service.dart';
import '../providers/app_state.dart';

// ═══════════════════════════════════════════════════════════════
// DASHBOARD SCREEN — dados reais via GamificationService +
//                    UserProfileService + TripHistoryService
// ═══════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  final int navIndex;
  final Function(int) onNavTap;
  final VoidCallback onSearchTap;
  final VoidCallback onProtectTap;
  final VoidCallback onNotifTap;
  final VoidCallback? onQuickDestination;  // ir direto para route-selection
  final VoidCallback? onManageFrequent;    // abrir tela de gerenciar

  const DashboardScreen({
    super.key,
    required this.navIndex,
    required this.onNavTap,
    required this.onSearchTap,
    required this.onProtectTap,
    required this.onNotifTap,
    this.onQuickDestination,
    this.onManageFrequent,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserProfile? _profile;
  MonthlyStats? _stats;
  Map<String, dynamic>? _todayStats;
  TripHistoryRecord? _lastTrip;
  int _unreadNotifs = 0;
  bool _loading = true;
  List<FrequentRoute> _frequentRoutes = [];
  double? _userLat;
  double? _userLon;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadGps();
  }

  Future<void> _loadGps() async {
    try {
      final state = await LocationService.instance.getCurrentPosition();
      if (state.hasPosition && mounted) {
        setState(() { _userLat = state.lat; _userLon = state.lon; });
      }
    } catch (_) {}
  }

  String _distLabel(double? lat, double? lon) {
    if (lat == null || lon == null || _userLat == null || _userLon == null) return '';
    final dLat = _deg2rad(lat - _userLat!);
    final dLon = _deg2rad(lon - _userLon!);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(_userLat!)) * math.cos(_deg2rad(lat)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final km = 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(0)} km';
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  // ── Rotas demo (exibidas quando o usuário ainda não cadastrou nenhuma) ──
  // Coordenadas reais de Vitória/ES para calcular distâncias GPS
  static const _kDemoRoutes = [
    _DemoRoute(
      icon: Icons.work_rounded,
      color: Color(0xFF1565C0),
      label: 'Trabalho',
      address: 'Av. Jerônimo Monteiro, 500',
      lat: -20.3191, lon: -40.3378,
    ),
    _DemoRoute(
      icon: Icons.home_rounded,
      color: Color(0xFF2E7D32),
      label: 'Casa',
      address: 'Rua das Laranjeiras, 120 — Serra',
      lat: -20.1278, lon: -40.3072,
    ),
    _DemoRoute(
      icon: Icons.local_mall_rounded,
      color: Color(0xFF6A1B9A),
      label: 'Shopping',
      address: 'Laranjeiras Shopping — Serra',
      lat: -20.1350, lon: -40.3100,
    ),
  ];

  Future<void> _onTapDemoRoute(_DemoRoute demo) async {
    HapticFeedback.mediumImpact();
    TripSession.current.setDestination(
      lat: demo.lat, lon: demo.lon, label: demo.label);
    if (_userLat != null && _userLon != null) {
      TripSession.current.setOrigin(lat: _userLat!, lon: _userLon!);
    }
    if (mounted) widget.onQuickDestination?.call();
  }

  Future<void> _onTapFrequentRoute(FrequentRoute route) async {
    HapticFeedback.mediumImpact();
    // Salva destino no TripSession
    TripSession.current.setDestination(
      lat: route.lat, lon: route.lon, label: route.label);
    // Salva origem (GPS atual)
    if (_userLat != null && _userLon != null) {
      TripSession.current.setOrigin(lat: _userLat!, lon: _userLon!);
    }
    // Incrementa uso
    await FrequentRoutesService.incrementUsage(route.id);
    // Vai direto para seleção de rota
    if (mounted) widget.onQuickDestination?.call();
  }

  Future<void> _loadData() async {
    try {
      final routes = await FrequentRoutesService.load();
      final results = await Future.wait([
        UserProfileService.load(),
        GamificationService.obterEstatisticasMes(),
        TripHistoryService.statsForToday(),
        TripHistoryService.lastTrip(),
        NotificationService.unreadCount(),
      ]);
      if (mounted) {
        setState(() {
          _frequentRoutes = routes
            ..sort((a, b) => b.tripCount.compareTo(a.tripCount));
          _profile    = results[0] as UserProfile;
          _stats      = results[1] as MonthlyStats;
          _todayStats = results[2] as Map<String, dynamic>;
          _lastTrip   = results[3] as TripHistoryRecord?;
          _unreadNotifs = results[4] as int;
          _loading    = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(context),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            _buildStatusCard(),
            _buildSearch(),
            Expanded(child: _buildQuickRoutes()),
            _buildProtectButton(),
          ],
          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final nome = _profile?.nome ?? '...';
    final primeiroNome = nome.split(' ').first;
    final inicial = _profile?.inicial ?? '?';
    final veiculo = _profile?.veiculoAtivo;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 12, left: 16, right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryAccentGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(inicial, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $primeiroNome 👋',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text,
                  ),
                ),
                Row(children: [
                  const Icon(Icons.directions_car_rounded, size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    veiculo != null ? veiculo.displayName : 'Nenhum veículo cadastrado',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ],
            ),
          ),
          // Sino notificações
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onNotifTap();
            },
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.notifications_rounded, size: 20, color: AppTheme.text)),
                  if (_unreadNotifs > 0)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _unreadNotifs > 9 ? '9+' : '$_unreadNotifs',
                            style: const TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Card ──────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final kmHoje = (_todayStats?['km'] as double?) ?? 0.0;
    final gastoHoje = (_todayStats?['cost'] as double?) ?? 0.0;
    final score = (_stats?.pontosTotais ?? 0).clamp(0, 1000);

    final kmStr = kmHoje > 0
        ? '${kmHoje.toStringAsFixed(1)} km'
        : '0 km';
    final gastoStr = gastoHoje > 0
        ? 'R\$ ${gastoHoje.toStringAsFixed(2).replaceAll('.', ',')}'
        : 'R\$ 0,00';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.darkCardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        children: [
          // Status proteção
          Row(children: [
            _PulseDot(isActive: kmHoje > 0),
            const SizedBox(width: 8),
            Text(
              kmHoje > 0 ? 'Proteção Ativa' : 'Proteção Desativada',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            if (_stats != null && _stats!.descontoMensalidade > 0) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${_stats!.descontoMensalidade.toStringAsFixed(0)}% off',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF22C55E)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          // Stats
          Row(children: [
            _StatusStat(icon: Icons.route_rounded, value: kmStr, label: 'Hoje'),
            _StatusStat(
              icon: Icons.account_balance_wallet_rounded,
              value: gastoStr, label: 'Gasto',
            ),
            _StatusStat(
              icon: Icons.star_rounded,
              value: '$score',
              label: 'Score',
            ),
          ]),
        ],
      ),
    );
  }

  // ── Search ──────────────────────────────────────────────────────
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PARA ONDE VAMOS?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted, letterSpacing: 0.06)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onSearchTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border, width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Digite o destino...',
                        style: TextStyle(fontSize: 14, color: AppTheme.textLight)),
                  ),
                  Icon(Icons.mic_rounded, color: AppTheme.primary, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Routes (última viagem + destinos frequentes) ───────────
  Widget _buildQuickRoutes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Última viagem (se houver)
          if (_lastTrip != null) ...[
            const Text('ÚLTIMA VIAGEM',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted, letterSpacing: 0.06)),
            const SizedBox(height: 8),
            _LastTripCard(trip: _lastTrip!, onTap: widget.onSearchTap),
            const SizedBox(height: 14),
          ],

          // ── Cabeçalho Frequentes + link Gerenciar ──────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DESTINOS FREQUENTES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted, letterSpacing: 0.06)),
              if (widget.onManageFrequent != null)
                GestureDetector(
                  onTap: widget.onManageFrequent,
                  child: const Text('Gerenciar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Lista de rotas frequentes reais ou demo ────────────
          if (_frequentRoutes.isEmpty) ...[
            // Demo clicáveis — mesma UX das rotas reais
            ..._kDemoRoutes.map((demo) {
              final dist = _distLabel(demo.lat, demo.lon);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuickRouteCard(
                  icon: demo.icon,
                  iconColor: demo.color,
                  iconBg: demo.color.withValues(alpha: 0.12),
                  title: demo.label,
                  subtitle: demo.address,
                  distance: dist.isNotEmpty ? dist : '— km',
                  onTap: () => _onTapDemoRoute(demo),
                ),
              );
            }),
            // Link discreto para cadastrar os seus próprios
            GestureDetector(
              onTap: widget.onManageFrequent,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 13, color: AppTheme.primary.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Text('Personalizar meus destinos',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: AppTheme.primary.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ] else
            ..._frequentRoutes.take(5).map((route) {
              final dist = _distLabel(route.lat, route.lon);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuickRouteCard(
                  icon: route.type.icon,
                  iconColor: route.type.color,
                  iconBg: route.type.color.withValues(alpha: 0.12),
                  title: route.label,
                  subtitle: route.address,
                  distance: dist.isNotEmpty ? dist : '— km',
                  onTap: () => _onTapFrequentRoute(route),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Botão Proteger ───────────────────────────────────────────────
  Widget _buildProtectButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onProtectTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryAccentGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 24, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Proteger Minha Viagem',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card da última viagem ────────────────────────────────────────
class _LastTripCard extends StatelessWidget {
  final TripHistoryRecord trip;
  final VoidCallback onTap;

  const _LastTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip.origin} → ${trip.destination}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${trip.dateFormatted} · ${trip.kmFormatted} · ${trip.priceFormatted}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final bool isActive;
  const _PulseDot({required this.isActive});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: widget.isActive ? AppTheme.green : AppTheme.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (widget.isActive ? AppTheme.green : AppTheme.red).withValues(alpha: 0.6),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatusStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        ],
      ),
    );
  }
}

class _QuickRouteCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String distance;
  final VoidCallback onTap;

  const _QuickRouteCard({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.subtitle, required this.distance, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Text(distance, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Modelo leve para rotas demo (sem persistência) ─────────────────
class _DemoRoute {
  final IconData icon;
  final Color color;
  final String label;
  final String address;
  final double lat;
  final double lon;
  const _DemoRoute({
    required this.icon, required this.color, required this.label,
    required this.address, required this.lat, required this.lon,
  });
}

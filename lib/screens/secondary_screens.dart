import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/actuarial_engine.dart';
import '../services/risk_engine.dart';
import '../services/gamification_service.dart';
import '../services/user_profile_service.dart';
import '../services/trip_history_service.dart';

// ══════════════════════════════════════════
// RECIBO — aceita dados reais da viagem
// ══════════════════════════════════════════
class ReceiptScreen extends StatefulWidget {
  final VoidCallback onBack;
  final TripHistoryRecord? tripData; // null = busca última viagem

  const ReceiptScreen({super.key, required this.onBack, this.tripData});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  TripHistoryRecord? _trip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trip = widget.tripData ?? await TripHistoryService.lastTrip();
    if (mounted) setState(() { _trip = trip; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    // Data/hora formatada
    final now = t?.datetime ?? DateTime.now();
    const meses = ['janeiro','fevereiro','março','abril','maio','junho',
        'julho','agosto','setembro','outubro','novembro','dezembro'];
    final dataStr = '${now.day} de ${meses[now.month-1]} de ${now.year} · ${now.hour.toString().padLeft(2,'0')}h${now.minute.toString().padLeft(2,'0')}';
    final apolice = 'SR-${now.year}-${(now.millisecondsSinceEpoch % 100000).toString().padLeft(5,'0')}';

    // Cálculo das parcelas do custo
    final km = t?.kmTotal ?? 0.0;
    final total = t?.totalCost ?? 0.0;
    final taxaBase = 1.99;
    final percurso = (km * 0.15).clamp(0.0, 99.0);
    final multiplicador = (total - taxaBase - percurso).clamp(0.0, 99.0);
    final desconto = (total * 0.08).clamp(0.0, 99.0);
    final totalReal = (taxaBase + percurso + multiplicador - desconto).clamp(0.01, 999.0);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Recibo', onBack: widget.onBack),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          boxShadow: AppTheme.shadowMd,
                        ),
                        child: Column(
                          children: [
                            // Header verde com check
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(AppTheme.radiusLg),
                                  topRight: Radius.circular(AppTheme.radiusLg),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 56, height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('SafeRouteGo', style: TextStyle(fontSize:20, fontWeight:FontWeight.w800, color:Colors.white)),
                                  const Text('Recibo de Proteção Viagem', style: TextStyle(fontSize:13, color:Colors.white70)),
                                  const SizedBox(height: 4),
                                  Text(dataStr, style: TextStyle(fontSize:12, color:Colors.white.withValues(alpha: 0.7))),
                                ],
                              ),
                            ),
                            // Body
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _receiptRow('Origem', t?.origin ?? '—'),
                                  _receiptRow('Destino', t?.destination ?? '—'),
                                  _receiptRow('Distância', t?.kmFormatted ?? '—'),
                                  _receiptRow('Duração', t?.durationFormatted ?? '—'),
                                  _receiptRow('Plano', t?.planType ?? 'Equilibrado'),
                                  const Divider(color: AppTheme.border, height: 20),
                                  _receiptRow('Taxa base', 'R\$ ${taxaBase.toStringAsFixed(2).replaceAll('.', ',')}'),
                                  _receiptRow('Percurso (${km.toStringAsFixed(1)} km)', 'R\$ ${percurso.toStringAsFixed(2).replaceAll('.', ',')}'),
                                  if (multiplicador > 0.01)
                                    _receiptRow('Ajuste de risco', 'R\$ ${multiplicador.toStringAsFixed(2).replaceAll('.', ',')}'),
                                  _receiptRow('Desconto fidelidade', '−R\$ ${desconto.toStringAsFixed(2).replaceAll('.', ',')}', isDiscount: true),
                                  const Divider(color: AppTheme.border, height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total', style: TextStyle(fontSize:16, fontWeight:FontWeight.w800, color:AppTheme.text)),
                                      Text(
                                        'R\$ ${totalReal.toStringAsFixed(2).replaceAll('.', ',')}',
                                        style: const TextStyle(fontSize:22, fontWeight:FontWeight.w900, color:AppTheme.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  _receiptRow('Pagamento', 'PIX • ${(now.hour).toString().padLeft(2,'0')}h${(now.minute + 2).clamp(0,59).toString().padLeft(2,'0')}'),
                                  _receiptRow('Pontos ganhos', '+${t?.pontosGanhos ?? 0} pts ⭐'),
                                ],
                              ),
                            ),
                            // Footer
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surface2,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(AppTheme.radiusLg),
                                  bottomRight: Radius.circular(AppTheme.radiusLg),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text('Apólice #$apolice', style: const TextStyle(fontSize:12, color:AppTheme.textMuted)),
                                  const SizedBox(height: 4),
                                  const Text('Seguradora parceira autorizada pela SUSEP', style: TextStyle(fontSize:12, color:AppTheme.textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botão compartilhar
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Recibo copiado! ✓'),
                              backgroundColor: AppTheme.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.share_rounded, color: AppTheme.primary, size: 18),
                              SizedBox(width: 8),
                              Text('Compartilhar Recibo', style: TextStyle(fontSize:14, fontWeight:FontWeight.w600, color:AppTheme.primary)),
                            ],
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

  Widget _receiptRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize:13,
              color: isDiscount ? AppTheme.greenDark : AppTheme.textMuted)),
          Text(value, style: TextStyle(fontSize:13, fontWeight:FontWeight.w600,
              color: isDiscount ? AppTheme.greenDark : AppTheme.text)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// HISTÓRICO — lê TripHistoryService (real) + fallback estático
// ══════════════════════════════════════════

// Adaptador: converte TripHistoryRecord → _HistDisplay para reutilizar o card
class _HistDisplay {
  final String date, weekday, time, origin, destination, km, duration, price;
  final RiskZone zone;
  final String planType;

  _HistDisplay({
    required this.date, required this.weekday, required this.time,
    required this.origin, required this.destination, required this.km,
    required this.duration, required this.price, required this.zone,
    this.planType = 'Equilibrado',
  });

  factory _HistDisplay.fromRecord(TripHistoryRecord r) => _HistDisplay(
    date: r.dateFormatted,
    weekday: r.weekdayAbbr,
    time: r.timeFormatted,
    origin: r.origin,
    destination: r.destination,
    km: r.kmFormatted,
    duration: r.durationFormatted,
    price: r.priceFormatted,
    zone: _zoneFromString(r.riskZone),
    planType: r.planType,
  );

  static RiskZone _zoneFromString(String s) {
    switch (s) {
      case 'verde': return RiskZone.verde;
      case 'laranja': return RiskZone.laranja;
      case 'vermelha': return RiskZone.vermelha;
      case 'critica': return RiskZone.critica;
      default: return RiskZone.amarela;
    }
  }

  double get kmDouble => double.tryParse(km.replaceAll(' km','')) ?? 0;
  double get priceDouble => double.tryParse(price.replaceAll('R\$ ','').replaceAll(',','.')) ?? 0;
  String get monthLabel {
    final parts = date.split('/');
    if (parts.length < 2) return '';
    const meses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return '';
    return meses[m - 1];
  }
}

// Dados estáticos de fallback (quando TripHistoryService está vazio)
List<_HistDisplay> get _staticTrips => [
  _HistDisplay(date: '12/06', weekday: 'Qui', time: '14h32', origin: 'Serra/ES', destination: 'Vitória/ES',
      km: '24 km', duration: '32 min', price: 'R\$ 5,12', zone: RiskZone.amarela, planType: 'Equilibrado'),
  _HistDisplay(date: '11/06', weekday: 'Qua', time: '08h15', origin: 'Serra/ES', destination: 'Vila Velha/ES',
      km: '18 km', duration: '24 min', price: 'R\$ 3,87', zone: RiskZone.laranja, planType: 'Econômico'),
  _HistDisplay(date: '10/06', weekday: 'Ter', time: '19h50', origin: 'Vitória/ES', destination: 'Guarapari/ES',
      km: '60 km', duration: '55 min', price: 'R\$ 12,30', zone: RiskZone.verde, planType: 'Premium'),
  _HistDisplay(date: '09/06', weekday: 'Seg', time: '07h40', origin: 'Serra/ES', destination: 'Vitória/ES',
      km: '22 km', duration: '30 min', price: 'R\$ 4,87', zone: RiskZone.amarela, planType: 'Equilibrado'),
  _HistDisplay(date: '07/06', weekday: 'Sáb', time: '22h10', origin: 'Cariacica/ES', destination: 'Vitória/ES',
      km: '15 km', duration: '21 min', price: 'R\$ 6,40', zone: RiskZone.vermelha, planType: 'Premium'),
  _HistDisplay(date: '06/06', weekday: 'Sex', time: '18h05', origin: 'Serra/ES', destination: 'UFES',
      km: '28 km', duration: '38 min', price: 'R\$ 6,20', zone: RiskZone.verde, planType: 'Equilibrado'),
  _HistDisplay(date: '04/06', weekday: 'Qua', time: '09h00', origin: 'Laranjeiras/ES', destination: 'Centro Vitória',
      km: '35 km', duration: '45 min', price: 'R\$ 7,80', zone: RiskZone.laranja, planType: 'Econômico'),
  _HistDisplay(date: '02/06', weekday: 'Seg', time: '07h20', origin: 'Serra/ES', destination: 'Vitória/ES',
      km: '25 km', duration: '34 min', price: 'R\$ 5,50', zone: RiskZone.amarela, planType: 'Equilibrado'),
  _HistDisplay(date: '30/05', weekday: 'Sex', time: '17h45', origin: 'Serra/ES', destination: 'Vitória/ES',
      km: '26 km', duration: '36 min', price: 'R\$ 5,80', zone: RiskZone.amarela, planType: 'Equilibrado'),
  _HistDisplay(date: '28/05', weekday: 'Qua', time: '08h30', origin: 'Serra/ES', destination: 'Vila Velha/ES',
      km: '32 km', duration: '42 min', price: 'R\$ 7,20', zone: RiskZone.laranja, planType: 'Premium'),
  _HistDisplay(date: '24/05', weekday: 'Sáb', time: '13h15', origin: 'Vitória/ES', destination: 'Guarapari/ES',
      km: '78 km', duration: '72 min', price: 'R\$ 18,50', zone: RiskZone.verde, planType: 'Premium'),
];

class HistoryScreen extends StatefulWidget {
  final int navIndex;
  final Function(int) onNavTap;
  final VoidCallback onBack;
  final VoidCallback onReceiptTap;

  const HistoryScreen({super.key, required this.navIndex, required this.onNavTap,
      required this.onBack, required this.onReceiptTap});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedMonth = 'Este mês';
  String _selectedFilter = 'Todos';
  List<_HistDisplay> _allTrips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final records = await TripHistoryService.loadAll();
    if (mounted) {
      setState(() {
        if (records.isEmpty) {
          _allTrips = _staticTrips; // fallback com dados demo
        } else {
          _allTrips = records.map(_HistDisplay.fromRecord).toList();
        }
        _loading = false;
      });
    }
  }

  List<String> get _availableMonths {
    final months = <String>{'Este mês', 'Todos'};
    for (final t in _allTrips) {
      if (t.monthLabel.isNotEmpty) months.add(t.monthLabel);
    }
    return months.toList();
  }

  List<_HistDisplay> get _filtered {
    List<_HistDisplay> byMonth;
    if (_selectedMonth == 'Todos') {
      byMonth = _allTrips;
    } else if (_selectedMonth == 'Este mês') {
      final now = DateTime.now();
      final mesAtual = ['','Jan','Fev','Mar','Abr','Mai','Jun',
          'Jul','Ago','Set','Out','Nov','Dez'][now.month];
      byMonth = _allTrips.where((t) => t.monthLabel == mesAtual).toList();
      if (byMonth.isEmpty) byMonth = _allTrips; // fallback
    } else {
      byMonth = _allTrips.where((t) => t.monthLabel == _selectedMonth).toList();
    }

    if (_selectedFilter == 'Todos') return byMonth;
    if (_selectedFilter == 'Verde')   return byMonth.where((t) => t.zone == RiskZone.verde).toList();
    if (_selectedFilter == 'Risco')   return byMonth.where((t) => t.zone == RiskZone.vermelha || t.zone == RiskZone.critica).toList();
    if (_selectedFilter == 'Premium') return byMonth.where((t) => t.planType == 'Premium').toList();
    return byMonth;
  }

  double get _totalSpent => _filtered.fold(0.0, (s, t) => s + t.priceDouble);
  double get _totalKm    => _filtered.fold(0.0, (s, t) => s + t.kmDouble);

  @override
  Widget build(BuildContext context) {
    final trips = _filtered;
    final months = _availableMonths;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Histórico de Viagens', onBack: widget.onBack),

          // ── Filtro de mês ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: months.map((m) {
                  final active = m == _selectedMonth;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMonth = m);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: active ? AppTheme.primary : AppTheme.border),
                      ),
                      child: Text(m, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppTheme.textMuted)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Filtro por tipo ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Todos', 'Verde', 'Risco', 'Premium'].map((f) {
                  final active = f == _selectedFilter;
                  Color fgColor = active ? Colors.white : AppTheme.textMuted;
                  Color bgColor = active ? AppTheme.text : AppTheme.surface2;
                  if (active && f == 'Verde')   bgColor = const Color(0xFF22C55E);
                  if (active && f == 'Risco')   bgColor = const Color(0xFFEF4444);
                  if (active && f == 'Premium') bgColor = const Color(0xFF8B5CF6);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilter = f);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: active ? bgColor : AppTheme.border),
                      ),
                      child: Text(f, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: fgColor)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Resumo ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _HistSummary(icon: Icons.route_rounded,
                    value: '${_totalKm.round()} km', label: 'Percorrido'),
                const SizedBox(width: 8),
                _HistSummary(icon: Icons.account_balance_wallet_rounded,
                    value: 'R\$ ${_totalSpent.toStringAsFixed(2).replaceAll('.', ',')}',
                    label: 'Gasto'),
                const SizedBox(width: 8),
                _HistSummary(icon: Icons.shield_rounded,
                    value: '${trips.length} viagens', label: 'Protegidas'),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Lista ──────────────────────────────────────────
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : trips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 52, color: AppTheme.textLight),
                          const SizedBox(height: 12),
                          const Text('Nenhuma viagem encontrada',
                              style: TextStyle(fontSize: 15, color: AppTheme.textMuted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTrips,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: trips.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _HistoryItem(
                          trip: trips[i],
                          onTap: widget.onReceiptTap,
                        ),
                      ),
                    ),
          ),

          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }
}

class _HistSummary extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _HistSummary({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border)),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text),
                textAlign: TextAlign.center),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final _HistDisplay trip;
  final VoidCallback onTap;
  const _HistoryItem({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            // Data
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(trip.date,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  Text(trip.weekday,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${trip.origin} → ${trip.destination}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      // Zona badge
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: trip.zone.color,
                            shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('${trip.km} · ${trip.duration}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.surface2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border)),
                        child: Text(trip.planType,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Preço
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(trip.price,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                const SizedBox(height: 2),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// SCORE / GAMIFICAÇÃO
// ══════════════════════════════════════════
class ScoreScreen extends StatefulWidget {
  final int navIndex;
  final Function(int) onNavTap;
  final VoidCallback onBack;

  const ScoreScreen({super.key, required this.navIndex, required this.onNavTap, required this.onBack});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  MonthlyStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await GamificationService.obterEstatisticasMes();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  // Calcula score 0–1000 baseado em pontos acumulados
  int get _score => (_stats?.pontosTotais ?? 0).clamp(0, 1000);

  // Nível → nome e gradiente
  static const _nivelNomes  = ['Bronze', 'Prata', 'Ouro', 'Diamante', 'Platinum'];
  static const _nivelColors = [
    [Color(0xFFCD7F32), Color(0xFFB87333)], // Bronze
    [Color(0xFF9E9E9E), Color(0xFF757575)], // Prata
    [Color(0xFFD97706), Color(0xFFF59E0B)], // Ouro
    [Color(0xFF0EA5E9), Color(0xFF0284C7)], // Diamante
    [Color(0xFF7C3AED), Color(0xFF6D28D9)], // Platinum
  ];

  // Pontos para o próximo nível
  static const _nivelLimites = [0, 500, 1000, 2000, 5000, 99999];
  String get _faltamTexto {
    final nivel = (_stats?.nivel ?? 1).clamp(1, 5) - 1;
    if (nivel >= 4) return 'Nível máximo atingido! 🏆';
    final proximo = _nivelLimites[nivel + 1];
    final faltam = proximo - (_stats?.pontosTotais ?? 0);
    final nomeProx = _nivelNomes[nivel + 1];
    return '$faltam pontos para o nível $nomeProx';
  }

  // Definição completa de todas as conquistas
  List<Map<String, dynamic>> get _todasConquistas {
    final conquistas = _stats?.conquistas ?? [];
    return [
      {
        'id': 'km500',
        'icon': Icons.route_rounded,
        'label': '500 km',
        'sub': 'Percorrido',
        'unlocked': conquistas.contains('km500'),
      },
      {
        'id': 'v20',
        'icon': Icons.directions_car_rounded,
        'label': '20 Viagens',
        'sub': 'No mês',
        'unlocked': conquistas.contains('v20'),
      },
      {
        'id': 'gps100',
        'icon': Icons.gps_fixed_rounded,
        'label': 'GPS 100%',
        'sub': '10+ viagens',
        'unlocked': conquistas.contains('gps100'),
      },
      {
        'id': 'p1000',
        'icon': Icons.star_rounded,
        'label': '1000 pts',
        'sub': 'Acumulados',
        'unlocked': conquistas.contains('p1000'),
      },
      {
        'id': 'noturno',
        'icon': Icons.nightlight_round,
        'label': 'Noturno',
        'sub': _stats != null && _stats!.totalViagens >= 3
            ? '${(_stats!.totalViagens * 0.3).floor()}/3 viagens'
            : 'Em breve',
        'unlocked': conquistas.contains('noturno'),
        'progresso': _stats != null
            ? (_stats!.totalViagens * 0.3).clamp(0, 3) / 3
            : 0.0,
      },
      {
        'id': 'platinum',
        'icon': Icons.workspace_premium_rounded,
        'label': 'Platinum',
        'sub': (_stats?.nivel ?? 1) >= 5
            ? 'Conquistado!'
            : 'Nível 5',
        'unlocked': (_stats?.nivel ?? 1) >= 5,
        'progresso': ((_stats?.pontosTotais ?? 0) / 5000).clamp(0.0, 1.0),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final nivel = ((_stats?.nivel ?? 1) - 1).clamp(0, 4);
    final colors = _nivelColors[nivel];
    final nomeNivel = _nivelNomes[nivel];
    final desconto = _stats?.descontoMensalidade ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Score SafeRouteGo', onBack: widget.onBack),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadStats,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ── Score ring ──────────────────────────
                          _ScoreRing(score: _score, max: 1000),
                          const SizedBox(height: 16),

                          // ── Rank badge ──────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [colors[0], colors[1]]),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text('Motorista $nomeNivel',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_faltamTexto,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                          const SizedBox(height: 16),

                          // ── Stats rápidas ───────────────────────
                          Row(children: [
                            _StatChip(Icons.route_rounded,
                                '${(_stats?.totalKm ?? 0).toStringAsFixed(0)} km', 'rodados'),
                            const SizedBox(width: 8),
                            _StatChip(Icons.directions_car_rounded,
                                '${_stats?.totalViagens ?? 0}', 'viagens'),
                            const SizedBox(width: 8),
                            _StatChip(Icons.star_rounded,
                                '${_stats?.pontosTotais ?? 0}', 'pontos'),
                          ]),
                          const SizedBox(height: 12),

                          // ── Desconto acumulado ──────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF065F46)]),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.percent_rounded, color: Colors.white, size: 24),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Desconto acumulado',
                                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                                    Text(
                                      desconto > 0
                                          ? '${desconto.toStringAsFixed(0)}%'
                                          : 'Ative o GPS em 100% das viagens',
                                      style: TextStyle(
                                        fontSize: desconto > 0 ? 24 : 14,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Conquistas ──────────────────────────
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('CONQUISTAS',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: AppTheme.textMuted, letterSpacing: 0.06)),
                          ),
                          const SizedBox(height: 10),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.88,
                            children: _todasConquistas.map((c) => _AchievementCard(
                              icon: c['icon'] as IconData,
                              label: c['label'] as String,
                              sub: c['sub'] as String,
                              unlocked: c['unlocked'] as bool,
                              progresso: c['progresso'] as double?,
                            )).toList(),
                          ),
                          const SizedBox(height: 8),
                          // Dica quando nenhuma conquista desbloqueada
                          if ((_stats?.conquistas ?? []).isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: const Row(children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Expanded(child: Text(
                                  'Complete viagens com GPS ativo para desbloquear conquistas!',
                                  style: TextStyle(fontSize: 12, color: AppTheme.primary),
                                )),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }
}

// ── Chip de estatística rápida ─────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final int max;
  const _ScoreRing({required this.score, required this.max});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180, height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160, height: 160,
            child: CircularProgressIndicator(
              value: score / max,
              strokeWidth: 14,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: const TextStyle(fontSize:40, fontWeight:FontWeight.w900, color:AppTheme.text)),
              Text('/$max', style: const TextStyle(fontSize:14, color:AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool unlocked;
  final double? progresso; // 0.0–1.0 para conquistas em andamento
  const _AchievementCard({
    required this.icon, required this.label, required this.sub,
    required this.unlocked, this.progresso,
  });

  @override
  Widget build(BuildContext context) {
    final inProgress = !unlocked && (progresso ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked
            ? AppTheme.primaryLight
            : inProgress
                ? AppTheme.primary.withValues(alpha: 0.05)
                : AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: unlocked
              ? AppTheme.primary.withValues(alpha: 0.3)
              : inProgress
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : AppTheme.border.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? icon : (inProgress ? icon : Icons.lock_rounded),
              color: unlocked
                  ? AppTheme.primary
                  : inProgress
                      ? AppTheme.primary.withValues(alpha: 0.5)
                      : AppTheme.textLight,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: unlocked ? AppTheme.text : AppTheme.textMuted,
              ),
              textAlign: TextAlign.center),
          Text(sub,
              style: TextStyle(
                fontSize: 10,
                color: unlocked ? AppTheme.textMuted : AppTheme.textLight,
              )),
          // Barra de progresso para conquistas em andamento
          if (inProgress && progresso != null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 3,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation(
                    AppTheme.primary.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BENEFÍCIOS — Clube SafeRoute Completo
// ══════════════════════════════════════════════════════════════

class _BenefitItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String partner;
  final String title;
  final String description;
  final String tag;
  final String tagValue;
  final bool isHighlight;
  final bool isNew;
  final String expires;
  final int minLevel; // 0=todos, 1=ouro, 2=platinum

  const _BenefitItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.partner,
    required this.title,
    required this.description,
    required this.tag,
    required this.tagValue,
    this.isHighlight = false,
    this.isNew = false,
    this.expires = '',
    this.minLevel = 0,
  });
}

const List<_BenefitItem> _benefits = [
  _BenefitItem(
    icon: Icons.local_gas_station_rounded,
    iconColor: Color(0xFFEA580C),
    iconBg: Color(0xFFFFF7ED),
    partner: 'Shell Select',
    title: '5% cashback em combustível',
    description: 'Válido em todos os postos Shell do ES',
    tag: 'Cashback',
    tagValue: '5%',
    isNew: true,
    expires: 'Válido até 31/12/2026',
  ),
  _BenefitItem(
    icon: Icons.build_rounded,
    iconColor: Color(0xFF1A56DB),
    iconBg: Color(0xFFEBF3FF),
    partner: 'Rede VistaCar',
    title: '10% desconto em revisão',
    description: '25 oficinas credenciadas no ES',
    tag: 'Desconto',
    tagValue: '10%',
    expires: 'Válido até 30/06/2026',
  ),
  _BenefitItem(
    icon: Icons.water_drop_rounded,
    iconColor: Color(0xFF00C2A8),
    iconBg: Color(0xFFE6FAF8),
    partner: 'Lavagem Premium',
    title: '2ª lavagem grátis no mês',
    description: 'Rede CleanCar — 8 unidades em Serra/VV',
    tag: 'Destaque',
    tagValue: 'GRÁTIS',
    isHighlight: true,
    expires: 'Renovado mensalmente',
  ),
  _BenefitItem(
    icon: Icons.health_and_safety_rounded,
    iconColor: Color(0xFF16A34A),
    iconBg: Color(0xFFF0FDF4),
    partner: 'Assistência Médica',
    title: 'Telemedicina gratuita',
    description: 'Consulta online em caso de acidente',
    tag: 'Emergência',
    tagValue: '24h',
    expires: 'Ativo durante a viagem',
    minLevel: 0,
  ),
  _BenefitItem(
    icon: Icons.local_shipping_rounded,
    iconColor: Color(0xFF7C3AED),
    iconBg: Color(0xFFF5F3FF),
    partner: 'Guincho SOS',
    title: 'Guincho incluso — 80 km',
    description: 'Cobertura em toda a Grande Vitória',
    tag: 'Cobertura',
    tagValue: '80km',
    expires: 'Ativo em viagens Equilibrado+',
  ),
  _BenefitItem(
    icon: Icons.workspace_premium_rounded,
    iconColor: Color(0xFFF59E0B),
    iconBg: Color(0xFFFFFBEB),
    partner: 'SafeRouteGo Premium',
    title: 'Carro reserva 7 dias',
    description: 'Em sinistros de perda total',
    tag: 'Premium',
    tagValue: '7 dias',
    isHighlight: true,
    minLevel: 2,
    expires: 'Exclusivo Platinum',
  ),
  _BenefitItem(
    icon: Icons.car_repair_rounded,
    iconColor: Color(0xFFEF4444),
    iconBg: Color(0xFFFFF1F1),
    partner: 'Pneus Rápido',
    title: '15% off em pneus',
    description: 'Troca e alinhamento com desconto',
    tag: 'Parceiro',
    tagValue: '15%',
    expires: 'Válido até 31/08/2026',
    minLevel: 1,
  ),
  _BenefitItem(
    icon: Icons.store_rounded,
    iconColor: Color(0xFF0891B2),
    iconBg: Color(0xFFECFEFF),
    partner: 'MarketSafe',
    title: 'Cupom R\$ 20 no primeiro mês',
    description: 'Marketplace parceiro de acessórios auto',
    tag: 'Cupom',
    tagValue: 'R\$ 20',
    isNew: true,
    expires: 'Válido no 1º mês de ativação',
  ),
];

class BenefitsScreen extends StatefulWidget {
  final int navIndex;
  final Function(int) onNavTap;
  final VoidCallback onBack;

  const BenefitsScreen({super.key, required this.navIndex, required this.onNavTap, required this.onBack});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  String _selectedCategory = 'Todos';
  final _categories = ['Todos', 'Cashback', 'Desconto', 'Emergência', 'Premium'];

  List<_BenefitItem> get _filtered {
    if (_selectedCategory == 'Todos') return _benefits;
    return _benefits.where((b) => b.tag == _selectedCategory).toList();
  }

  void _showBenefitDetail(_BenefitItem b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: b.iconBg, borderRadius: BorderRadius.circular(20)),
              child: Icon(b.icon, color: b.iconColor, size: 36),
            ),
            const SizedBox(height: 12),
            Text(b.partner,
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(b.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.text),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(b.description,
                style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(99)),
              child: Text(b.expires,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Ativar Benefício'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Clube SafeRouteGo', onBack: widget.onBack),

          // ── Banner cashback ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1A56DB), Color(0xFF00C2A8)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo de Cashback',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
                        const Text('R\$ 42,80',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(99)),
                              child: const Text('Motorista Ouro',
                                  style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            const Text('8 benefícios ativos',
                                style: TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      const Icon(Icons.savings_rounded, color: Colors.white70, size: 40),
                      const SizedBox(height: 4),
                      Text('Resgatar', style: TextStyle(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Filtros de categoria ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final active = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: active ? AppTheme.primary : AppTheme.border),
                      ),
                      child: Text(cat, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppTheme.textMuted)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── Lista de benefícios ──────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _BenefitCard(
                benefit: filtered[i],
                onTap: () => _showBenefitDetail(filtered[i]),
              ),
            ),
          ),

          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final _BenefitItem benefit;
  final VoidCallback onTap;

  const _BenefitCard({required this.benefit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b = benefit;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: b.isHighlight ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Row(
          children: [
            // Ícone
            Stack(
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(color: b.iconBg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(b.icon, color: b.iconColor, size: 26),
                ),
                if (b.isNew)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.red, borderRadius: BorderRadius.circular(6)),
                      child: const Text('NEW', style: TextStyle(fontSize: 8,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.partner,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500)),
                  Text(b.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppTheme.text)),
                  Text(b.description,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(b.tag,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: AppTheme.primary)),
                      ),
                      if (b.expires.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(b.expires,
                              style: const TextStyle(fontSize: 9, color: AppTheme.textLight),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Valor / Botão
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: b.isHighlight
                        ? AppTheme.accent.withValues(alpha: 0.1)
                        : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(b.tagValue,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: b.isHighlight ? AppTheme.accent : AppTheme.primary)),
                ),
                const SizedBox(height: 6),
                const Text('Ativar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// PERFIL — conectado ao UserProfileService
// ══════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  final int navIndex;
  final Function(int) onNavTap;
  final VoidCallback onSettings;
  final VoidCallback onChangeVehicle;
  final VoidCallback onLogout;
  final VoidCallback? onFrequentRoutes;

  const ProfileScreen({super.key, required this.navIndex, required this.onNavTap,
      required this.onSettings, required this.onChangeVehicle, required this.onLogout,
      this.onFrequentRoutes});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _photoBase64;
  bool _isLoadingPhoto = false;
  UserProfile? _profile;
  MonthlyStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await UserProfileService.load();
    final stats = await GamificationService.obterEstatisticasMes();
    if (mounted) {
      setState(() {
        _profile = profile;
        _stats = stats;
        _photoBase64 = profile.photoBase64;
      });
    }
  }

  Future<void> _loadSavedPhoto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('profile_photo');
      if (saved != null && mounted) {
        setState(() => _photoBase64 = saved);
      }
    } catch (_) {}
  }

  // ── Editar campo de perfil ──────────────────────────────────────
  Future<void> _editField(String field, String label, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text('Editar $label',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      UserProfile? updated;
      switch (field) {
        case 'nome':      updated = await UserProfileService.updateField(nome: result); break;
        case 'cpf':       updated = await UserProfileService.updateField(cpf: result); break;
        case 'email':     updated = await UserProfileService.updateField(email: result); break;
        case 'telefone':  updated = await UserProfileService.updateField(telefone: result); break;
      }
      if (updated != null && mounted) {
        HapticFeedback.lightImpact();
        setState(() => _profile = updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$label atualizado!'),
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    }
  }

  // ── Adicionar/editar veículo ─────────────────────────────────────
  Future<void> _showVehicleEditor({VehicleProfile? editing}) async {
    final brandCtrl = TextEditingController(text: editing?.brand ?? '');
    final modelCtrl = TextEditingController(text: editing?.model ?? '');
    final yearCtrl  = TextEditingController(text: editing?.year ?? '');
    final plateCtrl = TextEditingController(text: editing?.plate ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(editing == null ? 'Adicionar Veículo' : 'Editar Veículo',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text)),
              const SizedBox(height: 16),
              _inputField('Marca', brandCtrl, 'ex: Toyota'),
              const SizedBox(height: 10),
              _inputField('Modelo', modelCtrl, 'ex: Corolla'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _inputField('Ano', yearCtrl, '2024')),
                const SizedBox(width: 10),
                Expanded(child: _inputField('Placa', plateCtrl, 'ABC-1D23')),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final brand = brandCtrl.text.trim();
                  final model = modelCtrl.text.trim();
                  final year  = yearCtrl.text.trim();
                  final plate = plateCtrl.text.trim();
                  if (brand.isEmpty || model.isEmpty || plate.isEmpty) return;
                  Navigator.pop(ctx);
                  final v = VehicleProfile(
                    id: editing?.id ?? 'v_${DateTime.now().millisecondsSinceEpoch}',
                    brand: brand, model: model, year: year.isNotEmpty ? year : '2024',
                    plate: plate, isActive: editing?.isActive ?? false,
                  );
                  final updated = await UserProfileService.addVehicle(v);
                  if (mounted) setState(() => _profile = updated);
                  HapticFeedback.mediumImpact();
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Salvar Veículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (kIsWeb) {
      await _pickPhotoWeb();
    } else {
      _showPhotoOptions();
    }
  }

  Future<void> _pickPhotoWeb() async {
    setState(() => _isLoadingPhoto = true);
    try {
      // Web: usar input file HTML
      final result = await _webPickImage();
      if (result != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo', result);
        if (mounted) {
          setState(() {
            _photoBase64 = result;
            _isLoadingPhoto = false;
          });
          _showSuccessSnack();
        }
      } else {
        if (mounted) setState(() => _isLoadingPhoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPhoto = false);
        _showErrorSnack();
      }
    }
  }

  Future<String?> _webPickImage() async {
    // Usar dart:html para acesso ao file picker no web
    try {
      // Simulação web-compatible: retorna null para não quebrar
      // Na versão web real, usa input[type=file]
      return null;
    } catch (_) {
      return null;
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Alterar foto de perfil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text)),
            const SizedBox(height: 20),
            _photoOptionTile(Icons.camera_alt_rounded, 'Tirar foto', AppTheme.primary, () {
              Navigator.pop(ctx);
              _simulatePhotoUpload('camera');
            }),
            const SizedBox(height: 10),
            _photoOptionTile(Icons.photo_library_rounded, 'Escolher da galeria', AppTheme.accent, () {
              Navigator.pop(ctx);
              _simulatePhotoUpload('gallery');
            }),
            if (_photoBase64 != null) ...[
              const SizedBox(height: 10),
              _photoOptionTile(Icons.delete_rounded, 'Remover foto', AppTheme.red, () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('profile_photo');
                if (mounted) setState(() => _photoBase64 = null);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoOptionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _simulatePhotoUpload(String source) async {
    setState(() => _isLoadingPhoto = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    // Gerar avatar colorido com inicial "G"
    final avatarBase64 = _generateAvatarBase64();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_photo', avatarBase64);

    if (mounted) {
      setState(() {
        _photoBase64 = avatarBase64;
        _isLoadingPhoto = false;
      });
      _showSuccessSnack();
    }
  }

  // Gera um avatar SVG colorido como base64 para demo
  String _generateAvatarBase64() {
    const svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
  <defs>
    <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1A56DB"/>
      <stop offset="100%" style="stop-color:#00C2A8"/>
    </linearGradient>
  </defs>
  <circle cx="100" cy="100" r="100" fill="url(#g)"/>
  <text x="100" y="130" font-family="Arial" font-size="90" font-weight="bold"
    fill="white" text-anchor="middle">G</text>
</svg>''';
    return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
  }

  void _showSuccessSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Foto de perfil atualizada!'),
        ]),
        backgroundColor: AppTheme.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Erro ao carregar foto. Tente novamente.'),
        backgroundColor: AppTheme.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final inicial = profile?.inicial ?? 'U';
    final nome = profile?.nome ?? '...';
    final membroDesde = 'Motorista desde ${profile?.membroDesde ?? '...'}';
    final nivel = _stats?.nivel ?? 1;
    const nivelNomes = ['Bronze','Prata','Ouro','Diamante','Platinum'];
    final nomeNivel = 'Motorista ${nivelNomes[(nivel - 1).clamp(0, 4)]}';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Cabeçalho do perfil
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20, left: 20, right: 20,
            ),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              children: [
                // Avatar com botão de câmera
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: _isLoadingPhoto
                              ? const Center(child: SizedBox(width: 28, height: 28,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                              : _photoBase64 != null
                                  ? _buildPhotoWidget()
                                  : Center(child: Text(inicial,
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))),
                        ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Text(
                    _photoBase64 != null ? 'Alterar foto' : 'Adicionar foto',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                Text(membroDesde, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(nomeNivel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: profile == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _profileSection('Dados Pessoais', [
                        _ProfileEditItem(icon: Icons.person_rounded, label: 'Nome',
                            value: profile.nome.isEmpty ? 'Toque para editar' : profile.nome,
                            onEdit: () => _editField('nome', 'Nome', profile.nome)),
                        _ProfileEditItem(icon: Icons.badge_rounded, label: 'CPF',
                            value: profile.cpf.isEmpty ? 'Toque para editar' : profile.cpf,
                            onEdit: () => _editField('cpf', 'CPF', profile.cpf)),
                        _ProfileEditItem(icon: Icons.email_rounded, label: 'E-mail',
                            value: profile.email.isEmpty ? 'Toque para editar' : profile.email,
                            onEdit: () => _editField('email', 'E-mail', profile.email)),
                        _ProfileEditItem(icon: Icons.phone_rounded, label: 'Telefone',
                            value: profile.telefone.isEmpty ? 'Toque para editar' : profile.telefone,
                            onEdit: () => _editField('telefone', 'Telefone', profile.telefone)),
                      ]),
                      const SizedBox(height: 14),
                      // Seção veículos (múltiplos)
                      _buildVehiclesSection(profile),
                      const SizedBox(height: 14),
                      // Ações
                      _ProfileActionBtn(icon: Icons.star_rounded, label: 'Rotas Frequentes',
                          onTap: widget.onFrequentRoutes ?? widget.onSettings),
                      const SizedBox(height: 6),
                      _ProfileActionBtn(icon: Icons.settings_rounded, label: 'Configurações', onTap: widget.onSettings),
                      const SizedBox(height: 6),
                      _ProfileActionBtn(icon: Icons.lock_rounded, label: 'Alterar Senha', onTap: () {}),
                      const SizedBox(height: 6),
                      _ProfileActionBtn(icon: Icons.logout_rounded, label: 'Sair', onTap: widget.onLogout, isDanger: true),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
          ),
          AppBottomNav(currentIndex: widget.navIndex, onTap: widget.onNavTap),
        ],
      ),
    );
  }

  Widget _buildVehiclesSection(UserProfile profile) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('VEÍCULOS', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted, letterSpacing: 0.06)),
                ),
                if (profile.veiculos.length < 3)
                  GestureDetector(
                    onTap: () => _showVehicleEditor(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: AppTheme.primary),
                          SizedBox(width: 4),
                          Text('Adicionar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (profile.veiculos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: GestureDetector(
                onTap: () => _showVehicleEditor(),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_rounded, color: AppTheme.primary, size: 20),
                      SizedBox(width: 10),
                      Text('Adicionar veículo', style: TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            )
          else
            ...profile.veiculos.map((v) => _VehicleItem(
              vehicle: v,
              onSetActive: () async {
                final updated = await UserProfileService.setActiveVehicle(v.id);
                HapticFeedback.lightImpact();
                if (mounted) setState(() => _profile = updated);
              },
              onEdit: () => _showVehicleEditor(editing: v),
              onRemove: profile.veiculos.length > 1 ? () async {
                final updated = await UserProfileService.removeVehicle(v.id);
                HapticFeedback.mediumImpact();
                if (mounted) setState(() => _profile = updated);
              } : null,
            )),
        ],
      ),
    );
  }

  Widget _buildPhotoWidget() {
    final src = _photoBase64!;
    if (src.startsWith('data:image/svg+xml;base64,')) {
      // SVG: decodificar e exibir como imagem de rede
      return Image.network(src, fit: BoxFit.cover, width: 80, height: 80,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('G', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))));
    } else if (src.startsWith('data:image/')) {
      // Imagem real base64
      try {
        final base64Data = src.split(',').last;
        return Image.memory(base64Decode(base64Data), fit: BoxFit.cover, width: 80, height: 80);
      } catch (_) {
        return const Center(child: Text('G',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)));
      }
    }
    return const Center(child: Text('G',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)));
  }

  Widget _profileSection(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(title.toUpperCase(), style: const TextStyle(
                fontSize:11, fontWeight:FontWeight.w700, color:AppTheme.textMuted, letterSpacing:0.06)),
          ),
          ...items,
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Item de perfil editável (toque para editar) ──────────────────
class _ProfileEditItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;
  const _ProfileEditItem({required this.icon, required this.label, required this.value, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == 'Toque para editar';
    return GestureDetector(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  Text(value, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: isEmpty ? AppTheme.textLight : AppTheme.text)),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, size: 15, color: isEmpty ? AppTheme.primary : AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}

// ── Item de veículo com ações ────────────────────────────────────
class _VehicleItem extends StatelessWidget {
  final VehicleProfile vehicle;
  final VoidCallback onSetActive;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  const _VehicleItem({
    required this.vehicle,
    required this.onSetActive,
    required this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSetActive,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: vehicle.isActive ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color: vehicle.isActive ? AppTheme.primary : AppTheme.border,
                  width: 2,
                ),
              ),
              child: vehicle.isActive
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.brand} ${vehicle.model}',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: vehicle.isActive ? AppTheme.primary : AppTheme.text,
                  ),
                ),
                Text(
                  '${vehicle.plate} · ${vehicle.year}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (vehicle.isActive)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text('Ativo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ),
          GestureDetector(
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.edit_rounded, size: 15, color: AppTheme.textLight),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_rounded, size: 15, color: AppTheme.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;
  const _ProfileActionBtn({required this.icon, required this.label, required this.onTap, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: isDanger ? AppTheme.red.withValues(alpha: 0.3) : AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDanger ? AppTheme.red : AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(
                fontSize:14, fontWeight:FontWeight.w500,
                color: isDanger ? AppTheme.red : AppTheme.text))),
            Icon(Icons.chevron_right_rounded, color: isDanger ? AppTheme.red.withValues(alpha: 0.5) : AppTheme.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// CONFIGURAÇÕES
// ══════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SettingsScreen({super.key, required this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _biometrics = true;
  bool _gpsBackground = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() {
        _notifications  = prefs.getBool('setting_notifs') ?? true;
        _biometrics     = prefs.getBool('setting_bio') ?? true;
        _gpsBackground  = prefs.getBool('setting_gps_bg') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  bool get _isDarkMode {
    try {
      // Acessa ThemeMode via lookup
      return Theme.of(context).brightness == Brightness.dark;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getBool('dark_mode') ?? false;
      await prefs.setBool('dark_mode', !current);
      // Notifica o ThemeManager via SharedPreferences (relido no restart)
      // Para efeito imediato, usa o ValueNotifier global via reflexão
      // A mudança será visível na próxima abertura ou via hot restart
      // Emite um feedback visual imediato
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!current ? 'Modo escuro ativado!' : 'Modo claro ativado!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Configurações', onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _settingsGroup('Preferências', [
                    _SettingsToggle(icon: Icons.notifications_rounded, title: 'Notificações',
                        subtitle: 'Alertas de viagem e ofertas', value: _notifications,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          setState(() => _notifications = v);
                          _saveSetting('setting_notifs', v);
                        }),
                    _SettingsToggle(icon: Icons.fingerprint_rounded, title: 'Biometria',
                        subtitle: 'Login com digital ou face', value: _biometrics,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          setState(() => _biometrics = v);
                          _saveSetting('setting_bio', v);
                        }),
                    _SettingsToggle(icon: Icons.dark_mode_rounded, title: 'Modo Escuro',
                        subtitle: 'Interface em dark mode',
                        value: _isDarkMode,
                        onChanged: (v) async {
                          HapticFeedback.lightImpact();
                          await _toggleDarkMode();
                          if (mounted) setState(() {});
                        }),
                    _SettingsToggle(icon: Icons.gps_fixed_rounded, title: 'GPS em segundo plano',
                        subtitle: 'Monitora rota minimizado', value: _gpsBackground,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          setState(() => _gpsBackground = v);
                          _saveSetting('setting_gps_bg', v);
                        }),
                  ]),
                  const SizedBox(height: 14),
                  _settingsGroup('Sobre', [
                    _SettingsItem(icon: Icons.info_rounded, title: 'Versão do app', subtitle: 'SafeRouteGo v1.0.0'),
                    _SettingsNavItem(icon: Icons.article_rounded, title: 'Termos de Uso'),
                    _SettingsNavItem(icon: Icons.shield_rounded, title: 'Política de Privacidade'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsGroup(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(title.toUpperCase(), style: const TextStyle(
                fontSize:11, fontWeight:FontWeight.w700, color:AppTheme.textMuted, letterSpacing:0.06)),
          ),
          ...items,
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;
  const _SettingsToggle({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize:14, fontWeight:FontWeight.w500, color:AppTheme.text)),
              Text(subtitle, style: const TextStyle(fontSize:12, color:AppTheme.textMuted)),
            ],
          )),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primary),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SettingsItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize:14, fontWeight:FontWeight.w500, color:AppTheme.text)),
              Text(subtitle, style: const TextStyle(fontSize:12, color:AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SettingsNavItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize:14, fontWeight:FontWeight.w500, color:AppTheme.text))),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight, size: 20),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// IA COPILOTO
// ══════════════════════════════════════════
class AICopilotScreen extends StatefulWidget {
  final VoidCallback onBack;
  const AICopilotScreen({super.key, required this.onBack});

  @override
  State<AICopilotScreen> createState() => _AICopilotScreenState();
}

class _AICopilotScreenState extends State<AICopilotScreen> {
  bool _showResponse = false;
  final _chatCtrl = TextEditingController();
  List<Map<String, String>> _messages = [];

  final _suggestions = [
    '🛡️ Como funciona o seguro?',
    '💰 Quanto custa por km?',
    '🚨 Como acionar sinistro?',
    '⭐ Como aumentar meu score?',
  ];

  final _aiResponses = {
    '🛡️ Como funciona o seguro?': 'O SafeRouteGo funciona por percurso! Você ativa a proteção antes de sair e paga apenas pelos quilômetros percorridos. Taxa base de R\$ 1,99 + R\$ 0,15/km, com multiplicadores de risco e descontos pelo seu score.',
    '💰 Quanto custa por km?': 'O valor base é R\$ 0,15/km + taxa mínima de R\$ 1,99. Seu score de 920 pontos garante 15% de desconto! Em média, uma viagem de 22 km custa cerca de R\$ 4,87.',
    '🚨 Como acionar sinistro?': 'Em caso de acidente ou roubo: 1) Acesse Assistência na tela de viagem. 2) Selecione o tipo de ocorrência. 3) Preencha o formulário com fotos. 4) Envie e acompanhe pelo protocolo gerado.',
    '⭐ Como aumentar meu score?': 'Dicas para aumentar seu score: ✅ Evite freadas bruscas • ✅ Mantenha velocidade adequada • ✅ Faça viagens regulares • ✅ Sem acidentes por 30 dias • ✅ Complete conquistas',
  };

  void _sendSuggestion(String text) {
    setState(() {
      _messages.add({'role': 'user', 'text': text});
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'bot', 'text': _aiResponses[text] ?? 'Posso ajudar com mais alguma coisa sobre o SafeRouteGo?'});
        });
      }
    });
  }

  void _sendMessage() {
    if (_chatCtrl.text.trim().isEmpty) return;
    final msg = _chatCtrl.text.trim();
    _chatCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': msg});
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'bot', 'text': 'Entendido! Estou aqui para ajudar com todas as suas dúvidas sobre o SafeRouteGo. Pode perguntar sobre seguros, viagens, score ou benefícios!'});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Header especial IA
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 14, bottom: 14, left: 16, right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('IA Copiloto', style: TextStyle(fontSize:16, fontWeight:FontWeight.w600, color:Colors.white))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('ATIVO', style: TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Avatar IA
                  Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 40),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('SafeRouteGo AI', style: TextStyle(fontSize:18, fontWeight:FontWeight.w800, color:AppTheme.text)),
                      const Text('Seu copiloto inteligente', style: TextStyle(fontSize:13, color:AppTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Mensagem inicial
                  _AIMessage(
                    isBot: true,
                    text: 'Olá, Gelci! Sua rota possui trânsito intenso na Av. Beira Mar.\nDeseja uma rota mais segura?',
                  ),
                  if (!_showResponse)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _showResponse = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.route_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text('Sim, recalcular', style: TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:Colors.white)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: const Center(child: Text('Manter rota', style: TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:AppTheme.textMuted))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_showResponse) ...[
                    const SizedBox(height: 10),
                    _AIMessage(isBot: true, text: '✅ Nova rota calculada! Economia de 12 minutos e risco Médio → Baixo.'),
                  ],
                  // Mensagens do chat
                  ..._messages.map((m) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _AIMessage(isBot: m['role'] == 'bot', text: m['text']!),
                  )),
                  const SizedBox(height: 16),
                  // Insights
                  const Align(alignment: Alignment.centerLeft,
                      child: Text('INSIGHTS DESTA VIAGEM', style: TextStyle(fontSize:12, fontWeight:FontWeight.w700, color:AppTheme.textMuted, letterSpacing:0.06))),
                  const SizedBox(height: 10),
                  _InsightCard(icon: Icons.water_drop_rounded, title: 'Chuva prevista',
                      desc: 'Precipitação em 40 min. Reduza velocidade.'),
                  const SizedBox(height: 8),
                  _InsightCard(icon: Icons.school_rounded, title: 'Zona escolar',
                      desc: 'Limite de 30 km/h nos próximos 2 km.'),
                  const SizedBox(height: 8),
                  _InsightCard(icon: Icons.star_rounded, title: 'Score em alta!',
                      desc: 'Excelente direção. +8 pts ao chegar.'),
                ],
              ),
            ),
          ),
          // Sugestões + Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                // Sugestões
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _suggestions.map((s) => GestureDetector(
                      onTap: () => _sendSuggestion(s),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(s, style: const TextStyle(fontSize:12, color:AppTheme.primary, fontWeight:FontWeight.w500)),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                // Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        style: const TextStyle(fontSize:14, color:AppTheme.text),
                        decoration: InputDecoration(
                          hintText: 'Pergunte ao SafeRouteGo IA...',
                          hintStyle: const TextStyle(fontSize:13, color:AppTheme.textLight),
                          filled: true,
                          fillColor: AppTheme.surface2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppTheme.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppTheme.primary)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }
}

class _AIMessage extends StatelessWidget {
  final bool isBot;
  final String text;
  const _AIMessage({required this.isBot, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isBot ? const LinearGradient(
            colors: [AppTheme.primaryLight, Color(0xFFDCEEFF)],
          ) : AppTheme.primaryGradient,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isBot ? 4 : 16),
            bottomRight: Radius.circular(isBot ? 16 : 4),
          ),
        ),
        child: Text(text, style: TextStyle(
            fontSize: 13,
            color: isBot ? AppTheme.text : Colors.white,
            height: 1.5)),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _InsightCard({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:AppTheme.text)),
                Text(desc, style: const TextStyle(fontSize:12, color:AppTheme.textMuted, height:1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

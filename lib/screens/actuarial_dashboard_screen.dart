// ═══════════════════════════════════════════════════════════════════
// SAFEROUTE — DASHBOARD IA ATUARIAL
// Motor Atuarial V2 · Probabilidades · Comissões · Simulador
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/actuarial_engine.dart';
import '../services/risk_engine.dart';
import '../services/safe_map_engine.dart';

// ─────────────────────────────────────────────────────────────────
// TELA PRINCIPAL DO DASHBOARD ATUARIAL
// ─────────────────────────────────────────────────────────────────

class ActuarialDashboardScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ActuarialDashboardScreen({super.key, required this.onBack});

  @override
  State<ActuarialDashboardScreen> createState() => _ActuarialDashboardScreenState();
}

class _ActuarialDashboardScreenState extends State<ActuarialDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _metrics = ActuarialMetrics.demo;

  // ── Simulador ────────────────────────────────────────────────
  double _sliderKm     = 20;
  int    _sliderHour   = 19;
  int    _sliderAge    = 28;
  double _sliderFipe   = 130000;
  WeatherCondition _weather = WeatherCondition.chuva;
  String _vehicleModel = 'BYD Atto 2';
  String _planType     = 'equilibrado';

  ActuarialResult? _simResult;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _runSimulation();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _runSimulation() {
    final input = ActuarialInput(
      distanceKm: _sliderKm,
      departureTime: DateTime.now().copyWith(hour: _sliderHour),
      vehicleModel: _vehicleModel,
      vehicleFipeValue: _sliderFipe,
      driverAge: _sliderAge,
      weather: _weather,
      planType: _planType,
      driverHistory: const DriverHistory(score: 820),
      telemetry: const TelemetryData(score: 950),
    );
    setState(() => _simResult = ActuarialEngine.calculate(input));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Header especial
          _ActuarialHeader(onBack: widget.onBack),

          // Tabs
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tab,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Visão Geral'),
                Tab(text: 'Simulador'),
                Tab(text: 'Rotas'),
                Tab(text: 'Comissões'),
                Tab(text: 'Safe Map'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(metrics: _metrics),
                _SimulatorTab(
                  sliderKm: _sliderKm,
                  sliderHour: _sliderHour,
                  sliderAge: _sliderAge,
                  sliderFipe: _sliderFipe,
                  weather: _weather,
                  vehicleModel: _vehicleModel,
                  planType: _planType,
                  result: _simResult,
                  onKmChanged: (v) { _sliderKm = v; _runSimulation(); },
                  onHourChanged: (v) { _sliderHour = v.round(); _runSimulation(); },
                  onAgeChanged: (v) { _sliderAge = v.round(); _runSimulation(); },
                  onFipeChanged: (v) { _sliderFipe = v; _runSimulation(); },
                  onWeatherChanged: (v) { _weather = v; _runSimulation(); },
                  onVehicleChanged: (v) { _vehicleModel = v; _runSimulation(); },
                  onPlanChanged: (v) { _planType = v; _runSimulation(); },
                ),
                _RoutesTab(metrics: _metrics),
                _CommissionTab(result: _simResult),
                const _SafeMapAdminTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────

class _ActuarialHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ActuarialHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16, right: 16, bottom: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motor Atuarial IA',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('SafeRouteGo Actuarial Engine ${ActuarialEngine.version}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4))),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                SizedBox(width: 4),
                Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 1 — VISÃO GERAL
// ─────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final ActuarialMetrics metrics;
  const _OverviewTab({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final sinistralidade = metrics.taxaSinistralidade * 100;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── KPIs principais ────────────────────────────────
          Row(
            children: [
              _KpiCard(
                  label: 'Receita Total',
                  value: 'R\$ ${(metrics.receitaTotal / 1000).toStringAsFixed(1)}k',
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.primary,
                  sub: '${metrics.totalViagens} viagens'),
              const SizedBox(width: 10),
              _KpiCard(
                  label: 'Sinistros Pagos',
                  value: 'R\$ ${(metrics.sinistrosPagos / 1000).toStringAsFixed(1)}k',
                  icon: Icons.car_crash_rounded,
                  color: AppTheme.red,
                  sub: '${metrics.totalSinistros} eventos'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _KpiCard(
                  label: 'Margem Bruta',
                  value: 'R\$ ${(metrics.margemBruta / 1000).toStringAsFixed(1)}k',
                  icon: Icons.account_balance_rounded,
                  color: AppTheme.green,
                  sub: '${((metrics.margemBruta / metrics.receitaTotal) * 100).round()}% da receita'),
              const SizedBox(width: 10),
              _KpiCard(
                  label: 'Sinistralidade',
                  value: '${sinistralidade.toStringAsFixed(1)}%',
                  icon: Icons.analytics_rounded,
                  color: sinistralidade > 30 ? AppTheme.red : AppTheme.yellow,
                  sub: sinistralidade < 30 ? 'Meta: < 30%' : '⚠ Acima da meta'),
            ],
          ),

          const SizedBox(height: 20),

          // ── Gráfico de distribuição de receita ───────────
          _SectionTitle(title: 'Distribuição de Receita', icon: Icons.pie_chart_rounded),
          const SizedBox(height: 10),
          _RevenueDistribution(total: metrics.receitaTotal),

          const SizedBox(height: 20),

          // ── Cidades mais rentáveis ─────────────────────
          _SectionTitle(title: 'Cidades Mais Rentáveis', icon: Icons.location_city_rounded),
          const SizedBox(height: 10),
          ...metrics.cidadesRentaveis.map((c) => _CityBar(city: c)),

          const SizedBox(height: 20),

          // ── Veículos mais rentáveis ─────────────────────
          _SectionTitle(title: 'Veículos Mais Lucrativos', icon: Icons.directions_car_rounded),
          const SizedBox(height: 10),
          ...metrics.veiculosRentaveis.map((v) => _VehicleRow(vehicle: v)),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;
  const _KpiCard({required this.label, required this.value, required this.icon,
      required this.color, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                Icon(Icons.trending_up_rounded, color: AppTheme.textLight, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(sub,
                style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
          ],
        ),
      ),
    );
  }
}

class _RevenueDistribution extends StatelessWidget {
  final double total;
  const _RevenueDistribution({required this.total});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DistItem('Seguradora', 0.55, AppTheme.primary),
      _DistItem('Fundo Sinistro', 0.20, AppTheme.red),
      _DistItem('SixTech', 0.15, AppTheme.accent),
      _DistItem('Reserva', 0.10, AppTheme.yellow),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          // Barra empilhada
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: items.map((it) => Expanded(
                flex: (it.pct * 100).round(),
                child: Container(height: 16, color: it.color),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Legenda
          Row(
            children: items.map((it) => Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: it.color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(it.label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                    ],
                  ),
                  Text('${(it.pct * 100).round()}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: it.color)),
                  Text('R\$ ${((total * it.pct) / 1000).toStringAsFixed(1)}k',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _DistItem {
  final String label;
  final double pct;
  final Color color;
  const _DistItem(this.label, this.pct, this.color);
}

class _CityBar extends StatelessWidget {
  final CityMetric city;
  const _CityBar({required this.city});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(city.city,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
                Text('R\$ ${(city.revenue / 1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${city.trips} viagens · Margem: ${(city.margin * 100).round()}%',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const Spacer(),
                Text('${(city.margin * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: city.margin > 0.6 ? AppTheme.green : AppTheme.yellow)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: city.margin,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation(
                    city.margin > 0.6 ? AppTheme.green : AppTheme.yellow),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final VehicleMetric vehicle;
  const _VehicleRow({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_car_rounded, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.model,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
                  Text('FIPE: R\$ ${(vehicle.fipe / 1000).round()}k · ${vehicle.trips} viagens',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('R\$ ${(vehicle.revenue / 1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                Text('Margem ${(vehicle.margin * 100).round()}%',
                    style: TextStyle(fontSize: 11,
                        color: vehicle.margin > 0.6 ? AppTheme.green : AppTheme.yellow,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 2 — SIMULADOR DE PRECIFICAÇÃO
// ─────────────────────────────────────────────────────────────────

class _SimulatorTab extends StatelessWidget {
  final double sliderKm;
  final int sliderHour;
  final int sliderAge;
  final double sliderFipe;
  final WeatherCondition weather;
  final String vehicleModel;
  final String planType;
  final ActuarialResult? result;
  final ValueChanged<double> onKmChanged;
  final ValueChanged<double> onHourChanged;
  final ValueChanged<double> onAgeChanged;
  final ValueChanged<double> onFipeChanged;
  final ValueChanged<WeatherCondition> onWeatherChanged;
  final ValueChanged<String> onVehicleChanged;
  final ValueChanged<String> onPlanChanged;

  const _SimulatorTab({
    required this.sliderKm,
    required this.sliderHour,
    required this.sliderAge,
    required this.sliderFipe,
    required this.weather,
    required this.vehicleModel,
    required this.planType,
    required this.result,
    required this.onKmChanged,
    required this.onHourChanged,
    required this.onAgeChanged,
    required this.onFipeChanged,
    required this.onWeatherChanged,
    required this.onVehicleChanged,
    required this.onPlanChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Resultado principal ────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B4B), Color(0xFF1A56DB)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(color: r.riskZone.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(r.nivelRisco,
                        style: TextStyle(fontSize: 13, color: r.riskZone.color,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(r.precoFormatado,
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text('Multiplicador: ${r.multiplicadorFormatado}',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                // Probabilidade de sinistro
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ProbStat(label: 'Roubo', value: r.probs.fmt(r.probs.pRoubo)),
                      _ProbStat(label: 'Furto', value: r.probs.fmt(r.probs.pFurto)),
                      _ProbStat(label: 'Colisão', value: r.probs.fmt(r.probs.pColisao)),
                      _ProbStat(label: 'Sinistro', value: r.probs.fmt(r.probs.pTotal),
                          highlight: true, color: r.probs.pTotalColor),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Sliders ───────────────────────────────────
          _SectionTitle(title: 'Parâmetros de Simulação', icon: Icons.tune_rounded),
          const SizedBox(height: 10),

          _SliderCard(
            label: 'Distância',
            value: '${sliderKm.round()} km',
            child: Slider(
              value: sliderKm,
              min: 1, max: 100,
              onChanged: onKmChanged,
              activeColor: AppTheme.primary,
            ),
          ),

          _SliderCard(
            label: 'Horário de partida',
            value: '${sliderHour}h00 — ${HourRiskFactor.label(sliderHour).split(' ')[0]}',
            child: Slider(
              value: sliderHour.toDouble(),
              min: 0, max: 23,
              divisions: 23,
              onChanged: onHourChanged,
              activeColor: HourRiskFactor.color(sliderHour),
            ),
          ),

          _SliderCard(
            label: 'Idade do condutor',
            value: '$sliderAge anos — ${AgeFactor.label(sliderAge).split(' ').take(2).join(' ')}',
            child: Slider(
              value: sliderAge.toDouble(),
              min: 18, max: 80,
              divisions: 62,
              onChanged: onAgeChanged,
              activeColor: AgeFactor.color(sliderAge),
            ),
          ),

          _SliderCard(
            label: 'Valor FIPE do veículo',
            value: FipeRiskFactor.formatFipe(sliderFipe),
            child: Slider(
              value: sliderFipe,
              min: 20000, max: 500000,
              onChanged: onFipeChanged,
              activeColor: AppTheme.accent,
            ),
          ),

          // ── Clima ─────────────────────────────────────
          const SizedBox(height: 4),
          const Text('Clima',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted, letterSpacing: 0.04)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: WeatherCondition.values.map((w) {
                final active = w == weather;
                return GestureDetector(
                  onTap: () => onWeatherChanged(w),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? w.color.withValues(alpha: 0.15) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: active ? w.color : AppTheme.border, width: active ? 1.5 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(w.icon, color: active ? w.color : AppTheme.textMuted, size: 16),
                        const SizedBox(width: 4),
                        Text(w.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: active ? w.color : AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Plano ─────────────────────────────────────
          const Text('Plano de Cobertura',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted, letterSpacing: 0.04)),
          const SizedBox(height: 8),
          Row(
            children: PricingEngine.plans.map((plan) {
              final active = plan.id == planType;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPlanChanged(plan.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: active ? plan.color.withValues(alpha: 0.12) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: active ? plan.color : AppTheme.border, width: active ? 1.5 : 1),
                    ),
                    child: Column(
                      children: [
                        Icon(plan.icon, color: active ? plan.color : AppTheme.textLight, size: 20),
                        const SizedBox(height: 4),
                        Text(plan.name,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: active ? plan.color : AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // ── Breakdown dos 9 fatores ───────────────────
          _SectionTitle(title: 'Breakdown dos 9 Fatores', icon: Icons.analytics_rounded),
          const SizedBox(height: 10),
          _FactorGrid(result: r),

          const SizedBox(height: 16),

          // ── Franquia ──────────────────────────────────
          _SectionTitle(title: 'Franquia Inteligente', icon: Icons.shield_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border)),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                      color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.shield_moon_rounded, color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Franquia calculada',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Text(r.franquiaFormatada,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                              color: AppTheme.primary)),
                      Text('Plano ${planType[0].toUpperCase()}${planType.substring(1)} · FIPE ${FipeRiskFactor.formatFipe(sliderFipe)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ProbStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? color;
  const _ProbStat({required this.label, required this.value,
      this.highlight = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(
            fontSize: highlight ? 16 : 13,
            fontWeight: FontWeight.w800,
            color: color ?? Colors.white)),
        Text(label, style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _SliderCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget child;
  const _SliderCard({required this.label, required this.value, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600)),
                Text(value,
                    style: const TextStyle(fontSize: 12, color: AppTheme.text,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _FactorGrid extends StatelessWidget {
  final ActuarialResult result;
  const _FactorGrid({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final factors = [
      _Factor('F1 CEP',        r.fCep,              Icons.location_on_rounded),
      _Factor('F2 Rua',        r.fRua,              Icons.signpost_rounded),
      _Factor('F3 Horário',    r.fHorario,          Icons.access_time_rounded),
      _Factor('F4 Clima',      r.fClima,            Icons.cloud_rounded),
      _Factor('F5 Roubo',      r.fVeiculoRoubo,     Icons.car_crash_rounded),
      _Factor('F5 Colisão',    r.fVeiculoColisao,   Icons.merge_rounded),
      _Factor('F6 FIPE',       r.fFipe,             Icons.attach_money_rounded),
      _Factor('F7 Idade',      r.fIdade,            Icons.person_rounded),
      _Factor('F8 Histórico',  r.fHistorico,        Icons.history_rounded),
      _Factor('F9 Telemetria', r.fTelemetria,       Icons.speed_rounded),
      _Factor('Tráfego',       r.fTrafico,          Icons.traffic_rounded),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: factors.map((f) => _FactorTile(factor: f)).toList(),
    );
  }
}

class _Factor {
  final String label;
  final double value;
  final IconData icon;
  const _Factor(this.label, this.value, this.icon);
  Color get color {
    if (value <= 1.0) return const Color(0xFF22C55E);
    if (value <= 1.3) return const Color(0xFFF59E0B);
    if (value <= 1.8) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }
}

class _FactorTile extends StatelessWidget {
  final _Factor factor;
  const _FactorTile({required this.factor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: factor.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: factor.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(factor.icon, color: factor.color, size: 18),
          const SizedBox(height: 4),
          Text(factor.label,
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          Text('×${factor.value.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: factor.color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 3 — ROTAS
// ─────────────────────────────────────────────────────────────────

class _RoutesTab extends StatelessWidget {
  final ActuarialMetrics metrics;
  const _RoutesTab({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rotas lucrativas
          _SectionTitle(
              title: 'Rotas Mais Lucrativas',
              icon: Icons.trending_up_rounded,
              iconColor: AppTheme.green),
          const SizedBox(height: 8),
          ...metrics.rotasLucrativas.map((r) => _RouteCard(route: r, isProfit: true)),

          const SizedBox(height: 16),

          // Rotas problemáticas
          _SectionTitle(
              title: 'Rotas Problemáticas',
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.red),
          const SizedBox(height: 8),
          ...metrics.rotasProblematicas.map((r) => _RouteCard(route: r, isProfit: false)),

          const SizedBox(height: 16),

          // Info de zonas
          _SectionTitle(title: 'Zonas de Risco — ES', icon: Icons.map_rounded),
          const SizedBox(height: 8),
          _ZoneInfoCard(),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RouteMetric route;
  final bool isProfit;
  const _RouteCard({required this.route, required this.isProfit});

  @override
  Widget build(BuildContext context) {
    final color = isProfit
        ? (route.margin > 0.6 ? AppTheme.green : AppTheme.yellow)
        : AppTheme.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            Container(
              width: 10, height: 48,
              decoration: BoxDecoration(
                  color: route.zone.color,
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(route.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppTheme.text)),
                  Text('${route.trips} viagens · R\$ ${(route.revenue / 1000).toStringAsFixed(1)}k',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: route.margin,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${(route.margin * 100).round()}%',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                Text('margem',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        children: RiskZone.values.map((z) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: z.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(z.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppTheme.text)),
              const Spacer(),
              Text('×${z.multiplier.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: z.color)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(z.description,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 4 — COMISSÕES
// ─────────────────────────────────────────────────────────────────

class _CommissionTab extends StatelessWidget {
  final ActuarialResult? result;
  const _CommissionTab({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const Center(child: CircularProgressIndicator());

    final split = CommissionEngine.calculate(r.precoFinal);
    final splitTotal = CommissionEngine.calculate(148720.50); // receita total

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Divisão desta viagem ───────────────────────
          _SectionTitle(title: 'Esta Viagem — ${r.precoFormatado}', icon: Icons.receipt_rounded),
          const SizedBox(height: 10),
          _CommissionPieCard(split: split),

          const SizedBox(height: 16),

          // ── Divisão total ──────────────────────────────
          _SectionTitle(title: 'Receita Total do Período', icon: Icons.account_balance_rounded),
          const SizedBox(height: 10),
          _CommissionPieCard(split: splitTotal),

          const SizedBox(height: 16),

          // ── Tabela de tarifação ────────────────────────
          _SectionTitle(title: 'Planos de Cobertura', icon: Icons.list_alt_rounded),
          const SizedBox(height: 10),
          _PlanComparisonTable(),

          const SizedBox(height: 16),

          // ── Margem mínima ──────────────────────────────
          _SectionTitle(title: 'Proteção de Margem', icon: Icons.lock_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Regra de Margem Mínima',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 10),
                _MarginRow('Custo Atuarial',   '+'),
                _MarginRow('Reserva Técnica',  '+'),
                _MarginRow('Comissão Seguradora', '+'),
                _MarginRow('Comissão SixTech', '+'),
                _MarginRow('Lucro Mínimo',     '+'),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 6)),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('= Preço Mínimo de Venda',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text('Nunca abaixo disso',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CommissionPieCard extends StatelessWidget {
  final CommissionSplit split;
  const _CommissionPieCard({required this.split});

  @override
  Widget build(BuildContext context) {
    final items = [
      _CommItem('Seguradora',    split.seguradora,    55, AppTheme.primary),
      _CommItem('Fundo Sinistro',split.fundoSinistro, 20, AppTheme.red),
      _CommItem('SixTech',       split.sixtech,       15, AppTheme.accent),
      _CommItem('Reserva',       split.reserva,       10, AppTheme.yellow),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          // Barra empilhada
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: items.map((it) => Expanded(
                flex: it.pct,
                child: Container(height: 20, color: it.color),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Linhas de detalhe
          ...items.map((it) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(it.label,
                      style: const TextStyle(fontSize: 13, color: AppTheme.text,
                          fontWeight: FontWeight.w500)),
                ),
                Text('${it.pct}%',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(width: 12),
                Text('R\$ ${it.value.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: it.color)),
              ],
            ),
          )),
          Container(height: 1, color: AppTheme.border, margin: const EdgeInsets.symmetric(vertical: 6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
              Text('R\$ ${split.total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommItem {
  final String label;
  final double value;
  final int pct;
  final Color color;
  const _CommItem(this.label, this.value, this.pct, this.color);
}

class _PlanComparisonTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd))),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Plano',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
                Expanded(child: Text('Preço\n×Mult',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                    textAlign: TextAlign.center)),
                Expanded(child: Text('Franquia\n×Mult',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                    textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Rows
          ...PricingEngine.plans.map((plan) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(plan.icon, color: plan.color, size: 18),
                      const SizedBox(width: 8),
                      Text(plan.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppTheme.text)),
                    ],
                  ),
                ),
                Expanded(
                  child: Text('×${plan.priceMultiplier.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: plan.color),
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text('×${plan.deductibleMultiplier.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                          color: plan.deductibleMultiplier < 1 ? AppTheme.green : AppTheme.red),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _MarginRow extends StatelessWidget {
  final String label;
  final String op;
  const _MarginRow(this.label, this.op);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5)),
            child: Center(
              child: Text(op, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// WIDGETS COMPARTILHADOS
// ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  const _SectionTitle({required this.title, required this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppTheme.primary, size: 16),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                color: AppTheme.text, letterSpacing: 0.02)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5 — SAFE MAP (painel resumido no Dashboard Admin)
// ─────────────────────────────────────────────────────────────────────────────

class _SafeMapAdminTab extends StatelessWidget {
  const _SafeMapAdminTab();

  @override
  Widget build(BuildContext context) {
    final states = SafeMapDatabase.states;
    final cities = SafeMapDatabase.cities;
    final vehicles = SafeMapDatabase.topStolenVehicles;
    final criticals = SafeMapDatabase.topCriticalCities;
    final safest = SafeMapDatabase.topSafestCities;

    final avgScore = states.fold(0, (s, e) => s + e.score) ~/ states.length;
    final totalRoubos = states.fold(0, (s, e) => s + e.roubosAno);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs nacionais
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF00C2A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('Safe Map — Visão Geral Nacional',
                        style: TextStyle(color: Colors.white,
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _AdminKpi(label: 'Score Médio', value: '$avgScore', sub: '/ 1000', light: true),
                    const SizedBox(width: 8),
                    _AdminKpi(label: 'Total Roubos', value: _fmt(totalRoubos), sub: '/ano', light: true),
                    const SizedBox(width: 8),
                    _AdminKpi(label: 'Estados', value: '${states.length}', sub: 'cobertos', light: true),
                    const SizedBox(width: 8),
                    _AdminKpi(label: 'Cidades', value: '${cities.length}', sub: 'mapeadas', light: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Score bar visual de todos os estados
          _buildScoreBars(states),
          const SizedBox(height: 14),

          // Top críticas vs mais seguras
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCityRankPanel(
                  title: 'Cidades Críticas',
                  cities: criticals.take(4).toList(),
                  icon: Icons.dangerous_rounded,
                  iconColor: const Color(0xFFEF4444))),
              const SizedBox(width: 10),
              Expanded(child: _buildCityRankPanel(
                  title: 'Cidades Seguras',
                  cities: safest.take(4).toList(),
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF22C55E))),
            ],
          ),
          const SizedBox(height: 14),

          // Top veículos mais roubados
          _buildVehiclePanel(vehicles),
          const SizedBox(height: 14),

          // Time risk summary
          _buildTimeRiskSummary(),
          const SizedBox(height: 14),

          // IA Risk demos
          _buildAIRiskPanel(),
        ],
      ),
    );
  }

  Widget _buildScoreBars(List<StateRisk> states) {
    final sorted = List<StateRisk>.from(states)..sort((a, b) => b.score.compareTo(a.score));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bar_chart_rounded, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text('Score por Estado', style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: AppTheme.text)),
          ]),
          const SizedBox(height: 10),
          ...sorted.take(10).map((s) {
            final cls = SafeScoreClass.fromScore(s.score);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(width: 28,
                      child: Text(s.uf, style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: s.score / 1000,
                        backgroundColor: AppTheme.border,
                        color: cls.color,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(width: 32, child: Text('${s.score}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cls.color))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCityRankPanel({
    required String title,
    required List<CityRisk> cities,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Expanded(child: Text(title, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: AppTheme.text))),
          ]),
          const SizedBox(height: 8),
          ...cities.asMap().entries.map((e) {
            final cls = SafeScoreClass.fromScore(e.value.score);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Text('#${e.key + 1}', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                const SizedBox(width: 5),
                Expanded(child: Text(e.value.nome,
                    style: TextStyle(fontSize: 10, color: AppTheme.text))),
                Text('${e.value.score}', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800, color: cls.color)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVehiclePanel(List<VehicleRiskRecord> vehicles) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.car_crash_rounded, size: 14, color: const Color(0xFFEF4444)),
            const SizedBox(width: 6),
            Text('Top Veículos Mais Roubados', style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: AppTheme.text)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(width: 30, child: Text('#', style: TextStyle(fontSize: 9,
                color: AppTheme.textMuted))),
            Expanded(child: Text('Modelo', style: TextStyle(fontSize: 9,
                color: AppTheme.textMuted))),
            SizedBox(width: 50, child: Text('Roubo', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: AppTheme.textMuted))),
            SizedBox(width: 50, child: Text('Furto', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: AppTheme.textMuted))),
            SizedBox(width: 55, child: Text('FIPE', textAlign: TextAlign.right,
                style: TextStyle(fontSize: 9, color: AppTheme.textMuted))),
          ]),
          const Divider(height: 8),
          ...vehicles.take(8).toList().asMap().entries.map((e) {
            final v = e.value;
            final robbCls = SafeScoreClass.fromScore(v.robberyScore);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                SizedBox(width: 30, child: Text('#${e.key + 1}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: e.key < 3 ? const Color(0xFFF59E0B) : AppTheme.textMuted))),
                Expanded(child: Text('${v.marca} ${v.modelo}',
                    style: TextStyle(fontSize: 10, color: AppTheme.text))),
                SizedBox(width: 50, child: Text('${v.robberyScore}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: robbCls.color))),
                SizedBox(width: 50, child: Text('${v.theftScore}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted))),
                SizedBox(width: 55, child: Text('R\$${v.fipeMediaMil.toStringAsFixed(0)}K',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeRiskSummary() {
    final peaks = [
      (22, 'Mais Perigoso', const Color(0xFFEF4444)),
      (23, 'Segundo Pico', const Color(0xFFF97316)),
      (3, 'Madrugada', const Color(0xFFF59E0B)),
      (6, 'Mais Seguro', const Color(0xFF22C55E)),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.schedule_rounded, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text('Risco por Horário', style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: AppTheme.text)),
          ]),
          const SizedBox(height: 10),
          Row(
            children: peaks.map((p) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: p.$3.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.$3.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('${p.$1}h', style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w800, color: p.$3)),
                    const SizedBox(height: 2),
                    Text('×${TimeRiskTable.weight(p.$1).toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.$3)),
                    Text(p.$2, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRiskPanel() {
    final scenarios = [
      RiskAI.demoYoungHighRisk,
      RiskAI.demoAdultLowRisk,
      RiskAI.demoNight,
    ];
    final labels = ['Jovem / Alto Risco', 'Adulto / Baixo Risco', 'Noturno / Médio'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.psychology_rounded, size: 14, color: const Color(0xFF6366F1)),
            const SizedBox(width: 6),
            Text('Risk AI — Cenários Demo (${_fmt(RiskAI.trainingDataPoints)}+ rotas)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text)),
          ]),
          const SizedBox(height: 10),
          ...scenarios.asMap().entries.map((e) {
            final p = e.value;
            final sinColor = p.sinistroChance < 0.03
                ? const Color(0xFF22C55E)
                : p.sinistroChance < 0.08
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sinColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sinColor.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labels[e.key], style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600, color: AppTheme.text)),
                    Text(p.riskProfile, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                )),
                Text('${(p.sinistroChance * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: sinColor)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _AdminKpi extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool light;
  const _AdminKpi({required this.label, required this.value, required this.sub, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: 0.15) : AppTheme.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: light ? Colors.white : AppTheme.text)),
            Text(sub, style: TextStyle(fontSize: 8,
                color: light ? Colors.white60 : AppTheme.textMuted)),
            Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                color: light ? Colors.white70 : AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

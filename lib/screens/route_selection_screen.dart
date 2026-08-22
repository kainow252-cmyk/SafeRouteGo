// ═══════════════════════════════════════════════════════════════
// SAFEROUTE — TELA DE SELEÇÃO DE ROTA COM ATUÁRIO DE IA
// Exibe 3 opções: Segura / Rápida / Equilibrada
// Com preço por km, risco, tempo e análise atuarial completa
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/route_actuarial_service.dart';

class RouteSelectionScreen extends StatefulWidget {
  final String origin;
  final String destination;
  final double? distanceKm;
  final VoidCallback onBack;
  final void Function(RouteActuarialResult selectedRoute) onSelectRoute;

  const RouteSelectionScreen({
    super.key,
    required this.origin,
    required this.destination,
    this.distanceKm,
    required this.onBack,
    required this.onSelectRoute,
  });

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen>
    with TickerProviderStateMixin {
  List<RouteActuarialResult>? _routes;
  int _selectedIndex = 2;  // Equilibrada selecionada por padrão
  bool _loading = true;
  late AnimationController _shieldController;
  late AnimationController _cardController;
  late Animation<double> _shieldAnim;
  late Animation<double> _cardAnim;
  String _loadingStep = 'Calculando rotas...';
  final List<String> _steps = [
    'Analisando zonas de risco...',
    'Consultando motor atuarial...',
    'Calculando preço por km...',
    'Aplicando bônus de telemetria...',
    'Gerando 3 opções de rota...',
  ];
  int _stepIdx = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();

    _shieldController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _cardController   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _shieldAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shieldController, curve: Curves.elasticOut));
    _cardAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic));

    _startLoading();
  }

  void _startLoading() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _stepIdx = (_stepIdx + 1) % _steps.length;
        _loadingStep = _steps[_stepIdx];
      });
    });

    // Simula cálculo atuarial (1.8s para efeito visual)
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      _stepTimer?.cancel();
      final routes = RouteActuarialEngine.calculateRoutes(
        origin: widget.origin,
        destination: widget.destination,
        distanceKmHint: widget.distanceKm,
        telemetryScore: 850,
        departureTime: DateTime.now(),
      );
      setState(() {
        _routes = routes;
        _loading = false;
      });
      _shieldController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _cardController.forward();
      });
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _shieldController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading ? _buildLoading() : _buildRouteList(),
            ),
            if (!_loading) _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Escolha sua Rota',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    const Text('Atuário de IA calculou 3 opções para você',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              // Badge atuarial
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryAccentGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('IA Atuarial', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Origem → Destino
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    Container(width: 1.5, height: 20, color: Colors.grey.shade300),
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.origin, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text)),
                      const SizedBox(height: 8),
                      Text(widget.destination, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
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

  // ── Loading atuarial ─────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shield animado
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.05),
            duration: const Duration(milliseconds: 800),
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryAccentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4)],
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Motor Atuarial de IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.text)),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(_loadingStep, key: ValueKey(_loadingStep),
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 32),
          // Steps
          ...List.generate(_steps.length, (i) => _buildStep(i)),
        ],
      ),
    );
  }

  Widget _buildStep(int i) {
    final done = i < _stepIdx;
    final active = i == _stepIdx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 40),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: done ? AppTheme.green : active ? AppTheme.primary : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(done ? Icons.check_rounded : active ? Icons.circle : Icons.circle_outlined,
                size: 10, color: (done || active) ? Colors.white : Colors.grey.shade400),
          ),
          const SizedBox(width: 8),
          Text(_steps[i], style: TextStyle(
            fontSize: 12,
            color: done ? AppTheme.green : active ? AppTheme.primary : Colors.grey.shade400,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  // ── Lista de rotas ────────────────────────────────────────────
  Widget _buildRouteList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header atuarial
        FadeTransition(
          opacity: _shieldAnim,
          child: ScaleTransition(
            scale: _shieldAnim,
            child: _buildAIHeader(),
          ),
        ),
        const SizedBox(height: 16),
        // Cards das 3 rotas
        ...List.generate(_routes!.length, (i) {
          return FadeTransition(
            opacity: _cardAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(0, 0.3 * (i + 1) * 0.3), end: Offset.zero)
                  .animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRouteCard(_routes![i], i),
              ),
            ),
          );
        }),
        // Legenda de risco
        _buildRiskLegend(),
        const SizedBox(height: 12),
        // Disclaimer atuarial
        _buildDisclaimer(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildAIHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.08), AppTheme.accent.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryAccentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Atuário de IA — Análise Completa',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
                Text(
                  'Motor v3 · 10 fatores · ${_routes!.length} rotas calculadas · Preço por km personalizado',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.green, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  // ── Card de Rota ────────────────────────────────────────────
  Widget _buildRouteCard(RouteActuarialResult route, int idx) {
    final selected = idx == _selectedIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? route.type.color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? route.type.color.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.05),
              blurRadius: selected ? 16 : 8,
              spreadRadius: selected ? 1 : 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Cabeçalho do card
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              decoration: BoxDecoration(
                color: selected ? route.type.color.withValues(alpha: 0.06) : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  // Ícone do tipo
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: route.type.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(route.type.icon, color: route.type.color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(route.type.label,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: selected ? route.type.color : AppTheme.text)),
                            const SizedBox(width: 6),
                            if (idx == 0) _chip('MAIS SEGURO', const Color(0xFF22C55E)),
                            if (idx == 1) _chip('MAIS RÁPIDO', const Color(0xFFF97316)),
                            if (idx == 2) _chip('RECOMENDADO', AppTheme.primary),
                          ],
                        ),
                        Text(route.type.subtitle,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  // Seletor
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: selected ? route.type.color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? route.type.color : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                        : null,
                  ),
                ],
              ),
            ),

            // ── Métricas principais
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  // Linha de stats
                  Row(
                    children: [
                      _metricItem(Icons.straighten_rounded, route.distanceFmt, 'Distância'),
                      _divider(),
                      _metricItem(Icons.schedule_rounded, route.timeFmt, 'Tempo'),
                      _divider(),
                      _metricItem(Icons.speed_rounded, route.kmPriceFmt, 'Preço/km', highlight: true),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Zona de risco
                  Row(
                    children: [
                      Expanded(child: _buildZoneBadge(route.dominantZone)),
                      const SizedBox(width: 8),
                      // Preço total
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: route.type.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: route.type.color.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(route.totalPriceFmt,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                                    color: route.type.color)),
                            const Text('seguro da viagem',
                                style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Economia (se aplicável)
                  if (route.savings > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6F0DF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.savings_rounded, size: 14, color: Color(0xFF1B6E35)),
                          const SizedBox(width: 6),
                          Text(
                            'Economia de ${route.savingsFmt} vs rota mais cara',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1B6E35)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Barra de risco visual
                  const SizedBox(height: 10),
                  _buildRiskBar(route),

                  // Highlights e warnings (expansível)
                  if (selected) ...[
                    const SizedBox(height: 10),
                    _buildDetailsExpanded(route),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
  );

  Widget _metricItem(IconData icon, String value, String label, {bool highlight = false}) => Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: highlight ? AppTheme.accent : AppTheme.textMuted),
            const SizedBox(width: 3),
            Flexible(child: Text(value, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: highlight ? AppTheme.accent : AppTheme.text,
            ), overflow: TextOverflow.ellipsis)),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
      ],
    ),
  );

  Widget _divider() => Container(width: 1, height: 28, color: Colors.grey.shade200);

  Widget _buildZoneBadge(RouteRiskZone zone) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: zone.bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(zone.icon, size: 14, color: zone.fgColor),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: zone.fgColor)),
                Text(zone.riskLabel, style: TextStyle(fontSize: 9, color: zone.fgColor.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildRiskBar(RouteActuarialResult route) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Nível de risco da rota', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            Text('${(route.riskScore * 100).toInt()}%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: route.dominantZone.fgColor)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: route.riskScore,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(route.dominantZone.fgColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsExpanded(RouteActuarialResult route) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16),
        // Fatores de precificação
        const Text('Composição do preço', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text)),
        const SizedBox(height: 8),
        _priceRow('Base por km', 'R\$ ${route.baseKmPrice.toStringAsFixed(3)}'),
        _priceRow('× Zona (${route.dominantZone.label})', '×${route.zoneMultiplier.toStringAsFixed(2)}'),
        _priceRow('× Horário', '×${route.timeMultiplier.toStringAsFixed(2)}'),
        if (route.telemetryBonus > 0)
          _priceRow('− Bônus telemetria', '−${(route.telemetryBonus * 100).toStringAsFixed(0)}%',
              color: AppTheme.green),
        const Divider(height: 12),
        _priceRow('= Preço final/km', route.kmPriceFmt, bold: true),
        const SizedBox(height: 10),
        // Highlights
        if (route.highlights.isNotEmpty) ...[
          const Text('Pontos positivos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text)),
          const SizedBox(height: 6),
          ...route.highlights.map((h) => _infoRow(Icons.check_circle_outline_rounded, h, AppTheme.green)),
        ],
        // Warnings
        if (route.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Atenção', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text)),
          const SizedBox(height: 6),
          ...route.warnings.map((w) => _infoRow(Icons.warning_amber_rounded, w, const Color(0xFF7A5000))),
        ],
        // Segmentos de risco
        if (route.riskSegments.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Segmentos da rota', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text)),
          const SizedBox(height: 6),
          ...route.riskSegments.take(4).map((s) => _segmentRow(s)),
          if (route.riskSegments.length > 4)
            Text('+ ${route.riskSegments.length - 4} segmentos',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ],
    );
  }

  Widget _priceRow(String label, String value, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        Text(value, style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: color ?? AppTheme.text,
        )),
      ],
    ),
  );

  Widget _infoRow(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
      ],
    ),
  );

  Widget _segmentRow(RouteRiskSegment s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: s.zone.fgColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(s.name, style: const TextStyle(fontSize: 10, color: AppTheme.text))),
        Text('${s.length.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: s.zone.bgColor, borderRadius: BorderRadius.circular(4)),
          child: Text(s.zone.label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: s.zone.fgColor)),
        ),
      ],
    ),
  );

  Widget _buildRiskLegend() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Legenda de Zonas de Risco', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: RouteRiskZone.values.map((z) => _legendItem(z)).toList(),
        ),
      ],
    ),
  );

  Widget _legendItem(RouteRiskZone z) => Column(
    children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: z.fgColor, shape: BoxShape.circle),
      ),
      const SizedBox(height: 3),
      Text(z.label.split(' ').last,
          style: TextStyle(fontSize: 9, color: z.fgColor, fontWeight: FontWeight.w600)),
    ],
  );

  Widget _buildDisclaimer() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.textMuted),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Preços calculados em tempo real pelo Motor Atuarial v3 considerando 10 fatores: veículo FIPE, zona de risco, horário, telemetria, histórico do condutor e mais.',
            style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
          ),
        ),
      ],
    ),
  );

  // ── Botão de confirmar ───────────────────────────────────────
  Widget _buildConfirmButton() {
    final selected = _routes![_selectedIndex];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected.type.label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
                  Text('${selected.distanceFmt} · ${selected.timeFmt}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
              Text(selected.totalPriceFmt,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: selected.type.color)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => widget.onSelectRoute(selected),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: const Text('Navegar com esta Rota',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: selected.type.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

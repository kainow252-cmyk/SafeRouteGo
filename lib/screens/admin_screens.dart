// ═══════════════════════════════════════════════════════════════
// SAFEROUTE — PAINEL ADMINISTRATIVO SUPER BOOT
// Acesso: login admin@saferoute.com / senha: admin2025
// ═══════════════════════════════════════════════════════════════

import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/risk_engine.dart';
import '../services/route_actuarial_service.dart';
import '../services/territorial_risk_intelligence.dart';
import '../services/insurance_search_engine.dart';
import '../services/atuario_ia_engine.dart';

// ─────────────────────────────────────────────────────────────
// TELA PRINCIPAL DO ADMIN (com tabs)
// ─────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback? onActuarial;
  final VoidCallback? onSafeMap;
  final VoidCallback? onAtuarioIA;
  const AdminDashboardScreen({super.key, required this.onLogout, this.onActuarial, this.onSafeMap, this.onAtuarioIA});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 10, vsync: this);
    _tab.addListener(() => setState(() => _tabIndex = _tab.index));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Column(
        children: [
          _AdminHeader(onLogout: widget.onLogout, onActuarial: widget.onActuarial, onSafeMap: widget.onSafeMap, onAtuarioIA: widget.onAtuarioIA),
          _AdminTabBar(controller: _tab),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(),
                _RiskEngineTab(),
                _TripsTab(),
                _UsersTab(),
                _PricingTab(),
                _SimulatorTab(),
                _IntelligenceTab(),
                _SeguradoraTab(),
                _AtuarioIATab(),
                _SubscritorIATab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER ADMIN
// ─────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback? onActuarial;
  final VoidCallback? onSafeMap;
  final VoidCallback? onAtuarioIA;
  const _AdminHeader({required this.onLogout, this.onActuarial, this.onSafeMap, this.onAtuarioIA});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1)),
      ),
      child: Row(
        children: [
          // Logo + badge
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryAccentGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SafeRouteGo Admin',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SUPER ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accent, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 6),
                    Text('Risk Engine ${RiskEngine.version}',
                        style: const TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.green)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onActuarial != null)
            GestureDetector(
              onTap: onActuarial,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_rounded, color: Color(0xFF8B5CF6), size: 14),
                    SizedBox(width: 4),
                    Text('IA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                        color: Color(0xFF8B5CF6))),
                  ],
                ),
              ),
            ),
          if (onAtuarioIA != null) ...[  
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onAtuarioIA,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calculate_rounded, color: Color(0xFFA78BFA), size: 14),
                    SizedBox(width: 4),
                    Text('v3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                        color: Color(0xFFA78BFA))),
                  ],
                ),
              ),
            ),
          ],
          if (onSafeMap != null) ...[  
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onSafeMap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C2A8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00C2A8).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: Color(0xFF00C2A8), size: 14),
                    SizedBox(width: 4),
                    Text('MAP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                        color: Color(0xFF00C2A8))),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLogout,
            child: const Icon(Icons.logout_rounded, color: Colors.white38, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB BAR
// ─────────────────────────────────────────────────────────────

class _AdminTabBar extends StatelessWidget {
  final TabController controller;
  const _AdminTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1628),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        indicatorColor: AppTheme.accent,
        indicatorWeight: 2,
        labelColor: AppTheme.accent,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: '  Visão Geral  '),
          Tab(text: '  Risk Engine  '),
          Tab(text: '  Viagens  '),
          Tab(text: '  Usuários  '),
          Tab(text: '  Preços & IA  '),
          Tab(text: '  Simulador  '),
          Tab(text: '  🛰 Inteligência  '),
          Tab(text: '  🏦 Seguradora  '),
          Tab(text: '  🤖 Atuário IA  '),
          Tab(text: '  🛡️ Subscritor IA  '),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — VISÃO GERAL — KPIs Profissionais + IA Atuarial
// ═══════════════════════════════════════════════════════════════

class _OverviewTab extends StatefulWidget {
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Timer? _timer;
  final _rnd = Random();

  // ── KPIs dinâmicos ─────────────────────────────────────
  int _viagensAtivas = 14;
  double _receitaHoje = 1847.30;
  double _ticketMedio = 8.34;
  int _scoreMedio = 782;
  int _usuariosAtivos = 1203;
  double _sinistralidade = 42.7;
  int _propostas = 38;
  int _recusadas = 3;
  double _premioMensal = 94800.0;
  double _reservaTecnica = 284400.0;

  // ── Premissas SADI ──────────────────────────────────────
  final double _da = AtuarioPremissas.da;
  final double _cc = AtuarioPremissas.cc;
  final double _ml = AtuarioPremissas.ml;
  final double _iof = AtuarioPremissas.iof;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _viagensAtivas = 12 + _rnd.nextInt(6);
        _receitaHoje += (_rnd.nextDouble() * 40 - 5).clamp(-20, 60);
        _ticketMedio = 7.80 + _rnd.nextDouble() * 1.20;
        _scoreMedio = 760 + _rnd.nextInt(60);
        _usuariosAtivos = 1200 + _rnd.nextInt(15);
        _sinistralidade = 40.0 + _rnd.nextDouble() * 8.0;
        _propostas = 35 + _rnd.nextInt(8);
        _recusadas = 2 + _rnd.nextInt(3);
        _premioMensal += (_rnd.nextDouble() * 200 - 50);
        _reservaTecnica = _premioMensal * 3.0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Barra de status LIVE ──────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF0D1B4B).withValues(alpha: 0.9),
                const Color(0xFF1A3A7C).withValues(alpha: 0.7),
              ]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: AppTheme.green.withValues(alpha: 0.6), blurRadius: 6)])),
              const SizedBox(width: 8),
              const Text('SISTEMA ATUARIAL DIGITAL INTEGRADO — SADI v3.0', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
              const Spacer(),
              Text('LIVE  ${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}', style: TextStyle(color: AppTheme.green, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 16),

          // ── KPIs Principais ───────────────────────────────
          _sectionTitle('KPIs Operacionais — Tempo Real', Icons.bar_chart_rounded),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.55,
            children: [
              _KpiCard(label: 'Viagens Ativas', value: '$_viagensAtivas', icon: Icons.directions_car_rounded, color: AppTheme.green, delta: '+${_rnd.nextInt(3)+1} última hora'),
              _KpiCard(label: 'Receita Hoje', value: 'R\$ ${_receitaHoje.toStringAsFixed(0)}', icon: Icons.attach_money_rounded, color: AppTheme.accent, delta: '+12% vs. ontem'),
              _KpiCard(label: 'Ticket Médio', value: 'R\$ ${_ticketMedio.toStringAsFixed(2)}', icon: Icons.receipt_long_rounded, color: AppTheme.primary, delta: 'Pay-per-km'),
              _KpiCard(label: 'Score SADI', value: '$_scoreMedio', icon: Icons.psychology_rounded, color: const Color(0xFFF59E0B), delta: 'Tier: Prata'),
              _KpiCard(label: 'Usuários', value: '${_usuariosAtivos.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}', icon: Icons.people_rounded, color: AppTheme.purple, delta: '+47 esta semana'),
              _KpiCard(label: 'Propostas', value: '$_propostas', icon: Icons.description_rounded, color: AppTheme.primary, delta: '$_recusadas recusadas'),
            ],
          ),

          const SizedBox(height: 16),

          // ── KPIs Financeiros Atuariais ─────────────────────
          _sectionTitle('Indicadores Financeiros Atuariais', Icons.account_balance_rounded),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: [
              _FinancialKpiCard(
                label: 'Prêmio Total/Mês',
                value: 'R\$ ${(_premioMensal/1000).toStringAsFixed(1)}k',
                subValue: 'Arrecadação efetiva',
                color: AppTheme.accent,
                icon: Icons.trending_up_rounded,
              ),
              _FinancialKpiCard(
                label: 'Reserva Técnica',
                value: 'R\$ ${(_reservaTecnica/1000).toStringAsFixed(1)}k',
                subValue: '3× prêmio mensal',
                color: AppTheme.green,
                icon: Icons.savings_rounded,
              ),
              _FinancialKpiCard(
                label: 'Sinistralidade',
                value: '${_sinistralidade.toStringAsFixed(1)}%',
                subValue: 'Meta: <65%',
                color: _sinistralidade < 65 ? AppTheme.green : const Color(0xFFF97316),
                icon: Icons.car_crash_rounded,
              ),
              _FinancialKpiCard(
                label: 'Combined Ratio',
                value: '${(_sinistralidade + (_da + _cc + _ml) * 100).toStringAsFixed(1)}%',
                subValue: 'Sin + Desp',
                color: const Color(0xFFF59E0B),
                icon: Icons.pie_chart_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Premissas SADI ─────────────────────────────────
          _sectionTitle('Premissas SADI — Carregamento Comercial', Icons.settings_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1628),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3A5F)),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: _PremissaItem('DA', '${(_da * 100).toStringAsFixed(0)}%', 'Despesas Adm.', const Color(0xFF60A5FA))),
                Expanded(child: _PremissaItem('CC', '${(_cc * 100).toStringAsFixed(0)}%', 'Corretagem', const Color(0xFFA78BFA))),
                Expanded(child: _PremissaItem('ML', '${(_ml * 100).toStringAsFixed(0)}%', 'Margem Lucro', AppTheme.green)),
                Expanded(child: _PremissaItem('IOF', '${(_iof * 100).toStringAsFixed(2)}%', 'Imposto', const Color(0xFFF59E0B))),
                Expanded(child: _PremissaItem('SEG', '${(AtuarioPremissas.seguranca * 100).toStringAsFixed(0)}%', 'Segurança', const Color(0xFFF97316))),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.functions_rounded, color: AppTheme.green, size: 14),
                  const SizedBox(width: 8),
                  Text('Prêmio Comercial = (Puro × 1.05) / ${(AtuarioPremissas.carregamento * 100).toStringAsFixed(0)}% × (1 + IOF)', style: TextStyle(color: AppTheme.green, fontSize: 11, fontFamily: 'monospace')),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Distribuição de Produtos ───────────────────────
          _sectionTitle('Portfólio — Distribuição por Ramo', Icons.donut_large_rounded),
          const SizedBox(height: 12),
          _PortfolioDistribuicao(),

          const SizedBox(height: 16),

          // ── Alertas do Motor Antifraude ────────────────────
          _sectionTitle('Alertas — Motor Antifraude IA', Icons.security_rounded),
          const SizedBox(height: 10),
          _AlertCard(color: const Color(0xFFEF4444), icon: Icons.gpp_bad_rounded, title: 'Fraude detectada — Proposta #FR-2847', detail: 'CPF com flag ativa em birô de mercado SUSEP. Recusa automática executada. 2 tentativas simultâneas detectadas.'),
          const SizedBox(height: 6),
          _AlertCard(color: const Color(0xFFF97316), icon: Icons.balance_rounded, title: 'Litigância predatória — CPF #442', detail: '6 processos sem fundamento detectados nos últimos 24 meses. Compliance bloqueou a proposta automaticamente.'),
          const SizedBox(height: 6),
          _AlertCard(color: const Color(0xFFF59E0B), icon: Icons.warning_amber_rounded, title: 'Agravamento aplicado — Proposta #AG-1193', detail: 'Sinistralidade 145% da média do ramo. Prêmio agravado em 25%. Renovação sujeita a revisão atuarial.'),
          const SizedBox(height: 6),
          _AlertCard(color: AppTheme.green, icon: Icons.shield_rounded, title: 'Sem sinistros nas últimas 24h', detail: 'Todas as $_viagensAtivas viagens ativas dentro do padrão esperado. Motor de risco estável.'),

          const SizedBox(height: 16),

          // ── Distribuição Horária ───────────────────────────
          _sectionTitle('Distribuição por Horário', Icons.access_time_rounded),
          const SizedBox(height: 12),
          _HourlyChart(),

          const SizedBox(height: 16),
          _sectionTitle('Condições Climáticas — Serra/Vitória/ES', Icons.cloud_rounded),
          const SizedBox(height: 12),
          _WeatherSummary(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── FINANCIAL KPI CARD ────────────────────────────────────────
class _FinancialKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;
  final Color color;
  final IconData icon;
  const _FinancialKpiCard({required this.label, required this.value, required this.subValue, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(subValue, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ])),
      ]),
    );
  }
}

// ─── PREMISSA ITEM ─────────────────────────────────────────────
class _PremissaItem extends StatelessWidget {
  final String sigla;
  final String valor;
  final String desc;
  final Color color;
  const _PremissaItem(this.sigla, this.valor, this.desc, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(sigla, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(valor, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
    ]);
  }
}

// ─── PORTFÓLIO DISTRIBUIÇÃO ────────────────────────────────────
class _PortfolioDistribuicao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final categorias = [
      {'nome': 'Auto / PHYD', 'valor': 42.0, 'color': AppTheme.accent},
      {'nome': 'Vida', 'valor': 28.0, 'color': AppTheme.green},
      {'nome': 'Cyber', 'valor': 12.0, 'color': const Color(0xFFA78BFA)},
      {'nome': 'Paramétrico', 'valor': 8.0, 'color': const Color(0xFFF59E0B)},
      {'nome': 'Residencial', 'valor': 6.0, 'color': const Color(0xFF60A5FA)},
      {'nome': 'Outros', 'valor': 4.0, 'color': Colors.white30},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(children: [
        ...categorias.map((c) {
          final pct = c['valor'] as double;
          final cor = c['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(c['nome'] as String, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const Spacer(),
                Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: const Color(0xFF1E3A5F),
                  valueColor: AlwaysStoppedAnimation(cor),
                  minHeight: 4,
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// TAB 2 — RISK ENGINE (configuração dos multiplicadores)
// ═══════════════════════════════════════════════════════════════

class _RiskEngineTab extends StatefulWidget {
  @override
  State<_RiskEngineTab> createState() => _RiskEngineTabState();
}

class _RiskEngineTabState extends State<_RiskEngineTab> {
  late double _tarifaBase;
  late double _taxaMinima;
  late double _franquiaKm;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final cfg = RiskEngineConfig.current;
    _tarifaBase = cfg.tarifaBasePorKm;
    _taxaMinima = cfg.taxaMinimaAtivacao;
    _franquiaKm = cfg.franquiaPorKmExtra;
  }

  void _save() {
    RiskEngineConfig.update(RiskEngineConfig.current.copyWith(
      tarifaBasePorKm: _tarifaBase,
      taxaMinimaAtivacao: _taxaMinima,
      franquiaPorKmExtra: _franquiaKm,
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Risk Engine
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.settings_rounded, color: AppTheme.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Risk Engine Config', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('Versão ${RiskEngine.version} · Fórmula ativa', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fórmula visual
          _FormulaCard(),
          const SizedBox(height: 16),

          // Tarifas base
          _sectionTitle('Tarifas Base', Icons.paid_rounded),
          const SizedBox(height: 10),
          _AdminSlider(
            label: 'Tarifa base por km',
            value: _tarifaBase,
            min: 0.05, max: 0.50, divisions: 45,
            format: (v) => 'R\$ ${v.toStringAsFixed(2)}',
            onChanged: (v) => setState(() => _tarifaBase = v),
          ),
          const SizedBox(height: 10),
          _AdminSlider(
            label: 'Taxa mínima de ativação',
            value: _taxaMinima,
            min: 0.99, max: 9.99, divisions: 90,
            format: (v) => 'R\$ ${v.toStringAsFixed(2)}',
            onChanged: (v) => setState(() => _taxaMinima = v),
          ),
          const SizedBox(height: 10),
          _AdminSlider(
            label: 'Redução de franquia por km',
            value: _franquiaKm,
            min: 0.01, max: 0.30, divisions: 29,
            format: (v) => 'R\$ ${v.toStringAsFixed(2)}/km',
            onChanged: (v) => setState(() => _franquiaKm = v),
          ),

          const SizedBox(height: 16),
          _sectionTitle('Fator 1 — Zona de Risco', Icons.location_on_rounded),
          const SizedBox(height: 10),
          ...RiskZone.values.map((z) => _MultiplierRow(
            label: 'Zona ${z.label}',
            value: z.multiplier,
            color: z.color,
            description: z.description,
          )),

          const SizedBox(height: 16),
          _sectionTitle('Fator 2 — Horário', Icons.schedule_rounded),
          const SizedBox(height: 10),
          _MultiplierRow(label: '06h–12h  Manhã',     value: 1.0, color: AppTheme.green,  description: 'Menor incidência de roubos'),
          _MultiplierRow(label: '12h–18h  Tarde',     value: 1.1, color: AppTheme.yellow, description: 'Leve aumento no trânsito'),
          _MultiplierRow(label: '18h–24h  Noite',     value: 1.5, color: const Color(0xFFF97316), description: 'Pico de roubos e furtos'),
          _MultiplierRow(label: '00h–06h  Madrugada', value: 1.3, color: AppTheme.purple, description: 'Via mais vazias, riscos específicos'),

          const SizedBox(height: 16),
          _sectionTitle('Fator 3 — Quilometragem', Icons.route_rounded),
          const SizedBox(height: 10),
          _MultiplierRow(label: '0–10 km',   value: 1.0, color: AppTheme.green,          description: 'Percurso urbano curto'),
          _MultiplierRow(label: '10–30 km',  value: 1.1, color: AppTheme.green,          description: 'Percurso médio'),
          _MultiplierRow(label: '30–100 km', value: 1.3, color: AppTheme.yellow,         description: 'Percurso longo — maior exposição'),
          _MultiplierRow(label: '100–300 km',value: 1.6, color: const Color(0xFFF97316), description: 'Viagem interestadual'),
          _MultiplierRow(label: '300+ km',   value: 2.0, color: AppTheme.red,            description: 'Viagem longa — risco alto'),

          const SizedBox(height: 16),
          _sectionTitle('Fator 4 — Clima', Icons.cloud_rounded),
          const SizedBox(height: 10),
          ...WeatherCondition.values.map((w) => _MultiplierRow(
            label: w.label,
            value: w.multiplier,
            color: w.color,
            description: 'Fator climático automático',
            icon: w.icon,
          )),

          const SizedBox(height: 16),
          _sectionTitle('Fator 5 — Perfil do Motorista', Icons.person_rounded),
          const SizedBox(height: 10),
          ...DriverScoreTier.values.map((d) => _MultiplierRow(
            label: '${d.label}  (score ${d.scoreRange})',
            value: d.multiplier,
            color: d.color,
            description: d.multiplier < 1.0 ? 'Bônus de fidelidade' : 'Risco proporcional ao score',
          )),

          const SizedBox(height: 16),
          _sectionTitle('Franquias por Plano', Icons.account_balance_rounded),
          const SizedBox(height: 10),
          _FranchiseTable(),

          const SizedBox(height: 20),
          // Botão salvar
          GestureDetector(
            onTap: _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _saved
                    ? const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)])
                    : AppTheme.primaryAccentGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: (_saved ? AppTheme.green : AppTheme.primary).withValues(alpha: 0.4),
                  blurRadius: 20, offset: const Offset(0, 6),
                )],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_saved ? Icons.check_circle_rounded : Icons.save_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(_saved ? 'Configurações Salvas!' : 'Salvar Configurações',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 3 — VIAGENS (lista em tempo real)
// ═══════════════════════════════════════════════════════════════

class _TripsTab extends StatelessWidget {
  final List<_TripData> _trips = const [
    _TripData(user: 'Gelci S.', origin: 'Serra/ES', dest: 'Vitória/ES', km: 25.0, price: 8.91, zone: RiskZone.amarela, weather: WeatherCondition.chuva, hour: 20, score: 750, status: 'ativa'),
    _TripData(user: 'Ana P.', origin: 'Cariacica/ES', dest: 'Vila Velha/ES', km: 18.0, price: 6.20, zone: RiskZone.laranja, weather: WeatherCondition.nublado, hour: 19, score: 820, status: 'ativa'),
    _TripData(user: 'Carlos M.', origin: 'Vitória/ES', dest: 'Serra/ES', km: 22.0, price: 4.80, zone: RiskZone.verde, weather: WeatherCondition.sol, hour: 9, score: 910, status: 'concluída'),
    _TripData(user: 'Beatriz R.', origin: 'Guarapari/ES', dest: 'Vitória/ES', km: 48.0, price: 15.60, zone: RiskZone.vermelha, weather: WeatherCondition.chuva, hour: 22, score: 650, status: 'concluída'),
    _TripData(user: 'Marcos L.', origin: 'Serra/ES', dest: 'Cariacica/ES', km: 14.0, price: 3.90, zone: RiskZone.amarela, weather: WeatherCondition.sol, hour: 8, score: 870, status: 'concluída'),
    _TripData(user: 'Fernanda O.', origin: 'Vila Velha/ES', dest: 'Serra/ES', km: 32.0, price: 11.40, zone: RiskZone.laranja, weather: WeatherCondition.temporal, hour: 21, score: 580, status: 'cancelada'),
  ];

  @override
  Widget build(BuildContext context) {
    final ativas = _trips.where((t) => t.status == 'ativa').toList();
    final outras = _trips.where((t) => t.status != 'ativa').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Viagens Ativas (${ativas.length})', Icons.play_circle_rounded, color: AppTheme.green),
          const SizedBox(height: 10),
          ...ativas.map((t) => _TripCard(trip: t)),

          const SizedBox(height: 16),
          _sectionTitle('Histórico de Hoje', Icons.history_rounded),
          const SizedBox(height: 10),
          ...outras.map((t) => _TripCard(trip: t)),
        ],
      ),
    );
  }
}

class _TripData {
  final String user, origin, dest, status;
  final double km, price;
  final RiskZone zone;
  final WeatherCondition weather;
  final int hour, score;
  const _TripData({
    required this.user, required this.origin, required this.dest,
    required this.km, required this.price, required this.zone,
    required this.weather, required this.hour, required this.score,
    required this.status,
  });
}

class _TripCard extends StatelessWidget {
  final _TripData trip;
  const _TripCard({required this.trip});

  Color get _statusColor {
    switch (trip.status) {
      case 'ativa':      return AppTheme.green;
      case 'concluída':  return AppTheme.primary;
      case 'cancelada':  return AppTheme.red;
      default:           return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = RiskEngine.calculate(RiskInput(
      distanceKm: trip.km,
      zone: trip.zone,
      departureTime: DateTime.now().copyWith(hour: trip.hour),
      weather: trip.weather,
      driverScore: trip.score,
      traffic: TrafficLevel.moderado,
      vehicleFipeValue: 75000,
      vehicleModel: '-',
      planType: 'smart',
      origin: trip.origin,
      destination: trip.dest,
    ));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.user, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('${trip.origin} → ${trip.dest}',
                        style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(trip.status.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TripStat('${trip.km.round()} km', Icons.route_rounded),
              _TripStat('${trip.hour}h', Icons.schedule_rounded),
              _TripStat('Score ${trip.score}', Icons.star_rounded),
              _TripStat(trip.zone.label, Icons.location_on_rounded, color: trip.zone.color),
              const Spacer(),
              Text(result.precoFormatado,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.accent)),
              const SizedBox(width: 4),
              Text(result.multiplicadorFormatado,
                  style: TextStyle(fontSize: 10, color: result.corRisco)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _TripStat(this.label, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color ?? Colors.white38),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color ?? Colors.white38)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 4 — USUÁRIOS
// ═══════════════════════════════════════════════════════════════

class _UsersTab extends StatelessWidget {
  final List<_UserData> _users = const [
    _UserData(name: 'Gelci Silva', email: 'gelci@email.com', score: 920, tier: DriverScoreTier.elite, trips: 47, spent: 312.40, vehicle: 'BYD Atto 2'),
    _UserData(name: 'Ana Paula', email: 'ana.p@email.com', score: 845, tier: DriverScoreTier.gold, trips: 28, spent: 198.70, vehicle: 'Honda Civic'),
    _UserData(name: 'Carlos Mendes', email: 'carlos.m@email.com', score: 720, tier: DriverScoreTier.silver, trips: 15, spent: 87.20, vehicle: 'VW Gol'),
    _UserData(name: 'Beatriz Rocha', email: 'beatriz.r@email.com', score: 640, tier: DriverScoreTier.bronze, trips: 8, spent: 64.80, vehicle: 'Hyundai HB20'),
    _UserData(name: 'Marcos Lima', email: 'marcos.l@email.com', score: 870, tier: DriverScoreTier.gold, trips: 33, spent: 245.60, vehicle: 'Toyota Corolla'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats resumo
          Row(
            children: [
              _AdminMiniStat('1.203', 'Total Usuários', Icons.people_rounded, AppTheme.primary),
              const SizedBox(width: 10),
              _AdminMiniStat('14', 'Ativos Agora', Icons.circle_rounded, AppTheme.green),
              const SizedBox(width: 10),
              _AdminMiniStat('782', 'Score Médio', Icons.star_rounded, AppTheme.yellow),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('Lista de Usuários', Icons.manage_accounts_rounded),
          const SizedBox(height: 10),
          ..._users.map((u) => _UserCard(user: u)),
        ],
      ),
    );
  }
}

class _UserData {
  final String name, email, vehicle;
  final int score, trips;
  final double spent;
  final DriverScoreTier tier;
  const _UserData({
    required this.name, required this.email, required this.score,
    required this.tier, required this.trips, required this.spent,
    required this.vehicle,
  });
}

class _UserCard extends StatelessWidget {
  final _UserData user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: user.tier.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(user.name[0], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: user.tier.color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.tier.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(user.tier.label.toUpperCase(),
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: user.tier.color)),
                    ),
                  ],
                ),
                Text(user.vehicle, style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 11, color: user.tier.color),
                  const SizedBox(width: 2),
                  Text('${user.score}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: user.tier.color)),
                ],
              ),
              Text('${user.trips} viagens', style: const TextStyle(fontSize: 10, color: Colors.white38)),
              Text('R\$ ${user.spent.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 5 — PREÇOS & IA — Gestão do Motor Atuarial de Rotas
// ═══════════════════════════════════════════════════════════════

class _PricingTab extends StatefulWidget {
  @override
  State<_PricingTab> createState() => _PricingTabState();
}

class _PricingTabState extends State<_PricingTab> {
  // Preços por km (editáveis via slider)
  double _seguraKm      = RouteActuarialConfig.kmPriceSegura;
  double _rapidaKm      = RouteActuarialConfig.kmPriceRapida;
  double _equilibradaKm = RouteActuarialConfig.kmPriceEquilibrada;

  // Multiplicadores de zona
  double _multVerde    = RouteActuarialConfig.zoneMultiplierVerde;
  double _multAmarela  = RouteActuarialConfig.zoneMultiplierAmarela;
  double _multLaranja  = RouteActuarialConfig.zoneMultiplierLaranja;
  double _multVermelha = RouteActuarialConfig.zoneMultiplierVermelha;

  // Multiplicadores de horário
  double _multComercial  = RouteActuarialConfig.timeMultiplierComercial;
  double _multNoite      = RouteActuarialConfig.timeMultiplierNoite;
  double _multMadrugada  = RouteActuarialConfig.timeMultiplierMadrugada;

  // Taxa mínima
  double _taxaMinima = RouteActuarialConfig.taxaMinimaViagem;

  bool _saved = false;

  void _saveConfig() {
    // Aplica na configuração global
    RouteActuarialConfig.kmPriceSegura       = _seguraKm;
    RouteActuarialConfig.kmPriceRapida       = _rapidaKm;
    RouteActuarialConfig.kmPriceEquilibrada  = _equilibradaKm;
    RouteActuarialConfig.zoneMultiplierVerde    = _multVerde;
    RouteActuarialConfig.zoneMultiplierAmarela  = _multAmarela;
    RouteActuarialConfig.zoneMultiplierLaranja  = _multLaranja;
    RouteActuarialConfig.zoneMultiplierVermelha = _multVermelha;
    RouteActuarialConfig.timeMultiplierComercial  = _multComercial;
    RouteActuarialConfig.timeMultiplierNoite      = _multNoite;
    RouteActuarialConfig.timeMultiplierMadrugada  = _multMadrugada;
    RouteActuarialConfig.taxaMinimaViagem = _taxaMinima;

    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com status
          _buildAIStatusHeader(),
          const SizedBox(height: 20),

          // ─── Preço base por km por tipo de rota ───────────────
          _sectionTitle('Preço Base por Km (R\$/km)', Icons.price_change_rounded),
          const SizedBox(height: 12),
          _buildKmPriceCard(
            label: 'Rota Segura',
            icon: Icons.security_rounded,
            color: const Color(0xFF22C55E),
            value: _seguraKm,
            min: 0.02, max: 0.30,
            onChanged: (v) => setState(() => _seguraKm = v),
            description: 'Bairros seguros, policiamento, câmeras',
          ),
          const SizedBox(height: 10),
          _buildKmPriceCard(
            label: 'Rota Rápida',
            icon: Icons.bolt_rounded,
            color: const Color(0xFFF97316),
            value: _rapidaKm,
            min: 0.02, max: 0.30,
            onChanged: (v) => setState(() => _rapidaKm = v),
            description: 'Avenidas principais, risco moderado',
          ),
          const SizedBox(height: 10),
          _buildKmPriceCard(
            label: 'Rota Equilibrada',
            icon: Icons.balance_rounded,
            color: const Color(0xFF3B82F6),
            value: _equilibradaKm,
            min: 0.02, max: 0.30,
            onChanged: (v) => setState(() => _equilibradaKm = v),
            description: 'Mix de vias, balanço risco × tempo',
          ),

          const SizedBox(height: 24),

          // ─── Multiplicadores de Zona ───────────────────────────
          _sectionTitle('Multiplicadores por Zona de Risco', Icons.map_rounded),
          const SizedBox(height: 12),
          _buildZoneMultCard('Zona Verde',    _multVerde,    0.8, 1.5, const Color(0xFF1B6E35), const Color(0xFFD6F0DF), (v) => setState(() => _multVerde = v)),
          const SizedBox(height: 8),
          _buildZoneMultCard('Zona Amarela',  _multAmarela,  1.0, 2.0, const Color(0xFF7A5000), const Color(0xFFFFF3C4), (v) => setState(() => _multAmarela = v)),
          const SizedBox(height: 8),
          _buildZoneMultCard('Zona Laranja',  _multLaranja,  1.2, 2.5, const Color(0xFF8B3000), const Color(0xFFFFE0C8), (v) => setState(() => _multLaranja = v)),
          const SizedBox(height: 8),
          _buildZoneMultCard('Zona Vermelha', _multVermelha, 1.5, 3.0, const Color(0xFF8B0000), const Color(0xFFFFD6D6), (v) => setState(() => _multVermelha = v)),

          const SizedBox(height: 24),

          // ─── Multiplicadores de Horário ────────────────────────
          _sectionTitle('Multiplicadores por Horário', Icons.schedule_rounded),
          const SizedBox(height: 12),
          _buildTimeMultCard('Comercial (06–19h)', _multComercial, 0.8, 1.5, Icons.wb_sunny_rounded, const Color(0xFF22C55E), (v) => setState(() => _multComercial = v)),
          const SizedBox(height: 8),
          _buildTimeMultCard('Noite (19–23h)',     _multNoite,     1.0, 2.0, Icons.nightlight_round, const Color(0xFFF59E0B), (v) => setState(() => _multNoite = v)),
          const SizedBox(height: 8),
          _buildTimeMultCard('Madrugada (23–06h)', _multMadrugada, 1.2, 3.0, Icons.nights_stay_rounded, const Color(0xFFEF4444), (v) => setState(() => _multMadrugada = v)),

          const SizedBox(height: 24),

          // ─── Taxa mínima ───────────────────────────────────────
          _sectionTitle('Taxa Mínima por Viagem', Icons.attach_money_rounded),
          const SizedBox(height: 12),
          _buildTaxaMinima(),

          const SizedBox(height: 24),

          // ─── Preview do impacto ────────────────────────────────
          _buildImpactPreview(),

          const SizedBox(height: 24),

          // Botão salvar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: _saved
                  ? const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)])
                  : AppTheme.primaryAccentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: (_saved ? const Color(0xFF22C55E) : AppTheme.primary).withValues(alpha: 0.4),
                blurRadius: 16, offset: const Offset(0, 4),
              )],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _saveConfig,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_saved ? Icons.check_circle_rounded : Icons.save_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _saved ? 'Configuração Aplicada!' : 'Salvar e Aplicar Configuração',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAIStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryAccentGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motor Atuarial de IA — Configuração',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(
                  'v3.0 · 10 fatores · Precificação por km em tempo real',
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: AppTheme.green),
                SizedBox(width: 4),
                Text('ATIVO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKmPriceCard({
    required String label,
    required IconData icon,
    required Color color,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String description,
  }) {
    final previewKm = value * 15; // preview para 15km
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(description, style: const TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('R\$ ${value.toStringAsFixed(4)}/km',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                  Text('~R\$ ${previewKm.toStringAsFixed(2)} p/15km',
                      style: const TextStyle(fontSize: 9, color: Colors.white38)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('R\$0,02', style: TextStyle(fontSize: 9, color: Colors.white24)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    inactiveTrackColor: color.withValues(alpha: 0.15),
                    thumbColor: color,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayColor: color.withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: value,
                    min: min, max: max,
                    onChanged: onChanged,
                  ),
                ),
              ),
              const Text('R\$0,30', style: TextStyle(fontSize: 9, color: Colors.white24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneMultCard(String label, double value, double min, double max, Color fg, Color bg, ValueChanged<double> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70))),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: fg,
                inactiveTrackColor: fg.withValues(alpha: 0.15),
                thumbColor: fg,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
              ),
              child: Slider(
                value: value, min: min, max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('×${value.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeMultCard(String label, double value, double min, double max, IconData icon, Color color, ValueChanged<double> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70))),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.15),
                thumbColor: color,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
              ),
              child: Slider(
                value: value, min: min, max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('×${value.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxaMinima() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Taxa mínima garantida por viagem',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              Text('R\$ ${_taxaMinima.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.accent.withValues(alpha: 0.15),
              thumbColor: AppTheme.accent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              value: _taxaMinima,
              min: 0.99, max: 9.99,
              onChanged: (v) => setState(() => _taxaMinima = v),
            ),
          ),
          const Text('Cobrado mesmo que o cálculo por km seja menor que este valor',
              style: TextStyle(fontSize: 9, color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildImpactPreview() {
    // Simula preço para 10km e 30km
    final seg10  = (_seguraKm      * _multVerde    * _multComercial * 10).clamp(_taxaMinima, 999.0);
    final seg30  = (_seguraKm      * _multVerde    * _multComercial * 30).clamp(_taxaMinima, 999.0);
    final rap10  = (_rapidaKm      * _multLaranja  * _multNoite     * 10).clamp(_taxaMinima, 999.0);
    final rap30  = (_rapidaKm      * _multLaranja  * _multNoite     * 30).clamp(_taxaMinima, 999.0);
    final eq10   = (_equilibradaKm * _multAmarela  * _multComercial * 10).clamp(_taxaMinima, 999.0);
    final eq30   = (_equilibradaKm * _multAmarela  * _multComercial * 30).clamp(_taxaMinima, 999.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PREVIEW DE IMPACTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accent, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          const Text('Preços simulados com as configurações atuais:', style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
            children: [
              _tableRow(['Rota', '10 km', '30 km'], isHeader: true),
              _tableRow(['Segura (Verde, Dia)', 'R\$ ${seg10.toStringAsFixed(2)}', 'R\$ ${seg30.toStringAsFixed(2)}'], color: const Color(0xFF22C55E)),
              _tableRow(['Rápida (Laranja, Noite)', 'R\$ ${rap10.toStringAsFixed(2)}', 'R\$ ${rap30.toStringAsFixed(2)}'], color: const Color(0xFFF97316)),
              _tableRow(['Equilibrada (Amarela, Dia)', 'R\$ ${eq10.toStringAsFixed(2)}', 'R\$ ${eq30.toStringAsFixed(2)}'], color: const Color(0xFF3B82F6)),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _tableRow(List<String> cells, {bool isHeader = false, Color? color}) {
    return TableRow(
      children: cells.map((c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(c, style: TextStyle(
          fontSize: isHeader ? 9 : 11,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
          color: isHeader ? Colors.white24 : (color ?? Colors.white70),
        )),
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 6 — SIMULADOR SUPER BOOT
// ═══════════════════════════════════════════════════════════════

class _SimulatorTab extends StatefulWidget {
  @override
  State<_SimulatorTab> createState() => _SimulatorTabState();
}

class _SimulatorTabState extends State<_SimulatorTab> {
  // Inputs
  double _km = 25;
  RiskZone _zone = RiskZone.amarela;
  int _hour = 20;
  WeatherCondition _weather = WeatherCondition.chuva;
  int _score = 750;
  TrafficLevel _traffic = TrafficLevel.moderado;
  double _fipe = 80000;
  String _plan = 'smart';

  RiskBreakdown? _result;
  List<RouteInsight> _insights = [];

  void _calculate() {
    final input = RiskInput(
      distanceKm: _km,
      zone: _zone,
      departureTime: DateTime.now().copyWith(hour: _hour),
      weather: _weather,
      driverScore: _score,
      traffic: _traffic,
      vehicleFipeValue: _fipe,
      vehicleModel: 'Veículo',
      planType: _plan,
      origin: 'Origem',
      destination: 'Destino',
    );
    setState(() {
      _result = RiskEngine.calculate(input);
      _insights = RiskEngine.generateInsights(input, _result!);
    });
  }

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header simulador
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_rounded, color: AppTheme.accent, size: 24),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Simulador de Precificação', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('Teste em tempo real todos os fatores de risco', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Inputs
          _sectionTitle('Parâmetros da Viagem', Icons.tune_rounded),
          const SizedBox(height: 10),

          _AdminSlider(
            label: 'Distância (km)',
            value: _km,
            min: 1, max: 300, divisions: 299,
            format: (v) => '${v.round()} km',
            onChanged: (v) { setState(() => _km = v); _calculate(); },
          ),
          const SizedBox(height: 8),
          _AdminSlider(
            label: 'Score do motorista',
            value: _score.toDouble(),
            min: 300, max: 1000, divisions: 70,
            format: (v) => '${v.round()} pts — ${DriverScoreTier.fromScore(v.round()).label}',
            onChanged: (v) { setState(() => _score = v.round()); _calculate(); },
          ),
          const SizedBox(height: 8),
          _AdminSlider(
            label: 'Horário de saída',
            value: _hour.toDouble(),
            min: 0, max: 23, divisions: 23,
            format: (v) => '${v.round().toString().padLeft(2, "0")}h — ${RiskEngine.labelHorario(v.round())}',
            onChanged: (v) { setState(() => _hour = v.round()); _calculate(); },
          ),
          const SizedBox(height: 8),
          _AdminSlider(
            label: 'Valor FIPE do veículo',
            value: _fipe,
            min: 20000, max: 500000, divisions: 96,
            format: (v) => 'R\$ ${(v / 1000).round()}k',
            onChanged: (v) { setState(() => _fipe = v); _calculate(); },
          ),

          const SizedBox(height: 12),

          // Zona de risco
          _sectionTitle('Zona de Risco', Icons.location_on_rounded),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: RiskZone.values.map((z) => _ChoiceChip(
              label: z.label,
              selected: _zone == z,
              color: z.color,
              onTap: () { setState(() => _zone = z); _calculate(); },
            )).toList(),
          ),

          const SizedBox(height: 12),
          _sectionTitle('Clima', Icons.cloud_rounded),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: WeatherCondition.values.map((w) => _ChoiceChip(
              label: w.label,
              selected: _weather == w,
              color: w.color,
              onTap: () { setState(() => _weather = w); _calculate(); },
            )).toList(),
          ),

          const SizedBox(height: 12),
          _sectionTitle('Trânsito', Icons.traffic_rounded),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: TrafficLevel.values.map((t) => _ChoiceChip(
              label: t.label,
              selected: _traffic == t,
              color: t.color,
              onTap: () { setState(() => _traffic = t); _calculate(); },
            )).toList(),
          ),

          const SizedBox(height: 12),
          _sectionTitle('Plano', Icons.workspace_premium_rounded),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _ChoiceChip(label: 'Básico',  selected: _plan == 'basico',  color: AppTheme.textMuted, onTap: () { setState(() => _plan = 'basico');  _calculate(); }),
              _ChoiceChip(label: 'Smart',   selected: _plan == 'smart',   color: AppTheme.primary,   onTap: () { setState(() => _plan = 'smart');   _calculate(); }),
              _ChoiceChip(label: 'Premium', selected: _plan == 'premium', color: AppTheme.accent,    onTap: () { setState(() => _plan = 'premium'); _calculate(); }),
            ],
          ),

          // Resultado
          if (_result != null) ...[
            const SizedBox(height: 20),
            _SimulationResult(result: _result!),
            const SizedBox(height: 16),
            _BreakdownSteps(result: _result!),
            if (_insights.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle('Insights de Risco', Icons.insights_rounded),
              const SizedBox(height: 8),
              ..._insights.map((i) => _InsightCard(insight: i)),
            ],
            const SizedBox(height: 16),
            _FranchiseCard(result: _result!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS COMPARTILHADOS DO ADMIN
// ═══════════════════════════════════════════════════════════════

// Resultado do simulador
class _SimulationResult extends StatelessWidget {
  final RiskBreakdown result;
  const _SimulationResult({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B4B), Color(0xFF0A6B6B)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PREÇO CALCULADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(result.precoFormatado, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(result.multiplicadorFormatado,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: result.corRisco)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: result.corRisco.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Risco ${result.nivelRisco}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: result.corRisco)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResultStat('Base', RiskEngine.formatBRL(result.baseKm), Icons.route_rounded),
              _ResultStat('Mínimo', RiskEngine.formatBRL(result.taxaMinima), Icons.lock_rounded),
              _ResultStat('Franquia', result.franquiaFormatada, Icons.account_balance_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ResultStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
      ],
    );
  }
}

// Breakdown step-by-step
class _BreakdownSteps extends StatelessWidget {
  final RiskBreakdown result;
  const _BreakdownSteps({required this.result});

  @override
  Widget build(BuildContext context) {
    final cfg = RiskEngineConfig.current;
    // Cálculo passo a passo
    final step1 = result.distanceKm * cfg.tarifaBasePorKm;
    final step2 = step1 * result.fatorRegiao;
    final step3 = step2 * result.fatorHorario;
    final step4 = step3 * result.fatorKm;
    final step5 = step4 * result.fatorClima;
    final step6 = step5 * result.fatorMotorista;
    final step7 = step6 * result.fatorTrafico;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BREAKDOWN PASSO A PASSO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _StepRow('${result.distanceKm.round()} km × R\$ ${cfg.tarifaBasePorKm.toStringAsFixed(2)}/km', step1, isFirst: true),
          _StepRow('× Zona ${result.zone.label} (${RiskEngine.formatMultiplier(result.fatorRegiao)})', step2, color: result.zone.color),
          _StepRow('× ${RiskEngine.labelHorario(result.departureHour)} (${RiskEngine.formatMultiplier(result.fatorHorario)})', step3, color: const Color(0xFF7C3AED)),
          _StepRow('× Fator KM (${RiskEngine.formatMultiplier(result.fatorKm)})', step4, color: AppTheme.primary),
          _StepRow('× ${result.weather.label} (${RiskEngine.formatMultiplier(result.fatorClima)})', step5, color: result.weather.color),
          _StepRow('× Score ${result.driverTier.label} (${RiskEngine.formatMultiplier(result.fatorMotorista)})', step6,
              color: result.fatorMotorista < 1.0 ? AppTheme.green : result.driverTier.color,
              isDiscount: result.fatorMotorista < 1.0),
          _StepRow('× Tráfego ${result.traffic.label} (${RiskEngine.formatMultiplier(result.fatorTrafico)})', step7, color: result.traffic.color),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFF1E3A5F)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('= PREÇO FINAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(result.precoFormatado,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  final bool isFirst, isDiscount;
  const _StepRow(this.label, this.value, {this.color, this.isFirst = false, this.isDiscount = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (!isFirst) Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(isDiscount ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
                size: 10, color: color ?? Colors.white24),
          ),
          if (isFirst) const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 11, color: color ?? Colors.white54)),
          ),
          Text(RiskEngine.formatBRL(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDiscount ? AppTheme.green : (color ?? Colors.white70),
              )),
        ],
      ),
    );
  }
}

// Insight card
class _InsightCard extends StatelessWidget {
  final RouteInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: insight.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: insight.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(insight.icon, color: insight.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: insight.color)),
                const SizedBox(height: 2),
                Text(insight.detail, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 10, color: Colors.white38),
                    const SizedBox(width: 4),
                    Expanded(child: Text(insight.suggestion, style: const TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Franquia card
class _FranchiseCard extends StatelessWidget {
  final RiskBreakdown result;
  const _FranchiseCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final reducaoTotal = result.distanceKm * result.franquiaReducao;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, color: AppTheme.accent, size: 16),
              const SizedBox(width: 8),
              const Text('FRANQUIA DINÂMICA',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accent, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          _FranqRow('Franquia do plano', result.franquiaBaseFormatada),
          _FranqRow('− Redução por ${result.distanceKm.round()} km × R\$ ${result.franquiaReducao.toStringAsFixed(2)}',
              '− R\$ ${reducaoTotal.toStringAsFixed(0)}', isDiscount: true),
          _FranqRow('Mínimo garantido', 'R\$ ${result.franquiaMinima.toStringAsFixed(0)}'),
          Container(height: 1, color: const Color(0xFF1E3A5F), margin: const EdgeInsets.symmetric(vertical: 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Franquia desta viagem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(result.franquiaFormatada,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FranqRow extends StatelessWidget {
  final String label, value;
  final bool isDiscount;
  const _FranqRow(this.label, this.value, {this.isDiscount = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDiscount ? AppTheme.green : Colors.white54)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDiscount ? AppTheme.green : Colors.white70)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS UTILITÁRIOS ADMIN
// ─────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value, delta;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 14),
              ),
              const Spacer(),
              Text(delta, style: const TextStyle(fontSize: 8, color: Colors.white24)),
            ],
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
        ],
      ),
    );
  }
}

class _AdminMiniStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _AdminMiniStat(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _AdminSlider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  const _AdminSlider({
    required this.label, required this.value, required this.min,
    required this.max, required this.divisions, required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(format(value),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: const Color(0xFF1E3A5F),
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value,
              min: min, max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiplierRow extends StatelessWidget {
  final String label, description;
  final double value;
  final Color color;
  final IconData? icon;
  const _MultiplierRow({required this.label, required this.value, required this.color, required this.description, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(description, style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(RiskEngine.formatMultiplier(value),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF0D1628),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFF1E3A5F),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? color : Colors.white38,
        )),
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FÓRMULA ATIVA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accent, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text(
            'Preço = (km × R\$/km) × fRegião × fHorário × fKM × fClima × fMotorista × fTráfego',
            style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.5, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _formulaPill('fRegião', '×1.0–3.0', AppTheme.red),
              _formulaPill('fHorário', '×1.0–1.5', const Color(0xFF7C3AED)),
              _formulaPill('fKM', '×1.0–2.0', AppTheme.primary),
              _formulaPill('fClima', '×1.0–2.5', const Color(0xFF0891B2)),
              _formulaPill('fMotorista', '×0.85–1.6', AppTheme.yellow),
              _formulaPill('fTráfego', '×1.0–1.2', AppTheme.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formulaPill(String label, String range, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            TextSpan(text: ' $range', style: const TextStyle(fontSize: 9, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _RiskZoneSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final zones = [
      ('Verde', 8, RiskZone.verde.color),
      ('Amarela', 14, RiskZone.amarela.color),
      ('Laranja', 6, RiskZone.laranja.color),
      ('Vermelha', 3, RiskZone.vermelha.color),
      ('Crítica', 1, RiskZone.critica.color),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        children: [
          ...zones.map((z) {
            final pct = z.$2 / 32;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: z.$3, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  SizedBox(width: 65, child: Text('Zona ${z.$1}', style: const TextStyle(fontSize: 11, color: Colors.white54))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: const Color(0xFF1E3A5F),
                        valueColor: AlwaysStoppedAnimation<Color>(z.$3),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${z.$2} ativos', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = [2, 1, 0, 0, 1, 3, 8, 12, 10, 7, 6, 8, 11, 9, 7, 8, 14, 18, 22, 20, 17, 14, 10, 6];
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (i) {
          final h = data[i] / maxVal;
          Color c;
          if (i >= 0 && i < 6)        c = const Color(0xFF7C3AED);
          else if (i >= 6 && i < 12)  c = AppTheme.green;
          else if (i >= 12 && i < 18) c = AppTheme.yellow;
          else                         c = const Color(0xFFF97316);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: h.clamp(0.05, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                  if (i % 6 == 0)
                    Text('${i}h', style: const TextStyle(fontSize: 7, color: Colors.white24))
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _WeatherSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: WeatherCondition.values.map((w) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: w == WeatherCondition.alagamento ? 0 : 6),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: w == WeatherCondition.chuva
                ? w.color.withValues(alpha: 0.2)
                : const Color(0xFF0D1628),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: w == WeatherCondition.chuva
                  ? w.color.withValues(alpha: 0.5)
                  : const Color(0xFF1E3A5F),
            ),
          ),
          child: Column(
            children: [
              Icon(w.icon, color: w == WeatherCondition.chuva ? w.color : Colors.white24, size: 18),
              const SizedBox(height: 4),
              Text(w.label, style: TextStyle(fontSize: 8, color: w == WeatherCondition.chuva ? w.color : Colors.white24)),
              Text(RiskEngine.formatMultiplier(w.multiplier),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: w == WeatherCondition.chuva ? w.color : Colors.white24)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, detail;
  const _AlertCard({required this.color, required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                Text(detail, style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FranchiseTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cfg = RiskEngineConfig.current;
    final faixas = [
      ('Até R\$ 50k', 'ate50k'),
      ('R\$ 50k–100k', '50k_100k'),
      ('R\$ 100k–250k', '100k_250k'),
      ('Acima R\$ 250k', 'acima250k'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(flex: 3, child: Text('Faixa FIPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38))),
              Expanded(flex: 2, child: Text('Básico', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Smart', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accent), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Premium', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38), textAlign: TextAlign.center)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF1E3A5F), height: 1),
          const SizedBox(height: 6),
          ...faixas.map((f) {
            final row = cfg.franquias[f.$2]!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(f.$1, style: const TextStyle(fontSize: 11, color: Colors.white70))),
                  Expanded(flex: 2, child: Text('R\$ ${row["basico"]!.round()}', style: const TextStyle(fontSize: 11, color: Colors.white38), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('R\$ ${row["smart"]!.round()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('R\$ ${row["premium"]!.round()}', style: const TextStyle(fontSize: 11, color: Colors.white38), textAlign: TextAlign.center)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Helper global
Widget _sectionTitle(String title, IconData icon, {Color color = AppTheme.accent}) {
  return Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.4)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// TELA DE LOGIN ADMIN
// ─────────────────────────────────────────────────────────────

class AdminLoginScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onBack;
  const AdminLoginScreen({super.key, required this.onSuccess, required this.onBack});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static const _adminEmail = 'admin@saferoute.com';
  static const _adminPass  = 'admin2025';

  void _login() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    if (_emailCtrl.text.trim() == _adminEmail && _passCtrl.text == _adminPass) {
      widget.onSuccess();
    } else {
      setState(() { _error = 'Credenciais inválidas. Tente novamente.'; _loading = false; });
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
      backgroundColor: const Color(0xFF0A0F1E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Back
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: widget.onBack,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, color: Colors.white38, size: 18),
                      SizedBox(width: 6),
                      Text('Voltar', style: TextStyle(fontSize: 13, color: Colors.white38)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Shield icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryAccentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              const Text('Painel Administrativo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Acesso restrito — SafeRouteGo Admin', style: TextStyle(fontSize: 13, color: Colors.white38)),
              const SizedBox(height: 40),
              // Email
              _AdminField(
                controller: _emailCtrl,
                label: 'Email administrativo',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              // Senha
              _AdminField(
                controller: _passCtrl,
                label: 'Senha',
                icon: Icons.lock_rounded,
                obscure: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 18, color: Colors.white38),
                ),
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
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 16),
                      const SizedBox(width: 8),
                      Text(_error!, style: const TextStyle(fontSize: 12, color: AppTheme.red)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _loading ? null : _login,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryAccentGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Entrar no Painel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 14),
                        SizedBox(width: 6),
                        Text('Credenciais de demonstração', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Email: admin@saferoute.com\nSenha: admin2025',
                        style: TextStyle(fontSize: 11, color: Colors.white38, fontFamily: 'monospace', height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  const _AdminField({
    required this.controller, required this.label, required this.icon,
    this.obscure = false, this.keyboardType, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      cursorColor: Colors.white70,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF0D1628),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 7 — INTELIGÊNCIA TERRITORIAL 🛰️
// Motor interno de análise: crime, acidentes, facções, vias
// ═══════════════════════════════════════════════════════════════

class _IntelligenceTab extends StatefulWidget {
  @override
  State<_IntelligenceTab> createState() => _IntelligenceTabState();
}

class _IntelligenceTabState extends State<_IntelligenceTab> {
  // ── Filtros ───────────────────────────────────────────────
  String _selectedUf = 'ES';
  final _latCtrl = TextEditingController(text: '-20.3155');
  final _lonCtrl = TextEditingController(text: '-40.3128');

  // ── Estado ────────────────────────────────────────────────
  bool _loading = false;
  bool _initialized = false;
  TerritorialRiskReport? _report;
  String? _error;

  // ── Painel ativo: 0=análise, 1=hotspots, 2=facções ───────
  int _panel = 0;

  static const List<String> _ufs = [
    'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA',
    'MG','MS','MT','PA','PB','PE','PI','PR','RJ','RN',
    'RO','RR','RS','SC','SE','SP','TO',
  ];

  @override
  void dispose() {
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  // ─── Inicializa o motor (singleton) ──────────────────────
  Future<void> _initEngine() async {
    setState(() { _loading = true; _error = null; });
    try {
      await TerritorialRiskIntelligence.instance.init();
      setState(() { _initialized = true; });
    } catch (e) {
      setState(() { _error = 'Erro ao inicializar motor: $e'; });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ─── Análise por coordenadas ──────────────────────────────
  Future<void> _analyze() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lon = double.tryParse(_lonCtrl.text.trim());
    if (lat == null || lon == null) {
      setState(() => _error = 'Lat/Lon inválidos');
      return;
    }
    setState(() { _loading = true; _error = null; _report = null; });
    try {
      if (!_initialized) await TerritorialRiskIntelligence.instance.init();
      final r = await TerritorialRiskIntelligence.instance.analyzeLocation(
        lat: lat, lon: lon, uf: _selectedUf,
      );
      setState(() { _report = r; _panel = 0; });
    } catch (e) {
      setState(() => _error = 'Falha na análise: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ─── Score rápido por UF ──────────────────────────────────
  int get _ufScore => TerritorialRiskIntelligence.instance.quickScoreByUf(_selectedUf);
  double get _ufFactor => TerritorialRiskIntelligence.instance.quickActuarialFactorByUf(_selectedUf);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ───────────────────────────────────
          _triHeader(),
          const SizedBox(height: 16),

          // ── Painel de busca ─────────────────────────────
          _searchPanel(),
          const SizedBox(height: 16),

          // ── Score rápido por UF ─────────────────────────
          _ufQuickScore(),
          const SizedBox(height: 16),

          // ── Resultado da análise ─────────────────────────
          if (_loading)
            _buildLoading()
          else if (_error != null)
            _buildError()
          else if (_report != null)
            _buildReport(_report!),

          // ── Separador ────────────────────────────────────
          const SizedBox(height: 16),
          _panelSelector(),
          const SizedBox(height: 12),

          // ── Painel de hotspots e facções ─────────────────
          if (_panel == 1) _buildHotspots(),
          if (_panel == 2) _buildFactions(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // WIDGETS INTERNOS
  // ══════════════════════════════════════════════════════════

  Widget _triHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A3B), Color(0xFF2D1B69)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.satellite_alt_rounded, color: Color(0xFFA78BFA), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motor de Inteligência Territorial',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 3),
                Text('Crime • Acidentes • Facções • Vias de Risco',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
            ),
            child: const Text('INTERNO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                color: Color(0xFF34D399), letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _searchPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF6D28D9), size: 16),
              const SizedBox(width: 6),
              const Text('Análise por Localização', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          // UF selector
          Row(
            children: [
              const Text('UF:', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E3A5F)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUf,
                      dropdownColor: const Color(0xFF0D1628),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (v) => setState(() => _selectedUf = v!),
                      items: _ufs.map((uf) => DropdownMenuItem(
                        value: uf,
                        child: Text(uf),
                      )).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Lat/Lon row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  cursorColor: const Color(0xFFA78BFA),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF0A0F1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lonCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  cursorColor: const Color(0xFFA78BFA),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF0A0F1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Botão analisar
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.radar_rounded, size: 18),
              label: Text(_loading ? 'Analisando...' : 'Analisar Localização'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ufQuickScore() {
    final score = _ufScore;
    final factor = _ufFactor;
    final level = ThreatLevel.fromScore(score);
    final color = _levelColor(level);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score Rápido — $_selectedUf',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _triMiniCard(
                  label: 'Score Territorial',
                  value: score.toString(),
                  sub: level.emoji + ' ' + level.label,
                  color: color,
                  icon: Icons.shield_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _triMiniCard(
                  label: 'Fator Atuarial',
                  value: '×${factor.toStringAsFixed(2)}',
                  sub: 'Multiplicador de prêmio',
                  color: factor > 2.0 ? Colors.red : factor > 1.5 ? Colors.orange : Colors.green,
                  icon: Icons.calculate_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 1000,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 — Seguro', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.35))),
              Text('1000 — Extremo', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.35))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFF6D28D9), strokeWidth: 2),
          const SizedBox(height: 16),
          Text('Consultando fontes de inteligência...',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('IPEA • SINESP • PRF • Overpass • IBGE',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildReport(TerritorialRiskReport r) {
    final color = _levelColor(r.nivel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Score geral ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.nivel.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r.nivel.label} — Score ${r.scoreCompostoFinal}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                        Text(r.municipio.isNotEmpty ? '${r.bairro} · ${r.municipio}/${r.uf}' : r.uf,
                            style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Fator Atuarial', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4))),
                      Text('×${r.fatorAtuarial.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                              color: r.fatorAtuarial > 2 ? Colors.red : Colors.orange)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Score breakdown
              Row(
                children: [
                  _scorePill('Crime', r.scoreCrime, Colors.red),
                  const SizedBox(width: 6),
                  _scorePill('Acidente', r.scoreAcidente, Colors.orange),
                  const SizedBox(width: 6),
                  _scorePill('Facção', r.scoreFaccao, const Color(0xFF6D28D9)),
                  const SizedBox(width: 6),
                  _scorePill('Via', r.scoreVia, Colors.blue),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Cards de crime ───────────────────────────────────
        _sectionTitle2('Dados Criminais'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _crimeCard('Homicídios', r.homicidiosPor100k.toDouble(), '/100k hab', Colors.red, Icons.warning_rounded),
            _crimeCard('Roubo Veíc.', r.rouboVeiculoPor100k.toDouble(), '/100k hab', Colors.orange, Icons.directions_car_rounded),
            _crimeCard('Roubo Pess.', r.rouboTranseuntePor100k.toDouble(), '/100k hab', Colors.amber, Icons.person_rounded),
            _crimeCard('Tráfico', r.traficoPor100k.toDouble(), '/100k hab', const Color(0xFF6D28D9), Icons.dangerous_rounded),
          ],
        ),
        const SizedBox(height: 12),

        // ── Acidentes ────────────────────────────────────────
        _sectionTitle2('Acidentes no Raio 5km'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(child: _statItem(r.totalAcidentesRaio5km.toString(), 'Acidentes', Colors.orange)),
              _vertDivider(),
              Expanded(child: _statItem(r.mortosRaio5km.toString(), 'Mortos', Colors.red)),
              _vertDivider(),
              Expanded(child: _statItem(r.pontosNegros.length.toString(), 'Pontos Negros', Colors.amber)),
            ],
          ),
        ),

        // Pontos negros listados
        if (r.pontosNegros.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...r.pontosNegros.take(3).map((pn) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wrong_location_rounded, color: Colors.orange, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${pn.rodovia} KM ${pn.km.toStringAsFixed(0)} — ${pn.mortos} mortos (${pn.causaPrincipal})',
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ),
              ],
            ),
          )),
        ],

        // ── Facções ──────────────────────────────────────────
        const SizedBox(height: 12),
        _sectionTitle2('Presença de Facção'),
        const SizedBox(height: 8),
        _factionBadge(r.faccao),
        const SizedBox(height: 12),

        // ── Alertas ──────────────────────────────────────────
        if (r.alertas.isNotEmpty) ...[
          _sectionTitle2('Alertas do Território'),
          const SizedBox(height: 8),
          ...r.alertas.map((a) => _alertRow(a)),
          const SizedBox(height: 12),
        ],

        // ── Recomendações ────────────────────────────────────
        if (r.recomendacoes.isNotEmpty) ...[
          _sectionTitle2('Recomendações'),
          const SizedBox(height: 8),
          ...r.recomendacoes.map((rec) => _recRow(rec)),
          const SizedBox(height: 12),
        ],

        // ── Fontes ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: r.fontesDados.split(' + ').map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(f.trim(), style: const TextStyle(fontSize: 9, color: Colors.white38, fontFamily: 'monospace')),
            )).toList(),
          ),
        ),
        Text('Dados ${r.dadosReaisDisponiveis ? "REAIS" : "estimados"} · Gerado ${_fmtDate(r.geradoEm)}',
            style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _panelSelector() {
    return Row(
      children: [
        Expanded(child: _panelBtn(0, 'Análise', Icons.analytics_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _panelBtn(1, 'Hotspots PRF', Icons.car_crash_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _panelBtn(2, 'Facções', Icons.dangerous_rounded)),
      ],
    );
  }

  Widget _panelBtn(int idx, String label, IconData icon) {
    final active = _panel == idx;
    return GestureDetector(
      onTap: () => setState(() => _panel = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6D28D9).withValues(alpha: 0.25) : const Color(0xFF0D1628),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF6D28D9) : const Color(0xFF1E3A5F),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: active ? const Color(0xFFA78BFA) : Colors.white38),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: active ? const Color(0xFFA78BFA) : Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _buildHotspots() {
    final hotspots = TerritorialRiskIntelligence.instance.getTopAccidentHotspots(limit: 15);
    if (hotspots.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Motor não inicializado. Execute uma análise primeiro.',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle2('Top Pontos Negros — PRF Dados Abertos'),
        const SizedBox(height: 10),
        ...hotspots.asMap().entries.map((entry) {
          final i = entry.key;
          final h = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1628),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _severityColor(h.severidade).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _severityColor(h.severidade).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${i + 1}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: _severityColor(h.severidade))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${h.rodovia} KM ${h.km.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('${h.mortos} mortos · ${h.totalAcidentes} acidentes · ${h.causaPrincipal}',
                          style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      Text(h.periodo, style: const TextStyle(fontSize: 9, color: Colors.white38)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _severityColor(h.severidade).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_severityLabel(h.severidade),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: _severityColor(h.severidade))),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFactions() {
    final zones = TerritorialRiskIntelligence.instance.getFactionsByUf(_selectedUf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle2('Zonas de Domínio — $_selectedUf'),
        const SizedBox(height: 4),
        Text('${zones.length} zona(s) mapeada(s) · Fontes abertas / geo-correlação',
            style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 10),
        if (zones.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1628),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E3A5F)),
            ),
            child: const Center(
              child: Text('Nenhuma zona mapeada para esta UF\n(dados disponíveis: RJ · SP · BA · CE · PE · AM · MS · RN · ES)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          )
        else
          ...zones.map((z) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1628),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _presenceColor(z.presenca).withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _presenceColor(z.presenca).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(z.nome, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: _presenceColor(z.presenca))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(z.municipio, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ),
                    Text(z.presenca.label, style: TextStyle(
                        fontSize: 9, color: _presenceColor(z.presenca))),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: z.bairros.map((b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(b, style: const TextStyle(fontSize: 9, color: Colors.white54)),
                  )).toList(),
                ),
                if (z.atividadesConhecidas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Atividades: ${z.atividadesConhecidas.join(', ')}',
                      style: const TextStyle(fontSize: 9, color: Colors.white38)),
                ],
              ],
            ),
          )),
      ],
    );
  }

  // ── Helpers visuais ────────────────────────────────────────

  Widget _triMiniCard({required String label, required String value, required String sub,
      required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(sub, style: const TextStyle(fontSize: 9, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _scorePill(String label, int score, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(score.toString(), style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _crimeCard(String label, double value, String unit, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55))),
                Text(value.toStringAsFixed(1),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                Text(unit, style: const TextStyle(fontSize: 8, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factionBadge(FactionPresence presence) {
    final color = _presenceColor(presence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_fixed_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Text(presence.label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Text('×${presence.riskMultiplier.toStringAsFixed(2)} risco',
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _alertRow(String alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(alert, style: const TextStyle(fontSize: 11, color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _recRow(String rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(rec, style: const TextStyle(fontSize: 11, color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _sectionTitle2(String title) {
    return Text(title, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.3));
  }

  Widget _statItem(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
      ],
    );
  }

  Widget _vertDivider() {
    return Container(width: 1, height: 36, color: Colors.white12);
  }

  Color _levelColor(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.seguro:   return Colors.green;
      case ThreatLevel.baixo:    return const Color(0xFF84CC16);
      case ThreatLevel.moderado: return Colors.orange;
      case ThreatLevel.alto:     return Colors.deepOrange;
      case ThreatLevel.critico:  return Colors.red;
      case ThreatLevel.extremo:  return const Color(0xFF7F1D1D);
    }
  }

  Color _severityColor(AccidentSeverity s) {
    switch (s) {
      case AccidentSeverity.leve:     return Colors.green;
      case AccidentSeverity.moderado: return Colors.orange;
      case AccidentSeverity.grave:    return Colors.deepOrange;
      case AccidentSeverity.fatal:    return Colors.red;
    }
  }

  String _severityLabel(AccidentSeverity s) {
    switch (s) {
      case AccidentSeverity.leve:     return 'LEVE';
      case AccidentSeverity.moderado: return 'MODERADO';
      case AccidentSeverity.grave:    return 'GRAVE';
      case AccidentSeverity.fatal:    return 'FATAL';
    }
  }

  Color _presenceColor(FactionPresence p) {
    switch (p) {
      case FactionPresence.nenhuma:    return Colors.green;
      case FactionPresence.suspeita:   return Colors.amber;
      case FactionPresence.confirmada: return Colors.orange;
      case FactionPresence.dominada:   return Colors.red;
    }
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 8 — SEGURADORA INTERNA 🏦
// Motor completo: Catálogo · Cotações · Apólices · Sinistros · Analytics
// ═══════════════════════════════════════════════════════════════

class _SeguradoraTab extends StatefulWidget {
  @override
  State<_SeguradoraTab> createState() => _SeguradoraTabState();
}

class _SeguradoraTabState extends State<_SeguradoraTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTab;
  bool _loading = false;
  bool _initialized = false;

  // ── Cotador rápido ──────────────────────────────────────────
  final _ufCtrl = TextEditingController(text: 'ES');
  final _idadeCtrl = TextEditingController(text: '32');
  final _ubiCtrl = TextEditingController(text: '820');
  final _fipeCtrl = TextEditingController(text: '45000');
  String _usoVeiculo = 'particular';
  String _selectedUf = 'ES';
  bool _temPet = false;
  bool _temFilhos = false;
  bool _proprietario = false;

  List<InsuranceQuote> _quotes = [];

  static const List<String> _ufs = [
    'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA',
    'MG','MS','MT','PA','PB','PE','PI','PR','RJ','RN',
    'RO','RR','RS','SC','SE','SP','TO',
  ];

  @override
  void initState() {
    super.initState();
    _subTab = TabController(length: 5, vsync: this);
    _initEngine();
  }

  @override
  void dispose() {
    _subTab.dispose();
    _ufCtrl.dispose();
    _idadeCtrl.dispose();
    _ubiCtrl.dispose();
    _fipeCtrl.dispose();
    super.dispose();
  }

  Future<void> _initEngine() async {
    setState(() => _loading = true);
    try {
      await InsuranceSearchEngine.instance.init();
      setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runSearch() async {
    setState(() { _loading = true; _quotes = []; });
    try {
      final quotes = await InsuranceSearchEngine.instance.searchAndQuote(
        userId: 'ADMIN-PREVIEW',
        uf: _selectedUf,
        age: int.tryParse(_idadeCtrl.text) ?? 32,
        ubiScore: double.tryParse(_ubiCtrl.text) ?? 800,
        fipeValue: double.tryParse(_fipeCtrl.text) ?? 45000,
        vehicleUse: _usoVeiculo,
        temPet: _temPet,
        temFilhos: _temFilhos,
        proprietarioImovel: _proprietario,
      );
      setState(() { _quotes = quotes; _subTab.animateTo(1); });
    } catch (e) {
      setState(() {});
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_initialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A56DB), strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Inicializando motor de seguros...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Sub-tab bar ────────────────────────────────────────
        Container(
          color: const Color(0xFF07101F),
          child: TabBar(
            controller: _subTab,
            isScrollable: true,
            indicatorColor: const Color(0xFF1A56DB),
            indicatorWeight: 2,
            labelColor: const Color(0xFF60A5FA),
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: '  Catálogo  '),
              Tab(text: '  Motor Cotação  '),
              Tab(text: '  Apólices  '),
              Tab(text: '  Sinistros  '),
              Tab(text: '  Analytics  '),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTab,
            children: [
              _buildCatalogo(),
              _buildCotador(),
              _buildApolices(),
              _buildSinistros(),
              _buildAnalytics(),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SUB-TAB 1 — CATÁLOGO DE PRODUTOS
  // ══════════════════════════════════════════════════════════════
  Widget _buildCatalogo() {
    final categories = ProductCatalog.categories;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segHeader(
            'Catálogo de Produtos',
            '${ProductCatalog.all.length} produtos ativos em ${categories.length} categorias',
            Icons.inventory_2_rounded,
            const Color(0xFF1A56DB),
          ),
          const SizedBox(height: 14),

          // Stats rápidas
          Row(
            children: [
              Expanded(child: _miniStatCard('Total Produtos', '${ProductCatalog.all.length}', Icons.widgets_rounded, const Color(0xFF1A56DB))),
              const SizedBox(width: 8),
              Expanded(child: _miniStatCard('Paramétricos', '${ProductCatalog.parametricOnly.length}', Icons.bolt_rounded, const Color(0xFF6D28D9))),
              const SizedBox(width: 8),
              Expanded(child: _miniStatCard('SR Exclusivos', '${ProductCatalog.saferoureExclusive.length}', Icons.star_rounded, Colors.amber)),
            ],
          ),
          const SizedBox(height: 16),

          // Produtos por categoria
          ...categories.map((cat) {
            final products = ProductCatalog.byCategory(cat);
            final catColor = _catColor(cat);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header da categoria
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: catColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(_catIcon(cat), color: catColor, size: 15),
                      const SizedBox(width: 6),
                      Text(cat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: catColor)),
                      const Spacer(),
                      Text('${products.length} produto${products.length > 1 ? "s" : ""}',
                          style: TextStyle(fontSize: 10, color: catColor.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                // Lista de produtos
                ...products.map((p) => _productCard(p)),
                const SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _productCard(InsuranceProduct p) {
    final isExcl = p.line.isExclusiveSafeRoute;
    final isParam = p.isParametric;
    final color = isExcl ? Colors.amber : isParam ? const Color(0xFF6D28D9) : const Color(0xFF1A56DB);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: isExcl ? 0.5 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isExcl) const Text('⭐ ', style: TextStyle(fontSize: 12)),
                    if (isParam && !isExcl) const Text('⚡ ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(p.nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              // Badges
              if (isExcl) _badge('EXCLUSIVO', Colors.amber),
              if (isParam && !isExcl) ...[const SizedBox(width: 4), _badge('PARAM.', const Color(0xFF6D28D9))],
            ],
          ),
          const SizedBox(height: 4),
          Text(p.descricao, style: const TextStyle(fontSize: 10, color: Colors.white54), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              if (p.premioMinimoMensal > 0) ...[
                Icon(Icons.attach_money_rounded, color: Colors.green, size: 12),
                Text(
                  p.premioMinimoMensal == p.premioMaximoMensal
                      ? 'R\$ ${p.premioMinimoMensal.toStringAsFixed(2)}/mês'
                      : 'R\$ ${p.premioMinimoMensal.toStringAsFixed(0)} – ${p.premioMaximoMensal.toStringAsFixed(0)}/mês',
                  style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ] else ...[
                const Icon(Icons.bolt_rounded, color: Color(0xFF6D28D9), size: 12),
                const Text('Por uso / hora', style: TextStyle(fontSize: 10, color: Color(0xFF6D28D9), fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              if (p.triggerDescricao != null)
                Flexible(
                  child: Text('Trigger: ${p.triggerDescricao}',
                      style: const TextStyle(fontSize: 9, color: Colors.white38),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Coberturas chips
          Wrap(
            spacing: 4,
            runSpacing: 3,
            children: p.coberturas.take(4).map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text(c, style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.85))),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SUB-TAB 2 — MOTOR DE COTAÇÃO (NeedsDetector + QuoteEngine)
  // ══════════════════════════════════════════════════════════════
  Widget _buildCotador() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segHeader(
            'Motor de Cotação — NeedsDetector + QuoteEngine',
            'Simule o perfil de um cliente e veja as cotações rankeadas por IA',
            Icons.calculate_rounded,
            const Color(0xFF059669),
          ),
          const SizedBox(height: 14),

          // ── Formulário de perfil ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1628),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3A5F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Perfil do Cliente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),
                // UF + Idade
                Row(
                  children: [
                    Expanded(child: _cotadorDropdown('UF', _selectedUf, _ufs, (v) => setState(() => _selectedUf = v!))),
                    const SizedBox(width: 8),
                    Expanded(child: _cotadorField(_idadeCtrl, 'Idade', Icons.person_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                // UBI + FIPE
                Row(
                  children: [
                    Expanded(child: _cotadorField(_ubiCtrl, 'Score UBI (0-1000)', Icons.speed_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _cotadorField(_fipeCtrl, 'FIPE Veículo (R\$)', Icons.directions_car_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                // Uso veículo
                _cotadorDropdown(
                  'Uso do Veículo',
                  _usoVeiculo,
                  ['particular', 'aplicativo', 'motoboy', 'caminhao', 'comercial'],
                  (v) => setState(() => _usoVeiculo = v!),
                ),
                const SizedBox(height: 10),
                // Checkboxes
                Row(
                  children: [
                    _checkBox('Tem Pet', _temPet, (v) => setState(() => _temPet = v!)),
                    const SizedBox(width: 12),
                    _checkBox('Tem Filhos', _temFilhos, (v) => setState(() => _temFilhos = v!)),
                    const SizedBox(width: 12),
                    _checkBox('Proprietário', _proprietario, (v) => setState(() => _proprietario = v!)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _runSearch,
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.radar_rounded, size: 18),
                    label: Text(_loading ? 'Analisando...' : 'Detectar Necessidades + Cotar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Resultados ────────────────────────────────────────
          if (_quotes.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF059669), size: 14),
                const SizedBox(width: 6),
                Text('${_quotes.length} produtos detectados e cotados — rankeados por relevância',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 10),
            ..._quotes.asMap().entries.map((e) => _quoteCard(e.key + 1, e.value)),
          ] else if (!_loading) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1628),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3A5F)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.white24, size: 36),
                    const SizedBox(height: 8),
                    Text('Configure o perfil e clique em "Detectar Necessidades"',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quoteCard(int rank, InsuranceQuote q) {
    final isExcl = q.line.isExclusiveSafeRoute;
    final isParam = q.product.isParametric;
    final color = isExcl ? Colors.amber : isParam ? const Color(0xFF6D28D9) : const Color(0xFF1A56DB);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: rank == 1 ? 0.6 : 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: rank <= 3 ? color.withValues(alpha: 0.2) : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('#$rank', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: rank <= 3 ? color : Colors.white38)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.product.nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(q.line.category, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              // Prêmio
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(q.product.premioMinimoMensal > 0
                      ? 'R\$ ${q.premioMensal.toStringAsFixed(2)}/mês'
                      : 'Por uso',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                  if (q.product.premioMinimoMensal > 0)
                    Text('R\$ ${q.premioAnual.toStringAsFixed(0)}/ano',
                        style: const TextStyle(fontSize: 9, color: Colors.white38)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Score relevância
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: q.scoreRelevancia / 100,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${q.scoreRelevancia}% relevante',
                  style: TextStyle(fontSize: 9, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          // Fatores atuariais
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _fatorChip('UBI', q.fatorUbi),
              _fatorChip('Territorial', q.fatorTerritorial),
              _fatorChip('Idade', q.fatorIdade),
              _fatorChip('Risco Total', q.fatorRisco),
            ],
          ),
          const SizedBox(height: 8),
          // Motivos da recomendação
          if (q.motivosRecomendacao.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: q.motivosRecomendacao.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 11, color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(m, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)))),
                  ],
                ),
              )).toList(),
            ),
          const SizedBox(height: 8),
          // Botão emitir apólice (demo)
          SizedBox(
            width: double.infinity,
            height: 32,
            child: OutlinedButton.icon(
              onPressed: () => _emitirApolice(q),
              icon: const Icon(Icons.verified_rounded, size: 14),
              label: const Text('Emitir Apólice Demo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _emitirApolice(InsuranceQuote q) {
    final pol = PolicyManager.emitir(
      userId: 'ADMIN-DEMO',
      nomeUsuario: 'Cliente Demo',
      quote: q,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Apólice ${pol.numeroApolice} emitida! (${pol.line.label})'),
      backgroundColor: const Color(0xFF059669),
      duration: const Duration(seconds: 3),
    ));
  }

  // ══════════════════════════════════════════════════════════════
  // SUB-TAB 3 — APÓLICES
  // ══════════════════════════════════════════════════════════════
  Widget _buildApolices() {
    final policies = PolicyManager.policies;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segHeader(
            'Apólices Emitidas',
            '${PolicyManager.totalAtivas} ativas · R\$ ${PolicyManager.premioMensalTotal.toStringAsFixed(0)}/mês em prêmios',
            Icons.description_rounded,
            Colors.orange,
          ),
          const SizedBox(height: 14),

          // KPIs
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: [
              _miniStatCard('Apólices Ativas', '${PolicyManager.totalAtivas}', Icons.check_circle_rounded, Colors.green),
              _miniStatCard('Prêmio Mensal', 'R\$ ${PolicyManager.premioMensalTotal.toStringAsFixed(0)}', Icons.attach_money_rounded, Colors.blue),
              _miniStatCard('Receita Anual', 'R\$ ${(PolicyManager.premioMensalTotal * 12).toStringAsFixed(0)}', Icons.trending_up_rounded, Colors.purple),
              _miniStatCard('Total Emitidas', '${policies.length}', Icons.folder_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 14),

          const Text('Apólices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 8),

          ...policies.map((pol) => _policyCard(pol)),
        ],
      ),
    );
  }

  Widget _policyCard(InsurancePolicy pol) {
    final statusColor = _polStatusColor(pol.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pol.numeroApolice, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'monospace')),
                    Text(pol.nomeUsuario, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ),
              _badge(pol.status.label, statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(pol.line.label, style: const TextStyle(fontSize: 11, color: Colors.white70))),
              Text('R\$ ${pol.premioMensal.toStringAsFixed(2)}/mês',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Capital: R\$ ${_fmtNum(pol.capitalSegurado)}',
                  style: const TextStyle(fontSize: 9, color: Colors.white38)),
              const Spacer(),
              Text('Vigência: ${_fmtDt(pol.inicioVigencia)} → ${_fmtDt(pol.fimVigencia)}',
                  style: const TextStyle(fontSize: 9, color: Colors.white38)),
            ],
          ),
          if (pol.totalSinistros > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${pol.totalSinistros} sinistro(s) · Total pago: R\$ ${pol.totalPago.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 9, color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SUB-TAB 4 — SINISTROS
  // ══════════════════════════════════════════════════════════════
  Widget _buildSinistros() {
    final claims = PolicyManager.claims;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segHeader(
            'Gestão de Sinistros',
            '${claims.length} sinistros · Sinistralidade: ${PolicyManager.sinistralidade.toStringAsFixed(1)}%',
            Icons.car_crash_rounded,
            Colors.red,
          ),
          const SizedBox(height: 14),

          // KPIs sinistros
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: [
              _miniStatCard('Total Sinistros', '${claims.length}', Icons.warning_rounded, Colors.red),
              _miniStatCard('Total Reclamado', 'R\$ ${_fmtNum(PolicyManager.totalReclamado)}', Icons.request_page_rounded, Colors.orange),
              _miniStatCard('Total Pago', 'R\$ ${_fmtNum(PolicyManager.totalPago)}', Icons.payments_rounded, Colors.green),
              _miniStatCard('Sinistralidade', '${PolicyManager.sinistralidade.toStringAsFixed(1)}%', Icons.percent_rounded, Colors.purple),
            ],
          ),
          const SizedBox(height: 14),

          // Paramétricos destaque
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFA78BFA), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sinistros Paramétricos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFA78BFA))),
                      Text('${claims.where((c) => c.isParametric).length} sinistros liquidados automaticamente sem perícia',
                          style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                ),
                const Text('⚡ AUTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9))),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const Text('Comunicados de Sinistro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 8),

          ...claims.map((c) => _claimCard(c)),
        ],
      ),
    );
  }

  Widget _claimCard(InsuranceClaim c) {
    final statusColor = _claimStatusColor(c.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.numeroComunicado, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'monospace')),
                        if (c.isParametric) ...[
                          const SizedBox(width: 6),
                          _badge('⚡ PARAM.', const Color(0xFF6D28D9)),
                        ],
                      ],
                    ),
                    Text(c.nomeUsuario, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ),
              _badge(c.status.label, statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.descricaoEvento, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reclamado: R\$ ${c.valorReclamado.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 10, color: Colors.orange)),
                  if ((c.valorAprovado ?? 0) > 0)
                    Text('Aprovado: R\$ ${(c.valorAprovado ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10, color: Colors.green)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Abertura: ${_fmtDt(c.aberturaEm)}', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  if (c.liquidacaoEm != null)
                    Text('Liquidado: ${_fmtDt(c.liquidacaoEm!)}', style: const TextStyle(fontSize: 9, color: Colors.green)),
                ],
              ),
            ],
          ),
          if (c.triggerEvidencia != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Trigger: ${c.triggerEvidencia}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFFA78BFA), fontFamily: 'monospace')),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SUB-TAB 5 — ANALYTICS DA SEGURADORA
  // ══════════════════════════════════════════════════════════════
  Widget _buildAnalytics() {
    final byCategory = PolicyManager.policiesByCategory;
    final totalPolicies = PolicyManager.policies.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segHeader(
            'Analytics da Seguradora',
            'Métricas em tempo real da SafeRoute Seguros Interna',
            Icons.bar_chart_rounded,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 14),

          // KPIs principais
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.7,
            children: [
              _miniStatCard('Prêmio Mensal Total', 'R\$ ${_fmtNum(PolicyManager.premioMensalTotal)}', Icons.monetization_on_rounded, Colors.green),
              _miniStatCard('Receita Anual Proj.', 'R\$ ${_fmtNum(PolicyManager.premioMensalTotal * 12)}', Icons.trending_up_rounded, Colors.blue),
              _miniStatCard('Total Sinistros Pagos', 'R\$ ${_fmtNum(PolicyManager.totalPago)}', Icons.payments_rounded, Colors.red),
              _miniStatCard('Sinistralidade', '${PolicyManager.sinistralidade.toStringAsFixed(1)}%', Icons.percent_rounded,
                  PolicyManager.sinistralidade < 60 ? Colors.green : PolicyManager.sinistralidade < 80 ? Colors.orange : Colors.red),
              _miniStatCard('Apólices Ativas', '${PolicyManager.totalAtivas}', Icons.verified_rounded, Colors.green),
              _miniStatCard('Total no Catálogo', '${ProductCatalog.all.length} produtos', Icons.inventory_rounded, Colors.purple),
            ],
          ),
          const SizedBox(height: 16),

          // Margem técnica
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resultado Técnico Estimado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),
                _resultRow('Prêmio Ganho (mês)', 'R\$ ${_fmtNum(PolicyManager.premioMensalTotal)}', Colors.green),
                _resultRow('Sinistros Pagos (total)', '(R\$ ${_fmtNum(PolicyManager.totalPago)})', Colors.red),
                _resultRow('Carregamento Op. (30%)', '(R\$ ${_fmtNum(PolicyManager.premioMensalTotal * 0.30)})', Colors.orange),
                const Divider(color: Colors.white12, height: 16),
                _resultRow(
                  'Resultado Líquido',
                  'R\$ ${_fmtNum(PolicyManager.premioMensalTotal * 0.70 - PolicyManager.totalPago / 12)}',
                  PolicyManager.premioMensalTotal * 0.70 > PolicyManager.totalPago / 12 ? Colors.green : Colors.red,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Distribuição por categoria
          const Text('Distribuição de Apólices por Categoria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 10),
          if (totalPolicies > 0)
            ...byCategory.entries.map((e) {
              final pct = (e.value / totalPolicies * 100).round();
              final color = _catColor(e.key);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_catIcon(e.key), size: 12, color: color),
                        const SizedBox(width: 4),
                        Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11, color: Colors.white70))),
                        Text('${e.value} (${pct}%)', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: e.value / totalPolicies,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 16),

          // Produtos paramétricos
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFFA78BFA), size: 16),
                    SizedBox(width: 6),
                    Text('Produtos Paramétricos SafeRoute', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFA78BFA))),
                  ],
                ),
                const SizedBox(height: 10),
                ...ProductCatalog.parametricOnly.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_checked, size: 10, color: Color(0xFF6D28D9)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(p.nome, style: const TextStyle(fontSize: 11, color: Colors.white70))),
                      if (p.pagamentoParametrico != null)
                        Text(
                          p.pagamentoParametrico! < 10
                              ? 'R\$ ${p.pagamentoParametrico!.toStringAsFixed(2)}/h'
                              : 'R\$ ${_fmtNum(p.pagamentoParametrico!)}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6D28D9), fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                )),
                const Divider(color: Colors.white12, height: 16),
                Text('Liquidação automática = zero custo de perícia · Diferencial competitivo exclusivo SafeRoute',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  Widget _segHeader(String title, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(sub, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          _badge('ADMIN ONLY', Colors.white38),
        ],
      ),
    );
  }

  Widget _miniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.5)), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _fatorChip(String label, double value) {
    final isHigh = value > 1.2;
    final isLow = value < 0.95;
    final color = isHigh ? Colors.red : isLow ? Colors.green : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text('$label: ×${value.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _resultRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: bold ? 0.9 : 0.6),
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _cotadorField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      cursorColor: const Color(0xFF1A56DB),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.white38, size: 16),
        filled: true,
        fillColor: const Color(0xFF0A0F1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _cotadorDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E3A5F)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF0D1628),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              isExpanded: true,
              onChanged: onChanged,
              items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkBox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20, height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1A56DB),
            side: const BorderSide(color: Colors.white38),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Veículos':          return const Color(0xFF1A56DB);
      case 'Pessoas':           return const Color(0xFF059669);
      case 'Patrimônio':        return Colors.orange;
      case 'Digital & Cyber':   return const Color(0xFF6D28D9);
      case 'Viagem':            return Colors.teal;
      case 'Rural & Climático': return Colors.green;
      case 'Responsabilidades': return Colors.deepOrange;
      case 'Transporte & Carga':return Colors.brown;
      case 'Nichos Especiais':  return Colors.pink;
      case 'SafeRoute Exclusivo': return Colors.amber;
      default: return const Color(0xFF1A56DB);
    }
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'Veículos':           return Icons.directions_car_rounded;
      case 'Pessoas':            return Icons.people_rounded;
      case 'Patrimônio':         return Icons.home_rounded;
      case 'Digital & Cyber':    return Icons.security_rounded;
      case 'Viagem':             return Icons.flight_rounded;
      case 'Rural & Climático':  return Icons.grass_rounded;
      case 'Responsabilidades':  return Icons.gavel_rounded;
      case 'Transporte & Carga': return Icons.local_shipping_rounded;
      case 'Nichos Especiais':   return Icons.star_rounded;
      case 'SafeRoute Exclusivo':return Icons.shield_rounded;
      default: return Icons.widgets_rounded;
    }
  }

  Color _polStatusColor(PolicyStatus s) {
    switch (s) {
      case PolicyStatus.cotacao:   return Colors.blue;
      case PolicyStatus.ativa:     return Colors.green;
      case PolicyStatus.suspensa:  return Colors.orange;
      case PolicyStatus.cancelada: return Colors.red;
      case PolicyStatus.expirada:  return Colors.grey;
      case PolicyStatus.sinistro:  return Colors.deepOrange;
    }
  }

  Color _claimStatusColor(ClaimStatus s) {
    switch (s) {
      case ClaimStatus.aberto:    return Colors.blue;
      case ClaimStatus.emAnalise: return Colors.orange;
      case ClaimStatus.aprovado:  return Colors.teal;
      case ClaimStatus.pago:      return Colors.green;
      case ClaimStatus.negado:    return Colors.red;
      case ClaimStatus.cancelado: return Colors.grey;
    }
  }

  String _fmtNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  String _fmtDt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// ═══════════════════════════════════════════════════════════════
// TAB 9 — ATUÁRIO IA — Motor de precificação inteligente
// ═══════════════════════════════════════════════════════════════

class _AtuarioIATab extends StatefulWidget {
  @override
  State<_AtuarioIATab> createState() => _AtuarioIATabState();
}

class _AtuarioIATabState extends State<_AtuarioIATab> with SingleTickerProviderStateMixin {
  late TabController _sub;
  int _subIdx = 0;

  @override
  void initState() {
    super.initState();
    _sub = TabController(length: 5, vsync: this);
    _sub.addListener(() => setState(() => _subIdx = _sub.index));
  }

  @override
  void dispose() { _sub.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: const Color(0xFF0A0F1E),
        child: TabBar(
          controller: _sub,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFFA78BFA),
          labelColor: const Color(0xFFA78BFA),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '🚗 Auto'),
            Tab(text: '💙 Vida'),
            Tab(text: '🛡 Cyber'),
            Tab(text: '🌧 Paramétrico'),
            Tab(text: '📊 Matriz'),
          ],
        ),
      ),
      Expanded(child: TabBarView(
        controller: _sub,
        children: [
          _AutoCalculadorTab(),
          _VidaCalculadorTab(),
          _CyberCalculadorTab(),
          _ParametricoCalculadorTab(),
          _MatrizAtuarialTab(),
        ],
      )),
    ]);
  }
}

// ─── AUTO CALCULADOR ───────────────────────────────────────────
class _AutoCalculadorTab extends StatefulWidget {
  @override
  State<_AutoCalculadorTab> createState() => _AutoCalculadorTabState();
}

class _AutoCalculadorTabState extends State<_AutoCalculadorTab> {
  final _fipeCtrl = TextEditingController(text: '85000');
  final _idadeCtrl = TextEditingController(text: '35');
  final _cepCtrl = TextEditingController(text: '01310');
  final _anoCtrl = TextEditingController(text: '2021');
  int _bonus = 3;
  String _uso = 'lazer';
  CalculoAuto? _resultado;
  bool _calculando = false;

  void _calcular() async {
    setState(() { _calculando = true; });
    await Future.delayed(const Duration(milliseconds: 600)); // simula IA processando
    final c = CalculoAuto(
      valorFipe: double.tryParse(_fipeCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 85000,
      idadeMotorista: int.tryParse(_idadeCtrl.text) ?? 35,
      cepPernoite: _cepCtrl.text,
      anoVeiculo: int.tryParse(_anoCtrl.text) ?? 2020,
      classeBonus: _bonus,
      usoVeiculo: _uso,
    );
    setState(() { _resultado = c; _calculando = false; });
  }

  @override
  void dispose() { _fipeCtrl.dispose(); _idadeCtrl.dispose(); _cepCtrl.dispose(); _anoCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiHeader('Precificação Auto — PHYD', 'Frequência × Gravidade × Fatores Multiplicativos'),
        const SizedBox(height: 14),

        // Inputs
        _iaInputGrid([
          _IaInput('Valor FIPE (R\$)', _fipeCtrl, Icons.directions_car_rounded),
          _IaInput('Idade Motorista', _idadeCtrl, Icons.person_rounded),
          _IaInput('CEP Pernoite', _cepCtrl, Icons.location_on_rounded),
          _IaInput('Ano Veículo', _anoCtrl, Icons.calendar_today_rounded),
        ]),
        const SizedBox(height: 12),

        // Classe Bônus
        Row(children: [
          const Text('Classe Bônus:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 12),
          ...List.generate(11, (i) => GestureDetector(
            onTap: () => setState(() => _bonus = i),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _bonus == i ? const Color(0xFF1A56DB) : const Color(0xFF0D1628),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _bonus == i ? const Color(0xFF1A56DB) : const Color(0xFF1E3A5F)),
              ),
              alignment: Alignment.center,
              child: Text('$i', style: TextStyle(color: _bonus == i ? Colors.white : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          )),
        ]),
        const SizedBox(height: 12),

        // Uso
        Row(children: [
          const Text('Uso:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 12),
          ...['lazer', 'trabalho', 'aplicativo', 'frota'].map((u) => GestureDetector(
            onTap: () => setState(() => _uso = u),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _uso == u ? const Color(0xFF1A56DB) : const Color(0xFF0D1628),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _uso == u ? const Color(0xFF1A56DB) : const Color(0xFF1E3A5F)),
              ),
              child: Text(u[0].toUpperCase() + u.substring(1), style: TextStyle(color: _uso == u ? Colors.white : Colors.white54, fontSize: 11)),
            ),
          )),
        ]),
        const SizedBox(height: 16),

        // Botão calcular
        _calcButton(_calculando ? 'Processando...' : '🤖 Calcular Prêmio Auto', _calcular, _calculando),
        const SizedBox(height: 16),

        // Resultado
        if (_resultado != null) _autoResultado(_resultado!),
      ]),
    );
  }

  Widget _autoResultado(CalculoAuto c) {
    final m = c.toMap();
    return Column(children: [
      _resultCard('PRÊMIO COMERCIAL', [
        _resultRow('Mensal', 'R\$ ${c.premComercialMensal.toStringAsFixed(2)}', AppTheme.accent, big: true),
        _resultRow('Anual', 'R\$ ${c.premComercialAnual.toStringAsFixed(2)}', AppTheme.green),
        _resultRow('Diário', 'R\$ ${c.premComercialDiario.toStringAsFixed(4)}', const Color(0xFF60A5FA)),
      ]),
      const SizedBox(height: 10),
      _resultCard('FATORES MULTIPLICATIVOS', [
        _resultRow('Prêmio Puro Base (4% FIPE)', 'R\$ ${c.premPuroBase.toStringAsFixed(2)}', Colors.white60),
        _resultRow('Fator Idade (${c.idadeMotorista} anos)', '× ${c.fatId.toStringAsFixed(2)}', _fatorColor(c.fatId)),
        _resultRow('Fator CEP (${c.cepPernoite})', '× ${c.fatCep.toStringAsFixed(2)}', _fatorColor(c.fatCep)),
        _resultRow('Fator Ano Veículo', '× ${c.fatAno.toStringAsFixed(2)}', _fatorColor(c.fatAno)),
        _resultRow('Fator Bônus (Classe $_bonus)', '× ${c.fatBonus.toStringAsFixed(2)}', AppTheme.green),
        _resultRow('Fator Uso ($_uso)', '× ${c.fatUso.toStringAsFixed(2)}', _fatorColor(c.fatUso)),
        _resultRow('Prêmio Puro Final', 'R\$ ${c.premPuroFinal.toStringAsFixed(2)}', Colors.white70),
      ]),
      const SizedBox(height: 10),
      _resultCard('CARREGAMENTO SADI', [
        _resultRow('DA (Desp. Adm.)', '${(AtuarioPremissas.da * 100).toStringAsFixed(0)}%', const Color(0xFF60A5FA)),
        _resultRow('CC (Corretagem)', '${(AtuarioPremissas.cc * 100).toStringAsFixed(0)}%', const Color(0xFFA78BFA)),
        _resultRow('ML (Margem Lucro)', '${(AtuarioPremissas.ml * 100).toStringAsFixed(0)}%', AppTheme.green),
        _resultRow('IOF', '${(AtuarioPremissas.iof * 100).toStringAsFixed(2)}%', const Color(0xFFF59E0B)),
        _resultRow('Carregamento Total', '${((1 - AtuarioPremissas.carregamento) * 100).toStringAsFixed(0)}%', Colors.white60),
      ]),
    ]);
  }

  Color _fatorColor(double f) {
    if (f <= 0.95) return AppTheme.green;
    if (f <= 1.10) return Colors.white60;
    if (f <= 1.30) return const Color(0xFFF59E0B);
    return const Color(0xFFF97316);
  }
}

// ─── VIDA CALCULADOR ───────────────────────────────────────────
class _VidaCalculadorTab extends StatefulWidget {
  @override
  State<_VidaCalculadorTab> createState() => _VidaCalculadorTabState();
}

class _VidaCalculadorTabState extends State<_VidaCalculadorTab> {
  final _isCtrl = TextEditingController(text: '500000');
  final _idadeCtrl = TextEditingController(text: '35');
  bool _tabagista = false;
  String _profissao = 'geral';
  CalculoVida? _resultado;
  bool _calculando = false;

  static const _profissoes = ['geral', 'ti', 'professor', 'motorista', 'motoboy', 'policial', 'bombeiro', 'construção', 'aviação', 'escritório'];

  void _calcular() async {
    setState(() { _calculando = true; });
    await Future.delayed(const Duration(milliseconds: 700));
    final c = CalculoVida(
      capitalSegurado: double.tryParse(_isCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 500000,
      idade: int.tryParse(_idadeCtrl.text) ?? 35,
      tabagista: _tabagista,
      profissao: _profissao,
    );
    setState(() { _resultado = c; _calculando = false; });
  }

  @override
  void dispose() { _isCtrl.dispose(); _idadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiHeader('Precificação Vida — Tábua BR-EMS', 'Prêmio Puro = IS × qx  |  Tábua AT-2000 / BR-EMS'),
        const SizedBox(height: 14),
        _iaInputGrid([
          _IaInput('Capital Segurado (R\$)', _isCtrl, Icons.account_balance_rounded),
          _IaInput('Idade Segurado', _idadeCtrl, Icons.person_rounded),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Tabagista:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 12),
          Switch(value: _tabagista, onChanged: (v) => setState(() => _tabagista = v), activeColor: const Color(0xFFF97316)),
          const SizedBox(width: 20),
          const Text('Profissão:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3A5F))),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _profissao,
              dropdownColor: const Color(0xFF0D1628),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              items: _profissoes.map((p) => DropdownMenuItem(value: p, child: Text(p[0].toUpperCase() + p.substring(1)))).toList(),
              onChanged: (v) => setState(() => _profissao = v ?? 'geral'),
            )),
          )),
        ]),
        const SizedBox(height: 16),
        _calcButton(_calculando ? 'Processando...' : '🤖 Calcular Prêmio Vida', _calcular, _calculando),
        const SizedBox(height: 16),
        if (_resultado != null) _vidaResultado(_resultado!),
      ]),
    );
  }

  Widget _vidaResultado(CalculoVida c) {
    return Column(children: [
      _resultCard('PRÊMIO COMERCIAL', [
        _resultRow('Mensal', 'R\$ ${c.premComercialMensal.toStringAsFixed(2)}', AppTheme.accent, big: true),
        _resultRow('Anual', 'R\$ ${c.premComercialAnual.toStringAsFixed(2)}', AppTheme.green),
      ]),
      const SizedBox(height: 10),
      _resultCard('DADOS BIOMÉTRICOS (BR-EMS)', [
        _resultRow('Idade', '${c.idade} anos', Colors.white60),
        _resultRow('Taxa Mortalidade qx', '${(c.qx * 1000).toStringAsFixed(3)}‰', const Color(0xFFF59E0B)),
        _resultRow('Capital Segurado (IS)', 'R\$ ${(c.capitalSegurado / 1000).toStringAsFixed(0)}k', AppTheme.accent),
        _resultRow('Fator Tabagismo', '× ${c.fatorTabagismo.toStringAsFixed(2)}', c.tabagista ? const Color(0xFFF97316) : AppTheme.green),
        _resultRow('Fator Profissão ($_profissao)', '× ${c.fatorProfissao.toStringAsFixed(2)}', Colors.white60),
        _resultRow('Prêmio Puro Anual', 'R\$ ${c.premPuroAnual.toStringAsFixed(2)}', Colors.white70),
        _resultRow('+ Margem Segurança 5%', 'R\$ ${c.carregamentoSeguranca.toStringAsFixed(2)}', const Color(0xFFF59E0B)),
        _resultRow('Prêmio Puro Total', 'R\$ ${c.premPuroTotal.toStringAsFixed(2)}', Colors.white),
      ]),
    ]);
  }
}

// ─── CYBER CALCULADOR ──────────────────────────────────────────
class _CyberCalculadorTab extends StatefulWidget {
  @override
  State<_CyberCalculadorTab> createState() => _CyberCalculadorTabState();
}

class _CyberCalculadorTabState extends State<_CyberCalculadorTab> {
  final _limiteCtrl = TextEditingController(text: '500000');
  final _funcCtrl = TextEditingController(text: '50');
  String _segmento = 'pme';
  bool _possuiSoc = false;
  CalculoCyber? _resultado;
  bool _calculando = false;

  static const _segmentos = ['pessoal', 'pme', 'enterprise', 'saúde', 'financeiro'];

  void _calcular() async {
    setState(() { _calculando = true; });
    await Future.delayed(const Duration(milliseconds: 800));
    final c = CalculoCyber(
      limiteIndenizacao: double.tryParse(_limiteCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 500000,
      segmento: _segmento,
      funcionarios: int.tryParse(_funcCtrl.text) ?? 50,
      possuiSoc: _possuiSoc,
    );
    setState(() { _resultado = c; _calculando = false; });
  }

  @override
  void dispose() { _limiteCtrl.dispose(); _funcCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiHeader('Precificação Cyber', 'Frequência de Ataques × Vulnerabilidade × Limite de Indenização'),
        const SizedBox(height: 14),
        _iaInputGrid([
          _IaInput('Limite Indenização (R\$)', _limiteCtrl, Icons.security_rounded),
          _IaInput('Nº Funcionários', _funcCtrl, Icons.group_rounded),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Segmento:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3A5F))),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _segmento,
              dropdownColor: const Color(0xFF0D1628),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              items: _segmentos.map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
              onChanged: (v) => setState(() => _segmento = v ?? 'pme'),
            )),
          )),
          const SizedBox(width: 16),
          const Text('SOC:', style: TextStyle(color: Colors.white60, fontSize: 12)),
          Switch(value: _possuiSoc, onChanged: (v) => setState(() => _possuiSoc = v), activeColor: AppTheme.green),
        ]),
        const SizedBox(height: 16),
        _calcButton(_calculando ? 'Processando...' : '🤖 Calcular Prêmio Cyber', _calcular, _calculando),
        const SizedBox(height: 16),
        if (_resultado != null) _cyberResultado(_resultado!),
      ]),
    );
  }

  Widget _cyberResultado(CalculoCyber c) {
    return Column(children: [
      _resultCard('PRÊMIO COMERCIAL', [
        _resultRow('Mensal', 'R\$ ${c.premComercialMensal.toStringAsFixed(2)}', AppTheme.accent, big: true),
        _resultRow('Anual', 'R\$ ${c.premComercialAnual.toStringAsFixed(2)}', AppTheme.green),
      ]),
      const SizedBox(height: 10),
      _resultCard('PARÂMETROS CYBER', [
        _resultRow('Limite Indenização', 'R\$ ${(c.limiteIndenizacao/1000).toStringAsFixed(0)}k', Colors.white60),
        _resultRow('Segmento', _segmento.toUpperCase(), const Color(0xFFA78BFA)),
        _resultRow('Taxa Base', '${(c.taxaBase * 100).toStringAsFixed(2)}%', const Color(0xFFF59E0B)),
        _resultRow('Fator Escala (${c.funcionarios} func.)', '× ${c.fatorEscala.toStringAsFixed(2)}', Colors.white60),
        _resultRow('Fator SOC', '× ${c.fatorSoc.toStringAsFixed(2)}', c.possuiSoc ? AppTheme.green : const Color(0xFFF97316)),
        _resultRow('Prêmio Puro Anual', 'R\$ ${c.premPuroAnual.toStringAsFixed(2)}', Colors.white70),
      ]),
    ]);
  }
}

// ─── PARAMÉTRICO CALCULADOR ────────────────────────────────────
class _ParametricoCalculadorTab extends StatefulWidget {
  @override
  State<_ParametricoCalculadorTab> createState() => _ParametricoCalculadorTabState();
}

class _ParametricoCalculadorTabState extends State<_ParametricoCalculadorTab> {
  final _isCtrl = TextEditingController(text: '1200000');
  final _trigCtrl = TextEditingController(text: '30');
  final _exitCtrl = TextEditingController(text: '10');
  String _regiao = 'cerrado';
  String _cultura = 'soja';
  CalculoParametrico? _resultado;
  bool _calculando = false;

  static const _regioes = ['cerrado', 'semi-árido', 'amazônia', 'sul', 'sudeste'];
  static const _culturas = ['soja', 'milho', 'café', 'cana', 'algodão'];

  void _calcular() async {
    setState(() { _calculando = true; });
    await Future.delayed(const Duration(milliseconds: 900));
    final c = CalculoParametrico(
      capitalSegurado: double.tryParse(_isCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 1200000,
      cultura: _cultura,
      triggerMm: double.tryParse(_trigCtrl.text) ?? 30,
      exitMm: double.tryParse(_exitCtrl.text) ?? 10,
      regiao: _regiao,
    );
    setState(() { _resultado = c; _calculando = false; });
  }

  @override
  void dispose() { _isCtrl.dispose(); _trigCtrl.dispose(); _exitCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiHeader('Seguro Paramétrico Climático', 'GEV × Trigger × Exit × IS — Liquidação automática via satélite NASA/NOAA'),
        const SizedBox(height: 14),
        _iaInputGrid([
          _IaInput('Capital Segurado (R\$)', _isCtrl, Icons.agriculture_rounded),
          _IaInput('Trigger (mm mínimo)', _trigCtrl, Icons.water_drop_rounded),
          _IaInput('Exit (mm gatilho total)', _exitCtrl, Icons.thunderstorm_rounded),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Região:', style: TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3A5F))),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _regiao, isExpanded: true,
                dropdownColor: const Color(0xFF0D1628),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                items: _regioes.map((r) => DropdownMenuItem(value: r, child: Text(r[0].toUpperCase() + r.substring(1)))).toList(),
                onChanged: (v) => setState(() => _regiao = v ?? 'cerrado'),
              )),
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cultura:', style: TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3A5F))),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _cultura, isExpanded: true,
                dropdownColor: const Color(0xFF0D1628),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                items: _culturas.map((c) => DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1)))).toList(),
                onChanged: (v) => setState(() => _cultura = v ?? 'soja'),
              )),
            ),
          ])),
        ]),
        const SizedBox(height: 16),
        _calcButton(_calculando ? 'Processando...' : '🤖 Calcular Prêmio Paramétrico', _calcular, _calculando),
        const SizedBox(height: 16),
        if (_resultado != null) _paramResultado(_resultado!),
      ]),
    );
  }

  Widget _paramResultado(CalculoParametrico c) {
    return Column(children: [
      _resultCard('PRÊMIO COMERCIAL', [
        _resultRow('Mensal', 'R\$ ${c.premComercialMensal.toStringAsFixed(2)}', AppTheme.accent, big: true),
        _resultRow('Anual', 'R\$ ${c.premComercialAnual.toStringAsFixed(2)}', AppTheme.green),
      ]),
      const SizedBox(height: 10),
      _resultCard('PARÂMETROS CLIMÁTICOS', [
        _resultRow('Região / Cultura', '${_regiao.toUpperCase()} / ${_cultura.toUpperCase()}', Colors.white60),
        _resultRow('Freq. Histórica 30a', '${(c.freqHistorica * 100).toStringAsFixed(0)}% prob/ano', const Color(0xFFF59E0B)),
        _resultRow('Fator Cultura', '× ${c.fatorCultura.toStringAsFixed(2)}', Colors.white60),
        _resultRow('Perda Esperada (E[Y])', 'R\$ ${c.perdaEsperada.toStringAsFixed(2)}', const Color(0xFFF97316)),
        _resultRow('Trigger', '${c.triggerMm.toStringAsFixed(0)}mm  →  Exit: ${c.exitMm.toStringAsFixed(0)}mm', Colors.white70),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.green.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.satellite_alt_rounded, color: AppTheme.green, size: 14),
            const SizedBox(width: 6),
            const Text('GATILHO AUTOMÁTICO', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text('Se chuva < ${c.triggerMm.toStringAsFixed(0)}mm no mês → Smart Contract ativa liquidação proporcional.\nSe chuva < ${c.exitMm.toStringAsFixed(0)}mm → Pagamento total R\$ ${(c.capitalSegurado/1000).toStringAsFixed(0)}k via Pix em até 24h.', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ]),
      ),
    ]);
  }
}

// ─── MATRIZ ATUARIAL ───────────────────────────────────────────
class _MatrizAtuarialTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiHeader('Matriz Atuarial Completa', 'Todos os ramos — variáveis, fórmulas e carregamentos'),
        const SizedBox(height: 14),
        ...MatrizAtuarial.ramos.map((r) => _MatrizItem(
          ramo: r['ramo']!,
          variavel: r['variavel']!,
          formula: r['formula']!,
          carregamento: r['carregamento']!,
        )),
        const SizedBox(height: 16),
        _aiHeader('Portfólio de Produtos', '${PortfolioSeguros.produtos.length} produtos × ${PortfolioSeguros.categorias.length} categorias'),
        const SizedBox(height: 12),
        ...PortfolioSeguros.categorias.map((cat) {
          final prods = PortfolioSeguros.byCategoria(cat);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(cat.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            ...prods.map((p) => _ProdutoCard(p)),
          ]);
        }),
      ]),
    );
  }
}

class _MatrizItem extends StatelessWidget {
  final String ramo, variavel, formula, carregamento;
  const _MatrizItem({required this.ramo, required this.variavel, required this.formula, required this.carregamento});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1A56DB).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: Text(ramo, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text(variavel, style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ]),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF0A0F1E), borderRadius: BorderRadius.circular(6)), child: Text(formula, style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontFamily: 'monospace'))),
        const SizedBox(height: 4),
        Text('Carregamentos: $carregamento', style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ]),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  final ProdutoSeguro p;
  const _ProdutoCard(this.p);

  Color get _statusColor {
    if (p.statusViabilidade.contains('Urgente') || p.statusViabilidade == 'Ativo') return AppTheme.green;
    if (p.statusViabilidade.contains('Implementação')) return const Color(0xFFF59E0B);
    return const Color(0xFF60A5FA);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.verified_rounded, color: _statusColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nome, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(p.descricao, style: const TextStyle(color: Colors.white54, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(p.modeloPrecificacao, style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text(p.statusViabilidade, style: TextStyle(color: _statusColor, fontSize: 8, fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          if (p.escalaGlobal) const Text('🌐 Global', style: TextStyle(color: Colors.white38, fontSize: 8)),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 10 — SUBSCRITOR IA — Análise de propostas + Antifraude
// ═══════════════════════════════════════════════════════════════

class _SubscritorIATab extends StatefulWidget {
  @override
  State<_SubscritorIATab> createState() => _SubscritorIATabState();
}

class _SubscritorIATabState extends State<_SubscritorIATab> {
  final _cpfCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _capitalCtrl = TextEditingController(text: '85000');
  final _sins5aCtrl = TextEditingController(text: '0');
  final _valSinsCtrl = TextEditingController(text: '0');
  String _ramo = 'Auto';
  bool _possuiProcessos = false;
  bool _analisando = false;

  ScoreFraude? _scoreFraude;
  ResultadoSubscricao? _subscricao;

  // Base de propostas analisadas (simuladas)
  final _historico = <Map<String, dynamic>>[
    {'cpf': '123.456.789-00', 'nome': 'Carlos Silva', 'ramo': 'Auto', 'resultado': 'APROVADO', 'score': 812, 'prem': 287.40, 'ts': '14:22'},
    {'cpf': '987.654.321-00', 'nome': 'Ana Oliveira', 'ramo': 'Vida', 'resultado': 'APROVADO', 'score': 755, 'prem': 198.60, 'ts': '13:58'},
    {'cpf': '111.111.111-11', 'nome': 'João Fraudador', 'ramo': 'Auto', 'resultado': 'RECUSADO — FRAUDE', 'score': 120, 'prem': 0.0, 'ts': '13:45'},
    {'cpf': '333.333.333-33', 'nome': 'Pedro Litigante', 'ramo': 'Residencial', 'resultado': 'RECUSADO — COMPLIANCE', 'score': 250, 'prem': 0.0, 'ts': '13:30'},
    {'cpf': '555.555.555-55', 'nome': 'Maria Agravada', 'ramo': 'Auto', 'resultado': 'APROVADO — AGRAVADO', 'score': 520, 'prem': 412.80, 'ts': '12:55'},
  ];

  void _analisar() async {
    if (_cpfCtrl.text.isEmpty) return;
    setState(() { _analisando = true; _scoreFraude = null; _subscricao = null; });
    await Future.delayed(const Duration(milliseconds: 1200)); // simula consulta em tempo real

    final score = MotorAntifraude.analisar(
      _cpfCtrl.text.trim(),
      sinistrosUltimos5Anos: int.tryParse(_sins5aCtrl.text) ?? 0,
      valorSinistros: double.tryParse(_valSinsCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0,
      possuiProcessos: _possuiProcessos,
    );

    final capitalBase = double.tryParse(_capitalCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 85000;
    final premPuroBase = capitalBase * 0.04;

    final sub = SubscritorIA.analisarProposta(
      ramo: _ramo,
      premPuroBase: premPuroBase,
      scoreFraude: score,
      dadosAtuariais: {'capital': capitalBase},
    );

    // Adicionar ao histórico
    _historico.insert(0, {
      'cpf': _cpfCtrl.text,
      'nome': _nomeCtrl.text.isEmpty ? 'Proponente' : _nomeCtrl.text,
      'ramo': _ramo,
      'resultado': sub.decisao,
      'score': score.scoreRisco,
      'prem': sub.premComercialFinal / 12,
      'ts': '${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}',
    });

    setState(() { _scoreFraude = score; _subscricao = sub; _analisando = false; });
  }

  @override
  void dispose() {
    _cpfCtrl.dispose(); _nomeCtrl.dispose(); _capitalCtrl.dispose();
    _sins5aCtrl.dispose(); _valSinsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _aiHeader('Subscritor IA + Antifraude', 'Validação em tempo real — SUSEP / DPVAT / Birôs de Mercado'),
        const SizedBox(height: 14),

        // KPIs antifraude
        Row(children: [
          Expanded(child: _FraudeKpi('Propostas Hoje', '${_historico.length}', Icons.description_rounded, AppTheme.accent)),
          const SizedBox(width: 8),
          Expanded(child: _FraudeKpi('Aprovadas', '${_historico.where((h) => h['resultado'].toString().contains('APROVADO')).length}', Icons.check_circle_rounded, AppTheme.green)),
          const SizedBox(width: 8),
          Expanded(child: _FraudeKpi('Recusadas', '${_historico.where((h) => h['resultado'].toString().contains('RECUSADO')).length}', Icons.cancel_rounded, const Color(0xFFEF4444))),
        ]),
        const SizedBox(height: 16),

        // Formulário de análise
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E3A5F))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NOVA PROPOSTA', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _iaInputGrid([
              _IaInput('CPF do Proponente', _cpfCtrl, Icons.fingerprint_rounded, hint: '000.000.000-00'),
              _IaInput('Nome do Proponente', _nomeCtrl, Icons.person_rounded),
              _IaInput('Capital Segurado (R\$)', _capitalCtrl, Icons.account_balance_rounded),
              _IaInput('Sinistros últimos 5 anos', _sins5aCtrl, Icons.car_crash_rounded),
              _IaInput('Valor total sinistros (R\$)', _valSinsCtrl, Icons.monetization_on_rounded),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Ramo:', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: const Color(0xFF0A0F1E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3A5F))),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _ramo,
                  dropdownColor: const Color(0xFF0A0F1E),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  items: ['Auto', 'Vida', 'Cyber', 'Paramétrico', 'Residencial', 'Saúde'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _ramo = v ?? 'Auto'),
                )),
              )),
              const SizedBox(width: 16),
              const Text('Processos:', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Switch(value: _possuiProcessos, onChanged: (v) => setState(() => _possuiProcessos = v), activeColor: const Color(0xFFF97316)),
            ]),
            const SizedBox(height: 14),
            _calcButton(_analisando ? '🔍 Consultando birôs...' : '🛡️ Analisar Proposta (IA)', _analisar, _analisando),
          ]),
        ),

        const SizedBox(height: 16),

        // Resultado
        if (_analisando)
          _loadingIA(),

        if (_scoreFraude != null && _subscricao != null)
          _resultadoSubscricao(_scoreFraude!, _subscricao!),

        const SizedBox(height: 16),

        // Histórico
        _aiHeader('Histórico de Análises', 'Últimas propostas analisadas pelo Motor IA'),
        const SizedBox(height: 12),
        ..._historico.take(8).map((h) => _HistoricoItem(h)),

        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _loadingIA() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1A56DB).withValues(alpha: 0.4))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A56DB))),
        const SizedBox(width: 12),
        const Text('Consultando SUSEP / DPVAT / Birôs de Fraude...', style: TextStyle(color: Colors.white60, fontSize: 12)),
      ]),
    );
  }

  Widget _resultadoSubscricao(ScoreFraude score, ResultadoSubscricao sub) {
    final isAprovado = sub.aprovado;
    final cor = isAprovado ? AppTheme.green : const Color(0xFFEF4444);

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isAprovado ? Icons.check_circle_rounded : Icons.cancel_rounded, color: cor, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sub.decisao, style: TextStyle(color: cor, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(sub.justificativa, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('SCORE', style: TextStyle(color: cor, fontSize: 8)),
                Text('${score.scoreRisco}', style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E3A5F), height: 1),
          const SizedBox(height: 12),
          if (isAprovado && sub.premComercialFinal > 0) ...[
            Row(children: [
              Expanded(child: _resultRow('Prêmio Mensal', 'R\$ ${(sub.premComercialFinal/12).toStringAsFixed(2)}', AppTheme.accent, big: true)),
              Expanded(child: _resultRow('Prêmio Anual', 'R\$ ${sub.premComercialFinal.toStringAsFixed(2)}', AppTheme.green)),
              Expanded(child: _resultRow('Fator Aplicado', '× ${sub.fatorFinal.toStringAsFixed(2)}', const Color(0xFFF59E0B))),
            ]),
            const SizedBox(height: 10),
          ],
          // Flags
          Wrap(spacing: 6, runSpacing: 4, children: score.flags.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: f.contains('APROVADO') || f.contains('CLEAN') ? AppTheme.green.withValues(alpha: 0.15) : const Color(0xFFF97316).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(f, style: TextStyle(color: f.contains('APROVADO') || f.contains('CLEAN') ? AppTheme.green : const Color(0xFFF97316), fontSize: 9, fontWeight: FontWeight.bold)),
          )).toList()),
          const SizedBox(height: 10),
          // Observações
          ...sub.observacoes.map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.chevron_right_rounded, color: cor.withValues(alpha: 0.6), size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(o, style: const TextStyle(color: Colors.white54, fontSize: 10))),
            ]),
          )),
        ]),
      ),
    ]);
  }
}

// ─── FRAUDE KPI ────────────────────────────────────────────────
class _FraudeKpi extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _FraudeKpi(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }
}

// ─── HISTÓRICO ITEM ────────────────────────────────────────────
class _HistoricoItem extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoricoItem(this.data);

  Color get _cor {
    final r = data['resultado'].toString();
    if (r.contains('FRAUDE') || r.contains('COMPLIANCE')) return const Color(0xFFEF4444);
    if (r.contains('AGRAVADO') || r.contains('ANÁLISE')) return const Color(0xFFF59E0B);
    return AppTheme.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF0D1628), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E3A5F))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _cor, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['nome'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          Text('${data['cpf']}  •  ${data['ramo']}', style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(data['resultado'].toString().split('—').first.trim(), style: TextStyle(color: _cor, fontSize: 9, fontWeight: FontWeight.bold)),
          if ((data['prem'] as double) > 0)
            Text('R\$ ${(data['prem'] as double).toStringAsFixed(2)}/mês', style: const TextStyle(color: Colors.white54, fontSize: 9)),
          Text(data['ts'].toString(), style: const TextStyle(color: Colors.white30, fontSize: 8)),
        ]),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
          child: Text('${data['score']}', style: TextStyle(color: _cor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ─── HELPERS COMPARTILHADOS DAS ABAS IA ────────────────────────

Widget _aiHeader(String title, String subtitle) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        const Color(0xFF1A3A7C).withValues(alpha: 0.6),
        const Color(0xFF0D1B4B).withValues(alpha: 0.4),
      ]),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFA78BFA).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.psychology_rounded, color: Color(0xFFA78BFA), size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: AppTheme.green, fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
      ),
    ]),
  );
}

Widget _iaInputGrid(List<Widget> inputs) {
  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 3.5,
    children: inputs,
  );
}

class _IaInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  const _IaInput(this.label, this.controller, this.icon, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: Color(0xFF0A0F1E)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
          prefixIcon: Icon(icon, color: Colors.white38, size: 14),
          filled: true,
          fillColor: const Color(0xFF0A0F1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }
}

Widget _calcButton(String label, VoidCallback onTap, bool loading) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A56DB),
        disabledBackgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: loading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
        : Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    ),
  );
}

Widget _resultCard(String title, List<Widget> rows) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1628),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1E3A5F)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      const SizedBox(height: 10),
      ...rows,
    ]),
  );
}

Widget _resultRow(String label, String value, Color color, {bool big = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
      Text(value, style: TextStyle(color: color, fontSize: big ? 16 : 12, fontWeight: big ? FontWeight.bold : FontWeight.w500)),
    ]),
  );
}

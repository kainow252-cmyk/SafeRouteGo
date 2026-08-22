// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — TELA DO ATUÁRIO IA
// Dashboard completo do agente atuarial interno
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/actuarial_engine_v3.dart';
import '../services/atuario_ia.dart';

class AtuarioIAScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AtuarioIAScreen({super.key, this.onBack});

  @override
  State<AtuarioIAScreen> createState() => _AtuarioIAScreenState();
}

class _AtuarioIAScreenState extends State<AtuarioIAScreen>
    with TickerProviderStateMixin {
  late TabController _tab;

  // Input configurável pelo usuário
  // Começa com perfil demo, usuário pode ajustar
  double  _fipe           = 80000;
  int     _anoFab         = 2020;
  int     _anoMod         = 2021;
  VehicleCategory _categoria = VehicleCategory.popular;
  double  _theftIdx       = 0.55;
  String  _marca          = 'Hyundai';
  String  _modelo         = 'HB20';

  int     _driverIdade    = 29;
  int     _cnhAnos        = 7;
  int     _sinistros      = 0;
  int     _multas         = 1;
  int     _scoreInterno   = 820;

  double  _kmMes          = 1200;
  UsagePattern    _pattern      = UsagePattern.trabalho;
  DrivingTimeSlot _timeSlot     = DrivingTimeSlot.tarde;

  String  _uf             = 'ES';
  String  _cidade         = 'Serra';

  FranchiseType _franchiseType = FranchiseType.dinamica;
  int     _telemetryScore = 900;

  // Resultados
  ActuarialResultV3? _result;
  bool _calculando = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _calcular();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  ActuarialInputV3 get _buildInput => ActuarialInputV3(
    vehicle: VehicleDataV3(
      fipeValue:      _fipe,
      anoFabricacao:  _anoFab,
      anoModelo:      _anoMod,
      category:       _categoria,
      modelName:      _modelo,
      brandName:      _marca,
      theftIndex:     _theftIdx,
      collisionIndex: 0.35,
    ),
    driver: DriverDataV3(
      idade:             _driverIdade,
      tempoCnhAnos:      _cnhAnos,
      sinistrosUlt3Anos: _sinistros,
      multasUlt12Meses:  _multas,
      scoreInterno:      _scoreInterno,
    ),
    usage: UsageDataV3(
      kmMes:       _kmMes,
      pattern:     _pattern,
      primarySlot: _timeSlot,
    ),
    region: RegionDataV3.fromUF(_uf, cidade: _cidade),
    franchise: FranchiseConfig(type: _franchiseType),
    telemetryScore: _telemetryScore,
  );

  Future<void> _calcular() async {
    setState(() => _calculando = true);
    await Future.delayed(const Duration(milliseconds: 220));
    final r = ActuarialEngineV3.calculate(_buildInput);
    setState(() { _result = r; _calculando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _calculando
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      _buildTabScore(),
                      _buildTabPremio(),
                      _buildTabFranquia(),
                      _buildTabSugestoes(),
                      _buildTabParametros(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader() {
    final r = _result;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B4B), Color(0xFF1A3A7C), Color(0xFF6D28D9)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              // Ícone do agente
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('Aχ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Atuário IA',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Motor Atuarial v3 · interno · zero API',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
                  ],
                ),
              ),
              // Botão voltar
              if (widget.onBack != null)
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  ),
                ),
              const SizedBox(width: 8),
              // Classe de risco destaque
              if (r != null)
                _ClassBadgeLarge(r.riskClass),
            ],
          ),
          if (r != null) ...[
            const SizedBox(height: 14),
            // Score cards horizontais
            Row(
              children: [
                _hCard('Score', '×${r.score.scoreTotal.toStringAsFixed(3)}', Icons.analytics_rounded),
                const SizedBox(width: 8),
                _hCard('R\$/km', 'R\$ ${r.premium.taxaFinalKm.toStringAsFixed(4)}', Icons.speed_rounded),
                const SizedBox(width: 8),
                _hCard('Franquia', r.premium.franquiaFmt, Icons.shield_rounded),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _hCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.75)),
            const SizedBox(height: 4),
            Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label,
              style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.60))),
          ],
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────

  Widget _buildTabBar() {
    const tabs = [
      (Icons.analytics_rounded,  'Score'),
      (Icons.attach_money_rounded,'Prêmio'),
      (Icons.shield_rounded,     'Franquia'),
      (Icons.lightbulb_rounded,  'Sugestões'),
      (Icons.tune_rounded,       'Parâmetros'),
    ];
    return Container(
      color: const Color(0xFF1A3A7C),
      child: TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        indicatorColor: Colors.white,
        indicatorWeight: 2.5,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        tabs: tabs.map((t) => Tab(
          icon: Icon(t.$1, size: 15),
          text: t.$2,
          height: 46,
        )).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 1 — SCORE & CLASSE
  // ═══════════════════════════════════════════════════════════

  Widget _buildTabScore() {
    if (_result == null) return const SizedBox();
    final scoreR  = AtuarioIA.calcularScore(_buildInput);
    final regiaoR = AtuarioIA.avaliarRegiao(_uf, cidade: _cidade);
    final explR   = AtuarioIA.explicarCotacao(_buildInput);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        // Gauge visual do score
        _buildScoreGauge(scoreR),
        const SizedBox(height: 14),

        // Tabela de classes
        _buildClassTable(scoreR.classe),
        const SizedBox(height: 14),

        // Breakdown de fatores
        _sectionTitle('Breakdown dos Fatores', Icons.bar_chart_rounded),
        const SizedBox(height: 8),
        ...scoreR.fatores.map((f) => _buildFatorCard(f)),
        const SizedBox(height: 14),

        // Fórmula visual
        _buildFormula(scoreR),
        const SizedBox(height: 14),

        // Região
        _sectionTitle('Análise de Região', Icons.location_on_rounded),
        const SizedBox(height: 8),
        _buildRegiaoCard(regiaoR),
        const SizedBox(height: 14),

        // Probabilidades
        _sectionTitle('Probabilidades de Sinistro', Icons.pie_chart_rounded),
        const SizedBox(height: 8),
        _buildProbCards(),
        const SizedBox(height: 14),

        // Explicação narrativa
        _sectionTitle('Explicação da Cotação', Icons.chat_bubble_rounded),
        const SizedBox(height: 8),
        _buildExplicacao(explR),
      ],
    );
  }

  Widget _buildScoreGauge(ScoreResult sr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(sr.classe.index == 0 ? const Color(0xFF22C55E) : sr.classe.index == 1 ? const Color(0xFF84CC16) : sr.classe.index == 2 ? const Color(0xFFF59E0B) : sr.classe.index == 3 ? const Color(0xFFF97316) : const Color(0xFFEF4444)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(sr.scoreFmt,
                style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w900,
                  color: _result!.score.classColor,
                  letterSpacing: -1,
                )),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClassBadgeLarge(sr.classe),
                  const SizedBox(height: 4),
                  Text(sr.classe.descricao,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _result!.score.progressNormalized,
              backgroundColor: AppTheme.border,
              color: _result!.score.classColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0.80 (mín)', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
              Text(sr.resumo, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              const Text('2.50 (máx)', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassTable(RiskClass atual) {
    const classes = [
      (RiskClass.A, '0,00 – 1,20', '4% FIPE', 'Mínimo'),
      (RiskClass.B, '1,21 – 1,50', '5% FIPE', 'Baixo'),
      (RiskClass.C, '1,51 – 1,80', '6% FIPE', 'Moderado'),
      (RiskClass.D, '1,81 – 2,20', '8% FIPE', 'Alto'),
      (RiskClass.E, '> 2,20',      '10% FIPE','Crítico'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 30),
                Expanded(child: Text('Score', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
                Expanded(child: Text('Franquia', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
                Expanded(child: Text('Risco', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
              ],
            ),
          ),
          ...classes.map((c) {
            final isAtual = c.$1 == atual;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isAtual ? c.$1.color.withValues(alpha: 0.08) : null,
                border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: isAtual ? c.$1.color : c.$1.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(c.$1.name,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: isAtual ? Colors.white : c.$1.color,
                      )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.$2, style: TextStyle(
                    fontSize: 11,
                    fontWeight: isAtual ? FontWeight.w700 : FontWeight.w400,
                    color: isAtual ? AppTheme.text : AppTheme.textMuted,
                  ))),
                  Expanded(child: Text(c.$3, style: TextStyle(
                    fontSize: 11,
                    fontWeight: isAtual ? FontWeight.w700 : FontWeight.w400,
                    color: isAtual ? c.$1.color : AppTheme.textMuted,
                  ))),
                  Expanded(child: Text(c.$4, style: TextStyle(
                    fontSize: 11,
                    fontWeight: isAtual ? FontWeight.w700 : FontWeight.w400,
                    color: isAtual ? AppTheme.text : AppTheme.textMuted,
                  ))),
                  if (isAtual)
                    const Icon(Icons.arrow_left_rounded, size: 16, color: AppTheme.primary),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFatorCard(ScoreFator f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: f.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(f.icon, size: 14, color: f.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.nome,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    Text(f.descricao,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(f.valorFmt,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: f.color)),
                  Text('peso ${f.pesoFmt}',
                    style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: f.barWidth,
              backgroundColor: AppTheme.border,
              color: f.color,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Contribuição: ×${f.contribuicao.toStringAsFixed(3)}',
                style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
              Text(f.valor <= 1.0 ? '✓ Desconto' : f.valor <= 1.2 ? '→ Neutro' : '↑ Acréscimo',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: f.color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormula(ScoreResult sr) {
    final s = _result!.score;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.code_rounded, size: 13, color: Colors.white54),
            SizedBox(width: 6),
            Text('FÓRMULA ATUARIAL v3',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white54, letterSpacing: 0.06)),
          ]),
          const SizedBox(height: 10),
          _codeRow('F1 Veículo',      s.fVeiculo,       '×0.20', s.fVeiculo * 0.20),
          _codeRow('F2 Idade Veíc.',  s.fIdadeVeiculo,  '×0.10', s.fIdadeVeiculo * 0.10),
          _codeRow('F3 Condutor',     s.fCondutor,      '×0.25', s.fCondutor * 0.25),
          _codeRow('F4 Uso/Expo.',    s.fUso,           '×0.20', s.fUso * 0.20),
          _codeRow('F5 Região',       s.fRegiao,        '×0.18', s.fRegiao * 0.18),
          _codeRow('F6 Telemetria',   s.fTelemetria,    '×0.07', s.fTelemetria * 0.07),
          Container(height: 1, color: Colors.white12, margin: const EdgeInsets.symmetric(vertical: 6)),
          Row(
            children: [
              Expanded(child: Text('× Franquia (${s.fFranquia.toStringAsFixed(2)})',
                style: const TextStyle(fontSize: 11, color: Colors.white70))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _result!.score.classColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('= ×${s.scoreTotal.toStringAsFixed(3)} ${sr.classe.name}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                    color: _result!.score.classColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _codeRow(String label, double fator, String peso, double contrib) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: 'monospace'))),
          Text('×${fator.toStringAsFixed(3)}',
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
          Text('  $peso',
            style: const TextStyle(fontSize: 10, color: Colors.white38)),
          const Spacer(),
          Text('+${contrib.toStringAsFixed(4)}',
            style: TextStyle(fontSize: 10, color: Colors.green.shade300)),
        ],
      ),
    );
  }

  Widget _buildRegiaoCard(RegiaoResult r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(r.cor),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: r.cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.location_city_rounded, color: r.cor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.cidade.isNotEmpty ? r.cidade : r.uf} · ${r.uf}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    Text(r.classificacao,
                      style: TextStyle(fontSize: 12, color: r.cor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('×${r.fatorRegiao.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: r.cor)),
                  const Text('fator região', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            _indexChip('Roubo', r.indiceRoubo, Icons.car_crash_rounded),
            const SizedBox(width: 8),
            _indexChip('Colisão', r.indiceColisao, Icons.merge_rounded),
          ]),
          const SizedBox(height: 10),
          // Alertas
          ...r.alertas.map((a) => _alertRow(a, Icons.warning_amber_rounded, const Color(0xFFF97316))),
          ...r.pontosBons.map((b) => _alertRow(b, Icons.check_circle_rounded, const Color(0xFF22C55E))),
        ],
      ),
    );
  }

  Widget _indexChip(String label, double idx, IconData icon) {
    final pct  = (idx * 100).round();
    final color = idx > 0.60 ? const Color(0xFFEF4444)
                : idx > 0.40 ? const Color(0xFFF97316)
                : idx > 0.25 ? const Color(0xFFF59E0B)
                : const Color(0xFF22C55E);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
          ]),
        ]),
      ),
    );
  }

  Widget _alertRow(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.text))),
        ],
      ),
    );
  }

  Widget _buildProbCards() {
    if (_result == null) return const SizedBox();
    final p = _result!.probs;
    return Row(children: [
      _probChip('Roubo',     p.pRoubo,       Icons.car_crash_rounded),
      const SizedBox(width: 6),
      _probChip('Furto',     p.pFurto,       Icons.no_transfer_rounded),
      const SizedBox(width: 6),
      _probChip('Colisão',   p.pColisao,     Icons.merge_rounded),
      const SizedBox(width: 6),
      _probChip('3eiros',    p.pTerceiros,   Icons.people_rounded),
    ]);
  }

  Widget _probChip(String label, double prob, IconData icon) {
    final color = prob < 0.005 ? const Color(0xFF22C55E)
                : prob < 0.015 ? const Color(0xFFF59E0B)
                : prob < 0.04  ? const Color(0xFFF97316)
                : const Color(0xFFEF4444);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(prob < 0.001 ? '<0.1%' : '${(prob * 100).toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        ]),
      ),
    );
  }

  Widget _buildExplicacao(ExplicacaoResult exp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Text(exp.resumoExecutivo,
            style: const TextStyle(fontSize: 12, color: AppTheme.text, height: 1.5)),
        ),
        const SizedBox(height: 8),
        ...exp.itens.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(item.icon, size: 14, color: item.cor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titulo,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    const SizedBox(height: 3),
                    Text(item.texto,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 2 — PRÊMIO
  // ═══════════════════════════════════════════════════════════

  Widget _buildTabPremio() {
    if (_result == null) return const SizedBox();
    final premioR = AtuarioIA.calcularPremio(_buildInput, kmViagem: 25);
    final p = _result!.premium;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        // Card principal de prêmio
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('TAXA POR KM RODADO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.white60, letterSpacing: 0.08)),
              const SizedBox(height: 8),
              Text(p.taxaFinalKmFmt,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 4),
              Text('Base: R\$ ${p.taxaBaseKm.toStringAsFixed(2)}/km × ×${_result!.score.scoreTotal.toStringAsFixed(2)} score',
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
              const SizedBox(height: 16),
              Row(children: [
                _premioHCard('Viagem\n25 km', premioR.premioViagemFmt, Icons.route_rounded),
                const SizedBox(width: 8),
                _premioHCard('Mensal\nest.', premioR.premioMensalFmt, Icons.calendar_month_rounded),
                const SizedBox(width: 8),
                _premioHCard('Anual\nest.', premioR.premioAnualFmt, Icons.workspace_premium_rounded),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Simulador de viagens
        _sectionTitle('Simulador de Prêmio por Distância', Icons.calculate_rounded),
        const SizedBox(height: 8),
        _buildSimulador(),
        const SizedBox(height: 14),

        // Divisão de receita
        _sectionTitle('Divisão de Receita Mensal', Icons.pie_chart_rounded),
        const SizedBox(height: 8),
        _buildDivisaoReceita(),
        const SizedBox(height: 14),

        // Comparativo de classes
        _sectionTitle('Prêmio por Classe (comparativo)', Icons.compare_arrows_rounded),
        const SizedBox(height: 8),
        _buildComparativoClasses(),
      ],
    );
  }

  Widget _premioHCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(height: 6),
            Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
              textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulador() {
    final distancias = [5.0, 10.0, 20.0, 30.0, 50.0, 100.0];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 60, child: Text('KM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
                Expanded(child: Text('Prêmio Viagem', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
                Expanded(child: Text('R\$/km', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
              ],
            ),
          ),
          ...distancias.map((km) {
            final premio = _result!.premium.premioViagem(km);
            final taxa   = _result!.premium.taxaFinalKm;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
              ),
              child: Row(children: [
                SizedBox(width: 60,
                  child: Text('${km.round()} km',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text))),
                Expanded(child: Text(
                  'R\$ ${premio.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary))),
                Expanded(child: Text(
                  'R\$ ${taxa.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDivisaoReceita() {
    if (_result == null) return const SizedBox();
    final p = _result!.premium;
    final items = [
      ('Seguradora', p.comissaoSeguradora, '55%', const Color(0xFF1A56DB)),
      ('Fundo Sinistro', p.fundoSinistro, '20%', const Color(0xFFEF4444)),
      ('SixTech', p.comissaoSixtech, '15%', const Color(0xFF8B5CF6)),
      ('Reserva', p.reservaTecnica, '10%', const Color(0xFF22C55E)),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Barra visual de divisão
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: items.map((i) => Expanded(
                flex: (double.parse(i.$3.replaceAll('%',''))).round(),
                child: Container(height: 14, color: i.$4),
              )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: i.$4, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(i.$1, style: const TextStyle(fontSize: 12, color: AppTheme.text))),
              Text(i.$3, style: TextStyle(fontSize: 11, color: i.$4, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text(
                'R\$ ${i.$2.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text)),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildComparativoClasses() {
    final taxa = 0.06; // taxa base
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: RiskClass.values.map((cls) {
          final minScore = [0.80, 1.21, 1.51, 1.81, 2.21][cls.index];
          final taxaKm   = taxa * minScore;
          final premMens = taxaKm * _kmMes;
          final isAtual  = cls == _result!.riskClass;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isAtual ? cls.color.withValues(alpha: 0.07) : null,
              border: Border(top: BorderSide(
                color: cls.index == 0 ? Colors.transparent : AppTheme.border, width: 0.5)),
              borderRadius: cls.index == 0
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : cls.index == 4 ? const BorderRadius.vertical(bottom: Radius.circular(12)) : null,
            ),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: isAtual ? cls.color : cls.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(cls.name,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: isAtual ? Colors.white : cls.color)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Score ×${minScore.toStringAsFixed(2)}+',
                style: TextStyle(
                  fontSize: 11,
                  color: isAtual ? AppTheme.text : AppTheme.textMuted,
                  fontWeight: isAtual ? FontWeight.w600 : FontWeight.w400,
                ))),
              Text('R\$ ${taxaKm.toStringAsFixed(4)}/km',
                style: TextStyle(fontSize: 11, color: isAtual ? cls.color : AppTheme.textMuted,
                  fontWeight: isAtual ? FontWeight.w700 : FontWeight.w400)),
              const SizedBox(width: 10),
              Text(
                'R\$ ${premMens.toStringAsFixed(0)}/mês',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: isAtual ? cls.color : AppTheme.textMuted)),
              if (isAtual)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.arrow_left_rounded, size: 14, color: AppTheme.primary)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 3 — FRANQUIA
  // ═══════════════════════════════════════════════════════════

  Widget _buildTabFranquia() {
    if (_result == null) return const SizedBox();
    final franqR = AtuarioIA.definirFranquia(_buildInput);
    final p      = _result!.premium;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        // Card destaque
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDeco(_result!.score.classColor),
          child: Column(
            children: [
              Row(children: [
                _ClassBadgeLarge(_result!.riskClass),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Franquia ${p.franquiaTipo.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    Text(p.franquiaPctFmt,
                      style: TextStyle(fontSize: 12, color: _result!.score.classColor, fontWeight: FontWeight.w600)),
                  ],
                )),
                Text(p.franquiaFmt,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _result!.score.classColor)),
              ]),
              const SizedBox(height: 12),
              Text(franqR.recomendacao,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tabela de opções
        _sectionTitle('Opções de Franquia Disponíveis', Icons.table_chart_rounded),
        const SizedBox(height: 8),
        _buildTabelaFranquia(franqR),
        const SizedBox(height: 14),

        // Franquia dinâmica por classe
        _sectionTitle('Franquia Dinâmica por Classe de Risco', Icons.dynamic_form_rounded),
        const SizedBox(height: 8),
        _buildFranquiaDinamicaTable(),
        const SizedBox(height: 14),

        // Como funciona
        _sectionTitle('Como Funciona a Franquia SafeRouteGo', Icons.info_outline_rounded),
        const SizedBox(height: 8),
        _buildFranquiaInfo(),
      ],
    );
  }

  Widget _buildTabelaFranquia(FranquiaResult fr) {
    final tipos = [
      (FranchiseType.reduzida, 'Reduzida', 'Menor franquia · prêmio maior', Icons.keyboard_arrow_down_rounded),
      (FranchiseType.normal,   'Normal',   'Franquia padrão da classe', Icons.remove_rounded),
      (FranchiseType.dinamica, 'Dinâmica', 'Ajusta automaticamente pelo perfil', Icons.autorenew_rounded),
      (FranchiseType.majorada, 'Majorada', 'Maior franquia · prêmio menor -20%', Icons.keyboard_arrow_up_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: tipos.map((t) {
          final isAtual = t.$1 == _franchiseType;
          final valor   = fr.alternativas[t.$1] ?? 0;
          return GestureDetector(
            onTap: () => setState(() {
              _franchiseType = t.$1;
              _calcular();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isAtual ? AppTheme.primary.withValues(alpha: 0.06) : null,
                border: Border(top: BorderSide(
                  color: t.$1.index == 0 ? Colors.transparent : AppTheme.border, width: 0.5)),
                borderRadius: t.$1.index == 0
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : t.$1.index == 3 ? const BorderRadius.vertical(bottom: Radius.circular(12)) : null,
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isAtual ? AppTheme.primary : AppTheme.textMuted).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(t.$4, size: 14, color: isAtual ? AppTheme.primary : AppTheme.textMuted),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.$2, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isAtual ? AppTheme.primary : AppTheme.text)),
                    Text(t.$3, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R\$ ${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\b)'), (m) => '${m[1]}.')}',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: isAtual ? AppTheme.primary : AppTheme.textMuted)),
                    Text(
                      '${(FranchiseConfig.pctByClass(_result!.riskClass, t.$1) * 100).round()}% FIPE',
                      style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(width: 6),
                if (isAtual)
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primary)
                else
                  const Icon(Icons.radio_button_unchecked_rounded, size: 18, color: AppTheme.border),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFranquiaDinamicaTable() {
    const fipe = 80000.0;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(children: [
            SizedBox(width: 30, child: Text('', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
            Expanded(child: Text('Score', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
            Expanded(child: Text('% FIPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
            Expanded(child: Text('Franquia (R\$80k)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted))),
          ]),
        ),
        ...RiskClass.values.map((cls) {
          final pct   = FranchiseConfig.pctByClass(cls, FranchiseType.dinamica);
          final valor = fipe * pct;
          final isAtual = cls == _result!.riskClass;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isAtual ? cls.color.withValues(alpha: 0.07) : null,
              border: const Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
            ),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: isAtual ? cls.color : cls.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: Text(cls.name, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: isAtual ? Colors.white : cls.color)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(AtuarioIA.descricaoClasse(cls).split('→').last.trim(),
                style: TextStyle(fontSize: 10,
                  color: isAtual ? AppTheme.text : AppTheme.textMuted))),
              Expanded(child: Text('${(pct*100).round()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isAtual ? cls.color : AppTheme.textMuted))),
              Expanded(child: Text('R\$ ${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\b)'), (m) => '${m[1]}.')}',
                style: TextStyle(fontSize: 11, fontWeight: isAtual ? FontWeight.w700 : FontWeight.w400,
                  color: isAtual ? cls.color : AppTheme.textMuted))),
              if (isAtual) const Icon(Icons.arrow_left_rounded, size: 14, color: AppTheme.primary),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildFranquiaInfo() {
    const itens = [
      (Icons.info_rounded, 'O que é Franquia?',
       'É o valor que o segurado paga em caso de sinistro antes da seguradora cobrir o restante. Quanto maior a franquia, menor o prêmio.'),
      (Icons.dynamic_form_rounded, 'Franquia Dinâmica SafeRouteGo',
       'A franquia é calculada automaticamente pelo seu perfil de risco. Condutor seguro (Classe A) paga 4% FIPE; alto risco (Classe E) paga 10% FIPE.'),
      (Icons.savings_rounded, 'Estratégia de Economia',
       'Optar pela Franquia Majorada reduz o prêmio em ~20%, mas você assume mais risco em caso de sinistro. Indicado para quem tem reserva financeira.'),
    ];
    return Column(
      children: itens.map((i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i.$1, size: 16, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.text)),
                const SizedBox(height: 3),
                Text(i.$3, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4)),
              ],
            )),
          ],
        ),
      )).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 4 — SUGESTÕES DO ATUÁRIO IA
  // ═══════════════════════════════════════════════════════════

  Widget _buildTabSugestoes() {
    if (_result == null) return const SizedBox();
    final sugR = AtuarioIA.sugerirReducoes(_buildInput);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        // Banner economia
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.savings_rounded, size: 36, color: Colors.white),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Economia Potencial',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                Text('até ${sugR.economiaMaxEstimada.round()}% no prêmio',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                Text(sugR.mensagem,
                  style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 2),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 14),

        _sectionTitle('Sugestões do Atuário IA', Icons.lightbulb_rounded),
        const SizedBox(height: 8),

        ...sugR.sugestoes.map((s) => _buildSugestaoCard(s)),

        const SizedBox(height: 14),
        // Reprecificação simulada
        _sectionTitle('Simulação de Reprecificação Mensal', Icons.autorenew_rounded),
        const SizedBox(height: 8),
        _buildReprecificacao(),
      ],
    );
  }

  Widget _buildSugestaoCard(Sugestao s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.priorityColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: s.priorityColor.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: s.priorityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s.icon, size: 20, color: s.priorityColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(s.titulo,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s.economia,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.priorityColor)),
                  ),
                ]),
                const SizedBox(height: 5),
                Text(s.descricao,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: s.priorityColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s.priorityLabel,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: s.priorityColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReprecificacao() {
    final reprec = AtuarioIA.reprecificarMensal(
      inputBase:              _buildInput,
      kmRealRodado:           _kmMes * 0.85,    // simulado -15%
      telemetryAcumulado:     _telemetryScore + 30,
      sinistrosNoMes:         0,
    );

    final cor = reprec.reducao ? const Color(0xFF22C55E) : const Color(0xFFF97316);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(cor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.autorenew_rounded, size: 14, color: cor),
            const SizedBox(width: 6),
            Text('Simulação: mês seguinte',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _reprecCard('Mês Atual', reprec.premioAnteriorFmt, AppTheme.textMuted)),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.textMuted),
            Expanded(child: _reprecCard('Próximo Mês', reprec.premioNovoFmt, cor)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(reprec.reducao ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                size: 16, color: cor),
              const SizedBox(width: 6),
              Text('${reprec.variacaoFmt} (${reprec.variacaoPctFmt})',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cor)),
            ]),
          ),
          const SizedBox(height: 8),
          Text(reprec.motivo, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 6),
          ...reprec.detalhe.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              Icon(Icons.fiber_manual_record_rounded, size: 7, color: cor),
              const SizedBox(width: 6),
              Expanded(child: Text(d, style: const TextStyle(fontSize: 11, color: AppTheme.text))),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _reprecCard(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 5 — PARÂMETROS
  // ═══════════════════════════════════════════════════════════

  Widget _buildTabParametros() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _sectionTitle('Veículo', Icons.directions_car_rounded),
        const SizedBox(height: 8),
        _buildParamCard([
          _sliderParam('FIPE (R\$)', _fipe, 20000, 500000,
            label: _fipeFormatado(_fipe),
            onChanged: (v) => setState(() { _fipe = v; _calcular(); })),
          _sliderParam('Ano de Fabricação', _anoFab.toDouble(), 2000, 2025,
            label: _anoFab.toString(),
            onChanged: (v) => setState(() { _anoFab = v.round(); _calcular(); })),
          _sliderParam('Índice de Roubo do Modelo', _theftIdx, 0, 1,
            label: '${(_theftIdx*100).round()}%',
            onChanged: (v) => setState(() { _theftIdx = v; _calcular(); })),
          _dropdownParam<VehicleCategory>('Categoria', _categoria,
            VehicleCategory.values, (v) => v.categoryLabel,
            onChanged: (v) { _categoria = v!; _calcular(); }),
        ]),
        const SizedBox(height: 14),

        _sectionTitle('Condutor', Icons.person_rounded),
        const SizedBox(height: 8),
        _buildParamCard([
          _sliderParam('Idade', _driverIdade.toDouble(), 18, 75,
            label: '$_driverIdade anos',
            onChanged: (v) => setState(() { _driverIdade = v.round(); _calcular(); })),
          _sliderParam('Tempo de CNH (anos)', _cnhAnos.toDouble(), 0, 40,
            label: '$_cnhAnos anos',
            onChanged: (v) => setState(() { _cnhAnos = v.round(); _calcular(); })),
          _sliderParam('Score Interno', _scoreInterno.toDouble(), 0, 1000,
            label: '$_scoreInterno / 1000',
            onChanged: (v) => setState(() { _scoreInterno = v.round(); _calcular(); })),
          _sliderParam('Sinistros (últimos 3 anos)', _sinistros.toDouble(), 0, 10,
            label: _sinistros.toString(),
            onChanged: (v) => setState(() { _sinistros = v.round(); _calcular(); })),
        ]),
        const SizedBox(height: 14),

        _sectionTitle('Uso', Icons.speed_rounded),
        const SizedBox(height: 8),
        _buildParamCard([
          _sliderParam('KM / Mês', _kmMes, 100, 6000,
            label: '${_kmMes.round()} km',
            onChanged: (v) => setState(() { _kmMes = v; _calcular(); })),
          _dropdownParam<UsagePattern>('Padrão de Uso', _pattern,
            UsagePattern.values, (v) => v.patternLabel,
            onChanged: (v) { _pattern = v!; _calcular(); }),
          _dropdownParam<DrivingTimeSlot>('Horário Predominante', _timeSlot,
            DrivingTimeSlot.values, _slotLabel,
            onChanged: (v) { _timeSlot = v!; _calcular(); }),
        ]),
        const SizedBox(height: 14),

        _sectionTitle('Região', Icons.location_on_rounded),
        const SizedBox(height: 8),
        _buildParamCard([
          _dropdownParam<String>('Estado (UF)', _uf,
            ['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
             'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'],
            (v) => v, onChanged: (v) { _uf = v!; _calcular(); }),
        ]),
        const SizedBox(height: 14),

        _sectionTitle('Telemetria', Icons.sensors_rounded),
        const SizedBox(height: 8),
        _buildParamCard([
          _sliderParam('Score Telemetria', _telemetryScore.toDouble(), 0, 1000,
            label: '$_telemetryScore / 1000',
            onChanged: (v) => setState(() { _telemetryScore = v.round(); _calcular(); })),
        ]),
        const SizedBox(height: 14),

        // Botão resetar
        OutlinedButton.icon(
          onPressed: () => setState(() {
            final demo = ActuarialInputV3.demo;
            _fipe = demo.vehicle.fipeValue;
            _anoFab = demo.vehicle.anoFabricacao;
            _anoMod = demo.vehicle.anoModelo;
            _categoria = demo.vehicle.category;
            _theftIdx = demo.vehicle.theftIndex;
            _marca = demo.vehicle.brandName;
            _modelo = demo.vehicle.modelName;
            _driverIdade = demo.driver.idade;
            _cnhAnos = demo.driver.tempoCnhAnos;
            _sinistros = demo.driver.sinistrosUlt3Anos;
            _multas = demo.driver.multasUlt12Meses;
            _scoreInterno = demo.driver.scoreInterno;
            _kmMes = demo.usage.kmMes;
            _pattern = demo.usage.pattern;
            _timeSlot = demo.usage.primarySlot;
            _uf = demo.region.uf;
            _cidade = demo.region.cidade;
            _telemetryScore = demo.telemetryScore;
            _franchiseType = FranchiseType.dinamica;
            _calcular();
          }),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Resetar para Perfil Demo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(double.infinity, 0),
          ),
        ),
      ],
    );
  }

  Widget _buildParamCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _sliderParam(String title, double value, double min, double max,
      {required String label, required ValueChanged<double> onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min, max: max,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.border,
          ),
        ],
      ),
    );
  }

  Widget _dropdownParam<T>(String label, T value, List<T> options,
      String Function(T) labelFn, {required ValueChanged<T?> onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text))),
          DropdownButton<T>(
            value: value,
            items: options.map((o) => DropdownMenuItem<T>(
              value: o,
              child: Text(labelFn(o), style: const TextStyle(fontSize: 12)),
            )).toList(),
            onChanged: (v) { onChanged(v); setState(() {}); },
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: AppTheme.primary),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: AppTheme.textMuted, letterSpacing: 0.04)),
    ]);
  }

  BoxDecoration _cardDeco(Color accent) {
    return BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.25)),
    );
  }

  String _fipeFormatado(double v) {
    if (v >= 1000000) return 'R\$ ${(v/1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'R\$ ${(v/1000).toStringAsFixed(0)} mil';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  String _slotLabel(DrivingTimeSlot s) {
    switch (s) {
      case DrivingTimeSlot.manha:    return 'Manhã 06–12h';
      case DrivingTimeSlot.tarde:    return 'Tarde 12–18h';
      case DrivingTimeSlot.noite:    return 'Noite 18–22h';
      case DrivingTimeSlot.tardio:   return 'Tardio 22–02h';
      case DrivingTimeSlot.madrugada: return 'Madrugada 02–06h';
    }
  }

  // ignore: unused_element
  String _slotLabel2(DrivingTimeSlot slot) => _slotLabel(slot);
}

// Extensões de conveniência em RiskClass
extension RiskClassX on RiskClass {
  Color get color {
    switch (this) {
      case RiskClass.A: return const Color(0xFF22C55E);
      case RiskClass.B: return const Color(0xFF84CC16);
      case RiskClass.C: return const Color(0xFFF59E0B);
      case RiskClass.D: return const Color(0xFFF97316);
      case RiskClass.E: return const Color(0xFFEF4444);
    }
  }

  String get descricao {
    switch (this) {
      case RiskClass.A: return 'Risco Mínimo — perfil excelente';
      case RiskClass.B: return 'Risco Baixo — perfil bom';
      case RiskClass.C: return 'Risco Moderado — perfil regular';
      case RiskClass.D: return 'Risco Alto — requer atenção';
      case RiskClass.E: return 'Risco Crítico — cobertura majorada';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE DE CLASSE GRANDE
// ─────────────────────────────────────────────────────────────────────────────

class _ClassBadgeLarge extends StatelessWidget {
  final RiskClass cls;
  const _ClassBadgeLarge(this.cls);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cls.color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cls.color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CLASSE',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: cls.color)),
          Text(cls.name,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cls.color)),
        ],
      ),
    );
  }
}

// extensão patternLabel em UsagePattern
extension UsagePatternX on UsagePattern {
  String get patternLabel {
    switch (this) {
      case UsagePattern.trabalho:  return 'Trabalho / Diário';
      case UsagePattern.lazer:     return 'Lazer / FDS';
      case UsagePattern.app:       return 'App de Transporte';
      case UsagePattern.misto:     return 'Uso Misto';
      case UsagePattern.baixoUso:  return 'Baixo Uso';
    }
  }
}

extension VehicleCategoryX on VehicleCategory {
  String get categoryLabel {
    switch (this) {
      case VehicleCategory.popular:       return 'Popular';
      case VehicleCategory.intermediario: return 'Intermediário';
      case VehicleCategory.suv:           return 'SUV / Crossover';
      case VehicleCategory.luxo:          return 'Luxo';
      case VehicleCategory.superLuxo:     return 'Super Luxo';
      case VehicleCategory.eletrico:      return 'Elétrico';
      case VehicleCategory.moto:          return 'Moto';
      case VehicleCategory.caminhao:      return 'Caminhão';
    }
  }
}

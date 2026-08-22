// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — SAFE MAP SCREEN V1
// Mapa Nacional de Risco: Nação / Cidades / Veículos / Horários / IA Risk
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/safe_map_engine.dart';
import '../widgets/live_gps_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SafeMapScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SafeMapScreen({super.key, required this.onBack});

  @override
  State<SafeMapScreen> createState() => _SafeMapScreenState();
}

class _SafeMapScreenState extends State<SafeMapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) {
        setState(() => _tabIndex = _tab.index);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
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
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  _MyLocationTab(),
                  _NacaoTab(),
                  _CidadesTab(),
                  _VeiculosTab(),
                  _HorariosTab(),
                  _RiskAITab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppTheme.text),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A56DB), Color(0xFF00C2A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safe Map',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text)),
                Text('Banco Nacional de Risco',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          _buildUpdateBadge(),
        ],
      ),
    );
  }

  Widget _buildUpdateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text('Live',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF22C55E))),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (Icons.my_location_rounded, 'Minha Posição'),
      (Icons.public_rounded, 'Nação'),
      (Icons.location_city_rounded, 'Cidades'),
      (Icons.directions_car_rounded, 'Veículos'),
      (Icons.schedule_rounded, 'Horários'),
      (Icons.psychology_rounded, 'Risk AI'),
    ];

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2.5,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.only(left: 4),
        tabs: tabs
            .map((t) => Tab(
                  height: 42,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$1, size: 14),
                      const SizedBox(width: 5),
                      Text(t.$2),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 0 — MINHA POSIÇÃO (GPS em tempo real + BnL Geolocation API)
// ─────────────────────────────────────────────────────────────────────────────

class _MyLocationTab extends StatelessWidget {
  const _MyLocationTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Painel GPS com mapa ao vivo
          const LiveGpsPanel(),
          // Info sobre a API
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBD6F5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.api_rounded, size: 16, color: Color(0xFF1565C0)),
                      const SizedBox(width: 6),
                      const Text(
                        'Boxes\'n\'Lines Geolocation API',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _BnLEndpointRow(
                    method: 'GET',
                    path: '/geo/subdivision/fromGps/{lat},{lon}',
                    desc: 'Retorna o estado (UF) a partir de coordenadas GPS',
                    example: '"BR-SP" → São Paulo',
                  ),
                  const SizedBox(height: 4),
                  _BnLEndpointRow(
                    method: 'GET',
                    path: '/geo/country/fromGps/{lat},{lon}',
                    desc: 'Retorna o país a partir de coordenadas GPS',
                    example: '"BRA" → Brasil',
                  ),
                  const SizedBox(height: 4),
                  _BnLEndpointRow(
                    method: 'GET',
                    path: '/geo/country/BRA/isInCountry',
                    desc: 'Verifica se as coordenadas estão no Brasil',
                    example: 'true / false',
                  ),
                  const SizedBox(height: 4),
                  _BnLEndpointRow(
                    method: 'GET',
                    path: '/geo/subdivision/BR-SP/isInSubdivision',
                    desc: 'Verifica se as coordenadas estão em um estado específico',
                    example: 'true / false',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BnLEndpointRow extends StatelessWidget {
  final String method;
  final String path;
  final String desc;
  final String example;
  const _BnLEndpointRow({
    required this.method,
    required this.path,
    required this.desc,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            method,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                path,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFF1565C0),
                ),
              ),
              Text(
                '$desc → $example',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — NAÇÃO (Visão Nacional dos Estados)
// ─────────────────────────────────────────────────────────────────────────────

class _NacaoTab extends StatefulWidget {
  const _NacaoTab();

  @override
  State<_NacaoTab> createState() => _NacaoTabState();
}

class _NacaoTabState extends State<_NacaoTab> {
  String _sortBy = 'score'; // score | nome | roubos | acidentes

  List<StateRisk> get _sortedStates {
    final list = List<StateRisk>.from(SafeMapDatabase.states);
    switch (_sortBy) {
      case 'nome':
        list.sort((a, b) => a.nome.compareTo(b.nome));
      case 'roubos':
        list.sort((a, b) => b.roubosAno.compareTo(a.roubosAno));
      case 'acidentes':
        list.sort((a, b) => b.acidentesAno.compareTo(a.acidentesAno));
      default:
        list.sort((a, b) => b.score.compareTo(a.score));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNationalKPIs(),
          const SizedBox(height: 16),
          _buildScoreLegend(),
          const SizedBox(height: 16),
          _buildSectionHeader('Ranking Nacional por Estado', sortable: true),
          const SizedBox(height: 8),
          ..._sortedStates.map((s) => _StateRiskRow(state: s)),
          const SizedBox(height: 16),
          _buildTopCritical(),
          const SizedBox(height: 8),
          _buildTopSafe(),
          const SizedBox(height: 16),
          _buildDataSources(),
        ],
      ),
    );
  }

  Widget _buildNationalKPIs() {
    final states = SafeMapDatabase.states;
    final avgScore =
        states.fold(0, (s, e) => s + e.score) ~/ states.length;
    final totalRoubos =
        states.fold(0, (s, e) => s + e.roubosAno);
    final totalAcidentes =
        states.fold(0, (s, e) => s + e.acidentesAno);
    final cls = SafeScoreClass.fromScore(avgScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Text('Brasil — Panorama Nacional',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cls.color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(cls.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _KpiBox(
                label: 'Score Médio',
                value: '$avgScore',
                sub: '/ 1000',
                icon: Icons.speed_rounded,
                light: true,
              ),
              const SizedBox(width: 8),
              _KpiBox(
                label: 'Roubos/Ano',
                value: _fmt(totalRoubos),
                sub: 'nacionais',
                icon: Icons.warning_rounded,
                light: true,
              ),
              const SizedBox(width: 8),
              _KpiBox(
                label: 'Acidentes/Ano',
                value: _fmt(totalAcidentes),
                sub: 'nacionais',
                icon: Icons.car_crash_rounded,
                light: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiBox(
                label: 'Estados Críticos',
                value: '${states.where((s) => s.score > 700).length}',
                sub: 'score > 700',
                icon: Icons.dangerous_rounded,
                light: true,
              ),
              const SizedBox(width: 8),
              _KpiBox(
                label: 'Estados Seguros',
                value: '${states.where((s) => s.score < 400).length}',
                sub: 'score < 400',
                icon: Icons.verified_rounded,
                light: true,
              ),
              const SizedBox(width: 8),
              _KpiBox(
                label: 'Cobertura',
                value: '${states.length}',
                sub: 'estados',
                icon: Icons.map_rounded,
                light: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreLegend() {
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
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text('Escala de Score (0–1000)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: SafeScoreClass.values
                .map((c) => Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: c.bgColor,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: c.color.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Icon(c.icon, color: c.color, size: 14),
                            const SizedBox(height: 2),
                            Text(c.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: c.color)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool sortable = false}) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.text)),
        const Spacer(),
        if (sortable)
          GestureDetector(
            onTap: () => _showSortMenu(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.sort_rounded,
                      size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                      _sortBy == 'score'
                          ? 'Score'
                          : _sortBy == 'nome'
                              ? 'Nome'
                              : _sortBy == 'roubos'
                                  ? 'Roubos'
                                  : 'Acidentes',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ordenar por',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text)),
            const SizedBox(height: 12),
            ...['score', 'nome', 'roubos', 'acidentes'].map((opt) {
              final labels = {
                'score': 'Score de Risco',
                'nome': 'Nome (A-Z)',
                'roubos': 'Roubos/Ano',
                'acidentes': 'Acidentes/Ano'
              };
              return ListTile(
                dense: true,
                leading: Icon(
                    _sortBy == opt
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: _sortBy == opt
                        ? AppTheme.primary
                        : AppTheme.textMuted,
                    size: 20),
                title: Text(labels[opt]!,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.text)),
                onTap: () {
                  setState(() => _sortBy = opt);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCritical() {
    final cities = SafeMapDatabase.topCriticalCities;
    return _RankingCard(
      title: 'Cidades mais Críticas',
      icon: Icons.dangerous_rounded,
      iconColor: const Color(0xFFEF4444),
      items: cities
          .take(5)
          .map((c) => _RankItem(
                label: '${c.nome} / ${c.uf}',
                value: c.score,
                isHighBad: true,
              ))
          .toList(),
    );
  }

  Widget _buildTopSafe() {
    final cities = SafeMapDatabase.topSafestCities;
    return _RankingCard(
      title: 'Cidades mais Seguras',
      icon: Icons.verified_rounded,
      iconColor: const Color(0xFF22C55E),
      items: cities
          .take(5)
          .map((c) => _RankItem(
                label: '${c.nome} / ${c.uf}',
                value: c.score,
                isHighBad: true,
                invert: true,
              ))
          .toList(),
    );
  }

  Widget _buildDataSources() {
    final sources = SafeMapUpdateEngine.sources;
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
          Row(
            children: [
              Icon(Icons.source_rounded, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Fontes de Dados',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sources.entries
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.update_rounded, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                  'Última atualização: ${_formatDate(SafeMapUpdateEngine.lastUpdate)}',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — CIDADES
// ─────────────────────────────────────────────────────────────────────────────

class _CidadesTab extends StatefulWidget {
  const _CidadesTab();

  @override
  State<_CidadesTab> createState() => _CidadesTabState();
}

class _CidadesTabState extends State<_CidadesTab> {
  String? _selectedState;
  String? _selectedCity;

  List<StateRisk> get _states => SafeMapDatabase.states
    ..sort((a, b) => a.nome.compareTo(b.nome));

  List<CityRisk> get _cities {
    if (_selectedState == null) return [];
    return SafeMapDatabase.citiesByState(_selectedState!)
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  List<DistrictRisk> get _districts {
    if (_selectedCity == null) return [];
    return SafeMapDatabase.districtsByCity(_selectedCity!)
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  CityRisk? get _cityData {
    if (_selectedCity == null) return null;
    try {
      return _cities.firstWhere((c) => c.id == _selectedCity);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          if (_selectedState == null) _buildAllCitiesRanking(),
          if (_selectedState != null && _selectedCity == null)
            _buildCitiesList(),
          if (_selectedCity != null) _buildCityDetail(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final sortedStates = List<StateRisk>.from(SafeMapDatabase.states)
      ..sort((a, b) => a.nome.compareTo(b.nome));
    return Row(
      children: [
        Expanded(
          child: _DropdownFilter(
            label: 'Estado',
            value: _selectedState,
            items: sortedStates
                .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.uf} — ${s.nome}',
                        style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedState = v;
              _selectedCity = null;
            }),
          ),
        ),
        if (_selectedState != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _DropdownFilter(
              label: 'Cidade',
              value: _selectedCity,
              items: _cities
                  .map((c) => DropdownMenuItem(
                      value: c.id,
                      child:
                          Text(c.nome, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCity = v),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAllCitiesRanking() {
    final all = List<CityRisk>.from(SafeMapDatabase.cities)
      ..sort((a, b) => b.score.compareTo(a.score));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Todas as Cidades — Ranking Nacional',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.text)),
        const SizedBox(height: 8),
        ...all.map((c) => _CityRiskRow(city: c)),
      ],
    );
  }

  Widget _buildCitiesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cidades — ${_states.firstWhere((s) => s.id == _selectedState).nome}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.text)),
        const SizedBox(height: 8),
        ..._cities.map((c) => _CityRiskRow(city: c)),
      ],
    );
  }

  Widget _buildCityDetail() {
    final city = _cityData;
    if (city == null) return const SizedBox.shrink();
    final cls = SafeScoreClass.fromScore(city.score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // City header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cls.bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cls.color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(cls.icon, color: cls.color, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(city.nome,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text)),
                        Text('${city.uf} · ${city.isMetropole ? 'Metrópole' : 'Cidade'}',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${city.score}',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: cls.color)),
                      Text(cls.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cls.color)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(
                      label: 'Roubos/ano',
                      value: _fmtNum(city.roubosAno),
                      color: const Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  _StatChip(
                      label: 'Furtos/ano',
                      value: _fmtNum(city.furtoAno),
                      color: const Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  _StatChip(
                      label: 'Acidentes/ano',
                      value: _fmtNum(city.acidentesAno),
                      color: const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Districts
        Text('Bairros de ${city.nome}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.text)),
        const SizedBox(height: 8),
        if (_districts.isEmpty)
          _EmptyState(
              message:
                  'Dados de bairros disponíveis apenas para cidades do ES por enquanto.')
        else
          ..._districts.map((d) => _DistrictCard(district: d)),
      ],
    );
  }

  String _fmtNum(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — VEÍCULOS
// ─────────────────────────────────────────────────────────────────────────────

class _VeiculosTab extends StatefulWidget {
  const _VeiculosTab();

  @override
  State<_VeiculosTab> createState() => _VeiculosTabState();
}

class _VeiculosTabState extends State<_VeiculosTab> {
  String _filter = 'roubo'; // roubo | furto | colisao | fipe

  List<VehicleRiskRecord> get _sorted {
    final list = List<VehicleRiskRecord>.from(SafeMapDatabase.vehicleRiskTable);
    switch (_filter) {
      case 'furto':
        list.sort((a, b) => b.theftScore.compareTo(a.theftScore));
      case 'colisao':
        list.sort((a, b) => b.collisionScore.compareTo(a.collisionScore));
      case 'fipe':
        list.sort((a, b) => b.fipeMediaMil.compareTo(a.fipeMediaMil));
      default:
        list.sort((a, b) => b.robberyScore.compareTo(a.robberyScore));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVehicleKpis(),
          const SizedBox(height: 16),
          _buildFilterRow(),
          const SizedBox(height: 8),
          ..._sorted.asMap().entries.map((e) => _VehicleRow(
                rank: e.key + 1,
                vehicle: e.value,
                filter: _filter,
              )),
          const SizedBox(height: 16),
          _buildVehicleInfo(),
        ],
      ),
    );
  }

  Widget _buildVehicleKpis() {
    final list = SafeMapDatabase.vehicleRiskTable;
    final topRoubo = SafeMapDatabase.topStolenVehicles.first;
    final avgRisk =
        list.fold(0, (s, v) => s + v.robberyScore) ~/ list.length;
    final topFipe = list.reduce((a, b) =>
        a.fipeMediaMil > b.fipeMediaMil ? a : b);

    return Row(
      children: [
        Expanded(
          child: _VehicleKpiCard(
            icon: Icons.car_crash_rounded,
            color: const Color(0xFFEF4444),
            label: 'Mais Roubado',
            value: topRoubo.modelo,
            sub: 'Score ${topRoubo.robberyScore}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _VehicleKpiCard(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFFF59E0B),
            label: 'Risco Médio',
            value: '$avgRisk',
            sub: 'score médio',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _VehicleKpiCard(
            icon: Icons.attach_money_rounded,
            color: const Color(0xFF1A56DB),
            label: 'Maior FIPE',
            value: topFipe.marca,
            sub: 'R\$ ${topFipe.fipeMediaMil.toStringAsFixed(0)}K',
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    final filters = [
      ('roubo', 'Roubo', Icons.car_crash_rounded),
      ('furto', 'Furto', Icons.car_repair_rounded),
      ('colisao', 'Colisão', Icons.fmd_bad_rounded),
      ('fipe', 'FIPE', Icons.attach_money_rounded),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map((f) => GestureDetector(
                  onTap: () => setState(() => _filter = f.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filter == f.$1
                          ? AppTheme.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _filter == f.$1
                              ? AppTheme.primary
                              : AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(f.$3,
                            size: 13,
                            color: _filter == f.$1
                                ? Colors.white
                                : AppTheme.textMuted),
                        const SizedBox(width: 5),
                        Text(f.$2,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _filter == f.$1
                                    ? Colors.white
                                    : AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Os scores são calculados com base em dados do SENASP, Detran e registros B.O. '
              'Veículos populares tendem a ter score de roubo mais alto por volume de frota. '
              'Modelos elétricos e importados têm maior risco de furto de peças.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — HORÁRIOS
// ─────────────────────────────────────────────────────────────────────────────

class _HorariosTab extends StatefulWidget {
  const _HorariosTab();

  @override
  State<_HorariosTab> createState() => _HorariosTabState();
}

class _HorariosTabState extends State<_HorariosTab> {
  int _selectedHour = DateTime.now().hour;

  @override
  Widget build(BuildContext context) {
    final hours = TimeRiskTable.allHours;
    final selected = hours.firstWhere((h) => h.key == _selectedHour,
        orElse: () => hours.first);
    final weight = selected.value;
    final cls = SafeScoreClass.fromScore((weight * 400).toInt().clamp(0, 1000));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHourKpi(selected, cls),
          const SizedBox(height: 16),
          _buildHourlyChart(hours),
          const SizedBox(height: 16),
          _buildHourSelector(hours),
          const SizedBox(height: 16),
          _buildPeakInfo(),
          const SizedBox(height: 16),
          _buildTimeInsights(),
        ],
      ),
    );
  }

  Widget _buildHourKpi(MapEntry<int, double> h, SafeScoreClass cls) {
    final lbl = TimeRiskTable.label(h.key);
    final col = TimeRiskTable.color(h.key);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${_selectedHour.toString().padLeft(2, '0')}h',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lbl,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text)),
                const SizedBox(height: 2),
                Text('Multiplicador de risco: ×${h.value.toStringAsFixed(1)}',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: h.value / 2.0,
                    backgroundColor: AppTheme.border,
                    color: col,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(List<MapEntry<int, double>> hours) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risco por Hora do Dia',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: hours.map((h) {
                final barH = (h.value / 2.0) * 90;
                final color = TimeRiskTable.color(h.key);
                final isSelected = h.key == _selectedHour;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedHour = h.key),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: barH,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color
                                : color.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                            border: isSelected
                                ? Border.all(color: color, width: 1.5)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (h.key % 6 == 0)
                          Text('${h.key}h',
                              style: TextStyle(
                                  fontSize: 8, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Toque em uma barra para ver detalhes',
                style: TextStyle(fontSize: 10, color: AppTheme.textLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildHourSelector(List<MapEntry<int, double>> hours) {
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
          Text('Tabela de Risco Horário',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text)),
          const SizedBox(height: 10),
          ...hours.map((h) {
            final col = TimeRiskTable.color(h.key);
            final lbl = TimeRiskTable.label(h.key);
            final isSelected = h.key == _selectedHour;
            return GestureDetector(
              onTap: () => setState(() => _selectedHour = h.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? col.withValues(alpha: 0.08) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: col.withValues(alpha: 0.4))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 22,
                      decoration: BoxDecoration(
                        color: col,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text('${h.key}h',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(lbl,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.text)),
                    ),
                    Text('×${h.value.toStringAsFixed(1)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: col)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: h.value / 2.0,
                          backgroundColor: AppTheme.border,
                          color: col,
                          minHeight: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPeakInfo() {
    final hours = TimeRiskTable.allHours;
    final maxH = hours.reduce((a, b) => a.value > b.value ? a : b);
    final minH = hours.reduce((a, b) => a.value < b.value ? a : b);

    return Row(
      children: [
        Expanded(
          child: _PeakCard(
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFEF4444),
            label: 'Horário Mais Perigoso',
            hour: maxH.key,
            weight: maxH.value,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PeakCard(
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF22C55E),
            label: 'Horário Mais Seguro',
            hour: minH.key,
            weight: minH.value,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInsights() {
    final insights = [
      (Icons.nightlight_round_rounded, const Color(0xFF6366F1),
          'Madrugada (22h–04h)',
          'Período de maior risco. Menor policiamento, vias vazias e maior vulnerabilidade a abordagens.'),
      (Icons.wb_twilight_rounded, const Color(0xFFF97316), 'Final de tarde (17h–19h)',
          'Hora do rush com congestionamentos. Aumenta risco de colisões e oportunidades para roubos em semáforos.'),
      (Icons.wb_sunny_rounded, const Color(0xFF22C55E), 'Manhã (07h–11h)',
          'Período mais seguro. Alta visibilidade, presença policial e movimento regular de pessoas.'),
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
          Text('Análise por Período',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text)),
          const SizedBox(height: 10),
          ...insights.map((ins) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ins.$2.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(ins.$1, color: ins.$2, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ins.$3,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.text)),
                          const SizedBox(height: 2),
                          Text(ins.$4,
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5 — RISK AI
// ─────────────────────────────────────────────────────────────────────────────

class _RiskAITab extends StatefulWidget {
  const _RiskAITab();

  @override
  State<_RiskAITab> createState() => _RiskAITabState();
}

class _RiskAITabState extends State<_RiskAITab> {
  // Simulator state
  int _age = 28;
  String _vehicle = 'HB20';
  int _hour = 20;
  String _city = 'Vitória';
  String _district = 'André Carloni';
  double _weatherScore = 0.5;
  double _driverScore = 850.0;
  double _distanceKm = 15.0;

  RiskAIPrediction? _prediction;

  static const List<String> _vehicles = [
    'HB20',
    'Onix',
    'Argo',
    'Kwid',
    'Polo',
    'Compass',
    'Corolla',
    'BYD Atto 2',
    'Tesla Model 3',
    'BMW X1'
  ];
  static const List<String> _cities = [
    'Vitória',
    'Serra',
    'Vila Velha',
    'Cariacica',
    'São Paulo',
    'Rio de Janeiro',
    'Salvador',
    'Recife',
    'Fortaleza',
    'Belo Horizonte',
    'Curitiba',
    'Porto Alegre'
  ];
  static const List<String> _districts = [
    'André Carloni',
    'Laranjeiras',
    'Centro',
    'Jardim Camburi',
    'Taquara I',
    'Bento Ferreira',
    'Jardim da Penha'
  ];

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _prediction = RiskAI.predict(
        driverAge: _age,
        vehicleModel: _vehicle,
        hour: _hour,
        cityName: _city,
        districtName: _district,
        weatherScore: (_weatherScore * 1000).round(),
        driverScore: _driverScore.round(),
        distanceKm: _distanceKm,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAIHeader(),
          const SizedBox(height: 16),
          if (_prediction != null) _buildPredictionCard(),
          const SizedBox(height: 16),
          _buildSimulator(),
          const SizedBox(height: 16),
          _buildDemoScenarios(),
          const SizedBox(height: 16),
          _buildAIModelInfo(),
        ],
      ),
    );
  }

  Widget _buildAIHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Risk AI — Motor de Predição',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('10M+ rotas analisadas',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(RiskAI.version,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    final p = _prediction!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Resultado da Predição',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                    'Confiança: ${(p.aiConfidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A56DB))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Main sinistro probability
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _probColor(p.sinistroChance).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _probColor(p.sinistroChance).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: _CircleProgress(
                    value: p.sinistroChance,
                    color: _probColor(p.sinistroChance),
                    label: '${(p.sinistroChance * 100).toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Probabilidade de Sinistro',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text)),
                      const SizedBox(height: 2),
                      Text(p.riskProfile,
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      Text(p.recommendation,
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 3 sub-probs
          Row(
            children: [
              Expanded(
                child: _ProbChipAI(
                    label: 'Roubo',
                    prob: p.rouboChance,
                    icon: Icons.car_crash_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ProbChipAI(
                    label: 'Furto',
                    prob: p.furtoChance,
                    icon: Icons.car_repair_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ProbChipAI(
                    label: 'Colisão',
                    prob: p.colisaoChance,
                    icon: Icons.fmd_bad_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Key factors
          Text('Fatores Determinantes',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.keyFactors
                .map((f) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(f,
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulator() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Simulador de Risco',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text)),
            ],
          ),
          const SizedBox(height: 14),
          // Row 1: Veículo + Cidade
          Row(
            children: [
              Expanded(
                child: _SimDropdown(
                  label: 'Veículo',
                  value: _vehicle,
                  items: _vehicles,
                  onChanged: (v) {
                    if (v != null) setState(() => _vehicle = v);
                    _calculate();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SimDropdown(
                  label: 'Cidade',
                  value: _city,
                  items: _cities,
                  onChanged: (v) {
                    if (v != null) setState(() => _city = v);
                    _calculate();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Bairro
          _SimDropdown(
            label: 'Bairro / Região',
            value: _district,
            items: _districts,
            onChanged: (v) {
              if (v != null) setState(() => _district = v);
              _calculate();
            },
          ),
          const SizedBox(height: 12),
          // Sliders
          _SliderRow(
            label: 'Horário',
            value: _hour.toDouble(),
            min: 0,
            max: 23,
            divisions: 23,
            format: (v) => '${v.toInt()}h',
            color: TimeRiskTable.color(_hour),
            onChanged: (v) {
              setState(() => _hour = v.toInt());
              _calculate();
            },
          ),
          _SliderRow(
            label: 'Idade do motorista',
            value: _age.toDouble(),
            min: 18,
            max: 70,
            divisions: 52,
            format: (v) => '${v.toInt()} anos',
            color: AppTheme.primary,
            onChanged: (v) {
              setState(() => _age = v.toInt());
              _calculate();
            },
          ),
          _SliderRow(
            label: 'Score do motorista',
            value: _driverScore,
            min: 0,
            max: 1000,
            divisions: 100,
            format: (v) => '${v.toInt()}',
            color: AppTheme.accent,
            onChanged: (v) {
              setState(() => _driverScore = v);
              _calculate();
            },
          ),
          _SliderRow(
            label: 'Condição climática',
            value: _weatherScore,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            format: (v) => v < 0.2
                ? 'Sol'
                : v < 0.5
                    ? 'Nublado'
                    : v < 0.8
                        ? 'Chuva'
                        : 'Temporal',
            color: const Color(0xFF3B82F6),
            onChanged: (v) {
              setState(() => _weatherScore = v);
              _calculate();
            },
          ),
          _SliderRow(
            label: 'Distância',
            value: _distanceKm,
            min: 1,
            max: 100,
            divisions: 99,
            format: (v) => '${v.toInt()} km',
            color: const Color(0xFF8B5CF6),
            onChanged: (v) {
              setState(() => _distanceKm = v);
              _calculate();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDemoScenarios() {
    final scenarios = [
      ('Risco Alto', 'Jovem, HB20, 22h, André Carloni', RiskAI.demoYoungHighRisk),
      ('Risco Baixo', 'Adulto, BYD, 14h, Laranjeiras', RiskAI.demoAdultLowRisk),
      ('Noturno', 'Meia-idade, Onix, 23h, Centro', RiskAI.demoNight),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cenários Demo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.text)),
        const SizedBox(height: 8),
        ...scenarios.map((s) => _ScenarioCard(
              label: s.$1,
              description: s.$2,
              prediction: s.$3,
            )),
      ],
    );
  }

  Widget _buildAIModelInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_rounded,
                  size: 14, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              const Text('Sobre o Modelo',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'O Risk AI usa modelo estatístico treinado com ${_fmtNum(RiskAI.trainingDataPoints)}+ eventos '
            'coletados de fontes públicas (SENASP, Detran, INMET). '
            'O modelo considera 7 variáveis: perfil do motorista, veículo, horário, localização, '
            'clima, histórico e distância. '
            'Versão ${RiskAI.version} — atualizado mensalmente.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Color _probColor(double p) {
    if (p < 0.02) return const Color(0xFF22C55E);
    if (p < 0.05) return const Color(0xFFF59E0B);
    if (p < 0.10) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String _fmtNum(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StateRiskRow extends StatelessWidget {
  final StateRisk state;
  const _StateRiskRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final cls = SafeScoreClass.fromScore(state.score);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cls.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(state.uf,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cls.color)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.nome,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text)),
                Text(
                    '${_fmt(state.roubosAno)} roubos · ${_fmt(state.acidentesAno)} acidentes/ano',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${state.score}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cls.color)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cls.bgColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(cls.label,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: cls.color)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _CityRiskRow extends StatelessWidget {
  final CityRisk city;
  const _CityRiskRow({required this.city});

  @override
  Widget build(BuildContext context) {
    final cls = SafeScoreClass.fromScore(city.score);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 38,
            decoration: BoxDecoration(
              color: cls.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(city.nome,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text)),
                    if (city.isMetropole) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Metro',
                            style: TextStyle(
                                fontSize: 8, color: AppTheme.textMuted)),
                      ),
                    ],
                  ],
                ),
                Text(
                    '${city.uf} · ${_fmt(city.roubosAno)} roubos · ${_fmt(city.furtoAno)} furtos/ano',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Text('${city.score}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cls.color)),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _DistrictCard extends StatelessWidget {
  final DistrictRisk district;
  const _DistrictCard({required this.district});

  @override
  Widget build(BuildContext context) {
    final cls = SafeScoreClass.fromScore(district.score);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cls.icon, color: cls.color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(district.nome,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cls.bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: cls.color.withValues(alpha: 0.4)),
                ),
                child: Text('${district.score} · ${cls.label}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cls.color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(label: 'Roubo', value: district.robberyScore, bad: true),
              const SizedBox(width: 6),
              _MiniStat(label: 'Furto', value: district.theftScore, bad: true),
              const SizedBox(width: 6),
              _MiniStat(label: 'Acidente', value: district.accidentScore, bad: true),
              const SizedBox(width: 6),
              _MiniStat(label: 'Clima', value: district.weatherScore, bad: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (district.hasCamera)
                _TagChip(label: 'Câmeras', color: const Color(0xFF22C55E)),
              if (district.hasPoliciamento) ...[
                const SizedBox(width: 4),
                _TagChip(
                    label: 'Policiamento',
                    color: const Color(0xFF3B82F6)),
              ],
              if (district.isPeriferica) ...[
                const SizedBox(width: 4),
                _TagChip(
                    label: 'Periférica',
                    color: const Color(0xFFF97316)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final int rank;
  final VehicleRiskRecord vehicle;
  final String filter;
  const _VehicleRow(
      {required this.rank, required this.vehicle, required this.filter});

  int get _score {
    switch (filter) {
      case 'furto':
        return vehicle.theftScore;
      case 'colisao':
        return vehicle.collisionScore;
      default:
        return vehicle.robberyScore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cls = SafeScoreClass.fromScore(_score);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                  : AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('#$rank',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: rank <= 3
                          ? const Color(0xFFF59E0B)
                          : AppTheme.textMuted)),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.directions_car_rounded,
              size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${vehicle.marca} ${vehicle.modelo}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text)),
                Text(
                    filter == 'fipe'
                        ? 'FIPE: R\$ ${vehicle.fipeMediaMil.toStringAsFixed(0)}K'
                        : '${vehicle.roubosAno} roubos/ano · FIPE R\$ ${vehicle.fipeMediaMil.toStringAsFixed(0)}K',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (filter != 'fipe') ...[
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$_score',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: cls.color)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _score / 1000,
                      backgroundColor: AppTheme.border,
                      color: cls.color,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
                'R\$ ${vehicle.fipeMediaMil.toStringAsFixed(0)}K',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
          ],
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_RankItem> items;
  const _RankingCard(
      {required this.title,
      required this.icon,
      required this.iconColor,
      required this.items});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text('#${e.key + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: e.key == 0
                                ? iconColor
                                : AppTheme.textMuted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.value.label,
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.text)),
                    ),
                    Text('${e.value.value}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: e.value.invert
                                ? SafeScoreClass.fromScore(e.value.value).color
                                : SafeScoreClass.fromScore(e.value.value)
                                    .color)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: e.value.value / 1000,
                          backgroundColor: AppTheme.border,
                          color: e.value.invert
                              ? SafeScoreClass.fromScore(e.value.value).color
                              : SafeScoreClass.fromScore(e.value.value).color,
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _RankItem {
  final String label;
  final int value;
  final bool isHighBad;
  final bool invert;
  const _RankItem(
      {required this.label,
      required this.value,
      this.isHighBad = false,
      this.invert = false});
}

class _KpiBox extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final bool light;
  const _KpiBox(
      {required this.label,
      required this.value,
      required this.sub,
      required this.icon,
      this.light = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: light
              ? Colors.white.withValues(alpha: 0.15)
              : AppTheme.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 14, color: light ? Colors.white70 : AppTheme.textMuted),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: light ? Colors.white : AppTheme.text)),
            Text(sub,
                style: TextStyle(
                    fontSize: 9,
                    color: light ? Colors.white60 : AppTheme.textMuted)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: light ? Colors.white70 : AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 9, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final bool bad;
  const _MiniStat(
      {required this.label, required this.value, this.bad = false});

  @override
  Widget build(BuildContext context) {
    final cls = SafeScoreClass.fromScore(value);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: cls.bgColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cls.color)),
            Text(label,
                style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppTheme.textMuted, size: 24),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _DropdownFilter(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          items: items,
          onChanged: onChanged,
          style: TextStyle(fontSize: 12, color: AppTheme.text),
          icon: Icon(Icons.expand_more_rounded,
              color: AppTheme.textMuted, size: 16),
        ),
      ),
    );
  }
}

class _SimDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _SimDropdown(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map((i) => DropdownMenuItem(
                      value: i,
                      child: Text(i,
                          style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: onChanged,
              style: TextStyle(fontSize: 12, color: AppTheme.text),
              icon: Icon(Icons.expand_more_rounded,
                  color: AppTheme.textMuted, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final Color color;
  final ValueChanged<double> onChanged;
  const _SliderRow(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      required this.divisions,
      required this.format,
      required this.color,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted)),
            const Spacer(),
            Text(format(value),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: AppTheme.border,
            overlayColor: color.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _VehicleKpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  const _VehicleKpiCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value,
      required this.sub});

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text)),
          Text(sub,
              style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _PeakCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int hour;
  final double weight;
  const _PeakCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.hour,
      required this.weight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted)),
                Text('${hour.toString().padLeft(2, '0')}h — ×${weight.toStringAsFixed(1)}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbChipAI extends StatelessWidget {
  final String label;
  final double prob;
  final IconData icon;
  const _ProbChipAI(
      {required this.label, required this.prob, required this.icon});

  Color get _color {
    if (prob < 0.02) return const Color(0xFF22C55E);
    if (prob < 0.05) return const Color(0xFFF59E0B);
    if (prob < 0.10) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _color, size: 14),
          const SizedBox(height: 3),
          Text('${(prob * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _color)),
          Text(label,
              style:
                  TextStyle(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final String label;
  final String description;
  final RiskAIPrediction prediction;
  const _ScenarioCard(
      {required this.label,
      required this.description,
      required this.prediction});

  Color get _color {
    final p = prediction.sinistroChance;
    if (p < 0.03) return const Color(0xFF22C55E);
    if (p < 0.07) return const Color(0xFFF59E0B);
    if (p < 0.12) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    '${(prediction.sinistroChance * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _color)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text)),
                Text(description,
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(prediction.riskProfile,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _color)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.textMuted, size: 16),
        ],
      ),
    );
  }
}

class _CircleProgress extends StatelessWidget {
  final double value;
  final Color color;
  final String label;
  const _CircleProgress(
      {required this.value, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CirclePainter(progress: value, color: color),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color)),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _CirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const startAngle = -math.pi / 2;

    // Background
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);

    // Progress
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progress * math.pi * 2,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.progress != progress || old.color != color;
}

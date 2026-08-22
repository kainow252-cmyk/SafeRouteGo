// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — VEHICLE PICKER WIDGET v1.0
// UI de seleção de veículo com integração FIPE em tempo real
//
// Fluxo: Tipo → Marca → Modelo → Ano → Valor FIPE ao vivo
// Fontes: BrasilAPI FIPE (primária) → parallelum (fallback) → offline kFipeDb
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/fipe_api_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE SAÍDA — resultado da seleção
// ─────────────────────────────────────────────────────────────────────────────

class VehicleSelection {
  final String tipo;         // 'carros' | 'motos' | 'caminhoes'
  final String marcaNome;
  final String modeloNome;
  final int anoModelo;
  final double valorFipe;
  final double franquia;
  final double premioBaseKm;
  final int idadeVeiculo;
  final double fatorIdade;
  final String codigoFipe;
  final String combustivel;
  final bool isOffline;      // true se veio do banco offline

  const VehicleSelection({
    required this.tipo,
    required this.marcaNome,
    required this.modeloNome,
    required this.anoModelo,
    required this.valorFipe,
    required this.franquia,
    required this.premioBaseKm,
    required this.idadeVeiculo,
    required this.fatorIdade,
    required this.codigoFipe,
    required this.combustivel,
    this.isOffline = false,
  });

  factory VehicleSelection.fromFipePreco(FipePreco p, String tipo) {
    return VehicleSelection(
      tipo: tipo,
      marcaNome: p.marca,
      modeloNome: p.modelo,
      anoModelo: p.anoModelo,
      valorFipe: p.valor,
      franquia: p.franquia,
      premioBaseKm: p.premioBasePorKm,
      idadeVeiculo: p.idadeVeiculo,
      fatorIdade: p.fatorIdade,
      codigoFipe: p.codigoFipe,
      combustivel: p.combustivel,
      isOffline: false,
    );
  }

  factory VehicleSelection.fromOffline(FipePrecoOffline off, String tipo) {
    final anoBase = off.anoBase;
    final idade = (DateTime.now().year - anoBase).clamp(0, 50);
    final fator = FipeApiService.calcFatorIdade(idade);
    final val = off.valorBase; // valorBase é o campo correto
    return VehicleSelection(
      tipo: tipo,
      marcaNome: off.marca,
      modeloNome: off.modelo,
      anoModelo: anoBase,
      valorFipe: val,
      franquia: FipeApiService.calcFranquia(val),
      premioBaseKm: FipeApiService.calcPremioBaseKm(val, idade),
      idadeVeiculo: idade,
      fatorIdade: fator,
      codigoFipe: off.codigoFipe,
      combustivel: 'Gasolina/Flex',
      isOffline: true,
    );
  }

  String get valorFormatado {
    if (valorFipe <= 0) return 'Não disponível';
    return 'R\$ ${valorFipe.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+,)'), (m) => '${m[1]}.')}';
  }

  String get franquiaFormatada => 'R\$ ${franquia.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+\b)'), (m) => '${m[1]}.')}';

  String get idadeLabel {
    if (idadeVeiculo == 0) return 'Novo';
    if (idadeVeiculo == 1) return '1 ano';
    return '$idadeVeiculo anos';
  }

  String get fatorIdadeLabel {
    if (fatorIdade <= 1.0)  return 'Ótimo (0-2 anos)';
    if (fatorIdade <= 1.1)  return 'Bom (3-5 anos)';
    if (fatorIdade <= 1.25) return 'Regular (6-10 anos)';
    if (fatorIdade <= 1.5)  return 'Alto (11-15 anos)';
    return 'Muito Alto (16+ anos)';
  }

  Color get fatorIdadeColor {
    if (fatorIdade <= 1.0)  return const Color(0xFF22C55E);
    if (fatorIdade <= 1.1)  return const Color(0xFF84CC16);
    if (fatorIdade <= 1.25) return const Color(0xFFF59E0B);
    if (fatorIdade <= 1.5)  return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String get tipoLabel {
    switch (tipo) {
      case 'motos':      return 'Moto';
      case 'caminhoes':  return 'Caminhão';
      default:           return 'Carro';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VEHICLE PICKER WIDGET — bottom sheet completo
// ─────────────────────────────────────────────────────────────────────────────

class VehiclePickerWidget extends StatefulWidget {
  final VehicleSelection? currentSelection;
  final ValueChanged<VehicleSelection> onSelected;

  const VehiclePickerWidget({
    super.key,
    this.currentSelection,
    required this.onSelected,
  });

  /// Abre o picker como bottom sheet modal
  static Future<VehicleSelection?> show(
    BuildContext context, {
    VehicleSelection? current,
  }) async {
    VehicleSelection? result;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehiclePickerWidget(
        currentSelection: current,
        onSelected: (sel) {
          result = sel;
          Navigator.of(ctx).pop();
        },
      ),
    );
    return result;
  }

  @override
  State<VehiclePickerWidget> createState() => _VehiclePickerWidgetState();
}

class _VehiclePickerWidgetState extends State<VehiclePickerWidget>
    with SingleTickerProviderStateMixin {
  // ── Tipo de veículo ────────────────────────────────────────
  String _tipo = 'carros';

  // ── Seleções em cascata ────────────────────────────────────
  FipeMarca? _marcaSel;
  FipeModelo? _modeloSel;
  FipeAno? _anoSel;
  FipePreco? _precoFipe;

  // ── Listas ─────────────────────────────────────────────────
  List<FipeMarca>  _marcas  = [];
  List<FipeModelo> _modelos = [];
  List<FipeAno>    _anos    = [];

  // ── Estados de loading ─────────────────────────────────────
  bool _loadingMarcas  = false;
  bool _loadingModelos = false;
  bool _loadingAnos    = false;
  bool _loadingPreco   = false;

  // ── Pesquisa de marca/modelo ───────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Tab offline/online ─────────────────────────────────────
  bool _showOffline = false;
  String _offlineQuery = '';
  final _offlineCtrl = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadMarcas();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _offlineCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento em cascata ────────────────────────────────

  Future<void> _loadMarcas() async {
    setState(() { _loadingMarcas = true; _marcas = []; _marcaSel = null; _modeloSel = null; _anoSel = null; _precoFipe = null; });
    final marcas = await FipeApiService.getMarcas(_tipo);
    if (!mounted) return;
    setState(() { _marcas = marcas; _loadingMarcas = false; });
  }

  Future<void> _loadModelos(FipeMarca marca) async {
    setState(() { _loadingModelos = true; _modelos = []; _modeloSel = null; _anoSel = null; _precoFipe = null; _marcaSel = marca; });
    final modelos = await FipeApiService.getModelos(_tipo, marca.codigo);
    if (!mounted) return;
    setState(() { _modelos = modelos; _loadingModelos = false; });
  }

  Future<void> _loadAnos(FipeModelo modelo) async {
    setState(() { _loadingAnos = true; _anos = []; _anoSel = null; _precoFipe = null; _modeloSel = modelo; });
    final anos = await FipeApiService.getAnos(_tipo, _marcaSel!.codigo, modelo.codigo);
    if (!mounted) return;
    setState(() { _anos = anos; _loadingAnos = false; });
  }

  Future<void> _loadPreco(FipeAno ano) async {
    setState(() { _loadingPreco = true; _anoSel = ano; _precoFipe = null; });
    final preco = await FipeApiService.getPreco(
      tipo: _tipo,
      codigoMarca: _marcaSel!.codigo,
      codigoModelo: _modeloSel!.codigo,
      codigoAno: ano.codigo,
    );
    if (!mounted) return;
    setState(() { _precoFipe = preco; _loadingPreco = false; });
  }

  // ── Listas filtradas ───────────────────────────────────────

  List<FipeMarca> get _marcasFiltradas {
    if (_searchQuery.isEmpty) return _marcas;
    final q = _searchQuery.toLowerCase();
    return _marcas.where((m) => m.nome.toLowerCase().contains(q)).toList();
  }

  List<FipeModelo> get _modelosFiltrados {
    if (_searchQuery.isEmpty) return _modelos;
    final q = _searchQuery.toLowerCase();
    return _modelos.where((m) => m.nome.toLowerCase().contains(q)).toList();
  }

  List<FipePrecoOffline> get _offlineFiltrados {
    final tipoMap = {'carros': 'Carro', 'motos': 'Moto', 'caminhoes': 'Caminhao'};
    final tipoFiltro = tipoMap[_tipo] ?? 'Carro';
    var lista = kFipeDb.where((v) => v.tipo == tipoFiltro || v.tipo == 'Carro').toList();
    if (_offlineQuery.isNotEmpty) {
      final q = _offlineQuery.toLowerCase();
      lista = lista.where((v) => '${v.marca} ${v.modelo}'.toLowerCase().contains(q)).toList();
    }
    return lista;
  }

  // ── Confirmar seleção ──────────────────────────────────────

  void _confirmar() {
    if (_precoFipe != null && (_precoFipe!.valor > 0)) {
      widget.onSelected(VehicleSelection.fromFipePreco(_precoFipe!, _tipo));
    }
  }

  void _confirmarOffline(FipePrecoOffline off) {
    widget.onSelected(VehicleSelection.fromOffline(off, _tipo));
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.92;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: h,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTipoSelector(),
            _buildModeToggle(),
            Expanded(
              child: _showOffline ? _buildOfflineView() : _buildOnlineView(),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Handle
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Selecionar Veículo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.text)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Busque o valor FIPE do seu veículo',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ── TIPO SELECTOR (Carro / Moto / Caminhão) ────────────────

  Widget _buildTipoSelector() {
    final tipos = [
      ('carros', Icons.directions_car_rounded, 'Carro'),
      ('motos', Icons.two_wheeler_rounded, 'Moto'),
      ('caminhoes', Icons.local_shipping_rounded, 'Caminhão'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: tipos.map((t) {
          final selected = _tipo == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_tipo != t.$1) {
                  _tipo = t.$1;
                  _loadMarcas();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : AppTheme.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(t.$2, size: 18, color: selected ? Colors.white : AppTheme.textMuted),
                    const SizedBox(height: 3),
                    Text(t.$3,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppTheme.textMuted,
                      )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── TOGGLE Offline / Online ────────────────────────────────

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _modeBtn('Busca API FIPE', Icons.cloud_rounded, !_showOffline, () {
            setState(() { _showOffline = false; });
          }),
          const SizedBox(width: 8),
          _modeBtn('Banco Offline (200+)', Icons.offline_bolt_rounded, _showOffline, () {
            setState(() { _showOffline = true; });
          }),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surface2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? AppTheme.primary : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? AppTheme.primary : AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? AppTheme.primary : AppTheme.textMuted,
            )),
          ],
        ),
      ),
    );
  }

  // ── VIEW ONLINE (API FIPE) ────────────────────────────────

  Widget _buildOnlineView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passo 1 — Marca
          _buildStepHeader('1', 'Marca', _marcaSel?.nome, _loadingMarcas),
          if (_marcaSel == null && !_loadingMarcas) ...[
            _buildSearchField('Filtrar marcas...', _searchCtrl, (v) => setState(() => _searchQuery = v)),
            _buildMarcasGrid(),
          ],

          // Passo 2 — Modelo (só após marca)
          if (_marcaSel != null) ...[
            const SizedBox(height: 8),
            _buildStepHeader('2', 'Modelo', _modeloSel?.nome, _loadingModelos),
            if (_modeloSel == null && !_loadingModelos) ...[
              _buildSearchField('Filtrar modelos...', _searchCtrl, (v) => setState(() => _searchQuery = v)),
              _buildModelosList(),
            ],
          ],

          // Passo 3 — Ano (só após modelo)
          if (_modeloSel != null) ...[
            const SizedBox(height: 8),
            _buildStepHeader('3', 'Ano', _anoSel?.nome, _loadingAnos),
            if (_anoSel == null && !_loadingAnos)
              _buildAnosList(),
          ],

          // Resultado FIPE
          if (_loadingPreco)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Consultando tabela FIPE...', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ))
          else if (_precoFipe != null)
            _buildFipeResult(_precoFipe!),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String step, String title, String? selected, bool loading) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: selected != null ? AppTheme.green : AppTheme.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: selected != null
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
          if (selected != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                selected,
                style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (step == '3') { _anoSel = null; _precoFipe = null; }
                  else if (step == '2') { _modeloSel = null; _anoSel = null; _precoFipe = null; }
                  else { _marcaSel = null; _modeloSel = null; _anoSel = null; _precoFipe = null; }
                  _searchQuery = '';
                  _searchCtrl.clear();
                });
              },
              child: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.textMuted),
            ),
          ],
          if (loading) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(String hint, TextEditingController ctrl, ValueChanged<String> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () { ctrl.clear(); onChanged(''); },
              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildMarcasGrid() {
    final lista = _marcasFiltradas;
    if (lista.isEmpty) {
      return _emptyMsg('Nenhuma marca encontrada');
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final m = lista[i];
        return GestureDetector(
          onTap: () {
            _searchQuery = '';
            _searchCtrl.clear();
            _loadModelos(m);
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              m.nome,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.text),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _buildModelosList() {
    final lista = _modelosFiltrados;
    if (lista.isEmpty) return _emptyMsg('Nenhum modelo encontrado');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lista.length > 100 ? 100 : lista.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = lista[i];
        return InkWell(
          onTap: () {
            _searchQuery = '';
            _searchCtrl.clear();
            _loadAnos(m);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.directions_car_outlined, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(child: Text(m.nome, style: const TextStyle(fontSize: 13, color: AppTheme.text))),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnosList() {
    if (_anos.isEmpty) return _emptyMsg('Nenhum ano disponível');
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: _anos.map((a) {
        return GestureDetector(
          onTap: () => _loadPreco(a),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(a.nome,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.text)),
          ),
        );
      }).toList(),
    );
  }

  // ── RESULTADO FIPE ────────────────────────────────────────

  Widget _buildFipeResult(FipePreco p) {
    final canConfirm = p.valor > 0;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.green.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título veículo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.marca} ${p.modelo}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${p.anoModelo} · ${p.combustivel} · ${p.codigoFipe}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              if (p.mesReferencia.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(p.mesReferencia, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Valor FIPE destaque
          if (canConfirm) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Valor FIPE', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(width: 8),
                  Text(p.valorFormatado,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.text)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(child: Text('Valor FIPE não disponível — usando banco offline.',
                    style: TextStyle(fontSize: 11, color: Colors.orange))),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Grid de dados atuariais
          Row(children: [
            _fipeDataCard('Franquia', p.franquiaFormatada, Icons.shield_outlined, AppTheme.primary),
            const SizedBox(width: 8),
            _fipeDataCard('R\$/km base', 'R\$ ${p.premioBasePorKm.toStringAsFixed(3)}', Icons.speed_rounded, AppTheme.green),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _fipeDataCard('Idade', p.idadeLabel, Icons.calendar_today_rounded, Colors.grey),
            const SizedBox(width: 8),
            _fipeDataCard('Fator Risco', '×${p.fatorIdade.toStringAsFixed(2)} · ${p.fatorIdadeLabel}',
              Icons.trending_up_rounded, p.fatorIdade <= 1.1 ? AppTheme.green : Colors.orange),
          ]),

          const SizedBox(height: 14),

          // Botão confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canConfirm ? _confirmar : null,
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Usar este Veículo', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fipeDataCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                  Text(value,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── VIEW OFFLINE ──────────────────────────────────────────

  Widget _buildOfflineView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: _buildSearchField(
            'Buscar por marca ou modelo...',
            _offlineCtrl,
            (v) => setState(() => _offlineQuery = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: _offlineFiltrados.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final v = _offlineFiltrados[i];
              final sel = VehicleSelection.fromOffline(v, _tipo);
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car_rounded, size: 16, color: AppTheme.primary),
                ),
                title: Text('${v.marca} ${v.modelo}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text)),
                subtitle: Text(
                  '${v.anoBase} · ${sel.combustivel} · ${sel.franquiaFormatada} franquia',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(sel.valorFormatado,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: sel.fatorIdadeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('×${sel.fatorIdade.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 9, color: sel.fatorIdadeColor, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                onTap: () => _confirmarOffline(v),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyMsg(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(msg, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VEHICLE DISPLAY CARD — exibe veículo selecionado na QuoteScreen
// ─────────────────────────────────────────────────────────────────────────────

class VehicleDisplayCard extends StatelessWidget {
  final VehicleSelection? selection;
  final VoidCallback onTap;

  const VehicleDisplayCard({
    super.key,
    this.selection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (selection == null) {
      return _buildPlaceholder();
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selection!.marcaNome} ${selection!.modeloNome}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        '${selection!.anoModelo} · ${selection!.idadeLabel}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      if (selection!.isOffline) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('offline',
                            style: TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  selection!.valorFormatado,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text),
                ),
                Text(
                  'FIPE ${selection!.anoModelo}',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_rounded, size: 15, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
          // Borda tracejada efeito
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              'Selecionar veículo · Buscar valor FIPE',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.primary.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

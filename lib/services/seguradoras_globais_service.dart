// ═══════════════════════════════════════════════════════════════════════════
// SERVIÇO DE INTELIGÊNCIA GLOBAL DE SEGURADORAS — SafeRouteGo / SADI v3.0
// Base: 239 seguradoras de 42 países | Fontes: SUSEP, EIOPA, NAIC, Wikidata
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/services.dart';

class SeguradoraGlobal {
  final String idGlobal;
  final String nome;
  final String website;
  final String anoFundacao;
  final String tickerBolsa;
  final String regulador;

  const SeguradoraGlobal({
    required this.idGlobal,
    required this.nome,
    required this.website,
    required this.anoFundacao,
    required this.tickerBolsa,
    required this.regulador,
  });

  factory SeguradoraGlobal.fromJson(Map<String, dynamic> j) => SeguradoraGlobal(
    idGlobal:    j['id_global']       ?? '',
    nome:        j['nome_seguradora'] ?? '',
    website:     j['website']         ?? '',
    anoFundacao: j['ano_fundacao']    ?? '',
    tickerBolsa: j['ticker_bolsa']    ?? '',
    regulador:   j['regulador']       ?? '',
  );

  bool get temTicker      => tickerBolsa.isNotEmpty && tickerBolsa != 'null';
  bool get temWebsite     => website.isNotEmpty && website != 'null' && website.startsWith('http');
  bool get isInsurTech    => idGlobal.contains('INSURTECH') || regulador.contains('INSURTECH');
  bool get isResseguradora =>
      idGlobal.contains('RESSEGUROS') ||
      nome.toLowerCase().contains('re ') ||
      nome.toLowerCase().contains('resseguro') ||
      nome.toLowerCase().endsWith(' re') ||
      nome.toLowerCase().contains('reinsur');
}

class PaisInsurtech {
  final String codigoPais;
  final String pais;
  final int totalSeguradoras;
  final String reguladorPrincipal;
  final List<SeguradoraGlobal> seguradoras;

  const PaisInsurtech({
    required this.codigoPais,
    required this.pais,
    required this.totalSeguradoras,
    required this.reguladorPrincipal,
    required this.seguradoras,
  });

  factory PaisInsurtech.fromJson(Map<String, dynamic> j) {
    final lista = (j['seguradoras'] as List? ?? [])
        .map((e) => SeguradoraGlobal.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaisInsurtech(
      codigoPais:         j['codigo_pais']         ?? '',
      pais:               j['pais']                ?? '',
      totalSeguradoras:   j['total_seguradoras']   ?? 0,
      reguladorPrincipal: j['regulador_principal'] ?? '',
      seguradoras:        lista,
    );
  }
}

class MetaBase {
  final String versao;
  final String dataAtualizacao;
  final int totalSeguradoras;
  final int totalPaises;
  final List<String> fontes;

  const MetaBase({
    required this.versao,
    required this.dataAtualizacao,
    required this.totalSeguradoras,
    required this.totalPaises,
    required this.fontes,
  });

  factory MetaBase.fromJson(Map<String, dynamic> j) => MetaBase(
    versao:           j['versao']            ?? '',
    dataAtualizacao:  j['data_atualizacao']  ?? '',
    totalSeguradoras: j['total_seguradoras'] ?? 0,
    totalPaises:      j['total_paises']      ?? 0,
    fontes:           List<String>.from(j['fontes'] ?? []),
  );
}

class SeguradorasGlobaisService {
  static SeguradorasGlobaisService? _instance;
  static SeguradorasGlobaisService get instance =>
      _instance ??= SeguradorasGlobaisService._();
  SeguradorasGlobaisService._();

  MetaBase? _meta;
  List<PaisInsurtech> _paises = [];
  List<SeguradoraGlobal> _todas = [];
  bool _carregado = false;

  MetaBase?           get meta         => _meta;
  List<PaisInsurtech> get paises        => _paises;
  List<SeguradoraGlobal> get todas      => _todas;
  int                 get total         => _meta?.totalSeguradoras ?? 0;
  int                 get totalPaises   => _meta?.totalPaises ?? 0;
  bool                get carregado     => _carregado;

  Future<void> carregar() async {
    if (_carregado) return;
    try {
      final raw  = await rootBundle.loadString('assets/data/seguradoras_mundo.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _meta   = MetaBase.fromJson(data['meta'] as Map<String, dynamic>);
      _paises = (data['paises'] as List)
          .map((e) => PaisInsurtech.fromJson(e as Map<String, dynamic>))
          .toList();
      _todas  = _paises.expand((p) => p.seguradoras).toList();
      _carregado = true;
    } catch (_) {
      _carregado = false;
    }
  }

  List<SeguradoraGlobal> buscar(String query) {
    if (query.trim().isEmpty) return _todas;
    final q = query.toLowerCase();
    return _todas.where((s) =>
      s.nome.toLowerCase().contains(q) ||
      s.tickerBolsa.toLowerCase().contains(q) ||
      s.regulador.toLowerCase().contains(q)
    ).toList();
  }

  Map<String, int> estatisticasPorRegulador() {
    final map = <String, int>{};
    for (final s in _todas) {
      map[s.regulador] = (map[s.regulador] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  List<PaisInsurtech> topPaises({int n = 10}) {
    final sorted = [..._paises]..sort((a, b) =>
        b.totalSeguradoras.compareTo(a.totalSeguradoras));
    return sorted.take(n).toList();
  }

  int get totalComTicker     => _todas.where((s) => s.temTicker).length;
  int get totalInsurTechs    => _todas.where((s) => s.isInsurTech).length;
  int get totalResseguradoras => _todas.where((s) => s.isResseguradora).length;

  Map<String, int> distribuicaoPorRegiao() {
    const regioes = {
      'Américas': ['BR', 'US', 'MX', 'AR', 'CO', 'CL', 'PE', 'UY', 'EC', 'CA', 'BM'],
      'Europa':   ['DE', 'GB', 'FR', 'IT', 'ES', 'CH', 'NL', 'BE', 'AT', 'SE', 'NO', 'DK', 'FI', 'PT', 'PL', 'RU'],
      'Ásia-Pacífico': ['CN', 'JP', 'KR', 'IN', 'AU', 'SG', 'HK'],
      'Oriente Médio & África': ['AE', 'SA', 'QA', 'KW', 'ZA', 'NG', 'KE', 'IL'],
    };
    final result = <String, int>{};
    for (final p in _paises) {
      String regiao = 'Outros';
      for (final entry in regioes.entries) {
        if (entry.value.contains(p.codigoPais)) { regiao = entry.key; break; }
      }
      result[regiao] = (result[regiao] ?? 0) + p.totalSeguradoras;
    }
    return result;
  }

  String emojiPais(String cod) {
    final emojis = {
      'BR':'🇧🇷','US':'🇺🇸','DE':'🇩🇪','GB':'🇬🇧','FR':'🇫🇷','IT':'🇮🇹',
      'ES':'🇪🇸','CH':'🇨🇭','NL':'🇳🇱','BE':'🇧🇪','AT':'🇦🇹','SE':'🇸🇪',
      'NO':'🇳🇴','DK':'🇩🇰','FI':'🇫🇮','PT':'🇵🇹','PL':'🇵🇱','RU':'🇷🇺',
      'CN':'🇨🇳','JP':'🇯🇵','KR':'🇰🇷','IN':'🇮🇳','AU':'🇦🇺','SG':'🇸🇬',
      'HK':'🇭🇰','ZA':'🇿🇦','NG':'🇳🇬','KE':'🇰🇪','AE':'🇦🇪','SA':'🇸🇦',
      'QA':'🇶🇦','KW':'🇰🇼','IL':'🇮🇱','MX':'🇲🇽','AR':'🇦🇷','CO':'🇨🇴',
      'CL':'🇨🇱','PE':'🇵🇪','UY':'🇺🇾','EC':'🇪🇨','CA':'🇨🇦','BM':'🇧🇲',
    };
    return emojis[cod] ?? '🏳️';
  }
}

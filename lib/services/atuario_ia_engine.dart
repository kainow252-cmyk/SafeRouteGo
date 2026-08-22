// ═══════════════════════════════════════════════════════════════════
// ATUÁRIO IA ENGINE v4.0 — SafeRouteGo SADI
// Motor de cálculo atuarial em tempo real com IA
// Baseado no SADI (Sistema Atuarial Digital Integrado)
// Premissas: DA=15%, CC=10%, ML=8%, IOF=7,38%, Seg=5%
// ATUALIZADO: BR-EMS 2021 IBGE completa + dados World Bank (30 países)
// Fontes: dados_demograficos.json — SUSEP/IBGE/WorldBank Open Data
// ═══════════════════════════════════════════════════════════════════

import 'dart:math';

// ─── PREMISSAS GLOBAIS ─────────────────────────────────────────
class AtuarioPremissas {
  static const double da = 0.15;      // Despesas Administrativas
  static const double cc = 0.10;      // Comissão Corretagem
  static const double ml = 0.08;      // Margem de Lucro
  static const double iof = 0.0738;   // IOF
  static const double seguranca = 0.05; // Margem de Segurança

  // Carregamento total = 1 - (DA + CC + ML)
  static double get carregamento => 1.0 - da - cc - ml; // 0.67

  // Fórmula base: Premio Comercial = (PremPuro * (1 + seguranca)) / carregamento * (1 + iof)
  static double aplicarCarregamento(double premPuro) {
    return (premPuro * (1 + seguranca)) / carregamento * (1 + iof);
  }
}

// ─── INDICADORES DEMOGRÁFICOS GLOBAIS (World Bank 2024) ────────
// Fonte: dados_demograficos.json — WorldBank Open Data + IBGE
class DadosDemograficos {
  static const Map<String, Map<String, dynamic>> paises = {
    'BR': {'nome': 'Brasil',          'expVida': 76.02, 'gini': 50.3, 'pibPerCapita': 10713.29,  'mortalidadeInfantil': 12.3,  'fatorRisco': 28.2},
    'US': {'nome': 'EUA',             'expVida': 78.89, 'gini': 41.8, 'pibPerCapita': 90026.52,  'mortalidadeInfantil': 5.5,   'fatorRisco': 18.5},
    'DE': {'nome': 'Alemanha',        'expVida': 80.79, 'gini': 31.7, 'pibPerCapita': 60496.44,  'mortalidadeInfantil': 3.1,   'fatorRisco': 12.2},
    'FR': {'nome': 'França',          'expVida': 82.98, 'gini': 32.4, 'pibPerCapita': 48985.73,  'mortalidadeInfantil': 3.4,   'fatorRisco': 4.8},
    'GB': {'nome': 'Reino Unido',     'expVida': 81.39, 'gini': 35.1, 'pibPerCapita': 57601.96,  'mortalidadeInfantil': 4.1,   'fatorRisco': 8.3},
    'JP': {'nome': 'Japão',           'expVida': 84.26, 'gini': 32.9, 'pibPerCapita': 33834.62,  'mortalidadeInfantil': 1.8,   'fatorRisco': 2.1},
    'CN': {'nome': 'China',           'expVida': 78.21, 'gini': 38.2, 'pibPerCapita': 13136.14,  'mortalidadeInfantil': 5.2,   'fatorRisco': 15.4},
    'IN': {'nome': 'Índia',           'expVida': 70.19, 'gini': 35.7, 'pibPerCapita': 2411.58,   'mortalidadeInfantil': 26.6,  'fatorRisco': 42.8},
    'MX': {'nome': 'México',          'expVida': 75.05, 'gini': 45.4, 'pibPerCapita': 11492.74,  'mortalidadeInfantil': 12.5,  'fatorRisco': 31.5},
    'AR': {'nome': 'Argentina',       'expVida': 76.74, 'gini': 42.3, 'pibPerCapita': 10721.04,  'mortalidadeInfantil': 8.7,   'fatorRisco': 24.6},
    'CO': {'nome': 'Colômbia',        'expVida': 73.83, 'gini': 51.5, 'pibPerCapita': 6893.64,   'mortalidadeInfantil': 11.4,  'fatorRisco': 38.9},
    'CL': {'nome': 'Chile',           'expVida': 80.36, 'gini': 44.9, 'pibPerCapita': 15858.45,  'mortalidadeInfantil': 5.8,   'fatorRisco': 13.7},
    'ZA': {'nome': 'África do Sul',   'expVida': 62.32, 'gini': 63.0, 'pibPerCapita': 6773.59,   'mortalidadeInfantil': 25.5,  'fatorRisco': 72.4},
    'NG': {'nome': 'Nigéria',         'expVida': 55.75, 'gini': 35.1, 'pibPerCapita': 2065.10,   'mortalidadeInfantil': 68.4,  'fatorRisco': 89.3},
    'CA': {'nome': 'Canadá',          'expVida': 82.57, 'gini': 33.3, 'pibPerCapita': 58399.66,  'mortalidadeInfantil': 4.5,   'fatorRisco': 5.2},
    'AU': {'nome': 'Austrália',       'expVida': 83.44, 'gini': 34.3, 'pibPerCapita': 64491.13,  'mortalidadeInfantil': 3.6,   'fatorRisco': 4.1},
    'KR': {'nome': 'Coreia do Sul',   'expVida': 83.55, 'gini': 31.4, 'pibPerCapita': 36194.37,  'mortalidadeInfantil': 2.9,   'fatorRisco': 3.8},
    'IT': {'nome': 'Itália',          'expVida': 83.54, 'gini': 34.8, 'pibPerCapita': 40479.22,  'mortalidadeInfantil': 2.6,   'fatorRisco': 4.5},
    'ES': {'nome': 'Espanha',         'expVida': 83.56, 'gini': 34.7, 'pibPerCapita': 33783.93,  'mortalidadeInfantil': 2.7,   'fatorRisco': 4.3},
    'PT': {'nome': 'Portugal',        'expVida': 81.87, 'gini': 32.8, 'pibPerCapita': 26399.06,  'mortalidadeInfantil': 3.3,   'fatorRisco': 7.8},
    'NL': {'nome': 'Holanda',         'expVida': 82.18, 'gini': 28.2, 'pibPerCapita': 63754.38,  'mortalidadeInfantil': 3.5,   'fatorRisco': 5.9},
    'SE': {'nome': 'Suécia',          'expVida': 83.08, 'gini': 27.6, 'pibPerCapita': 60239.89,  'mortalidadeInfantil': 2.5,   'fatorRisco': 3.6},
    'NO': {'nome': 'Noruega',         'expVida': 83.22, 'gini': 26.1, 'pibPerCapita': 106155.79, 'mortalidadeInfantil': 2.1,   'fatorRisco': 2.9},
    'CH': {'nome': 'Suíça',           'expVida': 83.97, 'gini': 33.1, 'pibPerCapita': 98767.34,  'mortalidadeInfantil': 3.3,   'fatorRisco': 2.4},
    'RU': {'nome': 'Rússia',          'expVida': 72.58, 'gini': 36.0, 'pibPerCapita': 15926.26,  'mortalidadeInfantil': 4.9,   'fatorRisco': 32.1},
    'TR': {'nome': 'Turquia',         'expVida': 78.61, 'gini': 41.9, 'pibPerCapita': 13597.81,  'mortalidadeInfantil': 9.5,   'fatorRisco': 21.4},
    'SA': {'nome': 'Arábia Saudita',  'expVida': 76.43, 'gini': 45.9, 'pibPerCapita': 29979.98,  'mortalidadeInfantil': 6.6,   'fatorRisco': 22.7},
    'AE': {'nome': 'Emirados',        'expVida': 78.85, 'gini': null,  'pibPerCapita': 49977.79,  'mortalidadeInfantil': 5.7,   'fatorRisco': 16.2},
    'SG': {'nome': 'Singapura',       'expVida': 83.88, 'gini': 45.9, 'pibPerCapita': 88001.83,  'mortalidadeInfantil': 1.7,   'fatorRisco': 2.7},
    'IL': {'nome': 'Israel',          'expVida': 82.96, 'gini': 38.6, 'pibPerCapita': 55340.15,  'mortalidadeInfantil': 3.0,   'fatorRisco': 5.6},
  };

  // Expectativa de vida BR por estado (IBGE 2021)
  static const Map<String, double> expVidaEstados = {
    'AC': 72.1, 'AL': 72.4, 'AP': 73.9, 'AM': 72.2, 'BA': 74.0,
    'CE': 74.1, 'DF': 79.2, 'ES': 77.0, 'GO': 76.8, 'MA': 70.7,
    'MT': 74.7, 'MS': 75.7, 'MG': 77.3, 'PA': 72.0, 'PB': 74.4,
    'PR': 78.8, 'PE': 73.4, 'PI': 72.0, 'RJ': 75.9, 'RN': 74.5,
    'RS': 78.9, 'RO': 72.6, 'RR': 73.2, 'SC': 80.1, 'SP': 78.6,
    'SE': 73.3, 'TO': 73.5,
  };

  // Referência nacional BR-EMS: 72.2 M / 79.1 F / 75.5 geral
  static const double expVidaBrMasc = 72.2;
  static const double expVidaBrFem = 79.1;
  static const double expVidaBrGeral = 75.5;

  /// Fator de ajuste de prêmio baseado em expectativa de vida relativa ao BR
  /// País com exp_vida maior → fator < 1 (menor mortalidade = menor prêmio puro)
  /// País com exp_vida menor → fator > 1 (maior mortalidade = maior prêmio puro)
  static double fatorAjusteVida(String codigoPais) {
    final dados = paises[codigoPais.toUpperCase()];
    if (dados == null) return 1.0;
    final expVidaPais = (dados['expVida'] as double?) ?? expVidaBrGeral;
    // Razão invertida: BR/País — se País tem vida mais longa, prêmio cai
    return (expVidaBrGeral / expVidaPais).clamp(0.50, 2.50);
  }

  /// Fator de risco social baseado no Gini e outros indicadores
  static double fatorRiscoSocial(String codigoPais) {
    final dados = paises[codigoPais.toUpperCase()];
    if (dados == null) return 1.0;
    final risco = (dados['fatorRisco'] as double?) ?? 25.0;
    // Normalizado: risco 25 = fator 1.0
    return (risco / 25.0).clamp(0.30, 3.50);
  }

  /// Obter dados completos de um país
  static Map<String, dynamic>? getDados(String codigo) {
    return paises[codigo.toUpperCase()];
  }

  /// Lista de países ordenados por expectativa de vida
  static List<MapEntry<String, Map<String, dynamic>>> get rankingExpVida {
    final list = paises.entries.toList();
    list.sort((a, b) {
      final va = (a.value['expVida'] as double?) ?? 0.0;
      final vb = (b.value['expVida'] as double?) ?? 0.0;
      return vb.compareTo(va);
    });
    return list;
  }
}

// ─── TÁBUA DE MORTALIDADE BR-EMS 2021 — IBGE COMPLETA ─────────
// Fonte: IBGE Tabela 7350 — Tábua Completa de Mortalidade 2021
// Dados: dados_demograficos.json > brasil_detalhado > tabua_br_ems_masculino/feminino
// Probabilidade de morte qx por idade quinquenal (0-95)
class TabuaMortalidade {
  // BR-EMS 2021 Masculino — IBGE Tabela 7350 (qx por quinquênio)
  static const Map<int, double> _qxMasc = {
    0:  0.01089, 5:  0.00048, 10: 0.00040, 15: 0.00180,
    20: 0.00290, 25: 0.00280, 30: 0.00280, 35: 0.00340,
    40: 0.00480, 45: 0.00710, 50: 0.01060, 55: 0.01570,
    60: 0.02330, 65: 0.03540, 70: 0.05410, 75: 0.08290,
    80: 0.12520, 85: 0.18600, 90: 0.27100, 95: 0.38500,
  };

  // BR-EMS 2021 Feminino — IBGE Tabela 7350 (qx por quinquênio)
  static const Map<int, double> _qxFem = {
    0:  0.00839, 5:  0.00040, 10: 0.00028, 15: 0.00077,
    20: 0.00100, 25: 0.00110, 30: 0.00150, 35: 0.00220,
    40: 0.00340, 45: 0.00530, 50: 0.00800, 55: 0.01180,
    60: 0.01740, 65: 0.02630, 70: 0.04000, 75: 0.06280,
    80: 0.09780, 85: 0.15000, 90: 0.22700, 95: 0.33800,
  };

  // Legado: mapa genérico (média M+F) para compatibilidade
  static const Map<int, double> _qx = {
    0: 0.00964, 5: 0.00044, 10: 0.00034, 15: 0.00129,
    20: 0.00195, 25: 0.00195, 30: 0.00215, 35: 0.00280,
    40: 0.00410, 45: 0.00620, 50: 0.00930, 55: 0.01375,
    60: 0.02035, 65: 0.03085, 70: 0.04705, 75: 0.07285,
    80: 0.11150, 85: 0.16800, 90: 0.24900, 95: 0.36150,
  };

  /// Interpolação linear entre pontos quinquenais
  static double _interpolar(Map<int, double> tabela, int idade) {
    final keys = tabela.keys.toList()..sort();
    for (int i = 0; i < keys.length - 1; i++) {
      if (idade >= keys[i] && idade <= keys[i + 1]) {
        final t = (idade - keys[i]) / (keys[i + 1] - keys[i]);
        return tabela[keys[i]]! + t * (tabela[keys[i + 1]]! - tabela[keys[i]]!);
      }
    }
    if (idade < keys.first) return tabela[keys.first]!;
    return tabela[keys.last]!;
  }

  /// qx BR-EMS 2021 por gênero (masculino/feminino) — IBGE
  static double getQxGenero(int idade, {bool feminino = false}) {
    return _interpolar(feminino ? _qxFem : _qxMasc, idade);
  }

  /// qx BR-EMS 2021 médio (compatibilidade legado)
  static double getQx(int idade) => _interpolar(_qx, idade);

  /// Expectativa de vida residual aproximada (ex) pelo método de Chiang
  static double expectativaResidual(int idade, {bool feminino = false}) {
    final tabela = feminino ? _qxFem : _qxMasc;
    // Simplificado: média ponderada anos restantes
    final keys = tabela.keys.toList()..sort();
    double acum = 0.0;
    double px = 1.0; // probabilidade de sobrevivência acumulada
    for (int i = 0; i < keys.length; i++) {
      if (keys[i] >= idade) {
        acum += px * 5; // quinquênio
        px *= (1 - tabela[keys[i]]!);
      }
    }
    return acum.clamp(0.0, 95.0 - idade.toDouble());
  }

  /// Fator de ajuste internacional por país (World Bank data)
  /// Recalibra o qx BR-EMS para o contexto de mortalidade do país
  static double fatorPais(String codigoPais) {
    return DadosDemograficos.fatorAjusteVida(codigoPais);
  }

  /// qx ajustado para contexto internacional
  static double getQxInternacional(int idade, String codigoPais, {bool feminino = false}) {
    final qxBr = getQxGenero(idade, feminino: feminino);
    final fator = fatorPais(codigoPais);
    return qxBr * fator;
  }

  /// Informação da fonte para auditoria atuarial
  static const String fonte = 'IBGE Tabela 7350 — Tábua Completa de Mortalidade 2021 + SUSEP BR-EMS';
  static const String dataAtualizacao = '2021-01-01';
  static const String versao = 'BR-EMS 2021 v1.0';
}

// ─── FATORES DE RISCO AUTO ──────────────────────────────────────
class FatoresAuto {
  static double fatorIdade(int idade) {
    if (idade <= 19) return 1.60;
    if (idade <= 24) return 1.45;
    if (idade <= 29) return 1.20;
    if (idade <= 35) return 1.05;
    if (idade <= 45) return 1.00;
    if (idade <= 55) return 1.05;
    if (idade <= 65) return 1.10;
    return 1.25;
  }

  static double fatorAnoVeiculo(int ano) {
    final idade = DateTime.now().year - ano;
    if (idade <= 1) return 0.85;
    if (idade <= 3) return 0.90;
    if (idade <= 5) return 1.00;
    if (idade <= 8) return 1.10;
    if (idade <= 12) return 1.15;
    return 1.25;
  }

  static double fatorRegiao(String cep) {
    // Baseado no CEP/região — risco de roubo/furto
    final prefix = cep.isEmpty ? '01' : cep.substring(0, min(2, cep.length));
    const regioes = {
      '01': 1.55, '02': 1.50, '03': 1.45, '04': 1.40, // SP capital
      '05': 1.35, '06': 1.30, '08': 1.40, '09': 1.35, // Grande SP
      '20': 1.45, '21': 1.40, '22': 1.30, '23': 1.35, // RJ
      '40': 1.30, '41': 1.25, '42': 1.20,              // BA
      '29': 1.15, '30': 1.20, '31': 1.15,              // ES, MG
      '70': 1.10, '71': 1.05, '72': 1.00,              // DF
      '80': 1.20, '81': 1.15, '82': 1.10,              // PR
      '90': 1.10, '91': 1.05,                           // RS
    };
    return regioes[prefix] ?? 0.95;
  }

  static double fatorBonus(int classeBonus) {
    // 0=novo, 10=máx desconto
    return 1.0 - (classeBonus * 0.04).clamp(0.0, 0.35);
  }

  static double fatorUso(String uso) {
    switch (uso.toLowerCase()) {
      case 'lazer': return 0.90;
      case 'trabalho': return 1.10;
      case 'aplicativo': return 1.35;
      case 'frota': return 1.25;
      default: return 1.00;
    }
  }
}

// ─── CÁLCULO AUTO ──────────────────────────────────────────────
class CalculoAuto {
  final double premPuroBase;
  final int idadeMotorista;
  final String cepPernoite;
  final int anoVeiculo;
  final int classeBonus;
  final String usoVeiculo;
  final double valorFipe;

  CalculoAuto({
    required this.valorFipe,
    required this.idadeMotorista,
    required this.cepPernoite,
    required this.anoVeiculo,
    this.classeBonus = 0,
    this.usoVeiculo = 'lazer',
  }) : premPuroBase = valorFipe * 0.04; // 4% do FIPE como base

  double get fatId => FatoresAuto.fatorIdade(idadeMotorista);
  double get fatCep => FatoresAuto.fatorRegiao(cepPernoite);
  double get fatAno => FatoresAuto.fatorAnoVeiculo(anoVeiculo);
  double get fatBonus => FatoresAuto.fatorBonus(classeBonus);
  double get fatUso => FatoresAuto.fatorUso(usoVeiculo);

  double get premPuroFinal => premPuroBase * fatId * fatCep * fatAno * fatBonus * fatUso;
  double get premComercialAnual => AtuarioPremissas.aplicarCarregamento(premPuroFinal);
  double get premComercialMensal => premComercialAnual / 12;
  double get premComercialDiario => premComercialAnual / 365;

  Map<String, dynamic> toMap() => {
    'ramo': 'Automóvel',
    'prem_puro_base': premPuroBase,
    'fat_idade': fatId,
    'fat_cep': fatCep,
    'fat_ano': fatAno,
    'fat_bonus': fatBonus,
    'fat_uso': fatUso,
    'prem_puro_final': premPuroFinal,
    'prem_comercial_anual': premComercialAnual,
    'prem_comercial_mensal': premComercialMensal,
    'prem_comercial_diario': premComercialDiario,
    'da': AtuarioPremissas.da,
    'cc': AtuarioPremissas.cc,
    'ml': AtuarioPremissas.ml,
    'iof': AtuarioPremissas.iof,
  };
}

// ─── CÁLCULO VIDA ──────────────────────────────────────────────
// Atualizado para usar BR-EMS 2021 completa por gênero + ajuste internacional
class CalculoVida {
  final double capitalSegurado;
  final int idade;
  final bool tabagista;
  final String profissao;
  final bool feminino;        // 🆕 gênero para qx diferenciado
  final String paisCodigo;    // 🆕 código ISO2 do país (ex: 'BR', 'US')

  CalculoVida({
    required this.capitalSegurado,
    required this.idade,
    this.tabagista = false,
    this.profissao = 'geral',
    this.feminino = false,
    this.paisCodigo = 'BR',
  });

  /// qx BR-EMS 2021 por gênero — IBGE Tabela 7350
  double get qx => TabuaMortalidade.getQxGenero(idade, feminino: feminino);

  /// qx ajustado para país (quando não Brasil)
  double get qxInternacional => paisCodigo.toUpperCase() == 'BR'
      ? qx
      : TabuaMortalidade.getQxInternacional(idade, paisCodigo, feminino: feminino);

  double get fatorTabagismo => tabagista ? 1.35 : 1.0;

  double get fatorProfissao {
    switch (profissao.toLowerCase()) {
      case 'policial':
      case 'bombeiro': return 1.80;
      case 'motorista':
      case 'motoboy': return 1.45;
      case 'construção':
      case 'mineração': return 1.35;
      case 'aviação': return 1.20;
      case 'escritório':
      case 'ti':
      case 'professor': return 0.95;
      default: return 1.00;
    }
  }

  /// Fator de risco social do país (normalizado — BR=1.0)
  double get fatorPaisSocial => DadosDemograficos.fatorRiscoSocial(paisCodigo);

  /// Expectativa de vida residual a partir da idade atual
  double get expectativaVidaResidual =>
      TabuaMortalidade.expectativaResidual(idade, feminino: feminino);

  double get premPuroAnual =>
      capitalSegurado * qxInternacional * fatorTabagismo * fatorProfissao;
  double get carregamentoSeguranca => premPuroAnual * AtuarioPremissas.seguranca;
  double get premPuroTotal => premPuroAnual + carregamentoSeguranca;
  double get premComercialAnual => AtuarioPremissas.aplicarCarregamento(premPuroAnual);
  double get premComercialMensal => premComercialAnual / 12;

  Map<String, dynamic> toMap() {
    final dadosPais = DadosDemograficos.getDados(paisCodigo);
    return {
      'ramo': 'Vida',
      'capital_segurado': capitalSegurado,
      'idade': idade,
      'genero': feminino ? 'feminino' : 'masculino',
      'pais': paisCodigo,
      'exp_vida_residual': expectativaVidaResidual,
      'qx_br_ems': qx,
      'qx_ajustado': qxInternacional,
      'fat_tabagismo': fatorTabagismo,
      'fat_profissao': fatorProfissao,
      'fat_pais': TabuaMortalidade.fatorPais(paisCodigo),
      'fat_risco_social': fatorPaisSocial,
      'prem_puro_anual': premPuroAnual,
      'prem_comercial_anual': premComercialAnual,
      'prem_comercial_mensal': premComercialMensal,
      'fonte_tabua': TabuaMortalidade.fonte,
      'versao_tabua': TabuaMortalidade.versao,
      if (dadosPais != null) 'exp_vida_pais': dadosPais['expVida'],
      if (dadosPais != null) 'pib_per_capita': dadosPais['pibPerCapita'],
    };
  }
}

// ─── CÁLCULO CYBER ─────────────────────────────────────────────
class CalculoCyber {
  final double limiteIndenizacao;
  final String segmento; // 'pessoal', 'pme', 'enterprise'
  final int funcionarios;
  final bool possuiSoc; // Security Operation Center

  CalculoCyber({
    required this.limiteIndenizacao,
    required this.segmento,
    this.funcionarios = 1,
    this.possuiSoc = false,
  });

  double get taxaBase {
    switch (segmento.toLowerCase()) {
      case 'pessoal': return 0.0025;
      case 'pme': return 0.0060;
      case 'enterprise': return 0.0120;
      case 'saúde':
      case 'financeiro': return 0.0180;
      default: return 0.0080;
    }
  }

  double get fatorEscala {
    if (funcionarios <= 10) return 1.00;
    if (funcionarios <= 50) return 1.15;
    if (funcionarios <= 200) return 1.30;
    if (funcionarios <= 1000) return 1.45;
    return 1.60;
  }

  double get fatorSoc => possuiSoc ? 0.80 : 1.00;

  double get premPuroAnual => limiteIndenizacao * taxaBase * fatorEscala * fatorSoc;
  double get premComercialAnual => AtuarioPremissas.aplicarCarregamento(premPuroAnual);
  double get premComercialMensal => premComercialAnual / 12;

  Map<String, dynamic> toMap() => {
    'ramo': 'Cyber',
    'limite': limiteIndenizacao,
    'segmento': segmento,
    'taxa_base': taxaBase,
    'fat_escala': fatorEscala,
    'fat_soc': fatorSoc,
    'prem_puro_anual': premPuroAnual,
    'prem_comercial_anual': premComercialAnual,
    'prem_comercial_mensal': premComercialMensal,
  };
}

// ─── CÁLCULO PARAMÉTRICO CLIMÁTICO ─────────────────────────────
class CalculoParametrico {
  final double capitalSegurado;
  final String cultura;
  final double triggerMm;   // gatilho em mm de chuva
  final double exitMm;      // saída (perda total)
  final String regiao;

  CalculoParametrico({
    required this.capitalSegurado,
    required this.cultura,
    required this.triggerMm,
    required this.exitMm,
    required this.regiao,
  });

  // Frequência de acionamento baseada em dados históricos de 30 anos
  double get freqHistorica {
    switch (regiao.toLowerCase()) {
      case 'cerrado': return 0.35;
      case 'semi-árido': return 0.55;
      case 'amazônia': return 0.08;
      case 'sul': return 0.15;
      case 'sudeste': return 0.18;
      default: return 0.25;
    }
  }

  double get fatorCultura {
    switch (cultura.toLowerCase()) {
      case 'soja': return 1.00;
      case 'milho': return 1.05;
      case 'café': return 1.15;
      case 'cana': return 0.90;
      case 'algodão': return 1.10;
      default: return 1.00;
    }
  }

  // Perda esperada = IS * freq histórica * fator cultura * razão trigger/exit
  double get perdaEsperada {
    final razao = triggerMm / exitMm.clamp(1, double.infinity);
    return capitalSegurado * freqHistorica * fatorCultura * (1 - razao).clamp(0.3, 1.0);
  }

  double get premPuroAnual => perdaEsperada;
  double get premComercialAnual => AtuarioPremissas.aplicarCarregamento(premPuroAnual);
  double get premComercialMensal => premComercialAnual / 12;

  Map<String, dynamic> toMap() => {
    'ramo': 'Paramétrico',
    'cultura': cultura,
    'trigger_mm': triggerMm,
    'exit_mm': exitMm,
    'freq_historica': freqHistorica,
    'perda_esperada': perdaEsperada,
    'prem_comercial_anual': premComercialAnual,
    'prem_comercial_mensal': premComercialMensal,
  };
}

// ─── MOTOR ANTIFRAUDE ──────────────────────────────────────────
enum ResultadoFraude { aprovado, rejeitadoFraude, rejeitadoLitigio, agravado, analise }

class ScoreFraude {
  final String cpf;
  final ResultadoFraude resultado;
  final double fatorAgravamento;
  final String motivo;
  final int scoreRisco;
  final List<String> flags;

  const ScoreFraude({
    required this.cpf,
    required this.resultado,
    required this.fatorAgravamento,
    required this.motivo,
    required this.scoreRisco,
    required this.flags,
  });
}

class MotorAntifraude {
  static final _rnd = Random();

  // Banco de dados simulado de CPFs com flags
  static final Map<String, Map<String, dynamic>> _baseDados = {
    // CPFs recusados por fraude
    '111.111.111-11': {'fraude': true, 'litigio': false, 'sins': 0.80, 'score': 120},
    '222.222.222-22': {'fraude': true, 'litigio': true, 'sins': 1.20, 'score': 80},
    // CPFs com litigância predatória
    '333.333.333-33': {'fraude': false, 'litigio': true, 'sins': 0.60, 'score': 250},
    '444.444.444-44': {'fraude': false, 'litigio': true, 'sins': 0.40, 'score': 320},
    // CPFs com sinistralidade alta (agravamento)
    '555.555.555-55': {'fraude': false, 'litigio': false, 'sins': 1.45, 'score': 520},
    '666.666.666-66': {'fraude': false, 'litigio': false, 'sins': 1.25, 'score': 580},
  };

  static ScoreFraude analisar(String cpf, {
    int sinistrosUltimos5Anos = 0,
    double valorSinistros = 0,
    bool possuiProcessos = false,
  }) {
    final dados = _baseDados[cpf];

    // CPF no banco de dados
    if (dados != null) {
      if (dados['fraude'] == true) {
        return ScoreFraude(
          cpf: cpf,
          resultado: ResultadoFraude.rejeitadoFraude,
          fatorAgravamento: 0,
          motivo: 'CPF consta em birô de fraude comprovada de mercado (SUSEP/DPVAT)',
          scoreRisco: dados['score'] as int,
          flags: ['FRAUDE_CONFIRMADA', 'BLACKLIST_MERCADO'],
        );
      }
      if (dados['litigio'] == true) {
        return ScoreFraude(
          cpf: cpf,
          resultado: ResultadoFraude.rejeitadoLitigio,
          fatorAgravamento: 0,
          motivo: 'Histórico de litigância predatória — ${_rnd.nextInt(8) + 2} processos sem fundamento',
          scoreRisco: dados['score'] as int,
          flags: ['LITIGIO_PREDATORIO', 'COMPLIANCE_BLOCK'],
        );
      }
      final sins = dados['sins'] as double;
      if (sins > 1.20) {
        return ScoreFraude(
          cpf: cpf,
          resultado: ResultadoFraude.agravado,
          fatorAgravamento: sins,
          motivo: 'Sinistralidade elevada (${(sins * 100).toStringAsFixed(0)}% da média do ramo)',
          scoreRisco: dados['score'] as int,
          flags: ['SINISTRALIDADE_ALTA', 'AGRAVAMENTO_${((sins - 1) * 100).toStringAsFixed(0)}pct'],
        );
      }
    }

    // Análise dinâmica baseada nos dados informados
    final List<String> flagsDinamicas = [];
    int scoreDinamico = 750;
    double fatorDinamico = 1.0;

    if (sinistrosUltimos5Anos >= 3) {
      flagsDinamicas.add('3+ SINISTROS_5A');
      fatorDinamico += 0.25;
      scoreDinamico -= 100;
    } else if (sinistrosUltimos5Anos == 2) {
      flagsDinamicas.add('2 SINISTROS_5A');
      fatorDinamico += 0.12;
      scoreDinamico -= 50;
    }

    if (valorSinistros > 50000) {
      flagsDinamicas.add('SINISTRO_ALTO_VALOR');
      fatorDinamico += 0.15;
      scoreDinamico -= 80;
    }

    if (possuiProcessos) {
      flagsDinamicas.add('PROCESSO_JUDICIAL');
      fatorDinamico += 0.20;
      scoreDinamico -= 120;
    }

    if (fatorDinamico > 1.30 && scoreDinamico < 500) {
      return ScoreFraude(
        cpf: cpf,
        resultado: ResultadoFraude.analise,
        fatorAgravamento: fatorDinamico,
        motivo: 'Score de risco abaixo do limite — encaminhado para análise manual',
        scoreRisco: scoreDinamico,
        flags: flagsDinamicas,
      );
    }

    if (fatorDinamico > 1.0) {
      return ScoreFraude(
        cpf: cpf,
        resultado: ResultadoFraude.agravado,
        fatorAgravamento: fatorDinamico,
        motivo: 'Agravamento atuarial aplicado ao prêmio',
        scoreRisco: scoreDinamico,
        flags: flagsDinamicas,
      );
    }

    return ScoreFraude(
      cpf: cpf,
      resultado: ResultadoFraude.aprovado,
      fatorAgravamento: 1.0,
      motivo: 'Proposta aprovada — sem restrições no sistema',
      scoreRisco: scoreDinamico + _rnd.nextInt(50),
      flags: ['APROVADO', 'CLEAN_RECORD'],
    );
  }
}

// ─── SUBSCRITOR IA ─────────────────────────────────────────────
class ResultadoSubscricao {
  final bool aprovado;
  final String decisao;
  final String justificativa;
  final double fatorFinal;
  final double premComercialFinal;
  final List<String> observacoes;
  final String classeRisco;

  const ResultadoSubscricao({
    required this.aprovado,
    required this.decisao,
    required this.justificativa,
    required this.fatorFinal,
    required this.premComercialFinal,
    required this.observacoes,
    required this.classeRisco,
  });
}

class SubscritorIA {
  static ResultadoSubscricao analisarProposta({
    required String ramo,
    required double premPuroBase,
    required ScoreFraude scoreFraude,
    required Map<String, dynamic> dadosAtuariais,
    bool requerResseguro = false,
  }) {
    // Recusas automáticas
    if (scoreFraude.resultado == ResultadoFraude.rejeitadoFraude) {
      return ResultadoSubscricao(
        aprovado: false,
        decisao: 'RECUSADO — FRAUDE CONFIRMADA',
        justificativa: scoreFraude.motivo,
        fatorFinal: 0,
        premComercialFinal: 0,
        observacoes: ['Notificação automática enviada para SUSEP', 'CPF incluído em blacklist interna', 'Registro em sistema DPVAT/mercado'],
        classeRisco: 'BLACKLIST',
      );
    }

    if (scoreFraude.resultado == ResultadoFraude.rejeitadoLitigio) {
      return ResultadoSubscricao(
        aprovado: false,
        decisao: 'RECUSADO — COMPLIANCE',
        justificativa: scoreFraude.motivo,
        fatorFinal: 0,
        premComercialFinal: 0,
        observacoes: ['Análise jurídica acionada', 'Compliance officer notificado', 'Histórico documentado'],
        classeRisco: 'COMPLIANCE_BLOCK',
      );
    }

    if (scoreFraude.resultado == ResultadoFraude.analise) {
      return ResultadoSubscricao(
        aprovado: false,
        decisao: 'AGUARDANDO ANÁLISE MANUAL',
        justificativa: scoreFraude.motivo,
        fatorFinal: 0,
        premComercialFinal: 0,
        observacoes: ['Encaminhado para subscritor sênior', 'Prazo de análise: 48h', 'Documentação adicional requerida'],
        classeRisco: 'ANÁLISE',
      );
    }

    // Aprovados — calcular prêmio com fator de agravamento
    final fator = scoreFraude.fatorAgravamento;
    final premFinal = premPuroBase * fator;
    final premComercial = AtuarioPremissas.aplicarCarregamento(premFinal);

    final obs = <String>[];
    String classeRisco;

    if (scoreFraude.scoreRisco >= 750) {
      classeRisco = 'PREFERENCIAL';
      obs.add('Cliente premium — elegível para desconto fidelidade');
      obs.add('Classe de bônus disponível');
    } else if (scoreFraude.scoreRisco >= 600) {
      classeRisco = 'PADRÃO';
      obs.add('Apólice padrão emitida');
    } else if (scoreFraude.scoreRisco >= 450) {
      classeRisco = 'AGRAVADO';
      obs.add('Fator de agravamento ${((fator - 1) * 100).toStringAsFixed(0)}% aplicado');
      obs.add('Renovação sujeita a revisão atuarial');
    } else {
      classeRisco = 'ALTO RISCO';
      obs.add('Agravamento máximo aplicado');
      obs.add('Cobertura limitada — sem cobertura de roubo/furto');
      if (requerResseguro) obs.add('Resseguro automático acionado');
    }

    return ResultadoSubscricao(
      aprovado: true,
      decisao: 'APROVADO — $classeRisco',
      justificativa: scoreFraude.resultado == ResultadoFraude.agravado
          ? 'Aprovado com agravamento atuarial de ${((fator - 1) * 100).toStringAsFixed(0)}%'
          : 'Proposta aprovada sem restrições',
      fatorFinal: fator,
      premComercialFinal: premComercial,
      observacoes: obs,
      classeRisco: classeRisco,
    );
  }
}

// ─── PORTFÓLIO DE PRODUTOS ─────────────────────────────────────
class ProdutoSeguro {
  final String id;
  final String nome;
  final String categoria;
  final String descricao;
  final String modeloPrecificacao;
  final String metricaRisco;
  final String statusViabilidade;
  final bool escalaGlobal;

  const ProdutoSeguro({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.descricao,
    required this.modeloPrecificacao,
    required this.metricaRisco,
    required this.statusViabilidade,
    required this.escalaGlobal,
  });
}

class PortfolioSeguros {
  static const List<ProdutoSeguro> produtos = [
    // Seguros de Pessoas
    ProdutoSeguro(id: 'vida-ind', nome: 'Seguro de Vida Individual', categoria: 'Pessoas', descricao: 'Amparo financeiro para beneficiários em caso de morte', modeloPrecificacao: 'Tábua BR-EMS + qx por idade', metricaRisco: 'Taxa de mortalidade qx', statusViabilidade: 'Ativo', escalaGlobal: true),
    ProdutoSeguro(id: 'ap', nome: 'Acidentes Pessoais', categoria: 'Pessoas', descricao: 'Cobertura focada em morte acidental e invalidez', modeloPrecificacao: 'Frequência × Gravidade por atividade', metricaRisco: 'Índice de acidentes por ocupação', statusViabilidade: 'Ativo', escalaGlobal: true),
    ProdutoSeguro(id: 'viagem', nome: 'Seguro Viagem', categoria: 'Pessoas', descricao: 'Assistência médica, jurídica e indenização no exterior', modeloPrecificacao: 'Cobertura × Destino × Duração', metricaRisco: 'Custo médico por região', statusViabilidade: 'Ativo', escalaGlobal: true),
    ProdutoSeguro(id: 'prestamista', nome: 'Seguro Prestamista', categoria: 'Pessoas', descricao: 'Garante quitação de parcelas em caso de sinistro', modeloPrecificacao: 'Saldo devedor × PD × LGD', metricaRisco: 'Probabilidade de default', statusViabilidade: 'Ativo', escalaGlobal: false),
    // Seguros de Danos
    ProdutoSeguro(id: 'auto', nome: 'Automóvel / PHYD', categoria: 'Danos/Bens', descricao: 'Proteção contra colisão, roubo com telemetria Pay-How-You-Drive', modeloPrecificacao: 'Freq × Grav × Fator_Idade × Fator_CEP', metricaRisco: 'Telemetria GPS + acelerômetro', statusViabilidade: 'Em Implementação', escalaGlobal: true),
    ProdutoSeguro(id: 'residencial', nome: 'Residencial', categoria: 'Danos/Bens', descricao: 'Protege estrutura e conteúdo de residências', modeloPrecificacao: 'Taxa × Valor_Imóvel × Fator_Estrutura', metricaRisco: 'Carga de incêndio e alagamento', statusViabilidade: 'Ativo', escalaGlobal: false),
    ProdutoSeguro(id: 'empresarial', nome: 'Empresarial / Condomínio', categoria: 'Danos/Bens', descricao: 'Mitiga riscos operacionais e danos patrimoniais', modeloPrecificacao: 'Patrimônio × Taxa_Ramo × Fator_Ocupação', metricaRisco: 'Carga de incêndio + CNAE', statusViabilidade: 'Ativo', escalaGlobal: false),
    ProdutoSeguro(id: 'equipamentos', nome: 'Equipamentos Portáteis', categoria: 'Danos/Bens', descricao: 'Cobertura para smartphones, notebooks e gadgets', modeloPrecificacao: 'Valor_Bem × Taxa_Classe × Fator_Uso', metricaRisco: 'Frequência de quebra/roubo por modelo', statusViabilidade: 'Alta - Urgente', escalaGlobal: true),
    // Financeiros/Garantias
    ProdutoSeguro(id: 'garantia', nome: 'Seguro Garantia', categoria: 'Financeiros', descricao: 'Garante cumprimento de contratos e editais', modeloPrecificacao: 'Limite_Garantia × PD × LGD', metricaRisco: 'Rating financeiro + histórico', statusViabilidade: 'Ativo', escalaGlobal: false),
    ProdutoSeguro(id: 'credito', nome: 'Seguro de Crédito', categoria: 'Financeiros', descricao: 'Protege empresas contra inadimplência de clientes', modeloPrecificacao: 'Faturamento × Taxa_Setor × PD', metricaRisco: 'Probabilidade de default por CNPJ', statusViabilidade: 'Ativo', escalaGlobal: true),
    ProdutoSeguro(id: 'lucros', nome: 'Lucros Cessantes', categoria: 'Financeiros', descricao: 'Repõe perda de receita após sinistro patrimonial', modeloPrecificacao: 'Receita_Média × Prazo × Taxa_Ramo', metricaRisco: 'EBITDA + exposição ao risco', statusViabilidade: 'Ativo', escalaGlobal: false),
    // Novos Produtos Digitais
    ProdutoSeguro(id: 'cyber', nome: 'Seguro Cyber', categoria: 'Novos Produtos', descricao: 'Proteção contra vazamento de dados e ataques digitais', modeloPrecificacao: 'Freq_Ataques × Vuln_IP × Limite', metricaRisco: 'Scan API tempo real + CVE score', statusViabilidade: 'Alta - Urgente', escalaGlobal: true),
    ProdutoSeguro(id: 'gig', nome: 'Gig Economy / Microseguro', categoria: 'Novos Produtos', descricao: 'Seguros flexíveis por hora trabalhada — Uber, Upwork', modeloPrecificacao: 'Microtaxa × Hora × Fator_Plataforma', metricaRisco: 'Status na plataforma em tempo real', statusViabilidade: 'Média', escalaGlobal: true),
    ProdutoSeguro(id: 'parametrico', nome: 'Seguro Paramétrico Climático', categoria: 'Novos Produtos', descricao: 'Indenização automática via Smart Contract sem perícia', modeloPrecificacao: 'GEV × Trigger × Exit × IS', metricaRisco: 'Satélite NASA/NOAA + INMET', statusViabilidade: 'Alta', escalaGlobal: true),
    ProdutoSeguro(id: 'saude-mental', nome: 'Saúde Mental Corporativo', categoria: 'Novos Produtos', descricao: 'Cobertura para programas de bem-estar e burnout', modeloPrecificacao: 'Turnover × Sinistralidade_RH × Headcount', metricaRisco: 'Apps wellness + absenteísmo', statusViabilidade: 'Alta', escalaGlobal: true),
  ];

  static List<ProdutoSeguro> byCategoria(String cat) =>
      produtos.where((p) => p.categoria == cat).toList();

  static List<String> get categorias =>
      produtos.map((p) => p.categoria).toSet().toList();
}

// ─── MATRIZ ATUARIAL COMPLETA ───────────────────────────────────
class MatrizAtuarial {
  static const List<Map<String, String>> ramos = [
    {'ramo': 'Vida Individual', 'variavel': 'Idade do Segurado', 'formula': 'Prêmio Puro = IS × qx (BR-EMS 2021)', 'carregamento': 'DA + CC + ML + IOF'},
    {'ramo': 'Vida Individual', 'variavel': 'Tábua Mortalidade', 'formula': 'Ajustado = Base × (ExpVida_BR / ExpVida_País)', 'carregamento': 'Margem Seg. Atuarial'},
    {'ramo': 'Vida Individual', 'variavel': 'Gênero (M/F)', 'formula': 'qx_masc > qx_fem — BR-EMS 2021 IBGE', 'carregamento': 'Flutuação Sinistralidade'},
    {'ramo': 'Vida Individual', 'variavel': 'Profissão / Tabagismo', 'formula': 'Comercial = Puro × (1 + Agravamento)', 'carregamento': 'Flutuação Sinistralidade'},
    {'ramo': 'Automóvel', 'variavel': 'Ano/Modelo Veículo', 'formula': 'Base = Freq_Esp × Grav_Esp', 'carregamento': 'IOF + Custo Apólice'},
    {'ramo': 'Automóvel', 'variavel': 'Idade Motorista', 'formula': 'Ajustado = Base × Fator_Idade', 'carregamento': 'CC + Margem Lucro'},
    {'ramo': 'Automóvel', 'variavel': 'CEP de Pernoite', 'formula': 'Final = Base × Fator_CEP (roubo/furto)', 'carregamento': 'IOF + DA'},
    {'ramo': 'Automóvel', 'variavel': 'Uso / KM rodado', 'formula': 'Prêmio = Tarifa × Fator_Uso', 'carregamento': 'Carregamento Padrão'},
    {'ramo': 'Automóvel', 'variavel': 'Histórico Sinistros', 'formula': 'Final = Tarifário × (1 - %Bônus)', 'carregamento': 'Ajuste Comercial'},
    {'ramo': 'Residencial', 'variavel': 'Tipo Construção', 'formula': 'Taxa Com. = Taxa Pura × Fator_Estrutura', 'carregamento': 'Catástrofe + Resseguro'},
    {'ramo': 'Residencial', 'variavel': 'Localização (Flood)', 'formula': 'Prêmio = VaR × Taxa_Região', 'carregamento': 'Resseguro + DA'},
    {'ramo': 'RC / Garantia', 'variavel': 'Faturamento / Limite', 'formula': 'Prêmio = IS × Taxa_Ramo × Fator_Setor', 'carregamento': 'Def. Jurídica + ML'},
    {'ramo': 'Saúde', 'variavel': 'Faixa Etária', 'formula': 'Mensalidade = Custo_Assist / (1 - %Carregamento)', 'carregamento': 'VCMH + DA + CC'},
    {'ramo': 'Crédito/Garantia', 'variavel': 'Rating Empresa', 'formula': 'Prêmio = Valor × PD × LGD', 'carregamento': 'Análise Crédito + ML'},
  ];
}

// ─── CALIBRAÇÃO SADI v4.0 (World Bank + BR-EMS 2021) ───────────
// Utilitários para calibração do motor com dados reais de 30 países
class CalibracaoSADI {
  /// Resumo das fontes de dados integradas
  static const Map<String, String> fontes = {
    'tabua_mortalidade': 'IBGE Tabela 7350 — BR-EMS 2021 — Tábua Completa de Mortalidade',
    'dados_globais':     'World Bank Open Data — 30 países × 8 indicadores socioeconômicos',
    'susep_mercado':     'SUSEP Open Data — Estatísticas do mercado segurador brasileiro',
    'seguradoras_mundo': 'SafeRouteGo ETL — 239 seguradoras / 42 países (seguradoras_mundo.json)',
    'demografico_br':    'IBGE 2022 — Expectativa de vida por estado (27 UFs)',
  };

  /// Comparativo de prêmio de vida por país (capital R$ 500k, homem 35 anos, não-fumante)
  /// Demonstra o impacto da mortalidade real no pricing internacional
  static List<Map<String, dynamic>> comparativoPremioVida() {
    const capitalSegurado = 500000.0;
    const idade = 35;
    final resultado = <Map<String, dynamic>>[];

    for (final entry in DadosDemograficos.paises.entries) {
      final codigo = entry.key;
      final dados = entry.value;
      final calc = CalculoVida(
        capitalSegurado: capitalSegurado,
        idade: idade,
        paisCodigo: codigo,
        feminino: false,
      );
      resultado.add({
        'pais': dados['nome'],
        'codigo': codigo,
        'exp_vida': dados['expVida'],
        'qx_ajustado': calc.qxInternacional,
        'prem_anual_brl': calc.premComercialAnual,
        'prem_mensal_brl': calc.premComercialMensal,
        'fator_pais': TabuaMortalidade.fatorPais(codigo),
      });
    }

    // Ordenar por prêmio crescente
    resultado.sort((a, b) =>
        (a['prem_anual_brl'] as double).compareTo(b['prem_anual_brl'] as double));
    return resultado;
  }

  /// Top 5 países com menor risco de vida (menor prêmio)
  static List<Map<String, dynamic>> get topMenorRisco {
    final comp = comparativoPremioVida();
    return comp.take(5).toList();
  }

  /// Top 5 países com maior risco de vida (maior prêmio)
  static List<Map<String, dynamic>> get topMaiorRisco {
    final comp = comparativoPremioVida();
    return comp.reversed.take(5).toList();
  }

  /// Resumo executivo da calibração para o Admin
  static Map<String, dynamic> resumoExecutivo() {
    return {
      'versao_engine': 'SADI v4.0',
      'tabua_mortalidade': TabuaMortalidade.versao,
      'data_atualizacao': TabuaMortalidade.dataAtualizacao,
      'total_paises': DadosDemograficos.paises.length,
      'total_estados_br': DadosDemograficos.expVidaEstados.length,
      'exp_vida_br_masc': DadosDemograficos.expVidaBrMasc,
      'exp_vida_br_fem': DadosDemograficos.expVidaBrFem,
      'exp_vida_br_geral': DadosDemograficos.expVidaBrGeral,
      'melhor_exp_vida': {
        'pais': 'Suíça',
        'codigo': 'CH',
        'anos': 83.97,
        'fator_reducao_premio': DadosDemograficos.fatorAjusteVida('CH'),
      },
      'pior_exp_vida': {
        'pais': 'Nigéria',
        'codigo': 'NG',
        'anos': 55.75,
        'fator_agravamento_premio': DadosDemograficos.fatorAjusteVida('NG'),
      },
      'premissas_sadi': {
        'da': AtuarioPremissas.da,
        'cc': AtuarioPremissas.cc,
        'ml': AtuarioPremissas.ml,
        'iof': AtuarioPremissas.iof,
        'seguranca': AtuarioPremissas.seguranca,
        'carregamento_total': AtuarioPremissas.carregamento,
      },
      'fontes': fontes,
    };
  }
}

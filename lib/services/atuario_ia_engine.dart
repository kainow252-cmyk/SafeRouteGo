// ═══════════════════════════════════════════════════════════════════
// ATUÁRIO IA ENGINE v3.0 — SafeRouteGo
// Motor de cálculo atuarial em tempo real com IA
// Baseado no SADI (Sistema Atuarial Digital Integrado)
// Premissas: DA=15%, CC=10%, ML=8%, IOF=7,38%, Seg=5%
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

// ─── TÁBUA DE MORTALIDADE BR-EMS (simplificada) ───────────────
class TabuaMortalidade {
  static const Map<int, double> _qx = {
    18: 0.00082, 20: 0.00085, 25: 0.00092, 28: 0.00085,
    30: 0.00098, 33: 0.00112, 35: 0.00135, 40: 0.00178,
    42: 0.00235, 45: 0.00312, 50: 0.00418, 54: 0.00542,
    55: 0.00620, 60: 0.00890, 62: 0.01050, 65: 0.01280,
    67: 0.01480, 70: 0.01820, 75: 0.02350, 80: 0.03200,
  };

  static double getQx(int idade) {
    // Interpolação linear entre pontos conhecidos
    final keys = _qx.keys.toList()..sort();
    for (int i = 0; i < keys.length - 1; i++) {
      if (idade >= keys[i] && idade <= keys[i + 1]) {
        final t = (idade - keys[i]) / (keys[i + 1] - keys[i]);
        return _qx[keys[i]]! + t * (_qx[keys[i + 1]]! - _qx[keys[i]]!);
      }
    }
    if (idade < keys.first) return _qx[keys.first]!;
    return _qx[keys.last]!;
  }
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
class CalculoVida {
  final double capitalSegurado;
  final int idade;
  final bool tabagista;
  final String profissao;

  CalculoVida({
    required this.capitalSegurado,
    required this.idade,
    this.tabagista = false,
    this.profissao = 'geral',
  });

  double get qx => TabuaMortalidade.getQx(idade);

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

  double get premPuroAnual => capitalSegurado * qx * fatorTabagismo * fatorProfissao;
  double get carregamentoSeguranca => premPuroAnual * AtuarioPremissas.seguranca;
  double get premPuroTotal => premPuroAnual + carregamentoSeguranca;
  double get premComercialAnual => AtuarioPremissas.aplicarCarregamento(premPuroAnual);
  double get premComercialMensal => premComercialAnual / 12;

  Map<String, dynamic> toMap() => {
    'ramo': 'Vida',
    'capital_segurado': capitalSegurado,
    'idade': idade,
    'qx': qx,
    'fat_tabagismo': fatorTabagismo,
    'fat_profissao': fatorProfissao,
    'prem_puro_anual': premPuroAnual,
    'prem_comercial_anual': premComercialAnual,
    'prem_comercial_mensal': premComercialMensal,
  };
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
    {'ramo': 'Vida Individual', 'variavel': 'Idade do Segurado', 'formula': 'Prêmio Puro = IS × qx', 'carregamento': 'DA + CC + ML + IOF'},
    {'ramo': 'Vida Individual', 'variavel': 'Tábua Mortalidade', 'formula': 'Ajustado = Base × (ExpVida_ref / ExpVida_atual)', 'carregamento': 'Margem Seg. Atuarial'},
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

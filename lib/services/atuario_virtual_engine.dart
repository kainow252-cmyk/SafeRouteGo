// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — ATUÁRIO VIRTUAL ENGINE  (IA OCULTA)
//
// Motor atuarial totalmente automático: sem seletores manuais, sem tela
// de perfil visível. Recebe dados coletados pelo app e calcula tudo.
//
// FÓRMULA ATUARIAL:
//   Prêmio = P(sinistro) × Custo_médio + Despesas + Reserva + Margem
//
// SCORE ATUARIAL (0–100):
//   Cada fator contribui positiva ou negativamente.
//   Faixas: 0–20 Baixo / 21–40 Moderado / 41–60 Médio / 61–80 Alto / 81+ Crítico
//
// SAÍDA EXPLICÁVEL:
//   Cada fator exibe: nome, impacto em % e motivo — como um atuário real faria.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'risk_engine.dart'; // RiskZone, WeatherCondition, TrafficLevel

// ─────────────────────────────────────────────────────────────────────────────
// INPUT — todos os dados coletados automaticamente pelo app
// ─────────────────────────────────────────────────────────────────────────────

class AtuarioInput {
  // ── Veículo (FIPE real) ───────────────────────────────────────
  final double fipeValor;         // R$ — tabela FIPE
  final int    anoModelo;         // ex: 2020
  final String vehicleModel;      // ex: "Chevrolet Onix"
  final double theftIndex;        // 0.0–1.0 (índice de roubo do modelo)

  // ── Condutor (perfil salvo) ───────────────────────────────────
  final int    idadeCondutor;     // anos
  final int    cnhAnos;           // tempo de habilitação
  final int    sinistros3Anos;    // ocorrências históricas
  final int    multas12Meses;     // infrações recentes
  final int    acidentes3Anos;    // acidentes com dano
  final bool   temGaragem;        // veículo pernoita em garagem?
  final bool   temRastreador;     // rastreador instalado?

  // ── Rota / viagem (coletados automaticamente) ─────────────────
  final double distanciaKm;       // km reais da rota (OSRM)
  final double kmMes;             // km estimado por mês
  final DateTime horarioPartida;  // hora/min real do sistema
  final RiskZone zonaRota;        // zona de risco da rota
  final WeatherCondition clima;   // clima detectado
  final TrafficLevel transito;    // tráfego via OSRM

  // ── Região (GPS → CEP → dados OSM) ────────────────────────────
  final int    cepRiskScore;      // 0–1000 (CepRiskDatabase)
  final String cidadeOrigem;
  final String cidadeDestino;

  const AtuarioInput({
    // veículo
    this.fipeValor       = 80000,
    this.anoModelo       = 2020,
    this.vehicleModel    = 'Chevrolet Onix',
    this.theftIndex      = 0.55,
    // condutor
    this.idadeCondutor   = 28,
    this.cnhAnos         = 7,
    this.sinistros3Anos  = 0,
    this.multas12Meses   = 0,
    this.acidentes3Anos  = 0,
    this.temGaragem      = false,
    this.temRastreador   = false,
    // rota
    this.distanciaKm     = 25.0,
    this.kmMes           = 1200,
    this.horarioPartida  = const _FakeNow(),
    this.zonaRota        = RiskZone.amarela,
    this.clima           = WeatherCondition.sol,
    this.transito        = TrafficLevel.moderado,
    // região
    this.cepRiskScore    = 300,
    this.cidadeOrigem    = 'Serra',
    this.cidadeDestino   = 'Vitória',
  });
}

// helper — DateTime constante para const constructor
class _FakeNow implements DateTime {
  const _FakeNow();
  @override int get hour => DateTime.now().hour;
  @override int get minute => DateTime.now().minute;
  @override int get second => 0;
  @override int get millisecond => 0;
  @override int get microsecond => 0;
  @override int get millisecondsSinceEpoch => DateTime.now().millisecondsSinceEpoch;
  @override int get microsecondsSinceEpoch => DateTime.now().microsecondsSinceEpoch;
  @override int get day => DateTime.now().day;
  @override int get month => DateTime.now().month;
  @override int get year => DateTime.now().year;
  @override int get weekday => DateTime.now().weekday;
  @override bool get isUtc => false;
  @override String get timeZoneName => '';
  @override Duration get timeZoneOffset => Duration.zero;
  @override DateTime add(Duration d) => DateTime.now().add(d);
  @override DateTime subtract(Duration d) => DateTime.now().subtract(d);
  @override Duration difference(DateTime d) => DateTime.now().difference(d);
  @override bool isAfter(DateTime d) => DateTime.now().isAfter(d);
  @override bool isBefore(DateTime d) => DateTime.now().isBefore(d);
  @override bool isAtSameMomentAs(DateTime d) => false;
  @override int compareTo(DateTime d) => DateTime.now().compareTo(d);
  @override DateTime toLocal() => DateTime.now();
  @override DateTime toUtc() => DateTime.now().toUtc();
  @override String toIso8601String() => DateTime.now().toIso8601String();
  @override String toString() => DateTime.now().toString();
  @override int get hashCode => 0;
  @override bool operator ==(Object o) => false;
  @override bool operator >(DateTime d) => DateTime.now().isAfter(d);
  @override bool operator >=(DateTime d) => !DateTime.now().isBefore(d);
  @override bool operator <(DateTime d) => DateTime.now().isBefore(d);
  @override bool operator <=(DateTime d) => !DateTime.now().isAfter(d);
  @override Comparable<DateTime> get value => DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR EXPLICÁVEL — o que o usuário vê
// ─────────────────────────────────────────────────────────────────────────────

enum FatorTipo { aumenta, reduz, neutro }

class FatorExplicavel {
  final String nome;          // ex: "Região de alto roubo"
  final double pontos;        // ex: +25 (sempre positivo = aumenta score)
  final FatorTipo tipo;       // aumenta / reduz / neutro
  final String motivo;        // ex: "CEP com índice criminal acima da média"
  final IconData icone;
  final Color cor;

  const FatorExplicavel({
    required this.nome,
    required this.pontos,
    required this.tipo,
    required this.motivo,
    required this.icone,
    required this.cor,
  });

  String get impactoLabel {
    final pct = pontos.abs().toStringAsFixed(0);
    switch (tipo) {
      case FatorTipo.aumenta: return '+$pct pts';
      case FatorTipo.reduz:   return '-$pct pts';
      case FatorTipo.neutro:  return '±0 pts';
    }
  }

  String get impactoPremio {
    final pct = pontos.abs().toStringAsFixed(0);
    switch (tipo) {
      case FatorTipo.aumenta: return '+$pct%';
      case FatorTipo.reduz:   return '-$pct%';
      case FatorTipo.neutro:  return 'neutro';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROBABILIDADES DE SINISTRO
// ─────────────────────────────────────────────────────────────────────────────

class ProbSinistro {
  final double pRoubo;       // % ao ano
  final double pFurto;
  final double pColisao;
  final double pTerceiros;
  final double pTotal;       // P(ao menos um evento)

  final double custoMedioEsperado; // R$ — valor esperado de sinistro por ano
  final double custoRoubo;
  final double custoFurto;
  final double custoColisao;
  final double custoTerceiros;

  const ProbSinistro({
    required this.pRoubo, required this.pFurto,
    required this.pColisao, required this.pTerceiros, required this.pTotal,
    required this.custoMedioEsperado,
    required this.custoRoubo, required this.custoFurto,
    required this.custoColisao, required this.custoTerceiros,
  });

  String fmt(double p) => '${(p * 100).toStringAsFixed(1)}%';
  String fmtBRL(double v) => 'R\$ ${v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO COMPLETO
// ─────────────────────────────────────────────────────────────────────────────

class AtuarioResult {
  // ── Score atuarial ────────────────────────────────────────────
  final double scoreAtuarial;    // 0–100
  final String classeRisco;      // "Baixo" / "Moderado" / "Médio" / "Alto" / "Crítico"
  final Color  corClasse;
  final String descricaoClasse;

  // ── Precificação (fórmula atuarial) ──────────────────────────
  final double premioAnual;      // R$ por ANO
  final double premioMensal;     // R$ por MÊS
  final double premioPorKm;      // R$ por KM rodado (esta viagem)
  final double premioViagem;     // R$ para esta viagem específica

  // ── Breakdown do prêmio (transparência total) ─────────────────
  final double riscoEsperado;    // P(sinistro) × custo médio
  final double despesasAdmin;    // % do prêmio (custos operacionais)
  final double reservaTecnica;   // % do prêmio (margem de segurança)
  final double margemLucro;      // % do prêmio

  // ── Franquia ─────────────────────────────────────────────────
  final double franquia;         // valor a pagar em caso de sinistro

  // ── Probabilidades ────────────────────────────────────────────
  final ProbSinistro probs;

  // ── Fatores explicáveis ───────────────────────────────────────
  final List<FatorExplicavel> fatores; // ordenados por impacto

  // ── Contexto ─────────────────────────────────────────────────
  final String origemLabel;
  final String destinoLabel;
  final double distanciaKm;
  final DateTime calculadoEm;

  AtuarioResult({
    required this.scoreAtuarial,
    required this.classeRisco,
    required this.corClasse,
    required this.descricaoClasse,
    required this.premioAnual,
    required this.premioMensal,
    required this.premioPorKm,
    required this.premioViagem,
    required this.riscoEsperado,
    required this.despesasAdmin,
    required this.reservaTecnica,
    required this.margemLucro,
    required this.franquia,
    required this.probs,
    required this.fatores,
    required this.origemLabel,
    required this.destinoLabel,
    required this.distanciaKm,
  }) : calculadoEm = DateTime.now();

  String get premioViagemFmt  => 'R\$ ${premioViagem.toStringAsFixed(2).replaceAll('.', ',')}';
  String get premioMensalFmt  => 'R\$ ${premioMensal.toStringAsFixed(2).replaceAll('.', ',')}';
  String get premioAnualFmt   => 'R\$ ${premioAnual.toStringAsFixed(0).replaceAll('.', ',')}';
  String get premioPorKmFmt   => 'R\$ ${premioPorKm.toStringAsFixed(3).replaceAll('.', ',')}';
  String get franquiaFmt      => 'R\$ ${franquia.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  String get scoreLabel       => '${scoreAtuarial.toStringAsFixed(1)}/100';

  // Fatores que aumentam (ordenados por pontos desc)
  List<FatorExplicavel> get aumentam =>
      fatores.where((f) => f.tipo == FatorTipo.aumenta)
             .toList()..sort((a, b) => b.pontos.compareTo(a.pontos));

  // Fatores que reduzem
  List<FatorExplicavel> get reduzem =>
      fatores.where((f) => f.tipo == FatorTipo.reduz)
             .toList()..sort((a, b) => b.pontos.compareTo(a.pontos));
}

// ─────────────────────────────────────────────────────────────────────────────
// ATUÁRIO VIRTUAL ENGINE — CÁLCULO OCULTO
// ─────────────────────────────────────────────────────────────────────────────

class AtuarioVirtualEngine {
  // ── Tarifa base por km (R$/km rodado) ────────────────────────
  // ── Km médio anual de referência (condutor urbano brasileiro médio) ──────
  static const double _kmAnoReferencia = 15000.0; // 15.000 km/ano (SENATRAN)
  static const double _premioMinimo    = 4.99;    // R$ mínimo absoluto por viagem
  // Sem teto máximo — prêmio reflete o risco real (viagens longas/alto risco
  // podem ultrapassar R$ 850 sem limitação artificial)


  // ── Despesas operacionais / reserva / lucro ───────────────────
  static const double _pctDespesas  = 0.12; // 12% do prêmio técnico
  static const double _pctReserva   = 0.10; // 10%
  static const double _pctMargem    = 0.08; // 8%

  // ── CÁLCULO PRINCIPAL ─────────────────────────────────────────
  static AtuarioResult calculate(AtuarioInput input) {
    // 1) Constrói lista de fatores e acumula score
    final fatores = <FatorExplicavel>[];
    double score = 0;

    // ── F1: Faixa etária do condutor ─────────────────────────
    final fIdade = _fatorIdade(input.idadeCondutor, fatores);

    // ── F2: Experiência CNH ───────────────────────────────────
    final fCnh = _fatorCnh(input.cnhAnos, fatores);

    // ── F3: Histórico de sinistros ────────────────────────────
    final fSinistros = _fatorSinistros(
        input.sinistros3Anos, input.acidentes3Anos, fatores);

    // ── F4: Multas recentes ───────────────────────────────────
    final fMultas = _fatorMultas(input.multas12Meses, fatores);

    // ── F5: Região / CEP ──────────────────────────────────────
    final fRegiao = _fatorRegiao(input.cepRiskScore, input.zonaRota, fatores);

    // ── F6: Veículo — valor FIPE ──────────────────────────────
    final fFipe = _fatorFipe(input.fipeValor, fatores);

    // ── F7: Veículo — índice de roubo do modelo ───────────────
    final fRoubo = _fatorRouboModelo(input.theftIndex, input.vehicleModel, fatores);

    // ── F8: Idade do veículo ──────────────────────────────────
    final idadeVeiculo = DateTime.now().year - input.anoModelo;
    final fVeiculo = _fatorIdadeVeiculo(idadeVeiculo, fatores);

    // ── F9: Horário de circulação ─────────────────────────────
    final fHorario = _fatorHorario(input.horarioPartida.hour, fatores);

    // ── F10: Clima ─────────────────────────────────────────────
    final fClima = _fatorClima(input.clima, fatores);

    // ── F11: Trânsito (OSRM automático) ──────────────────────
    final fTransito = _fatorTransito(input.transito, fatores);

    // ── F12: Quilometragem mensal ─────────────────────────────
    final fKmMes = _fatorKmMes(input.kmMes, fatores);

    // ── F13: Garagem e rastreador (descontos) ─────────────────
    final fBonusEquip = _fatorBonus(input.temGaragem, input.temRastreador, fatores);

    // Score bruto: soma de todos os impactos nos fatores
    for (final f in fatores) {
      if (f.tipo == FatorTipo.aumenta) score += f.pontos;
      if (f.tipo == FatorTipo.reduz)   score -= f.pontos;
    }
    score = score.clamp(0, 100);

    // 2) Multiplicador atuarial composto (produto dos fatores)
    final multComposto = fIdade * fCnh * fSinistros * fMultas * fRegiao *
        fFipe * fRoubo * fVeiculo * fHorario * fClima * fTransito *
        fKmMes * fBonusEquip;

    // 3) Probabilidades de sinistro (bases por tipo, ES/urbano)
    final probs = _calcProbabilidades(input, fRegiao, fHorario, fRoubo,
        fClima, fIdade, fSinistros);

    // 4) FÓRMULA ATUARIAL CORRETA
    //
    //  Risco Esperado Anual = Σ(P × Severidade × FIPE)
    //    = P(roubo)×FIPE×80% + P(furto)×FIPE×60% + P(col)×FIPE×25% + P(3ºs)×FIPE×10%
    //
    //  Prêmio Técnico Anual = Risco × multComposto
    //  Prêmio Bruto Anual   = Técnico ÷ (1 − loading)  [loading = 30%]
    //
    //  Prêmio da Viagem     = Anual × (km_viagem ÷ km_condutor_ano)
    //    → rateia a exposição anual pela fração real desta viagem
    //
    final riscoEsperado = probs.custoMedioEsperado; // Σ(P × Sev × FIPE) anual
    final premioTecnico = riscoEsperado * multComposto;

    // Loading total = 30% (operação 12% + reserva 10% + margem 8%)
    const loadingTotal = _pctDespesas + _pctReserva + _pctMargem; // 0.30
    final premioAnualBruto = premioTecnico / (1.0 - loadingTotal);

    // Breakdown (para o painel de engenharia e _PremioBreakdownCard)
    final despesas = premioAnualBruto * _pctDespesas;
    final reserva  = premioAnualBruto * _pctReserva;
    final margem   = premioAnualBruto * _pctMargem;

    final premioAnual  = premioAnualBruto.clamp(900.0, 120000.0);
    final premioMensal = premioAnual / 12;

    // km real do condutor: usa dado do perfil ou referência SENATRAN
    final kmAnual     = math.max(input.kmMes * 12.0, 6000.0);
    final premioPorKm = premioAnual / kmAnual;

    // PRÊMIO DA VIAGEM = rateia o custo anual pela exposição desta viagem
    // Sem clamp máximo — prêmio reflete o risco real da distância percorrida.
    // Viagens longas (ex: ES→SP 900km) geram prêmio proporcional ao risco.
    // Fração sem limite superior: km_viagem / km_ano (mínimo 0,05% = ~7km)
    final fracaoExposicao   = math.max(input.distanciaKm / kmAnual, 0.0005);
    final premioViagemBruto = premioAnualBruto * fracaoExposicao;

    // Aplica apenas o mínimo operacional — sem teto máximo
    final premioViagem = math.max(premioViagemBruto, _premioMinimo);

    // 5) Franquia = 5% do FIPE × fator de risco
    final franquia = (input.fipeValor * 0.05 * (1 + score / 200))
                     .clamp(500.0, 15000.0);

    // 6) Classe de risco pelo score
    final (classe, cor, desc) = _classeScore(score);

    // 7) Ordena fatores por impacto absoluto (os mais relevantes primeiro)
    fatores.sort((a, b) => b.pontos.abs().compareTo(a.pontos.abs()));

    return AtuarioResult(
      scoreAtuarial:   score,
      classeRisco:     classe,
      corClasse:       cor,
      descricaoClasse: desc,
      premioAnual:     premioAnual,
      premioMensal:    premioMensal,
      premioPorKm:     premioPorKm,
      premioViagem:    premioViagem,
      riscoEsperado:   riscoEsperado,
      despesasAdmin:   despesas,
      reservaTecnica:  reserva,
      margemLucro:     margem,
      franquia:        franquia,
      probs:           probs,
      fatores:         fatores,
      origemLabel:     input.cidadeOrigem,
      destinoLabel:    input.cidadeDestino,
      distanciaKm:     input.distanciaKm,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FATORES INDIVIDUAIS (retornam multiplicador + adicionam FatorExplicavel)
  // ═══════════════════════════════════════════════════════════════

  static double _fatorIdade(int idade, List<FatorExplicavel> f) {
    if (idade < 18) {
      f.add(FatorExplicavel(nome: 'Abaixo de 18 anos', pontos: 35,
          tipo: FatorTipo.aumenta, motivo: 'Condutores menores não habilitados — risco extremo.',
          icone: Icons.person_outlined, cor: const Color(0xFFEF4444)));
      return 2.5;
    } else if (idade <= 25) {
      f.add(FatorExplicavel(nome: 'Condutor jovem ($idade anos)', pontos: 20,
          tipo: FatorTipo.aumenta, motivo: 'Faixa 18–25 anos registra 40% mais colisões que a média.',
          icone: Icons.person_outlined, cor: const Color(0xFFF97316)));
      return 1.6;
    } else if (idade <= 35) {
      f.add(FatorExplicavel(nome: 'Condutor adulto ($idade anos)', pontos: 5,
          tipo: FatorTipo.aumenta, motivo: 'Risco levemente acima da faixa ideal.',
          icone: Icons.person_outlined, cor: const Color(0xFFF59E0B)));
      return 1.2;
    } else if (idade <= 60) {
      f.add(FatorExplicavel(nome: 'Faixa etária ideal ($idade anos)', pontos: 5,
          tipo: FatorTipo.reduz, motivo: 'Condutor entre 36–60: menor índice de acidentes.',
          icone: Icons.person_rounded, cor: const Color(0xFF22C55E)));
      return 1.0;
    } else {
      f.add(FatorExplicavel(nome: 'Condutor sênior ($idade anos)', pontos: 8,
          tipo: FatorTipo.aumenta, motivo: 'Reflexos reduzidos aumentam risco acima de 60 anos.',
          icone: Icons.person_outlined, cor: const Color(0xFFF59E0B)));
      return 1.3;
    }
  }

  static double _fatorCnh(int anos, List<FatorExplicavel> f) {
    if (anos < 1) {
      f.add(FatorExplicavel(nome: 'CNH recente (< 1 ano)', pontos: 20,
          tipo: FatorTipo.aumenta, motivo: 'Habilitação nova = menor experiência = maior risco.',
          icone: Icons.credit_card_rounded, cor: const Color(0xFFEF4444)));
      return 1.5;
    } else if (anos < 3) {
      f.add(FatorExplicavel(nome: 'CNH nova ($anos anos)', pontos: 10,
          tipo: FatorTipo.aumenta, motivo: 'Menos de 3 anos de habilitação.',
          icone: Icons.credit_card_rounded, cor: const Color(0xFFF97316)));
      return 1.2;
    } else if (anos >= 10) {
      f.add(FatorExplicavel(nome: 'Condutor experiente ($anos anos CNH)', pontos: 8,
          tipo: FatorTipo.reduz, motivo: 'Mais de 10 anos de habilitação reduz risco estatístico.',
          icone: Icons.credit_card_rounded, cor: const Color(0xFF22C55E)));
      return 0.92;
    }
    return 1.0; // 3–9 anos: neutro
  }

  static double _fatorSinistros(int sinist, int acid, List<FatorExplicavel> f) {
    final total = sinist + acid;
    if (total == 0) {
      f.add(FatorExplicavel(nome: 'Histórico limpo (3 anos)', pontos: 10,
          tipo: FatorTipo.reduz, motivo: 'Nenhum sinistro ou acidente nos últimos 3 anos.',
          icone: Icons.verified_rounded, cor: const Color(0xFF22C55E)));
      return 0.9;
    } else if (total == 1) {
      f.add(FatorExplicavel(nome: '1 ocorrência em 3 anos', pontos: 15,
          tipo: FatorTipo.aumenta, motivo: 'Histórico de sinistro é o fator mais preditivo.',
          icone: Icons.warning_amber_rounded, cor: const Color(0xFFF59E0B)));
      return 1.3;
    } else if (total == 2) {
      f.add(FatorExplicavel(nome: '$total ocorrências em 3 anos', pontos: 28,
          tipo: FatorTipo.aumenta, motivo: 'Reincidência indica padrão comportamental de risco.',
          icone: Icons.warning_rounded, cor: const Color(0xFFF97316)));
      return 1.7;
    } else {
      f.add(FatorExplicavel(nome: '$total ocorrências em 3 anos', pontos: 40,
          tipo: FatorTipo.aumenta, motivo: 'Alto histórico de sinistros — risco crítico.',
          icone: Icons.gpp_bad_rounded, cor: const Color(0xFFEF4444)));
      return 2.2;
    }
  }

  static double _fatorMultas(int multas, List<FatorExplicavel> f) {
    if (multas == 0) return 1.0; // neutro — sem comentário
    if (multas <= 1) {
      f.add(FatorExplicavel(nome: '1 multa (12 meses)', pontos: 8,
          tipo: FatorTipo.aumenta, motivo: 'Infrações recentes indicam comportamento arriscado.',
          icone: Icons.speed_rounded, cor: const Color(0xFFF59E0B)));
      return 1.1;
    } else if (multas <= 3) {
      f.add(FatorExplicavel(nome: '$multas multas (12 meses)', pontos: 18,
          tipo: FatorTipo.aumenta, motivo: 'Padrão de infrações aumenta risco de colisão.',
          icone: Icons.speed_rounded, cor: const Color(0xFFF97316)));
      return 1.3;
    } else {
      f.add(FatorExplicavel(nome: '$multas multas (12 meses)', pontos: 30,
          tipo: FatorTipo.aumenta, motivo: 'Histórico grave — risco elevado de suspensão CNH.',
          icone: Icons.speed_rounded, cor: const Color(0xFFEF4444)));
      return 1.6;
    }
  }

  static double _fatorRegiao(int cepScore, RiskZone zona, List<FatorExplicavel> f) {
    if (cepScore <= 200) {
      f.add(FatorExplicavel(nome: 'Região de baixo risco', pontos: 5,
          tipo: FatorTipo.reduz, motivo: 'Área com baixo índice de roubos e acidentes.',
          icone: Icons.location_on_rounded, cor: const Color(0xFF22C55E)));
      return 0.95;
    } else if (cepScore <= 400) {
      return 1.0; // neutro
    } else if (cepScore <= 600) {
      f.add(FatorExplicavel(nome: 'Região de risco médio', pontos: 12,
          tipo: FatorTipo.aumenta, motivo: 'Área com ocorrências acima da média do ES.',
          icone: Icons.location_on_rounded, cor: const Color(0xFFF59E0B)));
      return 1.25;
    } else if (cepScore <= 800) {
      f.add(FatorExplicavel(nome: 'Região de alto risco', pontos: 25,
          tipo: FatorTipo.aumenta, motivo: 'Alto índice de roubos — aumenta prêmio em ~25%.',
          icone: Icons.location_on_rounded, cor: const Color(0xFFF97316)));
      return 1.6;
    } else {
      f.add(FatorExplicavel(nome: 'Região crítica de risco', pontos: 35,
          tipo: FatorTipo.aumenta, motivo: 'Zona de risco extremo — roubos e colisões frequentes.',
          icone: Icons.location_on_rounded, cor: const Color(0xFFEF4444)));
      return 2.0;
    }
  }

  static double _fatorFipe(double fipe, List<FatorExplicavel> f) {
    if (fipe <= 40000) {
      f.add(FatorExplicavel(nome: 'Veículo popular (${_fmtFipe(fipe)})', pontos: 5,
          tipo: FatorTipo.reduz, motivo: 'Custo de reparo/reposição baixo.',
          icone: Icons.directions_car_rounded, cor: const Color(0xFF22C55E)));
      return 0.95;
    } else if (fipe <= 80000) {
      return 1.0;
    } else if (fipe <= 150000) {
      f.add(FatorExplicavel(nome: 'Veículo intermediário (${_fmtFipe(fipe)})', pontos: 10,
          tipo: FatorTipo.aumenta, motivo: 'Custo de reparo elevado impacta prêmio.',
          icone: Icons.directions_car_rounded, cor: const Color(0xFFF59E0B)));
      return 1.2;
    } else if (fipe <= 300000) {
      f.add(FatorExplicavel(nome: 'Veículo premium (${_fmtFipe(fipe)})', pontos: 20,
          tipo: FatorTipo.aumenta, motivo: 'Peças e mão de obra especializadas encarecem o seguro.',
          icone: Icons.directions_car_filled_rounded, cor: const Color(0xFFF97316)));
      return 1.5;
    } else {
      f.add(FatorExplicavel(nome: 'Veículo de luxo (${_fmtFipe(fipe)})', pontos: 30,
          tipo: FatorTipo.aumenta, motivo: 'Alto valor de reposição — risco financeiro crítico.',
          icone: Icons.directions_car_filled_rounded, cor: const Color(0xFFEF4444)));
      return 1.9;
    }
  }

  static double _fatorRouboModelo(double idx, String model, List<FatorExplicavel> f) {
    if (idx >= 0.7) {
      f.add(FatorExplicavel(nome: 'Modelo muito visado ($model)', pontos: 20,
          tipo: FatorTipo.aumenta, motivo: 'Alta demanda por peças deste modelo no mercado ilegal.',
          icone: Icons.car_crash_rounded, cor: const Color(0xFFEF4444)));
      return 1.4;
    } else if (idx >= 0.5) {
      f.add(FatorExplicavel(nome: 'Modelo visado ($model)', pontos: 12,
          tipo: FatorTipo.aumenta, motivo: 'Índice de roubo acima da média para este modelo.',
          icone: Icons.car_crash_rounded, cor: const Color(0xFFF97316)));
      return 1.2;
    } else if (idx <= 0.3) {
      f.add(FatorExplicavel(nome: 'Modelo pouco visado ($model)', pontos: 8,
          tipo: FatorTipo.reduz, motivo: 'Baixo índice histórico de roubo para este modelo.',
          icone: Icons.verified_user_rounded, cor: const Color(0xFF22C55E)));
      return 0.9;
    }
    return 1.0;
  }

  static double _fatorIdadeVeiculo(int anos, List<FatorExplicavel> f) {
    if (anos <= 2) return 1.0;
    if (anos <= 5) {
      f.add(FatorExplicavel(nome: 'Veículo com $anos anos', pontos: 5,
          tipo: FatorTipo.aumenta, motivo: 'Início de depreciação — peças mais escassas.',
          icone: Icons.calendar_today_rounded, cor: const Color(0xFFF59E0B)));
      return 1.08;
    } else if (anos <= 10) {
      f.add(FatorExplicavel(nome: 'Veículo com $anos anos', pontos: 12,
          tipo: FatorTipo.aumenta, motivo: 'Desgaste e custo de manutenção elevados.',
          icone: Icons.calendar_today_rounded, cor: const Color(0xFFF97316)));
      return 1.2;
    } else {
      f.add(FatorExplicavel(nome: 'Veículo antigo (${anos}+ anos)', pontos: 18,
          tipo: FatorTipo.aumenta, motivo: 'Veículo com mais de 10 anos — maior risco de falha mecânica.',
          icone: Icons.calendar_today_rounded, cor: const Color(0xFFEF4444)));
      return 1.4;
    }
  }

  static double _fatorHorario(int hora, List<FatorExplicavel> f) {
    if (hora >= 6 && hora < 12)  return 1.0;
    if (hora >= 12 && hora < 18) {
      f.add(FatorExplicavel(nome: 'Horário vespertino (${hora}h)', pontos: 4,
          tipo: FatorTipo.aumenta, motivo: 'Tarde com trânsito mais intenso.',
          icone: Icons.wb_twilight_rounded, cor: const Color(0xFFF59E0B)));
      return 1.08;
    }
    if (hora >= 18 && hora < 22) {
      f.add(FatorExplicavel(nome: 'Horário noturno (${hora}h)', pontos: 15,
          tipo: FatorTipo.aumenta, motivo: 'Noite: +35% de roubos e colisões vs manhã.',
          icone: Icons.nights_stay_rounded, cor: const Color(0xFF7C3AED)));
      return 1.35;
    }
    // 22h–06h
    f.add(FatorExplicavel(nome: 'Madrugada / alta noite (${hora}h)', pontos: 22,
        tipo: FatorTipo.aumenta, motivo: 'Altas horas: pico de roubos, menor visibilidade.',
        icone: Icons.nights_stay_rounded, cor: const Color(0xFFEF4444)));
    return 1.7;
  }

  static double _fatorClima(WeatherCondition clima, List<FatorExplicavel> f) {
    switch (clima) {
      case WeatherCondition.sol:
        return 1.0;
      case WeatherCondition.nublado:
        return 1.03;
      case WeatherCondition.chuva:
        f.add(FatorExplicavel(nome: 'Chuva no trajeto', pontos: 10,
            tipo: FatorTipo.aumenta, motivo: 'Chuva aumenta risco de aquaplanagem e visibilidade.',
            icone: Icons.grain_rounded, cor: const Color(0xFF3B82F6)));
        return 1.18;
      case WeatherCondition.temporal:
        f.add(FatorExplicavel(nome: 'Temporal no trajeto', pontos: 20,
            tipo: FatorTipo.aumenta, motivo: 'Temporal: risco de colisão 3× maior que tempo seco.',
            icone: Icons.thunderstorm_rounded, cor: const Color(0xFF7C3AED)));
        return 1.45;
      case WeatherCondition.alagamento:
        f.add(FatorExplicavel(nome: 'Risco de alagamento', pontos: 35,
            tipo: FatorTipo.aumenta, motivo: 'Dano por alagamento pode superar valor do veículo.',
            icone: Icons.water_rounded, cor: const Color(0xFF0891B2)));
        return 2.2;
    }
  }

  static double _fatorTransito(TrafficLevel t, List<FatorExplicavel> f) {
    switch (t) {
      case TrafficLevel.livre:
        f.add(FatorExplicavel(nome: 'Trânsito livre', pontos: 5,
            tipo: FatorTipo.reduz, motivo: 'Via livre: menor exposição e menor risco de colisão traseira.',
            icone: Icons.traffic_rounded, cor: const Color(0xFF22C55E)));
        return 0.95;
      case TrafficLevel.moderado:
        return 1.0;
      case TrafficLevel.intenso:
        f.add(FatorExplicavel(nome: 'Trânsito intenso', pontos: 8,
            tipo: FatorTipo.aumenta, motivo: 'Congestionamento aumenta exposição e risco de batida traseira.',
            icone: Icons.traffic_rounded, cor: const Color(0xFFF97316)));
        return 1.1;
      case TrafficLevel.congestionado:
        f.add(FatorExplicavel(nome: 'Trânsito congestionado', pontos: 14,
            tipo: FatorTipo.aumenta, motivo: 'Lentidão extrema → mais tempo exposto em zonas de risco.',
            icone: Icons.traffic_rounded, cor: const Color(0xFFEF4444)));
        return 1.2;
    }
  }

  static double _fatorKmMes(double km, List<FatorExplicavel> f) {
    if (km <= 500) {
      f.add(FatorExplicavel(nome: 'Baixo uso (${km.round()} km/mês)', pontos: 8,
          tipo: FatorTipo.reduz, motivo: 'Menor exposição reduz probabilidade de sinistro.',
          icone: Icons.route_rounded, cor: const Color(0xFF22C55E)));
      return 0.9;
    } else if (km <= 1500) {
      return 1.0;
    } else if (km <= 3000) {
      f.add(FatorExplicavel(nome: 'Alto uso (${km.round()} km/mês)', pontos: 8,
          tipo: FatorTipo.aumenta, motivo: 'Maior exposição no tráfego eleva probabilidade.',
          icone: Icons.route_rounded, cor: const Color(0xFFF59E0B)));
      return 1.12;
    } else {
      f.add(FatorExplicavel(nome: 'Uso intenso (${km.round()} km/mês)', pontos: 16,
          tipo: FatorTipo.aumenta, motivo: 'Quilometragem muito acima da média: risco acumulado.',
          icone: Icons.route_rounded, cor: const Color(0xFFF97316)));
      return 1.25;
    }
  }

  static double _fatorBonus(bool garagem, bool rastreador, List<FatorExplicavel> f) {
    double mult = 1.0;
    if (garagem) {
      f.add(FatorExplicavel(nome: 'Garagem fechada', pontos: 10,
          tipo: FatorTipo.reduz, motivo: 'Pernoitar em garagem reduz risco de furto em até 60%.',
          icone: Icons.home_rounded, cor: const Color(0xFF22C55E)));
      mult *= 0.92;
    }
    if (rastreador) {
      f.add(FatorExplicavel(nome: 'Rastreador instalado', pontos: 5,
          tipo: FatorTipo.reduz, motivo: 'Rastreador facilita recuperação e reduz prêmio.',
          icone: Icons.gps_fixed_rounded, cor: const Color(0xFF06B6D4)));
      mult *= 0.95;
    }
    return mult;
  }

  // ── Probabilidades de sinistro por tipo ──────────────────────
  static ProbSinistro _calcProbabilidades(
    AtuarioInput input, double fRegiao, double fHorario,
    double fRoubo, double fClima, double fIdade, double fSinistros,
  ) {
    // ── Fator geográfico por cidade (dados SENATRAN/SUSEP 2023) ──────────
    // Bases são para ES urbano médio. Cidades com maior criminalidade recebem
    // multiplicador geográfico que eleva as bases automaticamente.
    final fGeo = _fatorGeografico(input.cidadeOrigem, input.cidadeDestino);

    // Bases anuais — ES urbano médio (SENATRAN/SUSEP 2023)
    final baseRoubo    = 0.045 * fGeo; // ajustado pela cidade
    final baseFurto    = 0.025 * fGeo;
    final baseColisao  = 0.085 * fGeo;
    final baseTerceiro = 0.035 * fGeo;

    final pRoubo  = (baseRoubo    * fRegiao * fHorario * fRoubo * fSinistros)
                    .clamp(0.001, 0.60);
    final pFurto  = (baseFurto    * fRegiao * fRoubo * fSinistros)
                    .clamp(0.001, 0.40);
    final pColisao = (baseColisao * fClima  * fIdade  * fSinistros)
                    .clamp(0.001, 0.50);
    final pTerceiro = (baseTerceiro * fClima * fIdade * fSinistros)
                    .clamp(0.001, 0.30);

    final pTotal = 1.0 -
        (1.0 - pRoubo) * (1.0 - pFurto) *
        (1.0 - pColisao) * (1.0 - pTerceiro);

    // Custo médio esperado por tipo (R$ anuais)
    final custoRoubo    = input.fipeValor * 0.80 * pRoubo;
    final custoFurto    = input.fipeValor * 0.60 * pFurto;
    final custoColisao  = input.fipeValor * 0.25 * pColisao;
    final custoTerceiro = input.fipeValor * 0.10 * pTerceiro;
    final custoTotal    = custoRoubo + custoFurto + custoColisao + custoTerceiro;

    return ProbSinistro(
      pRoubo: pRoubo, pFurto: pFurto, pColisao: pColisao,
      pTerceiros: pTerceiro, pTotal: pTotal.clamp(0, 0.99),
      custoMedioEsperado: custoTotal,
      custoRoubo: custoRoubo, custoFurto: custoFurto,
      custoColisao: custoColisao, custoTerceiros: custoTerceiro,
    );
  }

  // ── Classe de risco por score ─────────────────────────────────
  static (String, Color, String) _classeScore(double s) {
    if (s <= 20) return ('Baixo',      const Color(0xFF22C55E), 'Perfil de baixo risco — seguro mais acessível.');
    if (s <= 40) return ('Moderado',   const Color(0xFF84CC16), 'Risco moderado — prêmio compatível com a média.');
    if (s <= 60) return ('Médio',      const Color(0xFFF59E0B), 'Múltiplos fatores elevam o risco acima da média.');
    if (s <= 80) return ('Alto',       const Color(0xFFF97316), 'Perfil de risco elevado — prêmio acima da média.');
    return       ('Crítico',   const Color(0xFFEF4444), 'Risco muito alto — cobertura especial necessária.');
  }

  static String _fmtFipe(double v) {
    if (v >= 1000000) return 'R\$${(v / 1000000).toStringAsFixed(1)}M';
    return 'R\$${(v / 1000).toStringAsFixed(0)}k';
  }

  // ── Fator geográfico por cidade (SENATRAN/SUSEP 2023) ────────────────────
  // Multiplica as probabilidades base (calibradas para ES) pela realidade local
  // Fontes: SENATRAN anuário 2023, SUSEP dados abertos, SSP estaduais
  static double _fatorGeografico(String origem, String destino) {
    final o = origem.toLowerCase();
    final d = destino.toLowerCase();
    final texto = '$o $d';

    // São Paulo capital e RMSP — roubo/furto de veículos 3-4x ES
    if (texto.contains('são paulo') || texto.contains('sao paulo') ||
        texto.contains('sp') || texto.contains('guarulhos') ||
        texto.contains('osasco') || texto.contains('santo andré') ||
        texto.contains('mogi') || texto.contains('suzano') ||
        texto.contains('carapicuíba') || texto.contains('carapicuiba') ||
        texto.contains('itaquaquecetuba') || texto.contains('franco da rocha')) {
      return 3.2; // SP capital: roubo/furto 3.2× ES
    }

    // Rio de Janeiro — 2.8× ES
    if (texto.contains('rio de janeiro') || texto.contains('rj') ||
        texto.contains('niterói') || texto.contains('niteroi') ||
        texto.contains('duque de caxias') || texto.contains('nova iguaçu') ||
        texto.contains('belford roxo') || texto.contains('são gonçalo')) {
      return 2.8;
    }

    // Fortaleza / Ceará — 2.5×
    if (texto.contains('fortaleza') || texto.contains('ceará') ||
        texto.contains('ceara') || texto.contains('caucaia')) {
      return 2.5;
    }

    // Recife / PE — 2.4×
    if (texto.contains('recife') || texto.contains('pernambuco') ||
        texto.contains('caruaru') || texto.contains('olinda') ||
        texto.contains('jaboatão')) {
      return 2.4;
    }

    // Salvador / BA — 2.3×
    if (texto.contains('salvador') || texto.contains('bahia') ||
        texto.contains('feira de santana') || texto.contains('lauro de freitas')) {
      return 2.3;
    }

    // Belo Horizonte / MG — 2.0×
    if (texto.contains('belo horizonte') || texto.contains('contagem') ||
        texto.contains('betim') || texto.contains('ribeirão das neves') ||
        texto.contains('santa luzia') || texto.contains('mg')) {
      return 2.0;
    }

    // Curitiba / PR — 1.6×
    if (texto.contains('curitiba') || texto.contains('londrina') ||
        texto.contains('maringá') || texto.contains('maringa') ||
        texto.contains('ponta grossa') || texto.contains('são josé dos pinhais')) {
      return 1.6;
    }

    // Porto Alegre / RS — 1.7×
    if (texto.contains('porto alegre') || texto.contains('canoas') ||
        texto.contains('novo hamburgo') || texto.contains('viamão') ||
        texto.contains('alvorada') || texto.contains('gravataí')) {
      return 1.7;
    }

    // Brasília / DF — 1.8×
    if (texto.contains('brasília') || texto.contains('brasilia') ||
        texto.contains('distrito federal') || texto.contains('df') ||
        texto.contains('ceilândia') || texto.contains('taguatinga') ||
        texto.contains('planaltina')) {
      return 1.8;
    }

    // Manaus / AM — 2.1×
    if (texto.contains('manaus') || texto.contains('amazonas')) {
      return 2.1;
    }

    // Belém / PA — 2.0×
    if (texto.contains('belém') || texto.contains('belem') ||
        texto.contains('ananindeua') || texto.contains('pará')) {
      return 2.0;
    }

    // Vitória / ES e RMGV — 1.0× (base de calibração)
    if (texto.contains('vitória') || texto.contains('vitoria') ||
        texto.contains('vila velha') || texto.contains('cariacica') ||
        texto.contains('serra') || texto.contains('guarapari') ||
        texto.contains('es ') || texto.contains('espírito santo')) {
      return 1.0;
    }

    // Demais capitais e cidades médias — 1.4× (acima do ES)
    return 1.4;
  }

  // ── Gera input automaticamente a partir dos dados disponíveis ──
  static AtuarioInput buildInputFromContext({
    required double fipeValor,
    required int    anoModelo,
    required String vehicleModel,
    required double theftIndex,
    required double distanciaKm,
    required double kmMes,
    required RiskZone zonaRota,
    required WeatherCondition clima,
    required TrafficLevel transito,
    required int cepRiskScore,
    required String cidadeOrigem,
    required String cidadeDestino,
    // perfil do condutor (do DriverProfileService ou defaults)
    int idadeCondutor   = 28,
    int cnhAnos         = 7,
    int sinistros3Anos  = 0,
    int multas12Meses   = 0,
    int acidentes3Anos  = 0,
    bool temGaragem     = false,
    bool temRastreador  = false,
  }) {
    return AtuarioInput(
      fipeValor:      fipeValor,
      anoModelo:      anoModelo,
      vehicleModel:   vehicleModel,
      theftIndex:     theftIndex,
      distanciaKm:    distanciaKm,
      kmMes:          kmMes,
      horarioPartida: DateTime.now(),
      zonaRota:       zonaRota,
      clima:          clima,
      transito:       transito,
      cepRiskScore:   cepRiskScore,
      cidadeOrigem:   cidadeOrigem,
      cidadeDestino:  cidadeDestino,
      idadeCondutor:  idadeCondutor,
      cnhAnos:        cnhAnos,
      sinistros3Anos: sinistros3Anos,
      multas12Meses:  multas12Meses,
      acidentes3Anos: acidentes3Anos,
      temGaragem:     temGaragem,
      temRastreador:  temRastreador,
    );
  }
}

// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — MOTOR ATUARIAL v3.0 (INTERNO — ZERO API EXTERNA)
// Ciência Atuarial Digital embarcada em Dart puro
//
// Arquitetura:
//   ActuarialInputV3       → dados brutos coletados do usuário
//   ActuarialScoreV3       → score composto + classe (A/B/C/D/E)
//   ActuarialResultV3      → prêmio, franquia, probabilidades, explicação
//   ActuarialEngineV3      → cálculo principal (estático, sem estado)
//
// Fatores do modelo (10 variáveis):
//   F1 · Veículo (valor FIPE + roubo do modelo + categoria)
//   F2 · Idade do veículo (tabela depreciação de risco)
//   F3 · Condutor (idade + tempo CNH + histórico sinistros)
//   F4 · Uso (km/mês + horário predominante + dias da semana)
//   F5 · Região (CEP + cidade + índice roubo + índice colisão)
//   F6 · Horário de circulação
//   F7 · Clima / Sazonalidade
//   F8 · Telemetria (score comportamental em tempo real)
//   F9 · Histórico SafeRoute (sinistros internos + score acumulado)
//   F10· Franquia contratada (normal / reduzida / majorada / dinâmica)
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & CONSTANTES
// ─────────────────────────────────────────────────────────────────────────────

enum VehicleCategory {
  popular,   // até R$ 60k
  intermediario, // R$ 60k–100k
  suv,       // R$ 100k–200k
  luxo,      // R$ 200k–500k
  superLuxo, // acima R$ 500k
  eletrico,
  moto,
  caminhao,
}

enum FranchiseType { normal, reduzida, majorada, dinamica }

enum UsagePattern {
  trabalho,      // dias úteis, horários fixos
  lazer,         // fins de semana
  app,           // motorista de app (alta exposição)
  misto,
  baixoUso,      // < 500 km/mês
}

enum DrivingTimeSlot {
  manha,   // 06–12h
  tarde,   // 12–18h
  noite,   // 18–22h
  tardio,  // 22–02h
  madrugada, // 02–06h
}

enum RiskClass { A, B, C, D, E }

// ─────────────────────────────────────────────────────────────────────────────
// F1 · DADOS DO VEÍCULO
// ─────────────────────────────────────────────────────────────────────────────

class VehicleDataV3 {
  final double fipeValue;         // Valor FIPE em R$
  final int anoFabricacao;        // Ano de fabricação
  final int anoModelo;            // Ano modelo
  final VehicleCategory category;
  final String modelName;         // Ex: "Onix", "HB20", "Atto 2"
  final String brandName;         // Ex: "Chevrolet"
  final double theftIndex;        // 0.0–1.0 (índice de roubo do modelo)
  final double collisionIndex;    // 0.0–1.0 (índice de colisão do modelo)

  const VehicleDataV3({
    required this.fipeValue,
    required this.anoFabricacao,
    required this.anoModelo,
    this.category = VehicleCategory.popular,
    this.modelName = '',
    this.brandName = '',
    this.theftIndex = 0.35,
    this.collisionIndex = 0.30,
  });

  int get idadeVeiculo => math.max(0, DateTime.now().year - anoFabricacao);
  int get idadeModelo  => math.max(0, DateTime.now().year - anoModelo);

  /// Categoria inferida automaticamente pelo valor FIPE
  static VehicleCategory categoryFromFipe(double fipe, bool isElectric, bool isMoto, bool isTruck) {
    if (isMoto)      return VehicleCategory.moto;
    if (isTruck)     return VehicleCategory.caminhao;
    if (isElectric)  return VehicleCategory.eletrico;
    if (fipe <= 60000)  return VehicleCategory.popular;
    if (fipe <= 100000) return VehicleCategory.intermediario;
    if (fipe <= 200000) return VehicleCategory.suv;
    if (fipe <= 500000) return VehicleCategory.luxo;
    return VehicleCategory.superLuxo;
  }

  String get categoryLabel {
    switch (category) {
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

  String get fipeFormatado {
    if (fipeValue >= 1000000) return 'R\$ ${(fipeValue/1000000).toStringAsFixed(1)}M';
    if (fipeValue >= 1000) return 'R\$ ${(fipeValue/1000).toStringAsFixed(0)} mil';
    return 'R\$ ${fipeValue.toStringAsFixed(0)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// F2 · TABELA DE RISCO POR IDADE DO VEÍCULO
// ─────────────────────────────────────────────────────────────────────────────

class VehicleAgeRisk {
  static double factor(int idadeAnos) {
    if (idadeAnos <= 2)  return 1.00;
    if (idadeAnos <= 5)  return 1.10;
    if (idadeAnos <= 10) return 1.25;
    if (idadeAnos <= 15) return 1.50;
    return 1.80;
  }

  static String label(int idadeAnos) {
    if (idadeAnos <= 2)  return 'Novo (0–2 anos) ×1.00';
    if (idadeAnos <= 5)  return 'Recente (3–5 anos) ×1.10';
    if (idadeAnos <= 10) return 'Regular (6–10 anos) ×1.25';
    if (idadeAnos <= 15) return 'Antigo (11–15 anos) ×1.50';
    return 'Muito Antigo (16+ anos) ×1.80';
  }

  static Color color(int idadeAnos) {
    if (idadeAnos <= 2)  return const Color(0xFF22C55E);
    if (idadeAnos <= 5)  return const Color(0xFF84CC16);
    if (idadeAnos <= 10) return const Color(0xFFF59E0B);
    if (idadeAnos <= 15) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// F3 · DADOS DO CONDUTOR
// ─────────────────────────────────────────────────────────────────────────────

class DriverDataV3 {
  final int idade;               // Idade em anos
  final int tempoCnhAnos;        // Tempo de CNH em anos
  final int sinistrosUlt3Anos;   // Sinistros nos últimos 3 anos
  final int multasUlt12Meses;    // Multas nos últimos 12 meses
  final int acionamentosSeguro;  // Acionamentos do seguro
  final int scoreInterno;        // Score interno SafeRoute (0–1000)
  final bool primeiroVeiculo;
  final bool condutorPrincipal;  // Único condutor ou adicional

  const DriverDataV3({
    required this.idade,
    this.tempoCnhAnos = 5,
    this.sinistrosUlt3Anos = 0,
    this.multasUlt12Meses = 0,
    this.acionamentosSeguro = 0,
    this.scoreInterno = 800,
    this.primeiroVeiculo = false,
    this.condutorPrincipal = true,
  });

  /// Fator de risco pela idade do condutor
  double get ageFactor {
    if (idade < 18) return 2.50;
    if (idade <= 21) return 2.00;
    if (idade <= 25) return 1.80;
    if (idade <= 30) return 1.40;
    if (idade <= 35) return 1.20;
    if (idade <= 50) return 1.00;
    if (idade <= 65) return 1.10;
    return 1.30;
  }

  /// Fator pelo tempo de CNH
  double get cnhFactor {
    if (tempoCnhAnos < 1)  return 1.60;
    if (tempoCnhAnos < 2)  return 1.40;
    if (tempoCnhAnos < 5)  return 1.20;
    if (tempoCnhAnos < 10) return 1.05;
    return 1.00;
  }

  /// Fator pelo histórico de sinistros
  double get historyFactor {
    if (sinistrosUlt3Anos == 0 && multasUlt12Meses == 0) return 0.90; // bônus
    double f = 1.00;
    f += sinistrosUlt3Anos  * 0.25;
    f += multasUlt12Meses   * 0.08;
    f += acionamentosSeguro * 0.12;
    return f.clamp(0.85, 2.50);
  }

  /// Score interno → fator de desconto/acréscimo
  double get scoreFactor {
    if (scoreInterno >= 950) return 0.80;
    if (scoreInterno >= 900) return 0.85;
    if (scoreInterno >= 850) return 0.90;
    if (scoreInterno >= 800) return 0.95;
    if (scoreInterno >= 700) return 1.00;
    if (scoreInterno >= 600) return 1.15;
    if (scoreInterno >= 400) return 1.35;
    return 1.60;
  }

  /// Fator combinado do condutor
  double get combinedFactor =>
      (ageFactor * 0.35 + cnhFactor * 0.20 + historyFactor * 0.30 + scoreFactor * 0.15)
          .clamp(0.75, 3.00);

  String get ageLabel {
    if (idade < 18) return 'Menor de 18 ×2.5';
    if (idade <= 21) return '18–21 anos ×2.0';
    if (idade <= 25) return '22–25 anos ×1.8';
    if (idade <= 30) return '26–30 anos ×1.4';
    if (idade <= 35) return '31–35 anos ×1.2';
    if (idade <= 50) return '36–50 anos ×1.0';
    if (idade <= 65) return '51–65 anos ×1.1';
    return '65+ anos ×1.3';
  }

  String get tierLabel {
    if (scoreInterno >= 900) return 'Elite';
    if (scoreInterno >= 800) return 'Ouro';
    if (scoreInterno >= 700) return 'Prata';
    if (scoreInterno >= 600) return 'Bronze';
    return 'Básico';
  }

  Color get tierColor {
    if (scoreInterno >= 900) return const Color(0xFF06B6D4);
    if (scoreInterno >= 800) return const Color(0xFFF59E0B);
    if (scoreInterno >= 700) return const Color(0xFF94A3B8);
    if (scoreInterno >= 600) return const Color(0xFFB45309);
    return const Color(0xFFEF4444);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// F4 · DADOS DE USO
// ─────────────────────────────────────────────────────────────────────────────

class UsageDataV3 {
  final double kmMes;               // KM por mês
  final UsagePattern pattern;
  final DrivingTimeSlot primarySlot; // Horário predominante
  final int diasUteisUso;           // Dias úteis de uso por semana (1–5)
  final bool fimDeSemanaUso;
  final bool usaAutoEstrada;        // Uso frequente de rodovias

  const UsageDataV3({
    required this.kmMes,
    this.pattern = UsagePattern.misto,
    this.primarySlot = DrivingTimeSlot.manha,
    this.diasUteisUso = 5,
    this.fimDeSemanaUso = false,
    this.usaAutoEstrada = false,
  });

  /// Fator de risco pelo KM mensal
  double get kmFactor {
    if (kmMes <= 500)   return 0.90; // baixo uso — desconto
    if (kmMes <= 1000)  return 1.00;
    if (kmMes <= 2000)  return 1.10;
    if (kmMes <= 3000)  return 1.20;
    if (kmMes <= 5000)  return 1.35;
    return 1.55; // > 5000 km/mês (app, frota)
  }

  /// Fator pelo padrão de uso
  double get patternFactor {
    switch (pattern) {
      case UsagePattern.trabalho:  return 1.10;
      case UsagePattern.lazer:     return 0.95;
      case UsagePattern.app:       return 1.50;  // alta exposição
      case UsagePattern.misto:     return 1.15;
      case UsagePattern.baixoUso:  return 0.85;
    }
  }

  /// Fator pelo horário predominante
  double get timeFactor {
    switch (primarySlot) {
      case DrivingTimeSlot.manha:    return 1.00;
      case DrivingTimeSlot.tarde:    return 1.10;
      case DrivingTimeSlot.noite:    return 1.40;
      case DrivingTimeSlot.tardio:   return 2.00;
      case DrivingTimeSlot.madrugada: return 1.80;
    }
  }

  double get combinedFactor =>
      (kmFactor * 0.40 + patternFactor * 0.35 + timeFactor * 0.25)
          .clamp(0.80, 2.00);

  String get kmLabel {
    if (kmMes <= 500)  return 'Baixo uso (<500 km)';
    if (kmMes <= 1000) return 'Normal (500–1000 km)';
    if (kmMes <= 2000) return 'Intenso (1000–2000 km)';
    if (kmMes <= 3000) return 'Alto (2000–3000 km)';
    if (kmMes <= 5000) return 'Muito alto (3000–5000 km)';
    return 'Extremo (>5000 km)';
  }

  String get patternLabel {
    switch (pattern) {
      case UsagePattern.trabalho:  return 'Trabalho / Diário';
      case UsagePattern.lazer:     return 'Lazer / Fins de Semana';
      case UsagePattern.app:       return 'App de Transporte';
      case UsagePattern.misto:     return 'Uso Misto';
      case UsagePattern.baixoUso:  return 'Baixo Uso';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// F5 · DADOS DE REGIÃO
// ─────────────────────────────────────────────────────────────────────────────

class RegionDataV3 {
  final String cep;
  final String cidade;
  final String bairro;
  final String uf;
  final double theftIndex;     // 0.0–1.0 (índice municipal de roubo)
  final double collisionIndex; // 0.0–1.0 (índice municipal de colisão)

  const RegionDataV3({
    this.cep = '00000-000',
    this.cidade = '',
    this.bairro = '',
    this.uf = 'SP',
    this.theftIndex = 0.30,
    this.collisionIndex = 0.25,
  });

  /// Fator composto de risco regional
  double get regionFactor {
    // Ponderação: roubo pesa mais que colisão no prêmio
    final baseRoubo    = 1.0 + (theftIndex * 1.50);
    final baseColisao  = 1.0 + (collisionIndex * 0.80);
    return ((baseRoubo + baseColisao) / 2).clamp(1.00, 3.00);
  }

  String get riskLabel {
    final f = regionFactor;
    if (f < 1.20) return 'Baixo risco';
    if (f < 1.50) return 'Risco moderado';
    if (f < 1.80) return 'Risco alto';
    if (f < 2.20) return 'Risco muito alto';
    return 'Risco crítico';
  }

  Color get riskColor {
    final f = regionFactor;
    if (f < 1.20) return const Color(0xFF22C55E);
    if (f < 1.50) return const Color(0xFFF59E0B);
    if (f < 1.80) return const Color(0xFFF97316);
    if (f < 2.20) return const Color(0xFFEF4444);
    return const Color(0xFF7F1D1D);
  }

  /// Lookup de índices por UF (tabela interna — dados IBGE/SINESP aproximados)
  static RegionDataV3 fromUF(String uf, {String cep = '', String cidade = '', String bairro = ''}) {
    const ufRisk = {
      'SP': (theft: 0.55, collision: 0.45),
      'RJ': (theft: 0.72, collision: 0.50),
      'MG': (theft: 0.38, collision: 0.35),
      'RS': (theft: 0.32, collision: 0.38),
      'PR': (theft: 0.30, collision: 0.36),
      'SC': (theft: 0.22, collision: 0.30),
      'BA': (theft: 0.48, collision: 0.38),
      'GO': (theft: 0.42, collision: 0.40),
      'DF': (theft: 0.38, collision: 0.42),
      'PE': (theft: 0.50, collision: 0.35),
      'CE': (theft: 0.45, collision: 0.32),
      'AM': (theft: 0.40, collision: 0.28),
      'PA': (theft: 0.42, collision: 0.30),
      'ES': (theft: 0.40, collision: 0.38),
      'MT': (theft: 0.35, collision: 0.42),
      'MS': (theft: 0.30, collision: 0.38),
    };
    final data = ufRisk[uf.toUpperCase()];
    return RegionDataV3(
      cep: cep,
      cidade: cidade,
      bairro: bairro,
      uf: uf.toUpperCase(),
      theftIndex: data?.theft ?? 0.35,
      collisionIndex: data?.collision ?? 0.32,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// F10 · FRANQUIA CONTRATADA
// ─────────────────────────────────────────────────────────────────────────────

class FranchiseConfig {
  final FranchiseType type;

  const FranchiseConfig({this.type = FranchiseType.dinamica});

  /// Percentual da franquia sobre FIPE por classe de risco
  static double pctByClass(RiskClass cls, FranchiseType type) {
    // Tabela franquia dinâmica por classe
    const basePct = {
      RiskClass.A: 0.04,  // 4% FIPE
      RiskClass.B: 0.05,  // 5% FIPE
      RiskClass.C: 0.06,  // 6% FIPE
      RiskClass.D: 0.08,  // 8% FIPE
      RiskClass.E: 0.10,  // 10% FIPE
    };
    final base = basePct[cls] ?? 0.06;
    switch (type) {
      case FranchiseType.reduzida: return base * 0.60;  // -40%
      case FranchiseType.majorada: return base * 1.50;  // +50%
      case FranchiseType.dinamica: return base;
      case FranchiseType.normal:   return base;
    }
  }

  /// Fator de ajuste no prêmio pela franquia escolhida
  static double premiumAdjust(FranchiseType type) {
    switch (type) {
      case FranchiseType.reduzida: return 1.25; // franquia menor → prêmio maior
      case FranchiseType.majorada: return 0.80; // franquia maior → prêmio menor
      case FranchiseType.dinamica: return 1.00;
      case FranchiseType.normal:   return 1.00;
    }
  }

  String get label {
    switch (type) {
      case FranchiseType.normal:   return 'Normal';
      case FranchiseType.reduzida: return 'Reduzida (-40%)';
      case FranchiseType.majorada: return 'Majorada (+50%)';
      case FranchiseType.dinamica: return 'Dinâmica (por classe)';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT ATUARIAL v3 — DADOS COMPLETOS
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialInputV3 {
  final VehicleDataV3  vehicle;
  final DriverDataV3   driver;
  final UsageDataV3    usage;
  final RegionDataV3   region;
  final FranchiseConfig franchise;

  // Contexto da viagem (opcional — para cotação por percurso)
  final double? tripDistanceKm;
  final DateTime? departureTime;

  // Telemetria acumulada (opcional)
  final int telemetryScore; // 0–1000

  const ActuarialInputV3({
    required this.vehicle,
    required this.driver,
    required this.usage,
    required this.region,
    this.franchise = const FranchiseConfig(),
    this.tripDistanceKm,
    this.departureTime,
    this.telemetryScore = 900,
  });

  /// Input de demonstração — condutor padrão ES
  static ActuarialInputV3 get demo => ActuarialInputV3(
    vehicle: const VehicleDataV3(
      fipeValue: 80000,
      anoFabricacao: 2020,
      anoModelo: 2021,
      category: VehicleCategory.popular,
      modelName: 'HB20',
      brandName: 'Hyundai',
      theftIndex: 0.55,
      collisionIndex: 0.40,
    ),
    driver: const DriverDataV3(
      idade: 29,
      tempoCnhAnos: 7,
      sinistrosUlt3Anos: 0,
      multasUlt12Meses: 1,
      scoreInterno: 820,
    ),
    usage: const UsageDataV3(
      kmMes: 1200,
      pattern: UsagePattern.trabalho,
      primarySlot: DrivingTimeSlot.tarde,
      diasUteisUso: 5,
    ),
    region: RegionDataV3.fromUF('ES', cidade: 'Serra', bairro: 'Laranjeiras'),
    franchise: const FranchiseConfig(type: FranchiseType.dinamica),
    tripDistanceKm: 25,
    departureTime: null,
    telemetryScore: 900,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCORE ATUARIAL v3 — resultado intermediário
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialScoreV3 {
  // Fatores individuais calculados
  final double fVeiculo;       // F1: FIPE × roubo × categoria
  final double fIdadeVeiculo;  // F2: tabela de envelhecimento
  final double fCondutor;      // F3: idade + CNH + histórico + score
  final double fUso;           // F4: km + padrão + horário
  final double fRegiao;        // F5: roubo + colisão regional
  final double fTelemetria;    // F8: comportamento em tempo real
  final double fFranquia;      // F10: ajuste pelo tipo de franquia

  // Score final ponderado
  final double scoreTotal;
  final RiskClass riskClass;

  const ActuarialScoreV3({
    required this.fVeiculo,
    required this.fIdadeVeiculo,
    required this.fCondutor,
    required this.fUso,
    required this.fRegiao,
    required this.fTelemetria,
    required this.fFranquia,
    required this.scoreTotal,
    required this.riskClass,
  });

  static RiskClass classifyScore(double score) {
    if (score <= 1.20) return RiskClass.A;
    if (score <= 1.50) return RiskClass.B;
    if (score <= 1.80) return RiskClass.C;
    if (score <= 2.20) return RiskClass.D;
    return RiskClass.E;
  }

  String get classLabel => 'Classe ${riskClass.name}';

  String get classDescription {
    switch (riskClass) {
      case RiskClass.A: return 'Risco Mínimo — perfil excelente';
      case RiskClass.B: return 'Risco Baixo — perfil bom';
      case RiskClass.C: return 'Risco Moderado — perfil regular';
      case RiskClass.D: return 'Risco Alto — requer atenção';
      case RiskClass.E: return 'Risco Crítico — cobertura majorada';
    }
  }

  Color get classColor {
    switch (riskClass) {
      case RiskClass.A: return const Color(0xFF22C55E);
      case RiskClass.B: return const Color(0xFF84CC16);
      case RiskClass.C: return const Color(0xFFF59E0B);
      case RiskClass.D: return const Color(0xFFF97316);
      case RiskClass.E: return const Color(0xFFEF4444);
    }
  }

  Color get classColorLight {
    switch (riskClass) {
      case RiskClass.A: return const Color(0xFFDCFCE7);
      case RiskClass.B: return const Color(0xFFF0FDF4);
      case RiskClass.C: return const Color(0xFFFEF3C7);
      case RiskClass.D: return const Color(0xFFFFEDD5);
      case RiskClass.E: return const Color(0xFFFEE2E2);
    }
  }

  String get scoreTotalFormatado => '×${scoreTotal.toStringAsFixed(3)}';

  // Barra de progresso visual (0.0–1.0)
  double get progressNormalized => ((scoreTotal - 0.8) / (2.5 - 0.8)).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROBABILIDADES DE SINISTRO v3
// ─────────────────────────────────────────────────────────────────────────────

class SinistroProbsV3 {
  final double pRoubo;
  final double pFurto;
  final double pColisao;
  final double pTerceiros;
  final double pFenomenoNatural;
  final double pTotal;

  const SinistroProbsV3({
    required this.pRoubo,
    required this.pFurto,
    required this.pColisao,
    required this.pTerceiros,
    required this.pFenomenoNatural,
    required this.pTotal,
  });

  String fmt(double p) => '${(p * 100).toStringAsFixed(2)}%';
  String get pRouboFmt         => fmt(pRoubo);
  String get pFurtoFmt         => fmt(pFurto);
  String get pColisaoFmt       => fmt(pColisao);
  String get pTerceirosFmt     => fmt(pTerceiros);
  String get pFenomenoFmt      => fmt(pFenomenoNatural);
  String get pTotalFmt         => fmt(pTotal);

  String get pTotalLabel {
    if (pTotal < 0.01) return 'Risco Mínimo';
    if (pTotal < 0.03) return 'Risco Baixo';
    if (pTotal < 0.07) return 'Risco Moderado';
    if (pTotal < 0.15) return 'Risco Alto';
    return 'Risco Crítico';
  }

  Color get pTotalColor {
    if (pTotal < 0.01) return const Color(0xFF22C55E);
    if (pTotal < 0.03) return const Color(0xFF84CC16);
    if (pTotal < 0.07) return const Color(0xFFF59E0B);
    if (pTotal < 0.15) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRÊMIO CALCULADO v3
// ─────────────────────────────────────────────────────────────────────────────

class PremiumV3 {
  // Prêmio por percurso (R$/km)
  final double taxaBaseKm;      // R$/km base antes dos fatores
  final double taxaFinalKm;     // R$/km final (com todos os fatores)

  // Prêmio mensal estimado (baseado em km/mês)
  final double premioMensalEstimado;

  // Franquia
  final double franquiaValor;    // em R$
  final double franquiaPct;      // percentual sobre FIPE
  final FranchiseType franquiaTipo;

  // Reserva técnica (20% do prêmio)
  final double reservaTecnica;

  // Comissões
  final double comissaoSeguradora; // 55%
  final double comissaoSixtech;    // 15%
  final double fundoSinistro;      // 20%

  const PremiumV3({
    required this.taxaBaseKm,
    required this.taxaFinalKm,
    required this.premioMensalEstimado,
    required this.franquiaValor,
    required this.franquiaPct,
    required this.franquiaTipo,
    required this.reservaTecnica,
    required this.comissaoSeguradora,
    required this.comissaoSixtech,
    required this.fundoSinistro,
  });

  String fmt(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+,)'), (m) => '${m[1]}.')}';

  String get taxaFinalKmFmt         => 'R\$ ${taxaFinalKm.toStringAsFixed(4)}/km';
  String get premioMensalFmt        => fmt(premioMensalEstimado);
  String get franquiaFmt            => fmt(franquiaValor);
  String get reservaTecnicaFmt      => fmt(reservaTecnica);
  String get comissaoSeguradoraFmt  => fmt(comissaoSeguradora);
  String get comissaoSixtechFmt     => fmt(comissaoSixtech);
  String get fundoSinistroFmt       => fmt(fundoSinistro);
  String get franquiaPctFmt         => '${(franquiaPct * 100).toStringAsFixed(0)}% FIPE';

  // Prêmio para uma viagem específica
  double premioViagem(double km) => (taxaFinalKm * km).clamp(1.99, 9999);
  String premioViagemFmt(double km) => fmt(premioViagem(km));
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO ATUARIAL v3 — output completo
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialResultV3 {
  final ActuarialInputV3   input;
  final ActuarialScoreV3   score;
  final SinistroProbsV3    probs;
  final PremiumV3          premium;
  final DateTime           calculatedAt;

  const ActuarialResultV3({
    required this.input,
    required this.score,
    required this.probs,
    required this.premium,
    required this.calculatedAt,
  });

  // Atalhos
  RiskClass get riskClass    => score.riskClass;
  double get franquia        => premium.franquiaValor;
  double get taxaKm          => premium.taxaFinalKm;
  double get premioMensal    => premium.premioMensalEstimado;
  String get classLabel      => score.classLabel;
  Color  get classColor      => score.classColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTOR ATUARIAL v3 — cálculo principal
// 100% interno, zero API, executa em < 1ms
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialEngineV3 {
  static const String version = 'v3.0.0-internal';

  // Taxa base mínima: R$ 0.06/km (veículo popular, zona verde)
  static const double _taxaBaseKm = 0.06;
  static const double _taxaMinKm  = 0.02;

  static ActuarialResultV3 calculate(ActuarialInputV3 input) {
    final v  = input.vehicle;
    final d  = input.driver;
    final u  = input.usage;
    final r  = input.region;
    final fr = input.franchise;

    // ── F1: FATOR VEÍCULO ─────────────────────────────────────
    // FIPE como base de valor exposto + índice de roubo do modelo
    final fFipeBase  = _fipeFactor(v.fipeValue);
    final fRouboMod  = 1.0 + (v.theftIndex * 0.60);      // roubo do modelo
    final fColisaoMod = 1.0 + (v.collisionIndex * 0.30); // colisão do modelo
    final fCategoria  = _categoryFactor(v.category);
    final fVeiculo = fFipeBase * ((fRouboMod + fColisaoMod + fCategoria) / 3);

    // ── F2: FATOR IDADE DO VEÍCULO ────────────────────────────
    final fIdadeVeiculo = VehicleAgeRisk.factor(v.idadeVeiculo);

    // ── F3: FATOR CONDUTOR ────────────────────────────────────
    final fCondutor = d.combinedFactor;

    // ── F4: FATOR USO ─────────────────────────────────────────
    final fUso = u.combinedFactor;

    // ── F5: FATOR REGIÃO ─────────────────────────────────────
    final fRegiao = r.regionFactor;

    // ── F8: FATOR TELEMETRIA ──────────────────────────────────
    final fTelemetria = _telemetryFactor(input.telemetryScore);

    // ── F10: FATOR FRANQUIA ───────────────────────────────────
    final fFranquia = FranchiseConfig.premiumAdjust(fr.type);

    // ── SCORE PONDERADO ───────────────────────────────────────
    // Pesos calibrados para seguro auto por percurso
    final scoreTotal = (
      fVeiculo      * 0.20 +
      fIdadeVeiculo * 0.10 +
      fCondutor     * 0.25 +
      fUso          * 0.20 +
      fRegiao       * 0.18 +
      fTelemetria   * 0.07
    ) * fFranquia;

    final riskClass = ActuarialScoreV3.classifyScore(scoreTotal);

    final scoreObj = ActuarialScoreV3(
      fVeiculo:      fVeiculo,
      fIdadeVeiculo: fIdadeVeiculo,
      fCondutor:     fCondutor,
      fUso:          fUso,
      fRegiao:       fRegiao,
      fTelemetria:   fTelemetria,
      fFranquia:     fFranquia,
      scoreTotal:    scoreTotal,
      riskClass:     riskClass,
    );

    // ── PRÊMIO ────────────────────────────────────────────────
    final taxaFinalKm = math.max(_taxaMinKm, _taxaBaseKm * scoreTotal);
    final premioMensal = taxaFinalKm * u.kmMes;

    // ── FRANQUIA ──────────────────────────────────────────────
    final franquiaPct   = FranchiseConfig.pctByClass(riskClass, fr.type);
    final franquiaValor = v.fipeValue * franquiaPct;

    // ── DIVISÃO DE RECEITA ────────────────────────────────────
    final reserva       = premioMensal * 0.20;
    final comSeguradora = premioMensal * 0.55;
    final comSixtech    = premioMensal * 0.15;
    final fundoSin      = premioMensal * 0.20;

    final premium = PremiumV3(
      taxaBaseKm:           _taxaBaseKm,
      taxaFinalKm:          taxaFinalKm,
      premioMensalEstimado: premioMensal,
      franquiaValor:        franquiaValor,
      franquiaPct:          franquiaPct,
      franquiaTipo:         fr.type,
      reservaTecnica:       reserva,
      comissaoSeguradora:   comSeguradora,
      comissaoSixtech:      comSixtech,
      fundoSinistro:        fundoSin,
    );

    // ── PROBABILIDADES ────────────────────────────────────────
    final probs = _calcProbs(input, scoreTotal, fRegiao, fCondutor);

    return ActuarialResultV3(
      input:        input,
      score:        scoreObj,
      probs:        probs,
      premium:      premium,
      calculatedAt: DateTime.now(),
    );
  }

  // ── Fator FIPE ────────────────────────────────────────────
  static double _fipeFactor(double fipe) {
    if (fipe <= 40000)  return 0.85;
    if (fipe <= 60000)  return 1.00;
    if (fipe <= 80000)  return 1.10;
    if (fipe <= 100000) return 1.20;
    if (fipe <= 150000) return 1.35;
    if (fipe <= 200000) return 1.50;
    if (fipe <= 350000) return 1.80;
    if (fipe <= 500000) return 2.10;
    return 2.50;
  }

  // ── Fator Categoria ──────────────────────────────────────
  static double _categoryFactor(VehicleCategory cat) {
    switch (cat) {
      case VehicleCategory.popular:       return 1.00;
      case VehicleCategory.intermediario: return 1.05;
      case VehicleCategory.suv:           return 1.15;
      case VehicleCategory.luxo:          return 1.35;
      case VehicleCategory.superLuxo:     return 1.60;
      case VehicleCategory.eletrico:      return 1.10; // menor risco mecânico, maior custo reparo
      case VehicleCategory.moto:          return 1.80; // alta exposição
      case VehicleCategory.caminhao:      return 1.40;
    }
  }

  // ── Fator Telemetria ──────────────────────────────────────
  static double _telemetryFactor(int score) {
    if (score >= 950) return 0.80;
    if (score >= 900) return 0.88;
    if (score >= 850) return 0.93;
    if (score >= 800) return 0.97;
    if (score >= 700) return 1.00;
    if (score >= 600) return 1.10;
    if (score >= 500) return 1.22;
    return 1.40;
  }

  // ── Probabilidades de Sinistro ────────────────────────────
  static SinistroProbsV3 _calcProbs(
    ActuarialInputV3 input,
    double scoreTotal,
    double fRegiao,
    double fCondutor,
  ) {
    final r = input.region;
    final d = input.driver;

    // Bases estatísticas (por viagem de 25 km média)
    const baseRoubo     = 0.00080; // 0.08% por viagem
    const baseFurto     = 0.00050;
    const baseColisao   = 0.00120;
    const baseTerceiros = 0.00035;
    const baseFenomeno  = 0.00015;

    final pRoubo = (baseRoubo * fRegiao * (1 + r.theftIndex) * d.historyFactor)
        .clamp(0.0001, 0.30);
    final pFurto = (baseFurto * fRegiao * (1 + r.theftIndex * 0.5) * d.historyFactor)
        .clamp(0.0001, 0.20);
    final pColisao = (baseColisao * d.ageFactor * d.cnhFactor * input.usage.timeFactor)
        .clamp(0.0001, 0.35);
    final pTerceiros = (baseTerceiros * d.ageFactor * input.usage.kmFactor)
        .clamp(0.0001, 0.15);
    final pFenomeno = baseFenomeno;

    final pTotal = (1.0 -
        (1 - pRoubo) * (1 - pFurto) * (1 - pColisao) *
        (1 - pTerceiros) * (1 - pFenomeno)).clamp(0.0001, 0.80);

    return SinistroProbsV3(
      pRoubo:          pRoubo,
      pFurto:          pFurto,
      pColisao:        pColisao,
      pTerceiros:      pTerceiros,
      pFenomenoNatural: pFenomeno,
      pTotal:          pTotal,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPRECIFICAÇÃO MENSAL — ajusta prêmio com base no uso real
// ─────────────────────────────────────────────────────────────────────────────

class MonthlyRepricingV3 {
  /// Compara km planejado vs km real rodado e recalcula
  static ActuarialResultV3 reprice({
    required ActuarialInputV3 baseInput,
    required double kmRealRodado,
    required int telemetryScoreAcumulado,
    required int sinistrosNoMes,
  }) {
    // Atualiza uso com km real
    final newUsage = UsageDataV3(
      kmMes: kmRealRodado,
      pattern: baseInput.usage.pattern,
      primarySlot: baseInput.usage.primarySlot,
      diasUteisUso: baseInput.usage.diasUteisUso,
    );

    // Penalidade por sinistro no mês
    final extraSinistros = baseInput.driver.sinistrosUlt3Anos + sinistrosNoMes;
    final newDriver = DriverDataV3(
      idade:              baseInput.driver.idade,
      tempoCnhAnos:       baseInput.driver.tempoCnhAnos,
      sinistrosUlt3Anos:  extraSinistros,
      multasUlt12Meses:   baseInput.driver.multasUlt12Meses,
      acionamentosSeguro: baseInput.driver.acionamentosSeguro + sinistrosNoMes,
      scoreInterno:       baseInput.driver.scoreInterno,
    );

    final newInput = ActuarialInputV3(
      vehicle:        baseInput.vehicle,
      driver:         newDriver,
      usage:          newUsage,
      region:         baseInput.region,
      franchise:      baseInput.franchise,
      telemetryScore: telemetryScoreAcumulado,
    );

    return ActuarialEngineV3.calculate(newInput);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÍNDICE DE ROUBOS POR MODELO — lookup interno (SINESP/SENATRAN aproximado)
// ─────────────────────────────────────────────────────────────────────────────

class TheftIndexDatabase {
  static const Map<String, double> _index = {
    // Alta exposição ao roubo
    'chevrolet onix':     0.78,
    'hyundai hb20':       0.72,
    'volkswagen gol':     0.68,
    'toyota hilux':       0.65,
    'ford ranger':        0.62,
    'honda hrv':          0.58,
    'jeep renegade':      0.55,
    'fiat argo':          0.50,
    // Exposição moderada
    'volkswagen polo':    0.48,
    'toyota corolla':     0.45,
    'honda civic':        0.44,
    'jeep compass':       0.42,
    'hyundai creta':      0.40,
    // Baixa exposição
    'byd atto 2':         0.22,
    'byd dolphin':        0.20,
    'tesla model 3':      0.18,
    'volvo xc60':         0.15,
    'toyota sw4':         0.38,
    // Motos
    'honda cb 500':       0.70,
    'yamaha mt-07':       0.72,
    'honda cg 160':       0.80,
  };

  static double lookup(String modelName) {
    final lc = modelName.toLowerCase();
    for (final entry in _index.entries) {
      if (lc.contains(entry.key.split(' ').last)) return entry.value;
      if (entry.key.contains(lc)) return entry.value;
    }
    return 0.35; // padrão: risco médio
  }
}

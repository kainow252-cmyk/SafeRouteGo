// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// ATUÁRIO DIGITAL CORE — Motor oculto multi-ramo
// Roda em background silencioso. NUNCA expõe tela própria.
// Coleta dados → calcula risco → gera cotações → armazena resultado.
//
// Arquitetura:
//   AtuarioDigitalCore (singleton)
//     ├── RiskProfileService   → perfil de risco do cliente
//     ├── AtuarialEngine       → cálculo determinístico de prêmio
//     └── QuoteOrchestrator    → cotações multi-seguradora
//
// Ramos suportados:
//   AUTO · MOTO · VIDA · RESIDENCIAL · CELULAR · VIAGEM · CAMINHAO · EMPRESARIAL
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'territorial_risk_intelligence.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS FUNDAMENTAIS
// ─────────────────────────────────────────────────────────────────────────────

enum InsuranceBranch {
  auto,
  moto,
  vida,
  residencial,
  celular,
  viagem,
  caminhao,
  motoboy,
  empresarial,
}

extension InsuranceBranchExt on InsuranceBranch {
  String get label {
    switch (this) {
      case InsuranceBranch.auto:         return 'Auto';
      case InsuranceBranch.moto:         return 'Moto';
      case InsuranceBranch.vida:         return 'Vida';
      case InsuranceBranch.residencial:  return 'Residencial';
      case InsuranceBranch.celular:      return 'Celular';
      case InsuranceBranch.viagem:       return 'Viagem';
      case InsuranceBranch.caminhao:     return 'Caminhão';
      case InsuranceBranch.motoboy:      return 'Motoboy';
      case InsuranceBranch.empresarial:  return 'Empresarial';
    }
  }
}

enum RiskLevel { muitoBaixo, baixo, moderado, alto, critico }

extension RiskLevelExt on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.muitoBaixo: return 'Muito Baixo';
      case RiskLevel.baixo:      return 'Baixo';
      case RiskLevel.moderado:   return 'Moderado';
      case RiskLevel.alto:       return 'Alto';
      case RiskLevel.critico:    return 'Crítico';
    }
  }

  int get score {
    switch (this) {
      case RiskLevel.muitoBaixo: return 88;
      case RiskLevel.baixo:      return 72;
      case RiskLevel.moderado:   return 54;
      case RiskLevel.alto:       return 32;
      case RiskLevel.critico:    return 14;
    }
  }
}

enum VehicleUse { particular, trabalho, comercial, aplicativo, motoboy }

extension VehicleUseExt on VehicleUse {
  double get loadingFactor {
    switch (this) {
      case VehicleUse.particular:  return 1.00;
      case VehicleUse.trabalho:    return 1.18;
      case VehicleUse.comercial:   return 1.40;
      case VehicleUse.aplicativo:  return 1.75;
      case VehicleUse.motoboy:     return 2.20;
    }
  }

  String get label {
    switch (this) {
      case VehicleUse.particular:  return 'Particular';
      case VehicleUse.trabalho:    return 'Trabalho';
      case VehicleUse.comercial:   return 'Comercial';
      case VehicleUse.aplicativo:  return 'Aplicativo';
      case VehicleUse.motoboy:     return 'Motoboy';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERFIL DO CLIENTE — dados coletados silenciosamente
// ─────────────────────────────────────────────────────────────────────────────

class ClientRiskProfile {
  // ── Dados pessoais (coletados no cadastro) ──────────────────────
  final int? age;
  final String? gender;          // 'M' | 'F'
  final String? maritalStatus;   // 'solteiro' | 'casado' | 'divorciado'
  final String? profession;
  final String? incomeRange;     // 'ate3k' | '3k_8k' | '8k_20k' | 'acima20k'

  // ── Localização (coletada via GPS silencioso) ───────────────────
  final String? cep;
  final String? city;
  final String? uf;
  final double? homeLat;
  final double? homeLon;
  final double? workLat;
  final double? workLon;

  // ── Veículo (coletado no cadastro) ─────────────────────────────
  final String? vehicleBrand;
  final String? vehicleModel;
  final int? vehicleYear;
  final double? vehicleFipeValue;
  final String? vehicleType;     // 'carro' | 'moto' | 'caminhao'
  final VehicleUse? vehicleUse;

  // ── Comportamento (coletado durante viagens — OCULTO) ──────────
  final double totalKmRidden;        // km acumulados no app
  final int totalTrips;              // número de viagens
  final double avgSpeedKmh;          // velocidade média observada
  final int nightTrips;              // viagens após 22h
  final int weekendTrips;            // viagens fim de semana
  final int highRiskZoneTransits;    // passagens por zonas críticas/vermelhas
  final double avgTripDistanceKm;    // distância média por viagem

  // ── Histórico de sinistros (informado pelo cliente) ─────────────
  final int claimsLast3Years;        // sinistros nos últimos 3 anos
  final int claimsLast5Years;        // sinistros nos últimos 5 anos
  final bool hadTotalLoss;           // perda total alguma vez

  // ── Metadata ────────────────────────────────────────────────────
  final DateTime lastUpdated;
  final bool isComplete;             // tem dados suficientes para cotar

  const ClientRiskProfile({
    this.age,
    this.gender,
    this.maritalStatus,
    this.profession,
    this.incomeRange,
    this.cep,
    this.city,
    this.uf,
    this.homeLat,
    this.homeLon,
    this.workLat,
    this.workLon,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleFipeValue,
    this.vehicleType,
    this.vehicleUse,
    this.totalKmRidden = 0,
    this.totalTrips = 0,
    this.avgSpeedKmh = 0,
    this.nightTrips = 0,
    this.weekendTrips = 0,
    this.highRiskZoneTransits = 0,
    this.avgTripDistanceKm = 0,
    this.claimsLast3Years = 0,
    this.claimsLast5Years = 0,
    this.hadTotalLoss = false,
    required this.lastUpdated,
    this.isComplete = false,
  });

  ClientRiskProfile copyWith({
    int? age, String? gender, String? maritalStatus, String? profession,
    String? incomeRange, String? cep, String? city, String? uf,
    double? homeLat, double? homeLon, double? workLat, double? workLon,
    String? vehicleBrand, String? vehicleModel, int? vehicleYear,
    double? vehicleFipeValue, String? vehicleType, VehicleUse? vehicleUse,
    double? totalKmRidden, int? totalTrips, double? avgSpeedKmh,
    int? nightTrips, int? weekendTrips, int? highRiskZoneTransits,
    double? avgTripDistanceKm, int? claimsLast3Years, int? claimsLast5Years,
    bool? hadTotalLoss, DateTime? lastUpdated, bool? isComplete,
  }) {
    return ClientRiskProfile(
      age: age ?? this.age,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      profession: profession ?? this.profession,
      incomeRange: incomeRange ?? this.incomeRange,
      cep: cep ?? this.cep,
      city: city ?? this.city,
      uf: uf ?? this.uf,
      homeLat: homeLat ?? this.homeLat,
      homeLon: homeLon ?? this.homeLon,
      workLat: workLat ?? this.workLat,
      workLon: workLon ?? this.workLon,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleFipeValue: vehicleFipeValue ?? this.vehicleFipeValue,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleUse: vehicleUse ?? this.vehicleUse,
      totalKmRidden: totalKmRidden ?? this.totalKmRidden,
      totalTrips: totalTrips ?? this.totalTrips,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      nightTrips: nightTrips ?? this.nightTrips,
      weekendTrips: weekendTrips ?? this.weekendTrips,
      highRiskZoneTransits: highRiskZoneTransits ?? this.highRiskZoneTransits,
      avgTripDistanceKm: avgTripDistanceKm ?? this.avgTripDistanceKm,
      claimsLast3Years: claimsLast3Years ?? this.claimsLast3Years,
      claimsLast5Years: claimsLast5Years ?? this.claimsLast5Years,
      hadTotalLoss: hadTotalLoss ?? this.hadTotalLoss,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  Map<String, dynamic> toJson() => {
    'age': age, 'gender': gender, 'maritalStatus': maritalStatus,
    'profession': profession, 'incomeRange': incomeRange,
    'cep': cep, 'city': city, 'uf': uf,
    'homeLat': homeLat, 'homeLon': homeLon,
    'workLat': workLat, 'workLon': workLon,
    'vehicleBrand': vehicleBrand, 'vehicleModel': vehicleModel,
    'vehicleYear': vehicleYear, 'vehicleFipeValue': vehicleFipeValue,
    'vehicleType': vehicleType, 'vehicleUse': vehicleUse?.index,
    'totalKmRidden': totalKmRidden, 'totalTrips': totalTrips,
    'avgSpeedKmh': avgSpeedKmh, 'nightTrips': nightTrips,
    'weekendTrips': weekendTrips, 'highRiskZoneTransits': highRiskZoneTransits,
    'avgTripDistanceKm': avgTripDistanceKm,
    'claimsLast3Years': claimsLast3Years, 'claimsLast5Years': claimsLast5Years,
    'hadTotalLoss': hadTotalLoss,
    'lastUpdated': lastUpdated.toIso8601String(),
    'isComplete': isComplete,
  };

  factory ClientRiskProfile.fromJson(Map<String, dynamic> j) {
    return ClientRiskProfile(
      age: j['age'] as int?,
      gender: j['gender'] as String?,
      maritalStatus: j['maritalStatus'] as String?,
      profession: j['profession'] as String?,
      incomeRange: j['incomeRange'] as String?,
      cep: j['cep'] as String?,
      city: j['city'] as String?,
      uf: j['uf'] as String?,
      homeLat: (j['homeLat'] as num?)?.toDouble(),
      homeLon: (j['homeLon'] as num?)?.toDouble(),
      workLat: (j['workLat'] as num?)?.toDouble(),
      workLon: (j['workLon'] as num?)?.toDouble(),
      vehicleBrand: j['vehicleBrand'] as String?,
      vehicleModel: j['vehicleModel'] as String?,
      vehicleYear: j['vehicleYear'] as int?,
      vehicleFipeValue: (j['vehicleFipeValue'] as num?)?.toDouble(),
      vehicleType: j['vehicleType'] as String?,
      vehicleUse: j['vehicleUse'] != null
          ? VehicleUse.values[j['vehicleUse'] as int]
          : null,
      totalKmRidden: (j['totalKmRidden'] as num?)?.toDouble() ?? 0,
      totalTrips: j['totalTrips'] as int? ?? 0,
      avgSpeedKmh: (j['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
      nightTrips: j['nightTrips'] as int? ?? 0,
      weekendTrips: j['weekendTrips'] as int? ?? 0,
      highRiskZoneTransits: j['highRiskZoneTransits'] as int? ?? 0,
      avgTripDistanceKm: (j['avgTripDistanceKm'] as num?)?.toDouble() ?? 0,
      claimsLast3Years: j['claimsLast3Years'] as int? ?? 0,
      claimsLast5Years: j['claimsLast5Years'] as int? ?? 0,
      hadTotalLoss: j['hadTotalLoss'] as bool? ?? false,
      lastUpdated: j['lastUpdated'] != null
          ? DateTime.parse(j['lastUpdated'] as String)
          : DateTime.now(),
      isComplete: j['isComplete'] as bool? ?? false,
    );
  }

  /// Score de risco global 0–100 (100 = menor risco)
  int get riskScore {
    double score = 100.0;

    // Fator idade
    final a = age ?? 35;
    if (a < 25)      score -= 25;
    else if (a < 30) score -= 12;
    else if (a > 65) score -= 18;
    else if (a > 55) score -= 8;

    // Fator sexo
    if (gender == 'M') score -= 5;

    // Fator estado civil
    if (maritalStatus == 'casado') score += 4;

    // Fator uso do veículo
    final uf = vehicleUse;
    if (uf == VehicleUse.aplicativo) score -= 22;
    else if (uf == VehicleUse.motoboy) score -= 30;
    else if (uf == VehicleUse.comercial) score -= 15;
    else if (uf == VehicleUse.trabalho) score -= 8;

    // Fator sinistros
    score -= (claimsLast3Years * 12).toDouble();
    score -= (claimsLast5Years * 6).toDouble();
    if (hadTotalLoss) score -= 20;

    // Fator comportamento (viagens no app)
    if (totalTrips > 0) {
      if (avgSpeedKmh > 80) score -= 15;
      else if (avgSpeedKmh > 60) score -= 7;
      final nightRatio = totalTrips > 0 ? nightTrips / totalTrips : 0;
      if (nightRatio > 0.4) score -= 12;
      else if (nightRatio > 0.2) score -= 6;
      final riskZoneRatio = totalTrips > 0 ? highRiskZoneTransits / totalTrips : 0;
      if (riskZoneRatio > 0.5) score -= 10;
      else if (riskZoneRatio > 0.2) score -= 5;
    }

    return score.clamp(0, 100).round();
  }

  RiskLevel get riskLevel {
    final s = riskScore;
    if (s >= 80) return RiskLevel.muitoBaixo;
    if (s >= 65) return RiskLevel.baixo;
    if (s >= 45) return RiskLevel.moderado;
    if (s >= 25) return RiskLevel.alto;
    return RiskLevel.critico;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO DE COTAÇÃO — uma linha na tabela de seguradoras
// ─────────────────────────────────────────────────────────────────────────────

class InsuranceQuote {
  final String insurerName;
  final String insurerCode;       // 'A' | 'B' | 'C' ...
  final InsuranceBranch branch;
  final String coverageType;      // 'Completa' | 'Roubo/Furto' | 'Básica'
  final double deductible;        // franquia em R$
  final double annualPremium;     // prêmio anual em R$
  final double monthlyPremium;    // prêmio mensal em R$
  final int maxCoverageValue;     // capital segurado em R$
  final String highlight;         // diferencial da seguradora
  final bool isRecommended;       // melhor custo/benefício
  final double internalRiskScore; // nosso score antes de ajuste de mercado
  final DateTime calculatedAt;

  const InsuranceQuote({
    required this.insurerName,
    required this.insurerCode,
    required this.branch,
    required this.coverageType,
    required this.deductible,
    required this.annualPremium,
    required this.monthlyPremium,
    required this.maxCoverageValue,
    required this.highlight,
    required this.isRecommended,
    required this.internalRiskScore,
    required this.calculatedAt,
  });

  Map<String, dynamic> toJson() => {
    'insurerName': insurerName, 'insurerCode': insurerCode,
    'branch': branch.index, 'coverageType': coverageType,
    'deductible': deductible, 'annualPremium': annualPremium,
    'monthlyPremium': monthlyPremium, 'maxCoverageValue': maxCoverageValue,
    'highlight': highlight, 'isRecommended': isRecommended,
    'internalRiskScore': internalRiskScore,
    'calculatedAt': calculatedAt.toIso8601String(),
  };

  factory InsuranceQuote.fromJson(Map<String, dynamic> j) => InsuranceQuote(
    insurerName: j['insurerName'] as String,
    insurerCode: j['insurerCode'] as String,
    branch: InsuranceBranch.values[j['branch'] as int],
    coverageType: j['coverageType'] as String,
    deductible: (j['deductible'] as num).toDouble(),
    annualPremium: (j['annualPremium'] as num).toDouble(),
    monthlyPremium: (j['monthlyPremium'] as num).toDouble(),
    maxCoverageValue: j['maxCoverageValue'] as int,
    highlight: j['highlight'] as String,
    isRecommended: j['isRecommended'] as bool,
    internalRiskScore: (j['internalRiskScore'] as num).toDouble(),
    calculatedAt: DateTime.parse(j['calculatedAt'] as String),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PACOTE DE COTAÇÕES — resultado completo para um ramo
// ─────────────────────────────────────────────────────────────────────────────

class QuotePackage {
  final InsuranceBranch branch;
  final List<InsuranceQuote> quotes;
  final int clientRiskScore;         // 0–100
  final RiskLevel riskLevel;
  final String riskJustification;    // explicação textual do score
  final double actuarialPremium;     // prêmio estimado pelo nosso motor
  final DateTime generatedAt;

  const QuotePackage({
    required this.branch,
    required this.quotes,
    required this.clientRiskScore,
    required this.riskLevel,
    required this.riskJustification,
    required this.actuarialPremium,
    required this.generatedAt,
  });

  InsuranceQuote? get recommended =>
      quotes.where((q) => q.isRecommended).isNotEmpty
          ? quotes.firstWhere((q) => q.isRecommended)
          : quotes.isNotEmpty ? quotes.first : null;

  double get lowestPremium =>
      quotes.isEmpty ? 0 : quotes.map((q) => q.annualPremium).reduce(math.min);

  Map<String, dynamic> toJson() => {
    'branch': branch.index,
    'quotes': quotes.map((q) => q.toJson()).toList(),
    'clientRiskScore': clientRiskScore,
    'riskLevel': riskLevel.index,
    'riskJustification': riskJustification,
    'actuarialPremium': actuarialPremium,
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory QuotePackage.fromJson(Map<String, dynamic> j) => QuotePackage(
    branch: InsuranceBranch.values[j['branch'] as int],
    quotes: (j['quotes'] as List)
        .map((q) => InsuranceQuote.fromJson(q as Map<String, dynamic>))
        .toList(),
    clientRiskScore: j['clientRiskScore'] as int,
    riskLevel: RiskLevel.values[j['riskLevel'] as int],
    riskJustification: j['riskJustification'] as String,
    actuarialPremium: (j['actuarialPremium'] as num).toDouble(),
    generatedAt: DateTime.parse(j['generatedAt'] as String),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTOR ATUARIAL DETERMINÍSTICO — coração do sistema
// Todos os cálculos são reprodutíveis, auditáveis, sem IA generativa.
// ─────────────────────────────────────────────────────────────────────────────

class _AtuarialEngine {

  // ── Fator territorial TRI (Motor de Inteligência Territorial) ──────
  // Combina score de crime/acidentes/facções/vias por UF
  // Range: 1.0 (seguro) → 3.5 (extremo) — suavizado para ±30% do CEP
  static double _territorialLoading(String? uf) {
    if (uf == null || uf.isEmpty) return 1.0;
    // quickActuarialFactorByUf retorna 1.0–3.5 — normalizamos para fator de loading
    // em relação a 1.0 (base nacional). Peso: 20% do fator total.
    final triFactor = TerritorialRiskIntelligence.instance.quickActuarialFactorByUf(uf);
    // Normaliza: base = 1.25 (média nacional histórica de loading)
    // triFactor 1.0 → loading 1.0  |  triFactor 2.0 → loading 1.15  |  3.5 → loading 1.35
    return 1.0 + (triFactor - 1.0) * 0.14;
  }

  // ── Tabela de loading por CEP/UF ─────────────────────────────────
  static double _cepLoading(String? cep, String? uf) {
    if (cep == null) return 1.30; // sem CEP → carregamento padrão
    final prefix = cep.replaceAll('-', '').substring(0, math.min(5, cep.replaceAll('-', '').length));
    // ES — zona metropolitana
    if (['29100','29102','29103','29150','29152'].contains(prefix)) return 1.45;
    if (['29015','29020','29032'].contains(prefix)) return 1.65;
    if (['29055','29056','29053'].contains(prefix)) return 1.10;
    if (['29163','29167'].contains(prefix)) return 1.85;
    if (['29166','29161'].contains(prefix)) return 1.05;
    // SP — capital e ABCD
    if (prefix.startsWith('010') || prefix.startsWith('011')) return 1.90;
    if (prefix.startsWith('09')) return 1.75;
    // RJ
    if (prefix.startsWith('20') || prefix.startsWith('21')) return 1.80;
    // MG — BH
    if (prefix.startsWith('30') || prefix.startsWith('31')) return 1.50;
    // regiões de baixo risco
    if (prefix.startsWith('86') || prefix.startsWith('87')) return 1.05;
    // default nacional
    return 1.25;
  }

  // ── Fator de idade do veículo ─────────────────────────────────────
  static double _vehicleAgeLoading(int? year) {
    if (year == null) return 1.20;
    final age = DateTime.now().year - year;
    if (age <= 2)  return 1.00;
    if (age <= 5)  return 1.10;
    if (age <= 10) return 1.22;
    if (age <= 15) return 1.38;
    return 1.55;
  }

  // ── Fator de risco comportamental (baseado em dados do app) ───────
  static double _behaviorLoading(ClientRiskProfile p) {
    double factor = 1.0;
    if (p.totalTrips > 10) {
      // velocidade média
      if (p.avgSpeedKmh > 90) factor *= 1.35;
      else if (p.avgSpeedKmh > 70) factor *= 1.18;
      else if (p.avgSpeedKmh > 50) factor *= 1.05;
      else factor *= 0.95; // motorista conservador — desconto
      // viagens noturnas
      final nightRatio = p.nightTrips / math.max(p.totalTrips, 1);
      factor *= (1 + nightRatio * 0.40);
      // zonas de risco
      final riskRatio = p.highRiskZoneTransits / math.max(p.totalTrips, 1);
      factor *= (1 + riskRatio * 0.30);
      // km acumulados — UBI desconto por menos km
      if (p.totalKmRidden < 5000) factor *= 0.88;
      else if (p.totalKmRidden > 30000) factor *= 1.20;
    }
    return factor;
  }

  // ── Fator sinistros ───────────────────────────────────────────────
  static double _claimsLoading(ClientRiskProfile p) {
    double factor = 1.0;
    factor += p.claimsLast3Years * 0.35;
    factor += (p.claimsLast5Years - p.claimsLast3Years).clamp(0, 10) * 0.15;
    if (p.hadTotalLoss) factor += 0.50;
    return factor;
  }

  // ─────────────────────────────────────────────────────────────────
  // CÁLCULO AUTO / MOTO
  // Fórmula: Prêmio = FIPE × TasaBase × ProdutorioFatores
  // Fatores: CEP · Idade · Uso · Comportamento · Sinistros · Perfil
  // ─────────────────────────────────────────────────────────────────
  static double calcAutoMoto(ClientRiskProfile p, {bool isMoto = false}) {
    final fipe = p.vehicleFipeValue ?? (isMoto ? 15000 : 45000);
    // Taxa base da modalidade (% ao ano sobre FIPE)
    double baseRate = isMoto ? 0.058 : 0.042;

    // Fator etário do condutor
    final age = p.age ?? 35;
    double ageFactor;
    if (isMoto) {
      ageFactor = age < 25 ? 2.10
          : age < 30 ? 1.55
          : age < 40 ? 1.10
          : age < 55 ? 1.00
          : 1.20;
    } else {
      ageFactor = age < 25 ? 1.80
          : age < 30 ? 1.35
          : age < 40 ? 1.00
          : age < 55 ? 0.92
          : 1.15;
    }

    // Fator sexo
    final genderFactor = (p.gender == 'M') ? 1.08 : 0.95;

    // Fator estado civil
    final maritalFactor = (p.maritalStatus == 'casado') ? 0.95 : 1.00;

    // Demais fatores
    final cepF         = _cepLoading(p.cep, p.uf);
    final ageVehF      = _vehicleAgeLoading(p.vehicleYear);
    final useF         = p.vehicleUse?.loadingFactor ?? 1.18;
    final behaviorF    = _behaviorLoading(p);
    final claimsF      = _claimsLoading(p);
    final territorialF = _territorialLoading(p.uf); // 🛰️ Motor TRI

    final premium = fipe * baseRate *
        ageFactor * genderFactor * maritalFactor *
        cepF * ageVehF * useF * behaviorF * claimsF * territorialF;

    return premium;
  }

  // ─────────────────────────────────────────────────────────────────
  // CÁLCULO VIDA
  // Fórmula: Prêmio = CapitalSegurado × TasaMortalidade × Fatores
  // ─────────────────────────────────────────────────────────────────
  static double calcVida(ClientRiskProfile p, {double capitalSegurado = 500000}) {
    final age = p.age ?? 35;

    // Taxa de mortalidade base (tabela BR-EMSsb-v.2017)
    double mortalityRate;
    if (age < 25)      mortalityRate = 0.00085;
    else if (age < 30) mortalityRate = 0.00110;
    else if (age < 35) mortalityRate = 0.00145;
    else if (age < 40) mortalityRate = 0.00195;
    else if (age < 45) mortalityRate = 0.00270;
    else if (age < 50) mortalityRate = 0.00390;
    else if (age < 55) mortalityRate = 0.00580;
    else if (age < 60) mortalityRate = 0.00870;
    else if (age < 65) mortalityRate = 0.01280;
    else               mortalityRate = 0.01950;

    // Sexo (mortalidade masculina é maior)
    final genderFactor = (p.gender == 'M') ? 1.40 : 1.00;

    // Profissão de risco
    double professionFactor = 1.0;
    final prof = (p.profession ?? '').toLowerCase();
    if (prof.contains('motoboy') || prof.contains('motoboi')) professionFactor = 2.5;
    else if (prof.contains('motorista') || prof.contains('caminhon')) professionFactor = 1.8;
    else if (prof.contains('policial') || prof.contains('segurança')) professionFactor = 1.6;
    else if (prof.contains('construção') || prof.contains('pedreiro')) professionFactor = 1.4;
    else if (prof.contains('médico') || prof.contains('advogado')) professionFactor = 0.9;

    // Sinistros (histórico de saúde implícito via sinistros passados)
    final claimsF = 1.0 + (p.claimsLast5Years * 0.10);

    // 🛰️ Fator territorial (mortalidade regional — crime + acidentes)
    final territorialF = _territorialLoading(p.uf);

    // Loading / carregamento operacional SUSEP (35%)
    const susepLoading = 1.35;

    final premium = capitalSegurado * mortalityRate *
        genderFactor * professionFactor * claimsF * susepLoading * territorialF;

    return premium;
  }

  // ─────────────────────────────────────────────────────────────────
  // CÁLCULO RESIDENCIAL
  // ─────────────────────────────────────────────────────────────────
  static double calcResidencial(ClientRiskProfile p, {double imovelValue = 300000}) {
    // Taxa base residencial (% ao ano sobre valor do imóvel)
    const baseRate = 0.0018;

    // Fator CEP (incêndio, roubo, alagamento)
    final cepF = _cepLoading(p.cep, p.uf);

    // Fator tipo (casa × apartamento)
    const houseFactor = 1.15; // casa tem mais risco que apto

    // Histórico sinistros
    final claimsF = 1.0 + p.claimsLast3Years * 0.20;

    return imovelValue * baseRate * cepF * houseFactor * claimsF;
  }

  // ─────────────────────────────────────────────────────────────────
  // CÁLCULO CELULAR
  // ─────────────────────────────────────────────────────────────────
  static double calcCelular(ClientRiskProfile p, {double deviceValue = 3000}) {
    // Taxa base: furto/roubo/quebra acidental
    const baseRate = 0.085; // 8.5% ao ano

    // Fator CEP (furto regional)
    final cepF = _cepLoading(p.cep, p.uf) * 0.6 + 0.4;

    // Fator idade do cliente (jovens têm mais perda)
    final age = p.age ?? 35;
    final ageFactor = age < 25 ? 1.30 : age < 35 ? 1.10 : 1.00;

    // Sinistros
    final claimsF = 1.0 + p.claimsLast3Years * 0.30;

    return deviceValue * baseRate * cepF * ageFactor * claimsF;
  }

  // ─────────────────────────────────────────────────────────────────
  // CÁLCULO VIAGEM
  // ─────────────────────────────────────────────────────────────────
  static double calcViagem({int? age, int durationDays = 7, String? destination}) {
    final a = age ?? 35;
    // Taxa base por dia
    double dailyRate;
    if (a < 30)      dailyRate = 18.0;
    else if (a < 50) dailyRate = 22.0;
    else if (a < 65) dailyRate = 35.0;
    else             dailyRate = 58.0;

    // Destino (internacional custa mais)
    final dest = (destination ?? '').toLowerCase();
    double destFactor = 1.0;
    if (dest.contains('eua') || dest.contains('estados unidos')) destFactor = 2.8;
    else if (dest.contains('europa')) destFactor = 2.2;
    else if (dest.contains('caribe') || dest.contains('méxico')) destFactor = 1.8;
    else if (dest.contains('exterior') || dest.contains('international')) destFactor = 2.0;
    else destFactor = 1.0; // nacional

    return dailyRate * durationDays * destFactor;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORQUESTRADOR DE COTAÇÕES — simula múltiplas seguradoras
// Em produção: substituir por chamadas reais às APIs (Porto, Bradesco,
// Zurich, Mapfre, Allianz, HDI, Liberty, SulAmérica, Tokio Marine).
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteOrchestrator {

  static const _insurers = [
    {'name': 'Porto Seguro',    'code': 'A', 'factor': 1.00, 'highlight': 'Melhor rede credenciada'},
    {'name': 'Bradesco Seguros','code': 'B', 'factor': 1.08, 'highlight': 'Assistência 24h nacional'},
    {'name': 'Zurich Seguros',  'code': 'C', 'factor': 0.94, 'highlight': 'Menor franquia do mercado'},
    {'name': 'Mapfre',          'code': 'D', 'factor': 1.05, 'highlight': 'Carro reserva 30 dias'},
    {'name': 'Allianz',         'code': 'E', 'factor': 0.97, 'highlight': 'App premiado de gestão'},
    {'name': 'HDI Seguros',     'code': 'F', 'factor': 0.91, 'highlight': 'Menor prêmio do grupo'},
    {'name': 'Liberty Seguros', 'code': 'G', 'factor': 1.03, 'highlight': 'Desconto telemetria UBI'},
    {'name': 'SulAmérica',      'code': 'H', 'factor': 1.02, 'highlight': 'Proteção residencial inclusa'},
  ];

  static List<InsuranceQuote> generateAutoMoto(
      ClientRiskProfile profile, double actuarialPremium,
      {bool isMoto = false}) {

    final branch = isMoto ? InsuranceBranch.moto : InsuranceBranch.auto;
    final quotes = <InsuranceQuote>[];
    final fipe = profile.vehicleFipeValue ?? (isMoto ? 15000 : 45000);

    // Ordena por fator (menor primeiro = melhor oferta)
    final sorted = List.from(_insurers)
      ..sort((a, b) => (a['factor'] as double).compareTo(b['factor'] as double));

    for (int i = 0; i < math.min(sorted.length, 6); i++) {
      final ins = sorted[i];
      final factor = ins['factor'] as double;
      // Pequena variação aleatória determinística por código
      final jitter = 0.97 + (ins['code'].hashCode % 7) * 0.01;

      final annual = actuarialPremium * factor * jitter;
      final monthly = annual / 12;
      final deductible = fipe * (isMoto ? 0.12 : 0.08) * factor;

      // Coberturas: top 3 oferecem completa, demais básica ou roubo
      final coverage = i < 3 ? 'Completa' : (i < 5 ? 'Roubo/Furto + Colisão' : 'Básica');

      quotes.add(InsuranceQuote(
        insurerName: ins['name'] as String,
        insurerCode: ins['code'] as String,
        branch: branch,
        coverageType: coverage,
        deductible: deductible,
        annualPremium: annual,
        monthlyPremium: monthly,
        maxCoverageValue: fipe.round(),
        highlight: ins['highlight'] as String,
        isRecommended: i == 0, // menor prêmio = recomendado
        internalRiskScore: profile.riskScore.toDouble(),
        calculatedAt: DateTime.now(),
      ));
    }

    return quotes;
  }

  static List<InsuranceQuote> generateVida(
      ClientRiskProfile profile, double actuarialPremium,
      {double capitalSegurado = 500000}) {

    final quotes = <InsuranceQuote>[];
    final sorted = List.from(_insurers.sublist(0, 5))
      ..sort((a, b) => (a['factor'] as double).compareTo(b['factor'] as double));

    for (int i = 0; i < sorted.length; i++) {
      final ins = sorted[i];
      final factor = ins['factor'] as double;
      final annual = actuarialPremium * factor;
      quotes.add(InsuranceQuote(
        insurerName: ins['name'] as String,
        insurerCode: ins['code'] as String,
        branch: InsuranceBranch.vida,
        coverageType: i < 2 ? 'Completa (morte + invalidez)' : 'Morte Natural/Acidental',
        deductible: 0,
        annualPremium: annual,
        monthlyPremium: annual / 12,
        maxCoverageValue: capitalSegurado.round(),
        highlight: ins['highlight'] as String,
        isRecommended: i == 0,
        internalRiskScore: profile.riskScore.toDouble(),
        calculatedAt: DateTime.now(),
      ));
    }
    return quotes;
  }

  static List<InsuranceQuote> generateResidencial(
      ClientRiskProfile profile, double actuarialPremium,
      {double imovelValue = 300000}) {

    final quotes = <InsuranceQuote>[];
    final sorted = List.from(_insurers.sublist(0, 5))
      ..sort((a, b) => (a['factor'] as double).compareTo(b['factor'] as double));

    for (int i = 0; i < sorted.length; i++) {
      final ins = sorted[i];
      final annual = actuarialPremium * (ins['factor'] as double);
      quotes.add(InsuranceQuote(
        insurerName: ins['name'] as String,
        insurerCode: ins['code'] as String,
        branch: InsuranceBranch.residencial,
        coverageType: i < 2 ? 'Multirisco Completo' : 'Incêndio + Roubo',
        deductible: 0,
        annualPremium: annual,
        monthlyPremium: annual / 12,
        maxCoverageValue: imovelValue.round(),
        highlight: ins['highlight'] as String,
        isRecommended: i == 0,
        internalRiskScore: profile.riskScore.toDouble(),
        calculatedAt: DateTime.now(),
      ));
    }
    return quotes;
  }

  static List<InsuranceQuote> generateCelular(
      ClientRiskProfile profile, double actuarialPremium,
      {double deviceValue = 3000}) {

    const celularInsurers = [
      {'name': 'Thinkseg',   'code': 'A', 'factor': 1.00, 'highlight': 'Tela quebrada inclusa'},
      {'name': 'Chubb',      'code': 'B', 'factor': 1.12, 'highlight': 'Roubo e perda acidental'},
      {'name': 'BEm Seguro', 'code': 'C', 'factor': 0.92, 'highlight': 'Ativação em 24h'},
    ];

    return celularInsurers.map((ins) {
      final annual = actuarialPremium * (ins['factor'] as double);
      return InsuranceQuote(
        insurerName: ins['name'] as String,
        insurerCode: ins['code'] as String,
        branch: InsuranceBranch.celular,
        coverageType: 'Roubo + Quebra Acidental',
        deductible: 0,
        annualPremium: annual,
        monthlyPremium: annual / 12,
        maxCoverageValue: deviceValue.round(),
        highlight: ins['highlight'] as String,
        isRecommended: ins['code'] == 'C',
        internalRiskScore: profile.riskScore.toDouble(),
        calculatedAt: DateTime.now(),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATUÁRIO DIGITAL CORE — singleton principal
// Este é o único ponto de entrada. Roda invisível.
// ─────────────────────────────────────────────────────────────────────────────

class AtuarioDigitalCore {
  AtuarioDigitalCore._();
  static final AtuarioDigitalCore instance = AtuarioDigitalCore._();

  static const _profileKey  = 'atuario_client_profile_v2';
  static const _quotesKey   = 'atuario_quotes_cache_v2';
  static const _lastRunKey  = 'atuario_last_run_v2';

  ClientRiskProfile? _profile;
  final Map<InsuranceBranch, QuotePackage> _quotes = {};
  bool _initialized = false;

  /// Chamado silenciosamente no login — carrega perfil salvo
  Future<void> init() async {
    if (_initialized) return;
    await _loadProfile();
    await _loadQuotesCache();
    _initialized = true;
  }

  // ── GETTERS PÚBLICOS ─────────────────────────────────────────────

  ClientRiskProfile? get profile => _profile;

  int get riskScore => _profile?.riskScore ?? 50;

  RiskLevel get riskLevel => _profile?.riskLevel ?? RiskLevel.moderado;

  bool get hasQuotes => _quotes.isNotEmpty;

  QuotePackage? quotesFor(InsuranceBranch branch) => _quotes[branch];

  List<QuotePackage> get allQuotes => _quotes.values.toList();

  bool get profileComplete => _profile?.isComplete ?? false;

  // ── ALIMENTAÇÃO SILENCIOSA (chamada internamente pelo app) ────────

  /// Chamado ao completar cadastro — salva dados pessoais
  Future<void> onRegistrationComplete({
    required int age,
    required String gender,
    required String maritalStatus,
    String? profession,
    String? incomeRange,
  }) async {
    final p = (_profile ?? _defaultProfile()).copyWith(
      age: age,
      gender: gender,
      maritalStatus: maritalStatus,
      profession: profession,
      incomeRange: incomeRange,
      lastUpdated: DateTime.now(),
    );
    await _saveProfile(_checkCompleteness(p));
    _scheduleRecalc();
  }

  /// Chamado ao GPS obter localização — salva CEP/cidade silenciosamente
  Future<void> onLocationDetected({
    required double lat,
    required double lon,
    String? cep,
    String? city,
    String? uf,
    bool isHome = false,
    bool isWork = false,
  }) async {
    if (_profile == null) await _loadProfile();
    final p = (_profile ?? _defaultProfile()).copyWith(
      cep: cep ?? _profile?.cep,
      city: city ?? _profile?.city,
      uf: uf ?? _profile?.uf,
      homeLat: isHome ? lat : _profile?.homeLat,
      homeLon: isHome ? lon : _profile?.homeLon,
      workLat: isWork ? lat : _profile?.workLat,
      workLon: isWork ? lon : _profile?.workLon,
      lastUpdated: DateTime.now(),
    );
    await _saveProfile(_checkCompleteness(p));
  }

  /// Chamado ao cadastrar veículo
  Future<void> onVehicleRegistered({
    required String brand,
    required String model,
    required int year,
    required double fipeValue,
    required String vehicleType,
    VehicleUse vehicleUse = VehicleUse.particular,
  }) async {
    if (_profile == null) await _loadProfile();
    final p = (_profile ?? _defaultProfile()).copyWith(
      vehicleBrand: brand,
      vehicleModel: model,
      vehicleYear: year,
      vehicleFipeValue: fipeValue,
      vehicleType: vehicleType,
      vehicleUse: vehicleUse,
      lastUpdated: DateTime.now(),
    );
    await _saveProfile(_checkCompleteness(p));
    _scheduleRecalc(); // veículo completa o perfil — recalcula imediatamente
  }

  /// Chamado ao ENCERRAR cada viagem — alimenta comportamento UBI
  Future<void> onTripCompleted({
    required double distanceKm,
    required double avgSpeedKmh,
    required int durationSec,
    required bool isNight,
    required bool isWeekend,
    required int highRiskZoneCount,
    required DateTime tripDate,
  }) async {
    if (_profile == null) await _loadProfile();
    final p = _profile ?? _defaultProfile();

    final newTotal = p.totalTrips + 1;
    final newKm    = p.totalKmRidden + distanceKm;
    // Média ponderada de velocidade
    final newAvgSpeed = p.totalTrips == 0
        ? avgSpeedKmh
        : (p.avgSpeedKmh * p.totalTrips + avgSpeedKmh) / newTotal;
    final newAvgDist = newKm / newTotal;

    final updated = p.copyWith(
      totalTrips: newTotal,
      totalKmRidden: newKm,
      avgSpeedKmh: newAvgSpeed,
      nightTrips: p.nightTrips + (isNight ? 1 : 0),
      weekendTrips: p.weekendTrips + (isWeekend ? 1 : 0),
      highRiskZoneTransits: p.highRiskZoneTransits + highRiskZoneCount,
      avgTripDistanceKm: newAvgDist,
      lastUpdated: DateTime.now(),
    );

    await _saveProfile(_checkCompleteness(updated));

    // Recalcula cotações a cada 5 viagens (não a cada viagem — otimização)
    if (newTotal % 5 == 0) await recalculateAll();
  }

  /// Chamado ao informar sinistros
  Future<void> onClaimsInformed({
    required int claimsLast3Years,
    required int claimsLast5Years,
    required bool hadTotalLoss,
  }) async {
    if (_profile == null) await _loadProfile();
    final p = (_profile ?? _defaultProfile()).copyWith(
      claimsLast3Years: claimsLast3Years,
      claimsLast5Years: claimsLast5Years,
      hadTotalLoss: hadTotalLoss,
      lastUpdated: DateTime.now(),
    );
    await _saveProfile(_checkCompleteness(p));
    await recalculateAll(); // sinistros impactam muito — recalcula imediatamente
  }

  // ── RECÁLCULO PRINCIPAL ───────────────────────────────────────────

  /// Recalcula todas as cotações com o perfil atual.
  /// Silencioso — sem UI, sem loading.
  Future<void> recalculateAll() async {
    final p = _profile;
    if (p == null) return;

    final now = DateTime.now();
    final justification = _buildJustification(p);

    // AUTO
    if (p.vehicleType == 'carro' || p.vehicleType == null) {
      final actuarialPremium = _AtuarialEngine.calcAutoMoto(p, isMoto: false);
      final quotes = _QuoteOrchestrator.generateAutoMoto(p, actuarialPremium);
      _quotes[InsuranceBranch.auto] = QuotePackage(
        branch: InsuranceBranch.auto,
        quotes: quotes,
        clientRiskScore: p.riskScore,
        riskLevel: p.riskLevel,
        riskJustification: justification,
        actuarialPremium: actuarialPremium,
        generatedAt: now,
      );
    }

    // MOTO
    if (p.vehicleType == 'moto') {
      final actuarialPremium = _AtuarialEngine.calcAutoMoto(p, isMoto: true);
      final quotes = _QuoteOrchestrator.generateAutoMoto(p, actuarialPremium, isMoto: true);
      _quotes[InsuranceBranch.moto] = QuotePackage(
        branch: InsuranceBranch.moto,
        quotes: quotes,
        clientRiskScore: p.riskScore,
        riskLevel: p.riskLevel,
        riskJustification: justification,
        actuarialPremium: actuarialPremium,
        generatedAt: now,
      );
    }

    // VIDA (sempre calculado independente do veículo)
    final vidaPremium = _AtuarialEngine.calcVida(p);
    final vidaQuotes  = _QuoteOrchestrator.generateVida(p, vidaPremium);
    _quotes[InsuranceBranch.vida] = QuotePackage(
      branch: InsuranceBranch.vida,
      quotes: vidaQuotes,
      clientRiskScore: p.riskScore,
      riskLevel: p.riskLevel,
      riskJustification: justification,
      actuarialPremium: vidaPremium,
      generatedAt: now,
    );

    // RESIDENCIAL
    final resPremium = _AtuarialEngine.calcResidencial(p);
    final resQuotes  = _QuoteOrchestrator.generateResidencial(p, resPremium);
    _quotes[InsuranceBranch.residencial] = QuotePackage(
      branch: InsuranceBranch.residencial,
      quotes: resQuotes,
      clientRiskScore: p.riskScore,
      riskLevel: p.riskLevel,
      riskJustification: justification,
      actuarialPremium: resPremium,
      generatedAt: now,
    );

    // CELULAR
    final celPremium = _AtuarialEngine.calcCelular(p);
    final celQuotes  = _QuoteOrchestrator.generateCelular(p, celPremium);
    _quotes[InsuranceBranch.celular] = QuotePackage(
      branch: InsuranceBranch.celular,
      quotes: celQuotes,
      clientRiskScore: p.riskScore,
      riskLevel: p.riskLevel,
      riskJustification: justification,
      actuarialPremium: celPremium,
      generatedAt: now,
    );

    await _saveQuotesCache();
    await _saveLastRun(now);
  }

  // ── PERSISTÊNCIA ─────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json  = prefs.getString(_profileKey);
      if (json != null) {
        _profile = ClientRiskProfile.fromJson(
            jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _saveProfile(ClientRiskProfile p) async {
    _profile = p;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, jsonEncode(p.toJson()));
    } catch (_) {}
  }

  Future<void> _loadQuotesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json  = prefs.getString(_quotesKey);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        map.forEach((key, value) {
          final pkg = QuotePackage.fromJson(value as Map<String, dynamic>);
          _quotes[pkg.branch] = pkg;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveQuotesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      _quotes.forEach((branch, pkg) {
        map[branch.index.toString()] = pkg.toJson();
      });
      await prefs.setString(_quotesKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _saveLastRun(DateTime dt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastRunKey, dt.toIso8601String());
    } catch (_) {}
  }

  // ── HELPERS ──────────────────────────────────────────────────────

  ClientRiskProfile _defaultProfile() => ClientRiskProfile(
    lastUpdated: DateTime.now(),
  );

  ClientRiskProfile _checkCompleteness(ClientRiskProfile p) {
    final complete =
        p.age != null &&
        p.gender != null &&
        (p.cep != null || p.city != null) &&
        (p.vehicleFipeValue != null || p.vehicleType == null);
    return p.copyWith(isComplete: complete);
  }

  String _buildJustification(ClientRiskProfile p) {
    final reasons = <String>[];
    final age = p.age ?? 35;
    if (age < 25) reasons.add('Condutor jovem (< 25 anos)');
    else if (age >= 65) reasons.add('Condutor sênior (≥ 65 anos)');
    if (p.gender == 'M') reasons.add('Condutor masculino');
    if (p.vehicleUse == VehicleUse.aplicativo) reasons.add('Uso por aplicativo');
    if (p.vehicleUse == VehicleUse.motoboy) reasons.add('Uso como motoboy');
    if (p.claimsLast3Years > 0) reasons.add('${p.claimsLast3Years} sinistro(s) nos últimos 3 anos');
    if (p.hadTotalLoss) reasons.add('Histórico de perda total');
    if (p.totalTrips > 10 && p.avgSpeedKmh > 80) reasons.add('Velocidade média elevada (${p.avgSpeedKmh.round()} km/h)');
    if (p.totalTrips > 10) {
      final nightRatio = p.nightTrips / p.totalTrips;
      if (nightRatio > 0.3) reasons.add('Alta frequência de viagens noturnas');
    }
    if (p.highRiskZoneTransits > 5) reasons.add('Trafega frequentemente em zonas de risco');
    if (reasons.isEmpty) reasons.add('Perfil dentro do padrão esperado');
    return reasons.join(' · ');
  }

  /// Agendamento leve — recalcula em background sem bloquear a UI
  void _scheduleRecalc() {
    Future.delayed(const Duration(seconds: 2), () async {
      await recalculateAll();
    });
  }

  /// Reset completo (logout)
  Future<void> clear() async {
    _profile = null;
    _quotes.clear();
    _initialized = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
      await prefs.remove(_quotesKey);
      await prefs.remove(_lastRunKey);
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — SAFE MAP ENGINE V1
// Banco de Dados de Risco Nacional: Estado → Cidade → Bairro → Rua → Trecho
// Score 0-1000 · Robbery · Accident · Weather · Time · Vehicle · Route
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS E CLASSIFICAÇÃO DE SCORE
// ─────────────────────────────────────────────────────────────────────────────

enum SafeScoreClass {
  muitoSeguro,  // 0–200
  seguro,       // 201–400
  medio,        // 401–600
  alto,         // 601–800
  critico;      // 801–1000

  static SafeScoreClass fromScore(int score) {
    if (score <= 200) return muitoSeguro;
    if (score <= 400) return seguro;
    if (score <= 600) return medio;
    if (score <= 800) return alto;
    return critico;
  }

  String get label {
    switch (this) {
      case muitoSeguro: return 'Muito Seguro';
      case seguro:      return 'Seguro';
      case medio:       return 'Médio';
      case alto:        return 'Alto';
      case critico:     return 'Crítico';
    }
  }

  Color get color {
    switch (this) {
      case muitoSeguro: return const Color(0xFF22C55E);
      case seguro:      return const Color(0xFF84CC16);
      case medio:       return const Color(0xFFF59E0B);
      case alto:        return const Color(0xFFF97316);
      case critico:     return const Color(0xFFEF4444);
    }
  }

  Color get bgColor {
    switch (this) {
      case muitoSeguro: return const Color(0xFFF0FDF4);
      case seguro:      return const Color(0xFFF7FEE7);
      case medio:       return const Color(0xFFFFFBEB);
      case alto:        return const Color(0xFFFFF7ED);
      case critico:     return const Color(0xFFFFF1F1);
    }
  }

  IconData get icon {
    switch (this) {
      case muitoSeguro: return Icons.verified_rounded;
      case seguro:      return Icons.shield_rounded;
      case medio:       return Icons.warning_amber_rounded;
      case alto:        return Icons.report_problem_rounded;
      case critico:     return Icons.dangerous_rounded;
    }
  }

  double get priceMultiplier {
    switch (this) {
      case muitoSeguro: return 0.85;
      case seguro:      return 1.00;
      case medio:       return 1.35;
      case alto:        return 1.80;
      case critico:     return 2.60;
    }
  }
}

// Safe Score de viagem: 0–100 (inverso ao score de risco)
class SafeTripScore {
  final int score; // 0–100

  const SafeTripScore(this.score);

  String get label {
    if (score >= 85) return 'Muito Segura';
    if (score >= 70) return 'Segura';
    if (score >= 50) return 'Atenção';
    if (score >= 30) return 'Risco Moderado';
    return 'Risco Extremo';
  }

  Color get color {
    if (score >= 85) return const Color(0xFF22C55E);
    if (score >= 70) return const Color(0xFF84CC16);
    if (score >= 50) return const Color(0xFFF59E0B);
    if (score >= 30) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String get emoji {
    if (score >= 85) return '🟢';
    if (score >= 70) return '🟡';
    if (score >= 50) return '🟠';
    return '🔴';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: ESTADO
// ─────────────────────────────────────────────────────────────────────────────

class StateRisk {
  final String id;
  final String nome;
  final String uf;
  final int score;
  final int roubosAno;
  final int acidentesAno;
  final int frota;       // estimativa de veículos

  const StateRisk({
    required this.id,
    required this.nome,
    required this.uf,
    required this.score,
    required this.roubosAno,
    required this.acidentesAno,
    required this.frota,
  });

  SafeScoreClass get classification => SafeScoreClass.fromScore(score);

  double get taxaRoubo => frota > 0 ? roubosAno / frota * 1000 : 0; // por mil veículos
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: CIDADE
// ─────────────────────────────────────────────────────────────────────────────

class CityRisk {
  final String id;
  final String stateId;
  final String nome;
  final String uf;
  final int score;
  final int populacao;
  final int roubosAno;
  final int furtoAno;
  final int acidentesAno;
  final int atropelamentosAno;
  final bool isMetropole;

  const CityRisk({
    required this.id,
    required this.stateId,
    required this.nome,
    required this.uf,
    required this.score,
    required this.populacao,
    required this.roubosAno,
    required this.furtoAno,
    required this.acidentesAno,
    required this.atropelamentosAno,
    this.isMetropole = false,
  });

  SafeScoreClass get classification => SafeScoreClass.fromScore(score);
  double get rouboPorHab => populacao > 0 ? roubosAno / populacao * 100000 : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: BAIRRO
// ─────────────────────────────────────────────────────────────────────────────

class DistrictRisk {
  final String id;
  final String cityId;
  final String nome;
  final String cidade;
  final String uf;
  final int score;

  // Sub-scores
  final int robberyScore;
  final int theftScore;
  final int accidentScore;
  final int weatherScore;

  // Metadados
  final bool hasCamera;
  final bool hasPoliciamento;
  final bool isPeriferica;
  final int lastUpdate; // timestamp epoch

  const DistrictRisk({
    required this.id,
    required this.cityId,
    required this.nome,
    required this.cidade,
    required this.uf,
    required this.score,
    required this.robberyScore,
    required this.theftScore,
    required this.accidentScore,
    required this.weatherScore,
    this.hasCamera = false,
    this.hasPoliciamento = false,
    this.isPeriferica = false,
    this.lastUpdate = 0,
  });

  SafeScoreClass get classification => SafeScoreClass.fromScore(score);

  String get fullName => '$nome, $cidade/$uf';
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: RUA / TRECHO
// ─────────────────────────────────────────────────────────────────────────────

class StreetRisk {
  final String id;
  final String districtId;
  final String nome;
  final String bairro;
  final String cidade;
  final String uf;
  final int score;

  // Sub-scores do trecho
  final int robberyScore;
  final int accidentScore;
  final int speedLimit;       // km/h
  final int avgSpeed;         // velocidade real média
  final bool hasLighting;
  final bool hasCamera;
  final bool isPedestrianZone;
  final int incidentesUltimos12m;

  const StreetRisk({
    required this.id,
    required this.districtId,
    required this.nome,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.score,
    required this.robberyScore,
    required this.accidentScore,
    required this.speedLimit,
    required this.avgSpeed,
    this.hasLighting = true,
    this.hasCamera = false,
    this.isPedestrianZone = false,
    this.incidentesUltimos12m = 0,
  });

  SafeScoreClass get classification => SafeScoreClass.fromScore(score);
  String get fullName => '$nome — $bairro/$cidade';
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: ROBBERY SCORE (robbery_score)
// ─────────────────────────────────────────────────────────────────────────────

class RobberyRecord {
  final String cidade;
  final String bairro;
  final String rua;
  final int indiceAnual;     // ocorrências/ano
  final int score;           // 0–1000
  final double lat;
  final double lng;

  const RobberyRecord({
    required this.cidade,
    required this.bairro,
    required this.rua,
    required this.indiceAnual,
    required this.score,
    required this.lat,
    required this.lng,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: ACCIDENT SCORE (accident_score)
// ─────────────────────────────────────────────────────────────────────────────

class AccidentRecord {
  final String cidade;
  final String local;
  final int batidas;
  final int atropelamentos;
  final int perdaTotalVeiculos;
  final int score; // 0–1000

  const AccidentRecord({
    required this.cidade,
    required this.local,
    required this.batidas,
    required this.atropelamentos,
    required this.perdaTotalVeiculos,
    required this.score,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: WEATHER SCORE (weather_score)
// ─────────────────────────────────────────────────────────────────────────────

class WeatherRiskRecord {
  final String cidade;
  final String uf;
  final int enchentesAno;
  final int alagamentosAno;
  final int deslizamentosAno;
  final int chuvaExtremaAno;   // dias/ano com chuva acima de 50mm
  final int score;

  const WeatherRiskRecord({
    required this.cidade,
    required this.uf,
    required this.enchentesAno,
    required this.alagamentosAno,
    required this.deslizamentosAno,
    required this.chuvaExtremaAno,
    required this.score,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: TIME RISK (time_risk)
// ─────────────────────────────────────────────────────────────────────────────

class TimeRiskTable {
  static const Map<int, double> _weights = {
    0: 1.7,   // 00h
    1: 1.6,
    2: 1.8,   // pico madrugada
    3: 1.8,
    4: 1.7,
    5: 1.4,
    6: 1.0,   // manhã — base
    7: 1.0,
    8: 1.05,
    9: 1.1,
    10: 1.1,
    11: 1.1,
    12: 1.15, // almoço
    13: 1.1,
    14: 1.1,
    15: 1.15,
    16: 1.2,
    17: 1.35, // rush tarde
    18: 1.4,
    19: 1.5,  // noite inicial
    20: 1.6,
    21: 1.7,
    22: 2.0,  // pico noturno
    23: 1.9,
  };

  static double weight(int hour) => _weights[hour % 24] ?? 1.0;

  static String label(int hour) {
    if (hour >= 6  && hour < 12) return 'Manhã';
    if (hour >= 12 && hour < 17) return 'Tarde';
    if (hour >= 17 && hour < 20) return 'Horário de Pico';
    if (hour >= 20 && hour < 23) return 'Noite';
    return 'Madrugada';
  }

  static Color color(int hour) {
    final w = weight(hour);
    if (w <= 1.1) return const Color(0xFF22C55E);
    if (w <= 1.3) return const Color(0xFF84CC16);
    if (w <= 1.6) return const Color(0xFFF59E0B);
    if (w <= 1.9) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  // Retorna lista de (hora, peso) para o gráfico
  static List<MapEntry<int, double>> get allHours =>
      List.generate(24, (h) => MapEntry(h, weight(h)));
}

// ─────────────────────────────────────────────────────────────────────────────
// TABELA: VEHICLE RISK (vehicle_risk)
// ─────────────────────────────────────────────────────────────────────────────

class VehicleRiskRecord {
  final String modelo;
  final String marca;
  final int robberyScore;   // 0–1000 (mais roubado = score maior)
  final int theftScore;     // furto (sem chave)
  final int collisionScore; // acidente
  final int fipeMediaMil;   // valor FIPE médio em R$ mil
  final int roubosAno;      // estimativa nacional

  const VehicleRiskRecord({
    required this.modelo,
    required this.marca,
    required this.robberyScore,
    required this.theftScore,
    required this.collisionScore,
    required this.fipeMediaMil,
    required this.roubosAno,
  });

  int get overallScore =>
      ((robberyScore * 0.5) + (theftScore * 0.3) + (collisionScore * 0.2)).round();

  SafeScoreClass get riskClass => SafeScoreClass.fromScore(overallScore);

  double get priceMultiplier => 1.0 + (overallScore / 1000) * 1.2;
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: ROTA COM SCORE
// ─────────────────────────────────────────────────────────────────────────────

class RouteRiskProfile {
  final String routeId;
  final String name;
  final String from;
  final String to;
  final double distanceKm;
  final int estimatedMinutes;
  final int routeScore;         // score médio do trajeto
  final double tripPrice;       // preço calculado pelo engine
  final List<RouteSegmentRisk> segments;
  final bool isSaferAlternative;
  final bool isFastestAlternative;

  const RouteRiskProfile({
    required this.routeId,
    required this.name,
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.routeScore,
    required this.tripPrice,
    required this.segments,
    this.isSaferAlternative = false,
    this.isFastestAlternative = false,
  });

  SafeScoreClass get classification => SafeScoreClass.fromScore(routeScore);

  SafeTripScore get safeScore =>
      SafeTripScore(100 - (routeScore / 10).round().clamp(0, 100));

  String get priceFormatted =>
      'R\$ ${tripPrice.toStringAsFixed(2).replaceAll('.', ',')}';
}

class RouteSegmentRisk {
  final String name;
  final int score;
  final double lengthKm;
  final int incidentesAno;

  const RouteSegmentRisk({
    required this.name,
    required this.score,
    required this.lengthKm,
    required this.incidentesAno,
  });

  SafeScoreClass get classification => SafeScoreClass.fromScore(score);
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFE MAP DATABASE — dados nacionais
// ─────────────────────────────────────────────────────────────────────────────

class SafeMapDatabase {

  // ── ESTADOS ──────────────────────────────────────────────────────────────
  static const List<StateRisk> states = [
    StateRisk(id: 'SP', nome: 'São Paulo',          uf: 'SP', score: 780, roubosAno: 142000, acidentesAno: 68000, frota: 28000000),
    StateRisk(id: 'RJ', nome: 'Rio de Janeiro',     uf: 'RJ', score: 820, roubosAno: 98000,  acidentesAno: 41000, frota: 8200000),
    StateRisk(id: 'BA', nome: 'Bahia',              uf: 'BA', score: 760, roubosAno: 62000,  acidentesAno: 31000, frota: 4800000),
    StateRisk(id: 'PE', nome: 'Pernambuco',         uf: 'PE', score: 800, roubosAno: 55000,  acidentesAno: 28000, frota: 3900000),
    StateRisk(id: 'CE', nome: 'Ceará',              uf: 'CE', score: 790, roubosAno: 49000,  acidentesAno: 24000, frota: 3500000),
    StateRisk(id: 'MG', nome: 'Minas Gerais',       uf: 'MG', score: 620, roubosAno: 71000,  acidentesAno: 45000, frota: 11000000),
    StateRisk(id: 'PR', nome: 'Paraná',             uf: 'PR', score: 540, roubosAno: 38000,  acidentesAno: 29000, frota: 7200000),
    StateRisk(id: 'RS', nome: 'Rio Grande do Sul',  uf: 'RS', score: 480, roubosAno: 31000,  acidentesAno: 26000, frota: 6800000),
    StateRisk(id: 'SC', nome: 'Santa Catarina',     uf: 'SC', score: 380, roubosAno: 18000,  acidentesAno: 19000, frota: 5400000),
    StateRisk(id: 'GO', nome: 'Goiás',              uf: 'GO', score: 590, roubosAno: 29000,  acidentesAno: 22000, frota: 4200000),
    StateRisk(id: 'DF', nome: 'Distrito Federal',   uf: 'DF', score: 650, roubosAno: 22000,  acidentesAno: 12000, frota: 2100000),
    StateRisk(id: 'AM', nome: 'Amazonas',           uf: 'AM', score: 710, roubosAno: 14000,  acidentesAno: 8000,  frota: 980000),
    StateRisk(id: 'PA', nome: 'Pará',               uf: 'PA', score: 720, roubosAno: 19000,  acidentesAno: 11000, frota: 1800000),
    StateRisk(id: 'ES', nome: 'Espírito Santo',     uf: 'ES', score: 580, roubosAno: 16800,  acidentesAno: 9200,  frota: 2100000),
    StateRisk(id: 'AL', nome: 'Alagoas',            uf: 'AL', score: 840, roubosAno: 12000,  acidentesAno: 6200,  frota: 820000),
    StateRisk(id: 'MA', nome: 'Maranhão',           uf: 'MA', score: 730, roubosAno: 11000,  acidentesAno: 7800,  frota: 1100000),
    StateRisk(id: 'RN', nome: 'Rio Grande do Norte',uf: 'RN', score: 760, roubosAno: 9800,   acidentesAno: 5400,  frota: 1050000),
    StateRisk(id: 'PI', nome: 'Piauí',              uf: 'PI', score: 620, roubosAno: 5200,   acidentesAno: 4800,  frota: 740000),
    StateRisk(id: 'MT', nome: 'Mato Grosso',        uf: 'MT', score: 560, roubosAno: 8100,   acidentesAno: 9200,  frota: 1400000),
    StateRisk(id: 'MS', nome: 'Mato Grosso do Sul', uf: 'MS', score: 490, roubosAno: 7200,   acidentesAno: 8100,  frota: 1200000),
  ];

  // ── CIDADES — principais capitais e municípios ────────────────────────────
  static const List<CityRisk> cities = [
    // SP
    CityRisk(id: 'sao_paulo',       stateId: 'SP', nome: 'São Paulo',        uf: 'SP', score: 800, populacao: 12300000, roubosAno: 88000,  furtoAno: 124000, acidentesAno: 42000, atropelamentosAno: 1820, isMetropole: true),
    CityRisk(id: 'guarulhos',       stateId: 'SP', nome: 'Guarulhos',        uf: 'SP', score: 740, populacao: 1380000,  roubosAno: 9200,   furtoAno: 14000,  acidentesAno: 5200,  atropelamentosAno: 210),
    CityRisk(id: 'campinas',        stateId: 'SP', nome: 'Campinas',         uf: 'SP', score: 680, populacao: 1220000,  roubosAno: 7800,   furtoAno: 11200,  acidentesAno: 4100,  atropelamentosAno: 180),
    CityRisk(id: 'osasco',          stateId: 'SP', nome: 'Osasco',           uf: 'SP', score: 760, populacao: 710000,   roubosAno: 5400,   furtoAno: 7800,   acidentesAno: 2900,  atropelamentosAno: 124),
    // RJ
    CityRisk(id: 'rio_janeiro',     stateId: 'RJ', nome: 'Rio de Janeiro',   uf: 'RJ', score: 840, populacao: 6750000,  roubosAno: 71000,  furtoAno: 89000,  acidentesAno: 29000, atropelamentosAno: 1240, isMetropole: true),
    CityRisk(id: 'niteroi',         stateId: 'RJ', nome: 'Niterói',          uf: 'RJ', score: 680, populacao: 516000,   roubosAno: 4800,   furtoAno: 6200,   acidentesAno: 2100,  atropelamentosAno: 94),
    CityRisk(id: 'nova_iguacu',     stateId: 'RJ', nome: 'Nova Iguaçu',      uf: 'RJ', score: 820, populacao: 820000,   roubosAno: 9200,   furtoAno: 12000,  acidentesAno: 3800,  atropelamentosAno: 164),
    // BA
    CityRisk(id: 'salvador',        stateId: 'BA', nome: 'Salvador',         uf: 'BA', score: 790, populacao: 2900000,  roubosAno: 41000,  furtoAno: 52000,  acidentesAno: 18000, atropelamentosAno: 820, isMetropole: true),
    CityRisk(id: 'feira_santana',   stateId: 'BA', nome: 'Feira de Santana', uf: 'BA', score: 680, populacao: 620000,   roubosAno: 5800,   furtoAno: 7400,   acidentesAno: 2800,  atropelamentosAno: 118),
    // PE
    CityRisk(id: 'recife',          stateId: 'PE', nome: 'Recife',           uf: 'PE', score: 820, populacao: 1650000,  roubosAno: 38000,  furtoAno: 47000,  acidentesAno: 14000, atropelamentosAno: 620, isMetropole: true),
    CityRisk(id: 'caruaru',         stateId: 'PE', nome: 'Caruaru',          uf: 'PE', score: 580, populacao: 370000,   roubosAno: 2800,   furtoAno: 3600,   acidentesAno: 1400,  atropelamentosAno: 62),
    // CE
    CityRisk(id: 'fortaleza',       stateId: 'CE', nome: 'Fortaleza',        uf: 'CE', score: 810, populacao: 2690000,  roubosAno: 44000,  furtoAno: 56000,  acidentesAno: 16000, atropelamentosAno: 720, isMetropole: true),
    // MG
    CityRisk(id: 'belo_horizonte',  stateId: 'MG', nome: 'Belo Horizonte',  uf: 'MG', score: 650, populacao: 2530000,  roubosAno: 28000,  furtoAno: 38000,  acidentesAno: 14000, atropelamentosAno: 620, isMetropole: true),
    CityRisk(id: 'contagem',        stateId: 'MG', nome: 'Contagem',         uf: 'MG', score: 620, populacao: 660000,   roubosAno: 6200,   furtoAno: 8400,   acidentesAno: 3200,  atropelamentosAno: 138),
    // PR
    CityRisk(id: 'curitiba',        stateId: 'PR', nome: 'Curitiba',         uf: 'PR', score: 520, populacao: 1970000,  roubosAno: 14000,  furtoAno: 21000,  acidentesAno: 9800,  atropelamentosAno: 420, isMetropole: true),
    CityRisk(id: 'londrina',        stateId: 'PR', nome: 'Londrina',         uf: 'PR', score: 480, populacao: 570000,   roubosAno: 3800,   furtoAno: 5200,   acidentesAno: 2400,  atropelamentosAno: 104),
    // RS
    CityRisk(id: 'porto_alegre',    stateId: 'RS', nome: 'Porto Alegre',     uf: 'RS', score: 560, populacao: 1490000,  roubosAno: 12000,  furtoAno: 18000,  acidentesAno: 7200,  atropelamentosAno: 314, isMetropole: true),
    // SC
    CityRisk(id: 'florianopolis',   stateId: 'SC', nome: 'Florianópolis',    uf: 'SC', score: 360, populacao: 540000,   roubosAno: 3400,   furtoAno: 4800,   acidentesAno: 2100,  atropelamentosAno: 92),
    // DF
    CityRisk(id: 'brasilia',        stateId: 'DF', nome: 'Brasília',         uf: 'DF', score: 650, populacao: 3100000,  roubosAno: 22000,  furtoAno: 29000,  acidentesAno: 12000, atropelamentosAno: 520, isMetropole: true),
    // GO
    CityRisk(id: 'goiania',         stateId: 'GO', nome: 'Goiânia',          uf: 'GO', score: 600, populacao: 1560000,  roubosAno: 16800,  furtoAno: 22000,  acidentesAno: 8400,  atropelamentosAno: 362, isMetropole: true),
    // ES
    CityRisk(id: 'vitoria',         stateId: 'ES', nome: 'Vitória',          uf: 'ES', score: 560, populacao: 365000,   roubosAno: 3800,   furtoAno: 5200,   acidentesAno: 2100,  atropelamentosAno: 92,  isMetropole: false),
    CityRisk(id: 'serra',           stateId: 'ES', nome: 'Serra',            uf: 'ES', score: 530, populacao: 530000,   roubosAno: 4200,   furtoAno: 5800,   acidentesAno: 2400,  atropelamentosAno: 104, isMetropole: false),
    CityRisk(id: 'vila_velha',      stateId: 'ES', nome: 'Vila Velha',       uf: 'ES', score: 540, populacao: 500000,   roubosAno: 3900,   furtoAno: 5400,   acidentesAno: 2200,  atropelamentosAno: 96,  isMetropole: false),
    CityRisk(id: 'cariacica',       stateId: 'ES', nome: 'Cariacica',        uf: 'ES', score: 590, populacao: 380000,   roubosAno: 3400,   furtoAno: 4600,   acidentesAno: 1900,  atropelamentosAno: 82,  isMetropole: false),
    CityRisk(id: 'guarapari',       stateId: 'ES', nome: 'Guarapari',        uf: 'ES', score: 320, populacao: 130000,   roubosAno: 680,    furtoAno: 940,    acidentesAno: 420,   atropelamentosAno: 18,  isMetropole: false),
    // AM
    CityRisk(id: 'manaus',          stateId: 'AM', nome: 'Manaus',           uf: 'AM', score: 720, populacao: 2220000,  roubosAno: 12000,  furtoAno: 16000,  acidentesAno: 7200,  atropelamentosAno: 312, isMetropole: true),
    // AL
    CityRisk(id: 'maceio',          stateId: 'AL', nome: 'Maceió',           uf: 'AL', score: 850, populacao: 1040000,  roubosAno: 9800,   furtoAno: 12400,  acidentesAno: 4200,  atropelamentosAno: 182, isMetropole: true),
  ];

  // ── BAIRROS — ES detalhado + demais capitais ──────────────────────────────
  static const List<DistrictRisk> districts = [
    // Vitória/ES
    DistrictRisk(id: 'camburi',       cityId: 'vitoria',     nome: 'Jardim Camburi',  cidade: 'Vitória',   uf: 'ES', score: 180, robberyScore: 150, theftScore: 140, accidentScore: 200, weatherScore: 120, hasCamera: true,  hasPoliciamento: true),
    DistrictRisk(id: 'praia_canto',   cityId: 'vitoria',     nome: 'Praia do Canto',  cidade: 'Vitória',   uf: 'ES', score: 200, robberyScore: 180, theftScore: 160, accidentScore: 220, weatherScore: 140, hasCamera: true,  hasPoliciamento: true),
    DistrictRisk(id: 'enseada',       cityId: 'vitoria',     nome: 'Enseada do Suá',  cidade: 'Vitória',   uf: 'ES', score: 210, robberyScore: 190, theftScore: 170, accidentScore: 230, weatherScore: 130, hasCamera: true),
    DistrictRisk(id: 'barro_verm',    cityId: 'vitoria',     nome: 'Barro Vermelho',  cidade: 'Vitória',   uf: 'ES', score: 280, robberyScore: 260, theftScore: 240, accidentScore: 310, weatherScore: 200),
    DistrictRisk(id: 'centro_vit',    cityId: 'vitoria',     nome: 'Centro',          cidade: 'Vitória',   uf: 'ES', score: 480, robberyScore: 520, theftScore: 480, accidentScore: 440, weatherScore: 360, hasCamera: true),
    DistrictRisk(id: 'sao_pedro',     cityId: 'vitoria',     nome: 'São Pedro',       cidade: 'Vitória',   uf: 'ES', score: 870, robberyScore: 920, theftScore: 880, accidentScore: 780, weatherScore: 840, isPeriferica: true),
    DistrictRisk(id: 'consolacao',    cityId: 'vitoria',     nome: 'Consolação',      cidade: 'Vitória',   uf: 'ES', score: 790, robberyScore: 820, theftScore: 780, accidentScore: 720, weatherScore: 810, isPeriferica: true),
    DistrictRisk(id: 'ilha_caieiras', cityId: 'vitoria',     nome: 'Ilha das Caieiras',cidade: 'Vitória',  uf: 'ES', score: 760, robberyScore: 780, theftScore: 740, accidentScore: 700, weatherScore: 820, isPeriferica: true),
    // Serra/ES
    DistrictRisk(id: 'laranjeiras',   cityId: 'serra',       nome: 'Laranjeiras',     cidade: 'Serra',     uf: 'ES', score: 120, robberyScore: 100, theftScore: 110, accidentScore: 140, weatherScore: 90,  hasCamera: true, hasPoliciamento: true),
    DistrictRisk(id: 'nova_almeida',  cityId: 'serra',       nome: 'Nova Almeida',    cidade: 'Serra',     uf: 'ES', score: 150, robberyScore: 130, theftScore: 140, accidentScore: 170, weatherScore: 120),
    DistrictRisk(id: 'jd_limoeiro',   cityId: 'serra',       nome: 'Jardim Limoeiro', cidade: 'Serra',     uf: 'ES', score: 280, robberyScore: 260, theftScore: 250, accidentScore: 310, weatherScore: 200),
    DistrictRisk(id: 'serra_sede',    cityId: 'serra',       nome: 'Serra Sede',      cidade: 'Serra',     uf: 'ES', score: 320, robberyScore: 300, theftScore: 290, accidentScore: 350, weatherScore: 240),
    DistrictRisk(id: 'carapina',      cityId: 'serra',       nome: 'Carapina',        cidade: 'Serra',     uf: 'ES', score: 550, robberyScore: 580, theftScore: 560, accidentScore: 510, weatherScore: 420),
    DistrictRisk(id: 'andre_carloni', cityId: 'serra',       nome: 'André Carloni',   cidade: 'Serra',     uf: 'ES', score: 820, robberyScore: 860, theftScore: 820, accidentScore: 760, weatherScore: 780, isPeriferica: true),
    DistrictRisk(id: 'feu_rosa',      cityId: 'serra',       nome: 'Feu Rosa',        cidade: 'Serra',     uf: 'ES', score: 900, robberyScore: 940, theftScore: 900, accidentScore: 840, weatherScore: 860, isPeriferica: true),
    // Vila Velha/ES
    DistrictRisk(id: 'itaparica',     cityId: 'vila_velha',  nome: 'Itaparica',       cidade: 'Vila Velha',uf: 'ES', score: 170, robberyScore: 150, theftScore: 160, accidentScore: 190, weatherScore: 130, hasCamera: true),
    DistrictRisk(id: 'coqueiral',     cityId: 'vila_velha',  nome: 'Coqueiral',       cidade: 'Vila Velha',uf: 'ES', score: 190, robberyScore: 170, theftScore: 180, accidentScore: 210, weatherScore: 150),
    DistrictRisk(id: 'gloria',        cityId: 'vila_velha',  nome: 'Glória',          cidade: 'Vila Velha',uf: 'ES', score: 260, robberyScore: 240, theftScore: 230, accidentScore: 290, weatherScore: 190),
    DistrictRisk(id: 'vv_centro',     cityId: 'vila_velha',  nome: 'Centro',          cidade: 'Vila Velha',uf: 'ES', score: 450, robberyScore: 480, theftScore: 440, accidentScore: 410, weatherScore: 340),
    DistrictRisk(id: 'paul',          cityId: 'vila_velha',  nome: 'Paul',            cidade: 'Vila Velha',uf: 'ES', score: 760, robberyScore: 800, theftScore: 760, accidentScore: 700, weatherScore: 720, isPeriferica: true),
    // Cariacica/ES
    DistrictRisk(id: 'campo_grande',  cityId: 'cariacica',   nome: 'Campo Grande',    cidade: 'Cariacica', uf: 'ES', score: 520, robberyScore: 550, theftScore: 530, accidentScore: 480, weatherScore: 440),
    DistrictRisk(id: 'alto_laje',     cityId: 'cariacica',   nome: 'Alto Laje',       cidade: 'Cariacica', uf: 'ES', score: 760, robberyScore: 790, theftScore: 760, accidentScore: 700, weatherScore: 730, isPeriferica: true),
    DistrictRisk(id: 'porto_santana', cityId: 'cariacica',   nome: 'Porto de Santana',cidade: 'Cariacica', uf: 'ES', score: 970, robberyScore: 980, theftScore: 960, accidentScore: 920, weatherScore: 940, isPeriferica: true),
    // São Paulo (alguns bairros representativos)
    DistrictRisk(id: 'sp_jardins',    cityId: 'sao_paulo',   nome: 'Jardins',         cidade: 'São Paulo', uf: 'SP', score: 310, robberyScore: 380, theftScore: 420, accidentScore: 240, weatherScore: 200, hasCamera: true, hasPoliciamento: true),
    DistrictRisk(id: 'sp_mooca',      cityId: 'sao_paulo',   nome: 'Mooca',           cidade: 'São Paulo', uf: 'SP', score: 440, robberyScore: 480, theftScore: 460, accidentScore: 400, weatherScore: 310),
    DistrictRisk(id: 'sp_capao',      cityId: 'sao_paulo',   nome: 'Capão Redondo',   cidade: 'São Paulo', uf: 'SP', score: 820, robberyScore: 860, theftScore: 840, accidentScore: 760, weatherScore: 700, isPeriferica: true),
    DistrictRisk(id: 'sp_itaquera',   cityId: 'sao_paulo',   nome: 'Itaquera',        cidade: 'São Paulo', uf: 'SP', score: 720, robberyScore: 760, theftScore: 740, accidentScore: 660, weatherScore: 580),
    DistrictRisk(id: 'sp_pinheiros',  cityId: 'sao_paulo',   nome: 'Pinheiros',       cidade: 'São Paulo', uf: 'SP', score: 360, robberyScore: 420, theftScore: 400, accidentScore: 300, weatherScore: 240, hasCamera: true),
    // Rio de Janeiro (alguns bairros)
    DistrictRisk(id: 'rj_ipanema',    cityId: 'rio_janeiro', nome: 'Ipanema',         cidade: 'Rio de Janeiro', uf: 'RJ', score: 380, robberyScore: 460, theftScore: 440, accidentScore: 280, weatherScore: 240, hasCamera: true),
    DistrictRisk(id: 'rj_copacabana', cityId: 'rio_janeiro', nome: 'Copacabana',      cidade: 'Rio de Janeiro', uf: 'RJ', score: 520, robberyScore: 600, theftScore: 580, accidentScore: 420, weatherScore: 300, hasCamera: true),
    DistrictRisk(id: 'rj_complexo_al',cityId: 'rio_janeiro', nome: 'Complexo do Alemão',cidade: 'Rio de Janeiro',uf: 'RJ',score: 960, robberyScore: 980, theftScore: 960, accidentScore: 900, weatherScore: 860, isPeriferica: true),
    DistrictRisk(id: 'rj_barra',      cityId: 'rio_janeiro', nome: 'Barra da Tijuca', cidade: 'Rio de Janeiro', uf: 'RJ', score: 290, robberyScore: 340, theftScore: 320, accidentScore: 260, weatherScore: 200, hasCamera: true),
    // Salvador
    DistrictRisk(id: 'ssa_barra',     cityId: 'salvador',    nome: 'Barra',           cidade: 'Salvador',  uf: 'BA', score: 340, robberyScore: 400, theftScore: 380, accidentScore: 280, weatherScore: 220, hasCamera: true),
    DistrictRisk(id: 'ssa_cabula',    cityId: 'salvador',    nome: 'Cabula',          cidade: 'Salvador',  uf: 'BA', score: 680, robberyScore: 720, theftScore: 700, accidentScore: 620, weatherScore: 560),
    DistrictRisk(id: 'ssa_sussuarana',cityId: 'salvador',    nome: 'Sussuarana',      cidade: 'Salvador',  uf: 'BA', score: 820, robberyScore: 860, theftScore: 840, accidentScore: 760, weatherScore: 700, isPeriferica: true),
    // Recife
    DistrictRisk(id: 'rec_boa_viagem',cityId: 'recife',      nome: 'Boa Viagem',      cidade: 'Recife',    uf: 'PE', score: 380, robberyScore: 440, theftScore: 420, accidentScore: 300, weatherScore: 240, hasCamera: true),
    DistrictRisk(id: 'rec_ibura',     cityId: 'recife',      nome: 'Ibura',           cidade: 'Recife',    uf: 'PE', score: 820, robberyScore: 860, theftScore: 840, accidentScore: 760, weatherScore: 680, isPeriferica: true),
    // Fortaleza
    DistrictRisk(id: 'for_meireles',  cityId: 'fortaleza',   nome: 'Meireles',        cidade: 'Fortaleza', uf: 'CE', score: 310, robberyScore: 380, theftScore: 360, accidentScore: 260, weatherScore: 200, hasCamera: true),
    DistrictRisk(id: 'for_mondubim',  cityId: 'fortaleza',   nome: 'Mondubim',        cidade: 'Fortaleza', uf: 'CE', score: 840, robberyScore: 880, theftScore: 860, accidentScore: 780, weatherScore: 700, isPeriferica: true),
    // Maceió
    DistrictRisk(id: 'mac_pajucara',  cityId: 'maceio',      nome: 'Pajuçara',        cidade: 'Maceió',    uf: 'AL', score: 520, robberyScore: 580, theftScore: 560, accidentScore: 460, weatherScore: 380),
    DistrictRisk(id: 'mac_tabuleiro', cityId: 'maceio',      nome: 'Tabuleiro',       cidade: 'Maceió',    uf: 'AL', score: 880, robberyScore: 920, theftScore: 900, accidentScore: 820, weatherScore: 760, isPeriferica: true),
  ];

  // ── RUAS — ES detalhado ───────────────────────────────────────────────────
  static const List<StreetRisk> streets = [
    // Serra/ES — Rotas principais
    StreetRisk(id: 'str_001', districtId: 'laranjeiras',   nome: 'Av. Norte-Sul',              bairro: 'Laranjeiras', cidade: 'Serra', uf: 'ES', score: 150, robberyScore: 130, accidentScore: 180, speedLimit: 60, avgSpeed: 48, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 4),
    StreetRisk(id: 'str_002', districtId: 'serra_sede',    nome: 'Rua Coronel Borges',         bairro: 'Serra Sede',  cidade: 'Serra', uf: 'ES', score: 200, robberyScore: 190, accidentScore: 220, speedLimit: 40, avgSpeed: 28, hasLighting: true,  hasCamera: false, incidentesUltimos12m: 6),
    StreetRisk(id: 'str_003', districtId: 'carapina',      nome: 'BR-101 km 270',              bairro: 'Carapina',    cidade: 'Serra', uf: 'ES', score: 380, robberyScore: 400, accidentScore: 360, speedLimit: 100,avgSpeed: 82, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 18),
    StreetRisk(id: 'str_004', districtId: 'carapina',      nome: 'BR-101 km 265',              bairro: 'Carapina',    cidade: 'Serra', uf: 'ES', score: 520, robberyScore: 560, accidentScore: 480, speedLimit: 100,avgSpeed: 78, hasLighting: false, hasCamera: false, incidentesUltimos12m: 28),
    StreetRisk(id: 'str_005', districtId: 'andre_carloni', nome: 'BR-101 — André Carloni',     bairro: 'André Carloni',cidade: 'Serra',uf: 'ES', score: 820, robberyScore: 860, accidentScore: 780, speedLimit: 100,avgSpeed: 62, hasLighting: false, hasCamera: false, incidentesUltimos12m: 48),
    StreetRisk(id: 'str_006', districtId: 'feu_rosa',      nome: 'Acesso Feu Rosa',            bairro: 'Feu Rosa',    cidade: 'Serra', uf: 'ES', score: 900, robberyScore: 940, accidentScore: 840, speedLimit: 40, avgSpeed: 24, hasLighting: false, hasCamera: false, incidentesUltimos12m: 62),
    // Vitória/ES
    StreetRisk(id: 'str_007', districtId: 'centro_vit',    nome: 'Av. Jerônimo Monteiro',      bairro: 'Centro',      cidade: 'Vitória',uf: 'ES', score: 520, robberyScore: 560, accidentScore: 480, speedLimit: 40, avgSpeed: 20, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 24),
    StreetRisk(id: 'str_008', districtId: 'centro_vit',    nome: 'Av. Marechal Mascarenhas',   bairro: 'Centro',      cidade: 'Vitória',uf: 'ES', score: 480, robberyScore: 510, accidentScore: 440, speedLimit: 60, avgSpeed: 35, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 20),
    StreetRisk(id: 'str_009', districtId: 'camburi',       nome: 'Av. Dante Michelini',        bairro: 'Camburi',     cidade: 'Vitória',uf: 'ES', score: 160, robberyScore: 140, accidentScore: 190, speedLimit: 60, avgSpeed: 52, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 5),
    StreetRisk(id: 'str_010', districtId: 'enseada',       nome: 'Av. Hugo Musso',             bairro: 'Enseada',     cidade: 'Vitória',uf: 'ES', score: 190, robberyScore: 170, accidentScore: 210, speedLimit: 60, avgSpeed: 48, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 6),
    StreetRisk(id: 'str_011', districtId: 'sao_pedro',     nome: 'Acesso São Pedro',           bairro: 'São Pedro',   cidade: 'Vitória',uf: 'ES', score: 880, robberyScore: 920, accidentScore: 820, speedLimit: 40, avgSpeed: 22, hasLighting: false, hasCamera: false, incidentesUltimos12m: 58),
    // Contorno
    StreetRisk(id: 'str_012', districtId: 'barro_verm',    nome: 'Contorno — Bento Ferreira',  bairro: 'Bento Ferreira',cidade: 'Vitória',uf: 'ES', score: 540, robberyScore: 580, accidentScore: 500, speedLimit: 60, avgSpeed: 38, hasLighting: true,  hasCamera: false, incidentesUltimos12m: 22),
    // Cariacica/ES
    StreetRisk(id: 'str_013', districtId: 'porto_santana', nome: 'Av. Principal Porto Santana',bairro: 'Porto Santana',cidade: 'Cariacica',uf: 'ES', score: 970, robberyScore: 980, accidentScore: 940, speedLimit: 40, avgSpeed: 18, hasLighting: false, hasCamera: false, incidentesUltimos12m: 74),
    StreetRisk(id: 'str_014', districtId: 'campo_grande',  nome: 'BR-262 — Campo Grande',      bairro: 'Campo Grande',cidade: 'Cariacica',uf: 'ES', score: 520, robberyScore: 550, accidentScore: 490, speedLimit: 80, avgSpeed: 58, hasLighting: true,  hasCamera: false, incidentesUltimos12m: 24),
    // Vila Velha/ES
    StreetRisk(id: 'str_015', districtId: 'itaparica',     nome: 'Av. Carlos Lindenberg',      bairro: 'Itaparica',   cidade: 'Vila Velha',uf: 'ES', score: 180, robberyScore: 160, accidentScore: 200, speedLimit: 60, avgSpeed: 50, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 5),
    StreetRisk(id: 'str_016', districtId: 'paul',          nome: 'Rua São Paulo — Paul',        bairro: 'Paul',        cidade: 'Vila Velha',uf: 'ES', score: 780, robberyScore: 820, accidentScore: 720, speedLimit: 40, avgSpeed: 24, hasLighting: false, hasCamera: false, incidentesUltimos12m: 42),
    // Terceira Ponte
    StreetRisk(id: 'str_017', districtId: 'enseada',       nome: 'Terceira Ponte',             bairro: 'Enseada',     cidade: 'Vitória',uf: 'ES', score: 240, robberyScore: 210, accidentScore: 280, speedLimit: 80, avgSpeed: 74, hasLighting: true,  hasCamera: true,  incidentesUltimos12m: 8),
    StreetRisk(id: 'str_018', districtId: 'nova_almeida',  nome: 'ES-010 — Orla',              bairro: 'Nova Almeida',cidade: 'Serra', uf: 'ES', score: 140, robberyScore: 120, accidentScore: 160, speedLimit: 60, avgSpeed: 55, hasLighting: true,  hasCamera: false, incidentesUltimos12m: 3),
  ];

  // ── ROBBERY RECORDS (robbery_score) ──────────────────────────────────────
  static const List<RobberyRecord> robberyRecords = [
    RobberyRecord(cidade: 'Serra',     bairro: 'Feu Rosa',       rua: 'Acesso Feu Rosa',      indiceAnual: 124, score: 900, lat: -20.148, lng: -40.212),
    RobberyRecord(cidade: 'Serra',     bairro: 'André Carloni',  rua: 'BR-101 André Carloni', indiceAnual: 96,  score: 820, lat: -20.181, lng: -40.245),
    RobberyRecord(cidade: 'Cariacica', bairro: 'Porto Santana',  rua: 'Av. Principal',        indiceAnual: 148, score: 970, lat: -20.260, lng: -40.398),
    RobberyRecord(cidade: 'Vitória',   bairro: 'São Pedro',      rua: 'Acesso São Pedro',     indiceAnual: 116, score: 880, lat: -20.288, lng: -40.334),
    RobberyRecord(cidade: 'Vitória',   bairro: 'Centro',         rua: 'Av. Jerônimo Monteiro',indiceAnual: 48,  score: 520, lat: -20.319, lng: -40.338),
    RobberyRecord(cidade: 'Serra',     bairro: 'Carapina',       rua: 'BR-101 km 265',        indiceAnual: 56,  score: 520, lat: -20.199, lng: -40.269),
    RobberyRecord(cidade: 'Vila Velha',bairro: 'Paul',           rua: 'Rua São Paulo',        indiceAnual: 84,  score: 780, lat: -20.355, lng: -40.305),
    RobberyRecord(cidade: 'Vitória',   bairro: 'Consolação',     rua: 'Rua Consolação',       indiceAnual: 72,  score: 760, lat: -20.298, lng: -40.347),
  ];

  // ── ACCIDENT RECORDS (accident_score) ────────────────────────────────────
  static const List<AccidentRecord> accidentRecords = [
    AccidentRecord(cidade: 'Serra',     local: 'BR-101 km 265 — Carapina',       batidas: 48,  atropelamentos: 8,  perdaTotalVeiculos: 12, score: 520),
    AccidentRecord(cidade: 'Serra',     local: 'BR-101 km 270 — Serra Sede',     batidas: 32,  atropelamentos: 4,  perdaTotalVeiculos: 8,  score: 380),
    AccidentRecord(cidade: 'Vitória',   local: 'Contorno — Bento Ferreira',      batidas: 36,  atropelamentos: 12, perdaTotalVeiculos: 6,  score: 480),
    AccidentRecord(cidade: 'Vitória',   local: 'Av. Jerônimo Monteiro — Centro', batidas: 24,  atropelamentos: 18, perdaTotalVeiculos: 4,  score: 460),
    AccidentRecord(cidade: 'Cariacica', local: 'BR-262 — Campo Grande',          batidas: 42,  atropelamentos: 6,  perdaTotalVeiculos: 10, score: 500),
    AccidentRecord(cidade: 'São Paulo', local: 'Marginal Tietê — SP',            batidas: 840, atropelamentos: 42, perdaTotalVeiculos: 120,score: 780),
    AccidentRecord(cidade: 'Rio de Janeiro', local: 'Linha Amarela — RJ',        batidas: 620, atropelamentos: 38, perdaTotalVeiculos: 96, score: 720),
  ];

  // ── WEATHER RISK RECORDS (weather_score) ─────────────────────────────────
  static const List<WeatherRiskRecord> weatherRecords = [
    WeatherRiskRecord(cidade: 'Recife',         uf: 'PE', enchentesAno: 12, alagamentosAno: 48, deslizamentosAno: 8,  chuvaExtremaAno: 28, score: 780),
    WeatherRiskRecord(cidade: 'Salvador',       uf: 'BA', enchentesAno: 8,  alagamentosAno: 36, deslizamentosAno: 12, chuvaExtremaAno: 22, score: 720),
    WeatherRiskRecord(cidade: 'São Paulo',      uf: 'SP', enchentesAno: 18, alagamentosAno: 124,deslizamentosAno: 4,  chuvaExtremaAno: 42, score: 840),
    WeatherRiskRecord(cidade: 'Rio de Janeiro', uf: 'RJ', enchentesAno: 14, alagamentosAno: 82, deslizamentosAno: 18, chuvaExtremaAno: 38, score: 860),
    WeatherRiskRecord(cidade: 'Manaus',         uf: 'AM', enchentesAno: 6,  alagamentosAno: 28, deslizamentosAno: 2,  chuvaExtremaAno: 68, score: 640),
    WeatherRiskRecord(cidade: 'Vitória',        uf: 'ES', enchentesAno: 4,  alagamentosAno: 18, deslizamentosAno: 2,  chuvaExtremaAno: 14, score: 380),
    WeatherRiskRecord(cidade: 'Serra',          uf: 'ES', enchentesAno: 3,  alagamentosAno: 12, deslizamentosAno: 1,  chuvaExtremaAno: 12, score: 320),
    WeatherRiskRecord(cidade: 'Guarapari',      uf: 'ES', enchentesAno: 2,  alagamentosAno: 6,  deslizamentosAno: 0,  chuvaExtremaAno: 8,  score: 180),
    WeatherRiskRecord(cidade: 'Florianópolis',  uf: 'SC', enchentesAno: 4,  alagamentosAno: 16, deslizamentosAno: 8,  chuvaExtremaAno: 18, score: 420),
    WeatherRiskRecord(cidade: 'Porto Alegre',   uf: 'RS', enchentesAno: 8,  alagamentosAno: 42, deslizamentosAno: 4,  chuvaExtremaAno: 24, score: 580),
  ];

  // ── VEHICLE RISK RECORDS (vehicle_risk) ──────────────────────────────────
  static const List<VehicleRiskRecord> vehicleRiskTable = [
    VehicleRiskRecord(modelo: 'Onix',     marca: 'Chevrolet', robberyScore: 900, theftScore: 820, collisionScore: 450, fipeMediaMil: 75,  roubosAno: 48200),
    VehicleRiskRecord(modelo: 'HB20',     marca: 'Hyundai',   robberyScore: 850, theftScore: 780, collisionScore: 420, fipeMediaMil: 72,  roubosAno: 38400),
    VehicleRiskRecord(modelo: 'Argo',     marca: 'Fiat',      robberyScore: 700, theftScore: 640, collisionScore: 400, fipeMediaMil: 68,  roubosAno: 28600),
    VehicleRiskRecord(modelo: 'Polo',     marca: 'Volkswagen',robberyScore: 620, theftScore: 560, collisionScore: 380, fipeMediaMil: 84,  roubosAno: 22400),
    VehicleRiskRecord(modelo: 'T-Cross',  marca: 'Volkswagen',robberyScore: 580, theftScore: 520, collisionScore: 440, fipeMediaMil: 148, roubosAno: 18200),
    VehicleRiskRecord(modelo: 'Corolla',  marca: 'Toyota',    robberyScore: 500, theftScore: 440, collisionScore: 420, fipeMediaMil: 132, roubosAno: 12800),
    VehicleRiskRecord(modelo: 'Civic',    marca: 'Honda',     robberyScore: 520, theftScore: 460, collisionScore: 390, fipeMediaMil: 128, roubosAno: 14200),
    VehicleRiskRecord(modelo: 'Hilux',    marca: 'Toyota',    robberyScore: 720, theftScore: 660, collisionScore: 550, fipeMediaMil: 248, roubosAno: 16800),
    VehicleRiskRecord(modelo: 'Ranger',   marca: 'Ford',      robberyScore: 680, theftScore: 620, collisionScore: 530, fipeMediaMil: 228, roubosAno: 14400),
    VehicleRiskRecord(modelo: 'Compass',  marca: 'Jeep',      robberyScore: 450, theftScore: 400, collisionScore: 500, fipeMediaMil: 178, roubosAno: 8400),
    VehicleRiskRecord(modelo: 'Creta',    marca: 'Hyundai',   robberyScore: 420, theftScore: 380, collisionScore: 480, fipeMediaMil: 132, roubosAno: 6800),
    VehicleRiskRecord(modelo: 'BYD Atto 2',marca: 'BYD',     robberyScore: 250, theftScore: 220, collisionScore: 350, fipeMediaMil: 130, roubosAno: 820),
    VehicleRiskRecord(modelo: 'Dolphin',  marca: 'BYD',       robberyScore: 230, theftScore: 200, collisionScore: 330, fipeMediaMil: 110, roubosAno: 640),
    VehicleRiskRecord(modelo: 'Model 3',  marca: 'Tesla',     robberyScore: 200, theftScore: 180, collisionScore: 300, fipeMediaMil: 380, roubosAno: 280),
    VehicleRiskRecord(modelo: 'Camaro',   marca: 'Chevrolet', robberyScore: 380, theftScore: 320, collisionScore: 850, fipeMediaMil: 420, roubosAno: 480),
    VehicleRiskRecord(modelo: 'CB 500',   marca: 'Honda',     robberyScore: 650, theftScore: 680, collisionScore: 900, fipeMediaMil: 28,  roubosAno: 22000),
    VehicleRiskRecord(modelo: 'MT-07',    marca: 'Yamaha',    robberyScore: 700, theftScore: 720, collisionScore: 950, fipeMediaMil: 32,  roubosAno: 18000),
    VehicleRiskRecord(modelo: 'Kwid',     marca: 'Renault',   robberyScore: 480, theftScore: 420, collisionScore: 360, fipeMediaMil: 58,  roubosAno: 9800),
    VehicleRiskRecord(modelo: 'Cronos',   marca: 'Fiat',      robberyScore: 540, theftScore: 480, collisionScore: 380, fipeMediaMil: 72,  roubosAno: 12400),
    VehicleRiskRecord(modelo: 'Mobi',     marca: 'Fiat',      robberyScore: 560, theftScore: 500, collisionScore: 320, fipeMediaMil: 48,  roubosAno: 14200),
  ];

  // ── LOOKUP HELPERS ────────────────────────────────────────────────────────

  static StateRisk? stateByUf(String uf) {
    try {
      return states.firstWhere((s) => s.uf == uf.toUpperCase());
    } catch (_) { return null; }
  }

  static List<CityRisk> citiesByState(String stateId) =>
      cities.where((c) => c.stateId == stateId).toList();

  static CityRisk? cityByName(String name, {String? uf}) {
    final lc = name.toLowerCase();
    try {
      return cities.firstWhere((c) =>
          c.nome.toLowerCase().contains(lc) && (uf == null || c.uf == uf));
    } catch (_) { return null; }
  }

  static List<DistrictRisk> districtsByCity(String cityId) =>
      districts.where((d) => d.cityId == cityId).toList();

  static DistrictRisk? districtByName(String name, {String? cityId}) {
    final lc = name.toLowerCase();
    try {
      return districts.firstWhere((d) =>
          d.nome.toLowerCase().contains(lc) && (cityId == null || d.cityId == cityId));
    } catch (_) { return null; }
  }

  static List<StreetRisk> streetsByDistrict(String districtId) =>
      streets.where((s) => s.districtId == districtId).toList();

  static StreetRisk? streetByName(String name, {String? cityName}) {
    final lc = name.toLowerCase();
    try {
      return streets.firstWhere((s) {
        final matches = s.nome.toLowerCase().contains(lc) ||
            lc.contains(s.nome.toLowerCase().split(' ').last.toLowerCase());
        final cityMatch = cityName == null || s.cidade.toLowerCase().contains(cityName.toLowerCase());
        return matches && cityMatch;
      });
    } catch (_) { return null; }
  }

  static VehicleRiskRecord? vehicleByModel(String model) {
    final lc = model.toLowerCase();
    try {
      return vehicleRiskTable.firstWhere((v) =>
          lc.contains(v.modelo.toLowerCase()) ||
          v.modelo.toLowerCase().contains(lc.split(' ').last));
    } catch (_) { return null; }
  }

  /// Score médio de uma rota entre origem e destino
  static int routeScore(String fromCity, String toCity, List<String> viaStreets) {
    final scores = <int>[];
    for (final street in viaStreets) {
      final s = streetByName(street, cityName: fromCity) ?? streetByName(street);
      if (s != null) scores.add(s.score);
    }
    if (scores.isEmpty) {
      // fallback: score médio das cidades
      final from = cityByName(fromCity);
      final to   = cityByName(toCity);
      if (from != null && to != null) return ((from.score + to.score) / 2).round();
      return 350;
    }
    return scores.reduce((a, b) => a + b) ~/ scores.length;
  }

  /// Cidades mais críticas (top N por score)
  static List<CityRisk> get topCriticalCities {
    final sorted = [...cities]..sort((a, b) => b.score.compareTo(a.score));
    return sorted.take(10).toList();
  }

  /// Cidades mais seguras (top N por score inverso)
  static List<CityRisk> get topSafestCities {
    final sorted = [...cities]..sort((a, b) => a.score.compareTo(b.score));
    return sorted.take(10).toList();
  }

  /// Veículos mais roubados
  static List<VehicleRiskRecord> get topStolenVehicles {
    final sorted = [...vehicleRiskTable]..sort((a, b) => b.roubosAno.compareTo(a.roubosAno));
    return sorted.take(8).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFE SCORE ENGINE — Score de viagem 0–100
// ─────────────────────────────────────────────────────────────────────────────

class SafeScoreInput {
  final String originCity;
  final String destinationCity;
  final List<String> viaStreets;
  final String vehicleModel;
  final int hour;
  final int driverAge;
  final int driverHistoryScore;
  final int weatherScore;    // 0–1000 (clima atual)
  final String planType;     // economico, equilibrado, premium

  const SafeScoreInput({
    required this.originCity,
    required this.destinationCity,
    this.viaStreets = const [],
    this.vehicleModel = 'Onix',
    this.hour = 14,
    this.driverAge = 35,
    this.driverHistoryScore = 800,
    this.weatherScore = 100,
    this.planType = 'equilibrado',
  });
}

class SafeScoreOutput {
  // Score da viagem: 0–100 (100 = máxima segurança)
  final int tripScore;
  final SafeTripScore safeTripScore;

  // Scores dos componentes (0–1000)
  final int routeRiskScore;
  final int vehicleRiskScore;
  final int timeRiskScore;
  final int driverRiskScore;
  final int weatherRiskScore;

  // Preço calculado
  final double price;
  final double priceMultiplier;

  // Probabilidade de sinistro
  final double sinistroProb;

  // Rota alternativa (se houver)
  final RouteRiskProfile? saferRoute;
  final RouteRiskProfile? fasterRoute;

  // Insights
  final List<SafeInsight> insights;

  const SafeScoreOutput({
    required this.tripScore,
    required this.safeTripScore,
    required this.routeRiskScore,
    required this.vehicleRiskScore,
    required this.timeRiskScore,
    required this.driverRiskScore,
    required this.weatherRiskScore,
    required this.price,
    required this.priceMultiplier,
    required this.sinistroProb,
    this.saferRoute,
    this.fasterRoute,
    required this.insights,
  });

  String get priceFormatted =>
      'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';

  String get sinistroFormatted =>
      '${(sinistroProb * 100).toStringAsFixed(1)}%';
}

class SafeInsight {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final SafeScoreClass level;

  const SafeInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.level,
  });
}

class SafeScoreEngine {
  static const double _tarifaBase = 0.15; // R$/km
  static const double _taxaMinima = 1.99;

  static SafeScoreOutput calculate({
    required SafeScoreInput input,
    required double distanceKm,
  }) {
    // ── 1. Score da rota (pelas ruas percorridas) ────────────
    final routeRiskScore = SafeMapDatabase.routeScore(
        input.originCity, input.destinationCity, input.viaStreets);

    // ── 2. Score do veículo ──────────────────────────────────
    final vehicle = SafeMapDatabase.vehicleByModel(input.vehicleModel);
    final vehicleRiskScore = vehicle?.overallScore ?? 450;

    // ── 3. Score do horário ──────────────────────────────────
    final timeWeight = TimeRiskTable.weight(input.hour);
    final timeRiskScore = ((timeWeight - 1.0) / 1.0 * 500).clamp(0, 1000).round();

    // ── 4. Score do motorista (histórico) ───────────────────
    final driverRiskScore = (1000 - input.driverHistoryScore).clamp(0, 1000);

    // ── 5. Score do clima ────────────────────────────────────
    final weatherRiskScore = input.weatherScore;

    // ── Multiplicador ponderado ──────────────────────────────
    final mult =
        (routeRiskScore   / 1000.0) * 0.30 +
        (vehicleRiskScore / 1000.0) * 0.20 +
        (timeWeight - 1.0)          * 0.20 +
        (driverRiskScore  / 1000.0) * 0.15 +
        (weatherRiskScore / 1000.0) * 0.15;

    final priceMultiplier = 1.0 + mult * 2.0;

    // ── Preço ────────────────────────────────────────────────
    final base = distanceKm * _tarifaBase;
    final calc = base * priceMultiplier;
    final price = calc < _taxaMinima ? _taxaMinima : calc;

    // ── Trip Score (0–100 inverso) ───────────────────────────
    final avgRisk = ((routeRiskScore + vehicleRiskScore + timeRiskScore +
        driverRiskScore + weatherRiskScore) / 5.0);
    final tripScore = (100 - (avgRisk / 10.0)).clamp(0, 100).round();

    // ── Probabilidade de sinistro ────────────────────────────
    final sinistroProb = _calcSinistroProb(
        routeRiskScore, vehicleRiskScore, timeRiskScore,
        driverRiskScore, weatherRiskScore);

    // ── Rotas alternativas (mock para ES) ────────────────────
    final routes = _buildRouteProfiles(
        input, distanceKm, priceMultiplier, routeRiskScore, price);

    // ── Insights ─────────────────────────────────────────────
    final insights = _buildInsights(input, routeRiskScore,
        vehicleRiskScore, timeRiskScore, weatherRiskScore);

    return SafeScoreOutput(
      tripScore: tripScore,
      safeTripScore: SafeTripScore(tripScore),
      routeRiskScore: routeRiskScore,
      vehicleRiskScore: vehicleRiskScore,
      timeRiskScore: timeRiskScore,
      driverRiskScore: driverRiskScore,
      weatherRiskScore: weatherRiskScore,
      price: price,
      priceMultiplier: priceMultiplier,
      sinistroProb: sinistroProb,
      saferRoute:  routes.length > 1 ? routes[1] : null,
      fasterRoute: routes.isNotEmpty ? routes[0] : null,
      insights: insights,
    );
  }

  static double _calcSinistroProb(int route, int vehicle, int time,
      int driver, int weather) {
    const base = 0.008;
    final fRoute   = 1.0 + (route   / 1000.0) * 3.0;
    final fVehicle = 1.0 + (vehicle / 1000.0) * 1.5;
    final fTime    = 1.0 + (time    / 1000.0) * 1.2;
    final fDriver  = 1.0 + (driver  / 1000.0) * 1.0;
    final fWeather = 1.0 + (weather / 1000.0) * 0.8;
    return (base * fRoute * fVehicle * fTime * fDriver * fWeather).clamp(0.001, 0.50);
  }

  static List<RouteRiskProfile> _buildRouteProfiles(
      SafeScoreInput input, double km, double mult,
      int baseScore, double basePrice) {
    // Rota mais rápida (BR-101 para ES)
    final fastest = RouteRiskProfile(
      routeId: 'fastest',
      name: 'Rota Rápida',
      from: input.originCity,
      to: input.destinationCity,
      distanceKm: km,
      estimatedMinutes: (km / 60 * 60).round(),
      routeScore: baseScore,
      tripPrice: basePrice,
      isFastestAlternative: true,
      segments: [
        RouteSegmentRisk(name: 'Trecho inicial', score: (baseScore * 0.8).round(), lengthKm: km * 0.3, incidentesAno: 8),
        RouteSegmentRisk(name: 'Trecho principal', score: baseScore, lengthKm: km * 0.5, incidentesAno: 18),
        RouteSegmentRisk(name: 'Trecho final', score: (baseScore * 0.7).round(), lengthKm: km * 0.2, incidentesAno: 5),
      ],
    );

    // Rota mais segura (orla/alternativa)
    final safer = RouteRiskProfile(
      routeId: 'safer',
      name: 'Rota Segura',
      from: input.originCity,
      to: input.destinationCity,
      distanceKm: km * 1.25,
      estimatedMinutes: ((km * 1.25) / 50 * 60).round(),
      routeScore: (baseScore * 0.65).round(),
      tripPrice: basePrice * 1.08,
      isSaferAlternative: true,
      segments: [
        RouteSegmentRisk(name: 'Via Orla', score: (baseScore * 0.4).round(), lengthKm: km * 0.6, incidentesAno: 3),
        RouteSegmentRisk(name: 'Trecho residencial', score: (baseScore * 0.55).round(), lengthKm: km * 0.4, incidentesAno: 4),
      ],
    );

    return [fastest, safer];
  }

  static List<SafeInsight> _buildInsights(SafeScoreInput input,
      int routeScore, int vehicleScore, int timeScore, int weatherScore) {
    final insights = <SafeInsight>[];

    if (routeScore > 600) {
      insights.add(SafeInsight(
        icon: Icons.location_on_rounded,
        color: const Color(0xFFEF4444),
        title: 'Trecho de alto risco',
        body: 'O trajeto passa por áreas com score de risco ${routeScore}. Considere a rota alternativa.',
        level: SafeScoreClass.fromScore(routeScore),
      ));
    }

    if (timeScore > 400) {
      insights.add(SafeInsight(
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFF7C3AED),
        title: 'Horário de risco — ${input.hour}h',
        body: 'Peso horário: ×${TimeRiskTable.weight(input.hour).toStringAsFixed(1)}. Ocorrências aumentam neste horário.',
        level: SafeScoreClass.alto,
      ));
    }

    if (vehicleScore > 600) {
      insights.add(SafeInsight(
        icon: Icons.directions_car_rounded,
        color: const Color(0xFFF97316),
        title: 'Veículo com alto índice de roubo',
        body: '${input.vehicleModel} está entre os modelos mais visados nesta região.',
        level: SafeScoreClass.alto,
      ));
    }

    if (weatherScore > 500) {
      insights.add(SafeInsight(
        icon: Icons.thunderstorm_rounded,
        color: const Color(0xFF3B82F6),
        title: 'Condição climática adversa',
        body: 'Risco climático elevado. Probabilidade de alagamentos ou baixa visibilidade.',
        level: SafeScoreClass.medio,
      ));
    }

    if (routeScore <= 300 && timeScore <= 200 && vehicleScore <= 400) {
      insights.add(SafeInsight(
        icon: Icons.verified_rounded,
        color: const Color(0xFF22C55E),
        title: 'Viagem com baixo risco',
        body: 'Todos os indicadores estão em níveis seguros para esta viagem.',
        level: SafeScoreClass.seguro,
      ));
    }

    return insights;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RISK AI — Motor de IA para análise e predição
// ─────────────────────────────────────────────────────────────────────────────

class RiskAIPrediction {
  final double sinistroChance;    // 0–1
  final double rouboChance;
  final double furtoChance;
  final double colisaoChance;
  final String riskProfile;       // 'conservador', 'moderado', 'agressivo'
  final List<String> keyFactors;  // fatores mais relevantes
  final String recommendation;
  final int aiConfidence;         // 0–100%

  const RiskAIPrediction({
    required this.sinistroChance,
    required this.rouboChance,
    required this.furtoChance,
    required this.colisaoChance,
    required this.riskProfile,
    required this.keyFactors,
    required this.recommendation,
    required this.aiConfidence,
  });

  String get sinistroLabel => '${(sinistroChance * 100).toStringAsFixed(1)}%';
  String get rouboLabel    => '${(rouboChance    * 100).toStringAsFixed(1)}%';
  String get furtoLabel    => '${(furtoChance    * 100).toStringAsFixed(1)}%';
  String get colisaoLabel  => '${(colisaoChance  * 100).toStringAsFixed(1)}%';

  Color get sinistroColor {
    if (sinistroChance < 0.02) return const Color(0xFF22C55E);
    if (sinistroChance < 0.05) return const Color(0xFFF59E0B);
    if (sinistroChance < 0.12) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }
}

class RiskAI {
  static const String version = 'v1.0.0';
  static const int trainingDataPoints = 10000000; // 10 milhões de rotas

  /// Predição de IA baseada nos scores do SafeMap
  static RiskAIPrediction predict({
    required int driverAge,
    required String vehicleModel,
    required int hour,
    required String cityName,
    required String districtName,
    required int weatherScore,
    required int driverScore,
    required double distanceKm,
  }) {
    // Buscar dados do banco
    final vehicle  = SafeMapDatabase.vehicleByModel(vehicleModel);
    final city     = SafeMapDatabase.cityByName(cityName);
    final district = SafeMapDatabase.districtByName(districtName, cityId: city?.id);

    // Scores base
    final locScore   = district?.score ?? city?.score ?? 400;
    final vehScore   = vehicle?.overallScore ?? 450;
    final timeWeight = TimeRiskTable.weight(hour);
    final ageWeight  = _ageWeight(driverAge);
    final histWeight = 1.0 + ((1000 - driverScore) / 1000.0) * 0.8;

    // Base estatística (por km rodado no Brasil)
    const baseRoubo   = 0.006;
    const baseFurto   = 0.004;
    const baseColisao = 0.010;

    // Fatores para roubo
    final fLocRobo  = 1.0 + (locScore / 1000.0) * 4.0;
    final fVehRobo  = 1.0 + ((vehicle?.robberyScore ?? 500) / 1000.0) * 2.0;
    final fTimeRobo = timeWeight;
    final fDistRobo = 1.0 + (distanceKm / 100.0) * 0.3;

    final pRoubo = (baseRoubo * fLocRobo * fVehRobo * fTimeRobo * fDistRobo * histWeight)
        .clamp(0.001, 0.40);

    // Fatores para furto
    final fVehFurto = 1.0 + ((vehicle?.theftScore ?? 500) / 1000.0) * 1.5;
    final pFurto = (baseFurto * fLocRobo * fVehFurto * histWeight)
        .clamp(0.001, 0.25);

    // Fatores para colisão
    final fVehCol = 1.0 + ((vehicle?.collisionScore ?? 450) / 1000.0) * 1.8;
    final fWeaCol = 1.0 + (weatherScore / 1000.0) * 1.5;
    final fAgeCol = ageWeight;
    final pColisao = (baseColisao * fVehCol * fWeaCol * fAgeCol * fTimeRobo * histWeight)
        .clamp(0.001, 0.35);

    // Sinistro total: P(ao menos 1)
    final pSinistro = 1.0 -
        (1.0 - pRoubo) * (1.0 - pFurto) * (1.0 - pColisao);

    // Perfil
    final profile = pSinistro < 0.03
        ? 'conservador'
        : pSinistro < 0.08
            ? 'moderado'
            : 'agressivo';

    // Key factors
    final factors = <String>[];
    if (locScore   > 600) factors.add('Região de alto risco (score $locScore)');
    if (vehScore   > 600) factors.add('Veículo visado: $vehicleModel');
    if (timeWeight > 1.5) factors.add('Horário crítico: ${hour}h');
    if (driverAge  <= 24) factors.add('Condutor jovem: $driverAge anos');
    if (weatherScore > 500) factors.add('Clima adverso');
    if (driverScore < 600)  factors.add('Histórico de risco: score $driverScore');
    if (factors.isEmpty) factors.add('Todos os indicadores favoráveis');

    // Recomendação
    final rec = pSinistro < 0.03
        ? 'Viagem com baixo risco. Prossiga normalmente.'
        : pSinistro < 0.08
            ? 'Atenção moderada. Mantenha vidros fechados e evite paradas desnecessárias.'
            : pSinistro < 0.15
                ? 'Risco elevado. Considere a rota alternativa e mantenha alerta máximo.'
                : 'Risco crítico. Recomendamos adiar ou usar rota alternativa.';

    // Confiança da IA
    final confidence = 72 + (district != null ? 15 : 0) + (vehicle != null ? 10 : 0);

    return RiskAIPrediction(
      sinistroChance: pSinistro.clamp(0, 0.99),
      rouboChance:    pRoubo,
      furtoChance:    pFurto,
      colisaoChance:  pColisao,
      riskProfile:    profile,
      keyFactors:     factors,
      recommendation: rec,
      aiConfidence:   confidence.clamp(0, 99),
    );
  }

  static double _ageWeight(int age) {
    if (age < 18) return 2.5;
    if (age <= 24) return 1.8;
    if (age <= 35) return 1.3;
    if (age <= 60) return 1.0;
    return 1.4;
  }

  /// Retorna exemplo de predição para demonstração
  static RiskAIPrediction get demoYoungHighRisk => predict(
    driverAge: 22, vehicleModel: 'HB20', hour: 22,
    cityName: 'Serra', districtName: 'André Carloni',
    weatherScore: 300, driverScore: 620, distanceKm: 25,
  );

  static RiskAIPrediction get demoAdultLowRisk => predict(
    driverAge: 42, vehicleModel: 'BYD Atto 2', hour: 14,
    cityName: 'Serra', districtName: 'Laranjeiras',
    weatherScore: 50, driverScore: 920, distanceKm: 20,
  );

  static RiskAIPrediction get demoNight => predict(
    driverAge: 35, vehicleModel: 'Onix', hour: 23,
    cityName: 'Vitória', districtName: 'Centro',
    weatherScore: 200, driverScore: 750, distanceKm: 15,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTOR DE ATUALIZAÇÃO (simulado)
// ─────────────────────────────────────────────────────────────────────────────

enum UpdateFrequency { diaria, semanal, mensal }

class SafeMapUpdateEngine {
  static DateTime lastUpdate = DateTime(2026, 6, 12);
  static String dataSource = 'SENASP + Detran/ES + INMET + Cemaden';

  static Map<String, String> get sources => {
    'Segurança Pública': 'Ministério da Justiça / SENASP',
    'Acidentes':         'Detran/ES + PRF',
    'Clima':             'INMET + Cemaden',
    'Veículos':          'SENATRAN + SINESP',
    'Localização':       'OpenStreetMap + IBGE',
  };

  static Map<String, UpdateFrequency> get updateSchedule => {
    'score_hora':    UpdateFrequency.diaria,
    'score_bairro':  UpdateFrequency.semanal,
    'score_cidade':  UpdateFrequency.semanal,
    'score_estado':  UpdateFrequency.mensal,
    'vehicle_risk':  UpdateFrequency.mensal,
    'weather_score': UpdateFrequency.diaria,
  };

  static String describeFrequency(UpdateFrequency f) {
    switch (f) {
      case UpdateFrequency.diaria:  return 'Atualização diária';
      case UpdateFrequency.semanal: return 'Atualização semanal';
      case UpdateFrequency.mensal:  return 'Atualização mensal';
    }
  }
}

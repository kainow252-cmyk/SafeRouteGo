// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — MOTOR ATUARIAL INTELIGENTE V2
// Arquitetura: ActuarialEngine → PricingEngine → FraudEngine → CommissionEngine
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'risk_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 1 — CEP / REGIÃO
// ─────────────────────────────────────────────────────────────────────────────

class CepRiskData {
  final String cep;
  final String bairro;
  final String cidade;
  final int score; // 0–1000
  final RiskZone zone;

  const CepRiskData({
    required this.cep,
    required this.bairro,
    required this.cidade,
    required this.score,
    required this.zone,
  });

  double get multiplier {
    if (score <= 200) return 1.0;
    if (score <= 400) return 1.25;
    if (score <= 600) return 1.6;
    if (score <= 800) return 2.1;
    return 3.0;
  }

  String get riskLabel {
    if (score <= 200) return 'Muito Baixo';
    if (score <= 400) return 'Baixo';
    if (score <= 600) return 'Médio';
    if (score <= 800) return 'Alto';
    return 'Crítico';
  }
}

// Banco de CEPs do ES — expandível
class CepRiskDatabase {
  static const Map<String, CepRiskData> _data = {
    // Serra — Bairros
    '29166-000': CepRiskData(cep: '29166-000', bairro: 'Laranjeiras',     cidade: 'Serra', score: 120, zone: RiskZone.verde),
    '29161-000': CepRiskData(cep: '29161-000', bairro: 'Nova Almeida',    cidade: 'Serra', score: 150, zone: RiskZone.verde),
    '29164-000': CepRiskData(cep: '29164-000', bairro: 'Jardim Limoeiro', cidade: 'Serra', score: 280, zone: RiskZone.amarela),
    '29170-000': CepRiskData(cep: '29170-000', bairro: 'Serra Sede',      cidade: 'Serra', score: 320, zone: RiskZone.amarela),
    '29168-000': CepRiskData(cep: '29168-000', bairro: 'Carapina',        cidade: 'Serra', score: 550, zone: RiskZone.laranja),
    '29167-000': CepRiskData(cep: '29167-000', bairro: 'André Carloni',   cidade: 'Serra', score: 820, zone: RiskZone.vermelha),
    '29163-000': CepRiskData(cep: '29163-000', bairro: 'Feu Rosa',        cidade: 'Serra', score: 900, zone: RiskZone.critica),
    // Vitória — Bairros
    '29015-000': CepRiskData(cep: '29015-000', bairro: 'Centro Vitória',  cidade: 'Vitória', score: 480, zone: RiskZone.laranja),
    '29055-000': CepRiskData(cep: '29055-000', bairro: 'Jardim Camburi',  cidade: 'Vitória', score: 180, zone: RiskZone.verde),
    '29056-000': CepRiskData(cep: '29056-000', bairro: 'Camburi',         cidade: 'Vitória', score: 160, zone: RiskZone.verde),
    '29065-000': CepRiskData(cep: '29065-000', bairro: 'Barro Vermelho',  cidade: 'Vitória', score: 260, zone: RiskZone.amarela),
    '29053-000': CepRiskData(cep: '29053-000', bairro: 'Enseada do Suá',  cidade: 'Vitória', score: 200, zone: RiskZone.verde),
    '29020-000': CepRiskData(cep: '29020-000', bairro: 'São Pedro',       cidade: 'Vitória', score: 870, zone: RiskZone.critica),
    '29032-000': CepRiskData(cep: '29032-000', bairro: 'Consolação',      cidade: 'Vitória', score: 790, zone: RiskZone.vermelha),
    // Vila Velha
    '29102-000': CepRiskData(cep: '29102-000', bairro: 'Praia de Itaparica', cidade: 'Vila Velha', score: 170, zone: RiskZone.verde),
    '29103-000': CepRiskData(cep: '29103-000', bairro: 'Coqueiral',       cidade: 'Vila Velha', score: 190, zone: RiskZone.verde),
    '29100-000': CepRiskData(cep: '29100-000', bairro: 'VV Centro',       cidade: 'Vila Velha', score: 450, zone: RiskZone.laranja),
    '29105-000': CepRiskData(cep: '29105-000', bairro: 'Paul',            cidade: 'Vila Velha', score: 760, zone: RiskZone.vermelha),
    // Cariacica
    '29150-000': CepRiskData(cep: '29150-000', bairro: 'Campo Grande',    cidade: 'Cariacica', score: 520, zone: RiskZone.laranja),
    '29152-000': CepRiskData(cep: '29152-000', bairro: 'Porto de Santana',cidade: 'Cariacica', score: 970, zone: RiskZone.critica),
  };

  static CepRiskData lookup(String cep) {
    return _data[cep] ?? CepRiskData(
      cep: cep,
      bairro: 'Região não mapeada',
      cidade: 'ES',
      score: 300,
      zone: RiskZone.amarela,
    );
  }

  static List<CepRiskData> get allData => _data.values.toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 2 — RUA
// ─────────────────────────────────────────────────────────────────────────────

class StreetRiskData {
  final String streetName;
  final int score;  // 0–1000

  const StreetRiskData({required this.streetName, required this.score});

  double get multiplier {
    if (score <= 200) return 1.0;
    if (score <= 400) return 1.15;
    if (score <= 600) return 1.35;
    if (score <= 800) return 1.6;
    return 2.0;
  }
}

class StreetRiskDatabase {
  static const List<StreetRiskData> _known = [
    StreetRiskData(streetName: 'BR-101',                       score: 380),
    StreetRiskData(streetName: 'Av. Norte-Sul',                score: 290),
    StreetRiskData(streetName: 'Av. Central',                  score: 450),
    StreetRiskData(streetName: 'Rua Coronel Borges',           score: 200),
    StreetRiskData(streetName: 'Av. Jerônimo Monteiro',        score: 520),
    StreetRiskData(streetName: 'Av. Marechal Mascarenhas',     score: 480),
    StreetRiskData(streetName: 'Contorno',                     score: 540),
    StreetRiskData(streetName: 'André Carloni',                score: 820),
    StreetRiskData(streetName: 'Feu Rosa',                     score: 890),
    StreetRiskData(streetName: 'Porto de Santana',             score: 950),
    StreetRiskData(streetName: 'Praia de Camburi',             score: 120),
    StreetRiskData(streetName: 'Enseada do Suá',               score: 160),
    StreetRiskData(streetName: 'Av. Fernando Ferrari',         score: 200),
  ];

  static StreetRiskData lookup(String street) {
    final lc = street.toLowerCase();
    for (final s in _known) {
      if (lc.contains(s.streetName.toLowerCase())) return s;
    }
    return StreetRiskData(streetName: street, score: 250);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 3 — HORÁRIO (versão detalhada)
// ─────────────────────────────────────────────────────────────────────────────

class HourRiskFactor {
  static double multiplier(int hour) {
    if (hour >= 6  && hour < 12) return 1.0;   // Manhã
    if (hour >= 12 && hour < 18) return 1.1;   // Tarde
    if (hour >= 18 && hour < 22) return 1.4;   // Noite
    if (hour >= 22 || hour < 2 ) return 2.0;   // Altas horas
    return 1.8;                                  // Madrugada 02–06h
  }

  static String label(int hour) {
    if (hour >= 6  && hour < 12) return 'Manhã (06–12h) ×1.0';
    if (hour >= 12 && hour < 18) return 'Tarde (12–18h) ×1.1';
    if (hour >= 18 && hour < 22) return 'Noite (18–22h) ×1.4';
    if (hour >= 22 || hour < 2 ) return 'Alta noite (22–02h) ×2.0';
    return 'Madrugada (02–06h) ×1.8';
  }

  static Color color(int hour) {
    if (hour >= 6  && hour < 12) return const Color(0xFF22C55E);
    if (hour >= 12 && hour < 18) return const Color(0xFFF59E0B);
    if (hour >= 18 && hour < 22) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 5 — VEÍCULO (Score de Roubo + Score de Colisão)
// ─────────────────────────────────────────────────────────────────────────────

enum VehicleCategory { hatch, sedan, suv, pickup, eletrico, esportivo, moto }

class VehicleRiskData {
  final String model;
  final VehicleCategory category;
  final int theftScore;     // 0–1000
  final int collisionScore; // 0–1000

  const VehicleRiskData({
    required this.model,
    required this.category,
    required this.theftScore,
    required this.collisionScore,
  });

  double get theftMultiplier {
    if (theftScore <= 200) return 1.0;
    if (theftScore <= 400) return 1.15;
    if (theftScore <= 600) return 1.35;
    if (theftScore <= 800) return 1.6;
    return 2.0;
  }

  double get collisionMultiplier {
    if (collisionScore <= 200) return 1.0;
    if (collisionScore <= 400) return 1.1;
    if (collisionScore <= 600) return 1.25;
    if (collisionScore <= 800) return 1.45;
    return 1.8;
  }

  double get combinedMultiplier =>
      (theftMultiplier + collisionMultiplier) / 2;

  String get theftLabel {
    if (theftScore <= 200) return 'Muito baixo';
    if (theftScore <= 400) return 'Baixo';
    if (theftScore <= 600) return 'Médio';
    if (theftScore <= 800) return 'Alto';
    return 'Crítico';
  }

  IconData get icon {
    switch (category) {
      case VehicleCategory.moto:      return Icons.two_wheeler_rounded;
      case VehicleCategory.suv:       return Icons.directions_car_filled_rounded;
      case VehicleCategory.pickup:    return Icons.local_shipping_rounded;
      case VehicleCategory.eletrico:  return Icons.electric_car_rounded;
      case VehicleCategory.esportivo: return Icons.speed_rounded;
      default:                        return Icons.directions_car_rounded;
    }
  }
}

class VehicleRiskDatabase {
  static const List<VehicleRiskData> vehicles = [
    VehicleRiskData(model: 'Chevrolet Onix',     category: VehicleCategory.hatch,    theftScore: 800, collisionScore: 450),
    VehicleRiskData(model: 'Hyundai HB20',       category: VehicleCategory.hatch,    theftScore: 750, collisionScore: 420),
    VehicleRiskData(model: 'Fiat Argo',          category: VehicleCategory.hatch,    theftScore: 600, collisionScore: 400),
    VehicleRiskData(model: 'VW Polo',            category: VehicleCategory.hatch,    theftScore: 580, collisionScore: 380),
    VehicleRiskData(model: 'Toyota Corolla',     category: VehicleCategory.sedan,    theftScore: 500, collisionScore: 420),
    VehicleRiskData(model: 'Honda Civic',        category: VehicleCategory.sedan,    theftScore: 520, collisionScore: 390),
    VehicleRiskData(model: 'Toyota Hilux',       category: VehicleCategory.pickup,   theftScore: 720, collisionScore: 550),
    VehicleRiskData(model: 'Ford Ranger',        category: VehicleCategory.pickup,   theftScore: 680, collisionScore: 530),
    VehicleRiskData(model: 'Jeep Compass',       category: VehicleCategory.suv,      theftScore: 450, collisionScore: 500),
    VehicleRiskData(model: 'Hyundai Creta',      category: VehicleCategory.suv,      theftScore: 420, collisionScore: 480),
    VehicleRiskData(model: 'BYD Atto 2',         category: VehicleCategory.eletrico, theftScore: 250, collisionScore: 350),
    VehicleRiskData(model: 'BYD Dolphin',        category: VehicleCategory.eletrico, theftScore: 230, collisionScore: 330),
    VehicleRiskData(model: 'Tesla Model 3',      category: VehicleCategory.eletrico, theftScore: 200, collisionScore: 300),
    VehicleRiskData(model: 'Chevrolet Camaro',   category: VehicleCategory.esportivo,theftScore: 380, collisionScore: 850),
    VehicleRiskData(model: 'VW Golf GTI',        category: VehicleCategory.esportivo,theftScore: 460, collisionScore: 780),
    VehicleRiskData(model: 'Honda CB 500',       category: VehicleCategory.moto,     theftScore: 650, collisionScore: 900),
    VehicleRiskData(model: 'Yamaha MT-07',       category: VehicleCategory.moto,     theftScore: 700, collisionScore: 950),
  ];

  static VehicleRiskData lookup(String model) {
    final lc = model.toLowerCase();
    for (final v in vehicles) {
      if (lc.contains(v.model.toLowerCase().split(' ').last) ||
          v.model.toLowerCase().contains(lc)) {
        return v;
      }
    }
    // Padrão — hatch médio
    return const VehicleRiskData(
      model: 'Veículo padrão',
      category: VehicleCategory.hatch,
      theftScore: 400,
      collisionScore: 400,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 6 — FIPE
// ─────────────────────────────────────────────────────────────────────────────

class FipeRiskFactor {
  static double multiplier(double fipeValue) {
    if (fipeValue <= 50000)  return 1.0;
    if (fipeValue <= 100000) return 1.2;
    if (fipeValue <= 200000) return 1.5;
    if (fipeValue <= 500000) return 2.0;
    return 3.0;
  }

  static String label(double fipeValue) {
    if (fipeValue <= 50000)  return 'até R\$ 50 mil';
    if (fipeValue <= 100000) return 'R\$ 50–100 mil';
    if (fipeValue <= 200000) return 'R\$ 100–200 mil';
    if (fipeValue <= 500000) return 'R\$ 200–500 mil';
    return 'acima de R\$ 500 mil';
  }

  static String formatFipe(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)} mil';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 7 — IDADE DO CONDUTOR
// ─────────────────────────────────────────────────────────────────────────────

class AgeFactor {
  static double multiplier(int age) {
    if (age < 18) return 2.5;   // abaixo da legal — risco altíssimo
    if (age <= 24) return 1.8;  // jovens
    if (age <= 35) return 1.3;  // adultos jovens
    if (age <= 60) return 1.0;  // maduros — menor risco
    return 1.4;                  // idosos
  }

  static String label(int age) {
    if (age < 18) return 'Menor de 18 (×2.5)';
    if (age <= 24) return '18–24 anos (×1.8)';
    if (age <= 35) return '25–35 anos (×1.3)';
    if (age <= 60) return '36–60 anos (×1.0)';
    return '60+ anos (×1.4)';
  }

  static Color color(int age) {
    if (age <= 24) return const Color(0xFFEF4444);
    if (age <= 35) return const Color(0xFFF59E0B);
    if (age <= 60) return const Color(0xFF22C55E);
    return const Color(0xFFF59E0B);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 8 — HISTÓRICO DO MOTORISTA
// ─────────────────────────────────────────────────────────────────────────────

class DriverHistory {
  final int sinistros;       // número de sinistros
  final int multas;          // multas nos últimos 12 meses
  final int acidentes;       // acidentes
  final int chamados;        // acionamentos do seguro
  final int score;           // 0–1000 (calculado ou informado)

  const DriverHistory({
    this.sinistros = 0,
    this.multas = 0,
    this.acidentes = 0,
    this.chamados = 0,
    this.score = 800,
  });

  // Score calculado automaticamente se não informado
  int get calculatedScore {
    int s = 1000;
    s -= sinistros * 150;
    s -= multas * 40;
    s -= acidentes * 120;
    s -= chamados * 60;
    return s.clamp(0, 1000);
  }

  double get multiplier {
    final s = score > 0 ? score : calculatedScore;
    if (s >= 900) return 0.85;   // Elite — desconto
    if (s >= 800) return 1.00;   // Ouro
    if (s >= 700) return 1.10;   // Prata
    if (s >= 600) return 1.30;   // Bronze
    if (s >= 400) return 1.60;   // Básico
    return 2.20;                  // Risco elevado
  }

  String get tier {
    final s = score > 0 ? score : calculatedScore;
    if (s >= 900) return 'Elite';
    if (s >= 800) return 'Ouro';
    if (s >= 700) return 'Prata';
    if (s >= 600) return 'Bronze';
    return 'Básico';
  }

  Color get tierColor {
    final s = score > 0 ? score : calculatedScore;
    if (s >= 900) return const Color(0xFF06B6D4);
    if (s >= 800) return const Color(0xFFF59E0B);
    if (s >= 700) return const Color(0xFF94A3B8);
    if (s >= 600) return const Color(0xFFB45309);
    return const Color(0xFFEF4444);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR 9 — TELEMETRIA
// ─────────────────────────────────────────────────────────────────────────────

class TelemetryData {
  final int score;               // 0–1000 (alimentado em tempo real)
  final double avgSpeedKmh;
  final int harshBrakings;       // freadas bruscas
  final int harshAccelerations;  // arrancadas bruscas
  final int sharpTurns;          // curvas bruscas
  final bool phoneUsage;         // uso do celular detectado
  final double maxSpeedKmh;

  const TelemetryData({
    this.score = 950,
    this.avgSpeedKmh = 55,
    this.harshBrakings = 0,
    this.harshAccelerations = 0,
    this.sharpTurns = 0,
    this.phoneUsage = false,
    this.maxSpeedKmh = 80,
  });

  double get multiplier {
    if (score >= 900) return 0.80; // desconto agressivo
    if (score >= 800) return 0.90;
    if (score >= 700) return 1.00;
    if (score >= 500) return 1.20;
    return 1.50;
  }

  String get discountLabel {
    if (score >= 900) return '-20% Telemetria Elite';
    if (score >= 800) return '-10% Telemetria Boa';
    if (score >= 700) return 'Sem ajuste';
    if (score >= 500) return '+20% Risco telemetria';
    return '+50% Risco elevado';
  }

  // Score calculado pela viagem
  static int calcFromTrip({
    required int harshBrakings,
    required int harshAccelerations,
    required int sharpTurns,
    required bool phoneUsage,
    required double avgSpeed,
    required double speedLimit,
  }) {
    int s = 1000;
    s -= harshBrakings * 30;
    s -= harshAccelerations * 25;
    s -= sharpTurns * 20;
    if (phoneUsage) s -= 150;
    if (avgSpeed > speedLimit * 1.2) s -= 100;
    return s.clamp(0, 1000);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT ATUARIAL COMPLETO
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialInput {
  // Básicos
  final double distanceKm;
  final DateTime departureTime;
  final String originAddress;
  final String destinationAddress;

  // Fator 1 — CEP
  final String originCep;
  final String destinationCep;

  // Fator 2 — Rua
  final String originStreet;
  final String destinationStreet;

  // Fator 4 — Clima
  final WeatherCondition weather;

  // Fator 5 — Veículo
  final String vehicleModel;
  final VehicleCategory vehicleCategory;

  // Fator 6 — FIPE (agora inclui dados reais da API)
  final double vehicleFipeValue;
  final int anoModelo;           // Ano do modelo (ex: 2022)
  final int idadeVeiculo;        // Anos desde o modelo (calculado automaticamente)
  final String marcaFipe;        // Marca (ex: "Volkswagen")
  final String codigoFipe;       // Código FIPE (ex: "005340-4")
  final double franquiaDinamica; // Franquia calculada pela tabela FIPE (sobrescreve cálculo antigo)

  // Fator 7 — Idade
  final int driverAge;

  // Fator 8 — Histórico
  final DriverHistory driverHistory;

  // Fator 9 — Telemetria
  final TelemetryData telemetry;

  // Extras
  final TrafficLevel traffic;
  final String planType; // 'economico', 'equilibrado', 'premium'

  const ActuarialInput({
    required this.distanceKm,
    required this.departureTime,
    this.originAddress = 'Serra/ES',
    this.destinationAddress = 'Vitória/ES',
    this.originCep = '29170-000',
    this.destinationCep = '29015-000',
    this.originStreet = 'Av. Norte-Sul',
    this.destinationStreet = 'Av. Jerônimo Monteiro',
    this.weather = WeatherCondition.sol,
    this.vehicleModel = 'BYD Atto 2',
    this.vehicleCategory = VehicleCategory.eletrico,
    this.vehicleFipeValue = 130000,
    this.anoModelo = 2022,
    this.idadeVeiculo = 3,
    this.marcaFipe = 'BYD',
    this.codigoFipe = '',
    this.franquiaDinamica = 0, // 0 = auto-calculado pelo engine
    this.driverAge = 28,
    this.driverHistory = const DriverHistory(score: 800),
    this.telemetry = const TelemetryData(score: 950),
    this.traffic = TrafficLevel.moderado,
    this.planType = 'equilibrado',
  });

  static ActuarialInput get demo => ActuarialInput(
    distanceKm: 20,
    departureTime: DateTime.now().copyWith(hour: 19, minute: 0),
    originCep: '29170-000',
    destinationCep: '29015-000',
    weather: WeatherCondition.chuva,
    vehicleModel: 'BYD Atto 2',
    vehicleCategory: VehicleCategory.eletrico,
    vehicleFipeValue: 130000,
    anoModelo: 2022,
    idadeVeiculo: DateTime.now().year - 2022,
    marcaFipe: 'BYD',
    codigoFipe: '190003-5',
    franquiaDinamica: 0,
    driverAge: 28,
    driverHistory: const DriverHistory(score: 800),
    telemetry: const TelemetryData(score: 950),
    traffic: TrafficLevel.moderado,
    planType: 'equilibrado',
  );

  /// Cria ActuarialInput a partir de dados reais da API FIPE
  /// Usa o FipePreco retornado pelo FipeApiService
  static ActuarialInput fromFipeData({
    required double distanceKm,
    required DateTime departureTime,
    required double fipeValor,
    required String fipeMarca,
    required String fipeModelo,
    required int fipeAnoModelo,
    required String fipeCodigoFipe,
    required double fipeFranquia,
    String originCep = '29170-000',
    String destinationCep = '29015-000',
    WeatherCondition weather = WeatherCondition.sol,
    int driverAge = 28,
    DriverHistory driverHistory = const DriverHistory(score: 800),
    TelemetryData telemetry = const TelemetryData(score: 950),
    TrafficLevel traffic = TrafficLevel.moderado,
    String planType = 'equilibrado',
  }) {
    final idadeAnos = DateTime.now().year - fipeAnoModelo;
    return ActuarialInput(
      distanceKm: distanceKm,
      departureTime: departureTime,
      vehicleModel: '$fipeMarca $fipeModelo',
      vehicleFipeValue: fipeValor,
      anoModelo: fipeAnoModelo,
      idadeVeiculo: idadeAnos.clamp(0, 50),
      marcaFipe: fipeMarca,
      codigoFipe: fipeCodigoFipe,
      franquiaDinamica: fipeFranquia,
      originCep: originCep,
      destinationCep: destinationCep,
      weather: weather,
      driverAge: driverAge,
      driverHistory: driverHistory,
      telemetry: telemetry,
      traffic: traffic,
      planType: planType,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROBABILIDADES DE SINISTRO (IA Preditiva)
// ─────────────────────────────────────────────────────────────────────────────

class SinistroProbs {
  final double pRoubo;     // probabilidade de roubo
  final double pFurto;     // probabilidade de furto
  final double pColisao;   // probabilidade de colisão
  final double pTerceiros; // probabilidade de danos a terceiros
  final double pTotal;     // probabilidade total de sinistro

  const SinistroProbs({
    required this.pRoubo,
    required this.pFurto,
    required this.pColisao,
    required this.pTerceiros,
    required this.pTotal,
  });

  String get pTotalLabel {
    if (pTotal < 0.02) return 'Risco Mínimo';
    if (pTotal < 0.05) return 'Risco Baixo';
    if (pTotal < 0.10) return 'Risco Moderado';
    if (pTotal < 0.20) return 'Risco Alto';
    return 'Risco Crítico';
  }

  Color get pTotalColor {
    if (pTotal < 0.02) return const Color(0xFF22C55E);
    if (pTotal < 0.05) return const Color(0xFF84CC16);
    if (pTotal < 0.10) return const Color(0xFFF59E0B);
    if (pTotal < 0.20) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String fmt(double p) => '${(p * 100).toStringAsFixed(1)}%';
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO ATUARIAL COMPLETO
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialResult {
  // Fatores individuais
  final double fCep;
  final double fRua;
  final double fHorario;
  final double fClima;
  final double fVeiculoRoubo;
  final double fVeiculoColisao;
  final double fFipe;
  final double fIdade;
  final double fHistorico;
  final double fTelemetria;
  final double fTrafico;
  final double fIdadeVeiculo; // NOVO: fator de idade do veículo

  // Multiplicador total
  final double multiplicadorTotal;

  // Preço
  final double precoBase;
  final double precoAtuarial;
  final double precoFinal;

  // Probabilities
  final SinistroProbs probs;

  // Franquia
  final double franquia;

  // Nível de risco
  final RiskZone riskZone;
  final String nivelRisco;

  // Dados contextuais
  final CepRiskData originCepData;
  final CepRiskData destCepData;
  final VehicleRiskData vehicleData;

  const ActuarialResult({
    required this.fCep,
    required this.fRua,
    required this.fHorario,
    required this.fClima,
    required this.fVeiculoRoubo,
    required this.fVeiculoColisao,
    required this.fFipe,
    required this.fIdade,
    required this.fHistorico,
    required this.fTelemetria,
    required this.fTrafico,
    this.fIdadeVeiculo = 1.0,
    required this.multiplicadorTotal,
    required this.precoBase,
    required this.precoAtuarial,
    required this.precoFinal,
    required this.probs,
    required this.franquia,
    required this.riskZone,
    required this.nivelRisco,
    required this.originCepData,
    required this.destCepData,
    required this.vehicleData,
  });

  String get precoFormatado =>
      'R\$ ${precoFinal.toStringAsFixed(2).replaceAll('.', ',')}';

  String get multiplicadorFormatado =>
      '×${multiplicadorTotal.toStringAsFixed(2)}';

  String get franquiaFormatada =>
      'R\$ ${franquia.toStringAsFixed(0)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTUARIAL ENGINE — cálculo principal
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialEngine {
  static const String version = 'v2.0.0';
  static const double tarifaBasePorKm = 0.15;
  static const double taxaMinima = 1.99;

  static ActuarialResult calculate(ActuarialInput input) {
    // ── Dados dos fatores ─────────────────────────────────────
    final originCep   = CepRiskDatabase.lookup(input.originCep);
    final destCep     = CepRiskDatabase.lookup(input.destinationCep);
    final originStreet = StreetRiskDatabase.lookup(input.originStreet);
    final destStreet   = StreetRiskDatabase.lookup(input.destinationStreet);
    final vehicleData  = VehicleRiskDatabase.lookup(input.vehicleModel);

    // ── Cálculo dos fatores ───────────────────────────────────

    // F1 — CEP: média origem + destino
    final fCep = (originCep.multiplier + destCep.multiplier) / 2;

    // F2 — Rua: pior entre origem e destino
    final fRua = [originStreet.multiplier, destStreet.multiplier].reduce(
        (a, b) => a > b ? a : b);

    // F3 — Horário
    final fHorario = HourRiskFactor.multiplier(input.departureTime.hour);

    // F4 — Clima
    final fClima = input.weather.multiplier;

    // F5 — Veículo
    final fVeiculoRoubo    = vehicleData.theftMultiplier;
    final fVeiculoColisao  = vehicleData.collisionMultiplier;

    // F6 — FIPE
    final fFipe = FipeRiskFactor.multiplier(input.vehicleFipeValue);

    // F7 — Idade
    final fIdade = AgeFactor.multiplier(input.driverAge);

    // F8 — Histórico
    final fHistorico = input.driverHistory.multiplier;

    // F9 — Telemetria
    final fTelemetria = input.telemetry.multiplier;

    // F10 — Idade do Veículo (FIPE real — tabela atuarial SixTech)
    final fIdadeVeiculo = _calcFatorIdadeVeiculo(input.idadeVeiculo);

    // Tráfego
    final fTrafico = input.traffic.multiplier;

    // ── Multiplicador total ───────────────────────────────────
    // Pesos: CEP×0.18, Rua×0.13, Horário×0.14, Clima×0.09,
    //        Veículo×0.08, FIPE×0.10, IdadeCondutor×0.08, Histórico×0.08,
    //        Telemetria×0.04, IdadeVeiculo×0.08
    final multPonderado =
        fCep            * 0.18 +
        fRua            * 0.13 +
        fHorario        * 0.14 +
        fClima          * 0.09 +
        fVeiculoRoubo   * 0.06 +
        fVeiculoColisao * 0.02 +
        fFipe           * 0.10 +
        fIdade          * 0.08 +
        fHistorico      * 0.08 +
        fTelemetria     * 0.04 +
        fIdadeVeiculo   * 0.08;

    // Multiplicador de tráfego aplicado sobre o total
    final multiplicadorTotal = multPonderado * fTrafico;

    // ── Preço ─────────────────────────────────────────────────
    final precoBase     = input.distanceKm * tarifaBasePorKm;
    final precoAtuarial = precoBase * multiplicadorTotal;
    final precoFinal    = precoAtuarial < taxaMinima ? taxaMinima : precoAtuarial;

    // ── Probabilidades ────────────────────────────────────────
    final probs = _calcProbs(input, fCep, fHorario, fClima,
        fVeiculoRoubo, fVeiculoColisao, fIdade, fHistorico);

    // ── Franquia Inteligente ──────────────────────────────────
    // Usa franquia dinâmica da API FIPE se disponível (> 0)
    final franquia = input.franquiaDinamica > 0
        ? input.franquiaDinamica
        : _calcFranquia(
            fipeValue: input.vehicleFipeValue,
            riskMultiplier: multiplicadorTotal,
            planType: input.planType,
          );

    // ── Zona de risco ─────────────────────────────────────────
    final riskZone = _determineZone(multiplicadorTotal);
    final nivelRisco = _nivelRisco(multiplicadorTotal);

    return ActuarialResult(
      fCep: fCep,
      fRua: fRua,
      fHorario: fHorario,
      fClima: fClima,
      fVeiculoRoubo: fVeiculoRoubo,
      fVeiculoColisao: fVeiculoColisao,
      fFipe: fFipe,
      fIdade: fIdade,
      fHistorico: fHistorico,
      fTelemetria: fTelemetria,
      fTrafico: fTrafico,
      fIdadeVeiculo: fIdadeVeiculo,
      multiplicadorTotal: multiplicadorTotal,
      precoBase: precoBase,
      precoAtuarial: precoAtuarial,
      precoFinal: precoFinal,
      probs: probs,
      franquia: franquia,
      riskZone: riskZone,
      nivelRisco: nivelRisco,
      originCepData: originCep,
      destCepData: destCep,
      vehicleData: vehicleData,
    );
  }

  // ── Cálculo de probabilidades ─────────────────────────────
  static SinistroProbs _calcProbs(
    ActuarialInput input,
    double fCep, double fHorario, double fClima,
    double fVRoubo, double fVColisao, double fIdade, double fHist,
  ) {
    // Base estatística do ES: 3% de chance de roubo por viagem em zona neutra
    const baseRoubo    = 0.008;
    const baseFurto    = 0.005;
    const baseColisao  = 0.012;
    const baseTerceiro = 0.004;

    final pRoubo = (baseRoubo * fCep * fHorario * fVRoubo * fHist)
        .clamp(0.001, 0.5);
    final pFurto = (baseFurto * fCep * fVRoubo * fHist)
        .clamp(0.001, 0.3);
    final pColisao = (baseColisao * fClima * fIdade * fVColisao * fHist)
        .clamp(0.001, 0.4);
    final pTerceiro = (baseTerceiro * fClima * fIdade * fHist)
        .clamp(0.001, 0.2);

    // P(ao menos um) = 1 - P(nenhum)
    final pTotal = 1.0 -
        (1.0 - pRoubo) *
        (1.0 - pFurto) *
        (1.0 - pColisao) *
        (1.0 - pTerceiro);

    return SinistroProbs(
      pRoubo: pRoubo,
      pFurto: pFurto,
      pColisao: pColisao,
      pTerceiros: pTerceiro,
      pTotal: pTotal.clamp(0, 0.99),
    );
  }

  // ── Franquia inteligente ──────────────────────────────────
  static double _calcFranquia({
    required double fipeValue,
    required double riskMultiplier,
    required String planType,
  }) {
    // Base = 5% FIPE
    double base = fipeValue * 0.05;

    // Ajuste pelo risco
    base *= riskMultiplier;

    // Ajuste pelo plano
    switch (planType) {
      case 'economico': base *= 1.5;   break;
      case 'premium':   base *= 0.5;   break;
      default:          break; // equilibrado — sem ajuste
    }

    // Limitar: mín R$500 / máx R$15.000
    return base.clamp(500, 15000);
  }

  // ── Fator de idade do veículo (tabela SixTech) ───────────
  static double _calcFatorIdadeVeiculo(int idadeAnos) {
    if (idadeAnos <= 2)  return 1.00;
    if (idadeAnos <= 5)  return 1.10;
    if (idadeAnos <= 10) return 1.25;
    if (idadeAnos <= 15) return 1.50;
    return 1.80;
  }

  static String fatorIdadeLabel(int idadeAnos) {
    if (idadeAnos <= 2)  return 'Novo (×1.0)';
    if (idadeAnos <= 5)  return 'Recente (×1.1)';
    if (idadeAnos <= 10) return 'Regular (×1.25)';
    if (idadeAnos <= 15) return 'Antigo (×1.5)';
    return 'Muito antigo (×1.8)';
  }

  // ── Zona de risco ─────────────────────────────────────────
  static RiskZone _determineZone(double mult) {
    if (mult <= 1.1) return RiskZone.verde;
    if (mult <= 1.4) return RiskZone.amarela;
    if (mult <= 1.8) return RiskZone.laranja;
    if (mult <= 2.5) return RiskZone.vermelha;
    return RiskZone.critica;
  }

  static String _nivelRisco(double mult) {
    if (mult <= 1.1) return 'Muito Baixo';
    if (mult <= 1.4) return 'Baixo';
    if (mult <= 1.8) return 'Moderado';
    if (mult <= 2.5) return 'Alto';
    return 'Crítico';
  }

  static String formatBRL(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// PRICING ENGINE — Margem mínima, planos flex, reserva técnica
// ─────────────────────────────────────────────────────────────────────────────

class PricingPlan {
  final String id;
  final String name;
  final String description;
  final double priceMultiplier;
  final double deductibleMultiplier; // franquia
  final Color color;
  final IconData icon;
  final List<String> features;

  const PricingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMultiplier,
    required this.deductibleMultiplier,
    required this.color,
    required this.icon,
    required this.features,
  });
}

class PricingEngine {
  static const List<PricingPlan> plans = [
    PricingPlan(
      id: 'economico',
      name: 'Econômico',
      description: 'Preço menor, franquia maior',
      priceMultiplier: 0.80,
      deductibleMultiplier: 1.50,
      color: Color(0xFF22C55E),
      icon: Icons.savings_rounded,
      features: [
        'Cobertura básica RCF-V',
        'Franquia maior',
        'Seguro roubo e furto',
      ],
    ),
    PricingPlan(
      id: 'equilibrado',
      name: 'Equilibrado',
      description: 'Melhor custo-benefício',
      priceMultiplier: 1.00,
      deductibleMultiplier: 1.00,
      color: Color(0xFF1A56DB),
      icon: Icons.balance_rounded,
      features: [
        'Cobertura completa',
        'Franquia padrão',
        'Assistência 24h',
        'Guincho incluso',
      ],
    ),
    PricingPlan(
      id: 'premium',
      name: 'Premium',
      description: 'Franquia mínima, máxima cobertura',
      priceMultiplier: 1.30,
      deductibleMultiplier: 0.50,
      color: Color(0xFF8B5CF6),
      icon: Icons.workspace_premium_rounded,
      features: [
        'Cobertura completa + vidros',
        'Franquia reduzida 50%',
        'Carro reserva 7 dias',
        'Assessoria jurídica',
        'App gestão sinistro',
      ],
    ),
  ];

  // ── Divisão de receita (comissão) ─────────────────────────
  static CommissionSplit calcCommission(double precoFinal) {
    return CommissionSplit(
      seguradora:   precoFinal * 0.55,  // 55%
      fundoSinistro: precoFinal * 0.20, // 20%
      sixtech:      precoFinal * 0.15,  // 15%
      reserva:      precoFinal * 0.10,  // 10%
      total:        precoFinal,
    );
  }

  // ── Margem mínima ─────────────────────────────────────────
  // O sistema nunca vende abaixo da margem técnica
  static double calcPrecoMinimo({
    required double custoAtuarial,
    required double reservaTecnica,    // % do prêmio
    required double comissaoSeguradora,
    required double comissaoSixtech,
    required double margemLucro,
  }) {
    final custo = custoAtuarial;
    final reserva = custo * reservaTecnica;
    final comissoes = custo * (comissaoSeguradora + comissaoSixtech);
    final lucro = custo * margemLucro;
    return custo + reserva + comissoes + lucro;
  }

  static PricingPlan planById(String id) =>
      plans.firstWhere((p) => p.id == id, orElse: () => plans[1]);
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMISSION ENGINE
// ─────────────────────────────────────────────────────────────────────────────

class CommissionSplit {
  final double seguradora;
  final double fundoSinistro;
  final double sixtech;
  final double reserva;
  final double total;

  const CommissionSplit({
    required this.seguradora,
    required this.fundoSinistro,
    required this.sixtech,
    required this.reserva,
    required this.total,
  });

  String fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  String get seguradoraFmt    => fmt(seguradora);
  String get fundoSinistroFmt => fmt(fundoSinistro);
  String get sixtechFmt       => fmt(sixtech);
  String get reservaFmt       => fmt(reserva);
  String get totalFmt         => fmt(total);

  double get seguradoraPct    => seguradora / total * 100;
  double get fundoPct         => fundoSinistro / total * 100;
  double get sixtechPct       => sixtech / total * 100;
  double get reservaPct       => reserva / total * 100;
}

class CommissionEngine {
  static const Map<String, double> _rates = {
    'seguradora':    0.55,
    'fundo_sinistro': 0.20,
    'sixtech':        0.15,
    'reserva':        0.10,
  };

  static CommissionSplit calculate(double precoFinal) {
    return CommissionSplit(
      seguradora:    precoFinal * _rates['seguradora']!,
      fundoSinistro: precoFinal * _rates['fundo_sinistro']!,
      sixtech:       precoFinal * _rates['sixtech']!,
      reserva:       precoFinal * _rates['reserva']!,
      total:         precoFinal,
    );
  }

  static Map<String, double> get rates => Map.unmodifiable(_rates);
}

// ─────────────────────────────────────────────────────────────────────────────
// FRAUD ENGINE — IA de detecção de fraude
// ─────────────────────────────────────────────────────────────────────────────

enum FraudRisk { baixo, medio, alto, critico }

class FraudSignal {
  final String title;
  final String description;
  final FraudRisk level;

  const FraudSignal({
    required this.title,
    required this.description,
    required this.level,
  });
}

class FraudAnalysis {
  final int fraudScore;       // 0–1000 (0=limpo, 1000=fraude certa)
  final FraudRisk riskLevel;
  final List<FraudSignal> signals;
  final bool blocked;

  const FraudAnalysis({
    required this.fraudScore,
    required this.riskLevel,
    required this.signals,
    required this.blocked,
  });

  String get riskLabel {
    switch (riskLevel) {
      case FraudRisk.baixo:   return 'Sem indicadores de fraude';
      case FraudRisk.medio:   return 'Monitoramento ativo';
      case FraudRisk.alto:    return 'Análise humana recomendada';
      case FraudRisk.critico: return 'Sinistro bloqueado automaticamente';
    }
  }

  Color get riskColor {
    switch (riskLevel) {
      case FraudRisk.baixo:   return const Color(0xFF22C55E);
      case FraudRisk.medio:   return const Color(0xFFF59E0B);
      case FraudRisk.alto:    return const Color(0xFFF97316);
      case FraudRisk.critico: return const Color(0xFFEF4444);
    }
  }
}

class FraudEngine {
  static FraudAnalysis analyze({
    required DriverHistory history,
    required double claimValue,
    required double vehicleFipeValue,
    required int daysSincePolicy,
    required int claimsLast12Months,
    required bool claimInHighRiskZone,
    required bool claimAfterMidnight,
    required double distanceKm,
  }) {
    int score = 0;
    final signals = <FraudSignal>[];

    // Regra 1 — Sinistro muito logo após a apólice
    if (daysSincePolicy < 30) {
      score += 300;
      signals.add(const FraudSignal(
        title: 'Sinistro em apólice nova',
        description: 'Ocorrência nos primeiros 30 dias da cobertura.',
        level: FraudRisk.alto,
      ));
    } else if (daysSincePolicy < 90) {
      score += 150;
      signals.add(const FraudSignal(
        title: 'Apólice recente (< 90 dias)',
        description: 'Menor histórico de comportamento disponível.',
        level: FraudRisk.medio,
      ));
    }

    // Regra 2 — Múltiplos sinistros
    if (claimsLast12Months >= 3) {
      score += 350;
      signals.add(FraudSignal(
        title: 'Múltiplos sinistros (12 meses)',
        description: '$claimsLast12Months acionamentos nos últimos 12 meses.',
        level: FraudRisk.critico,
      ));
    } else if (claimsLast12Months >= 2) {
      score += 150;
      signals.add(FraudSignal(
        title: 'Reincidência de sinistro',
        description: '$claimsLast12Months acionamentos nos últimos 12 meses.',
        level: FraudRisk.medio,
      ));
    }

    // Regra 3 — Valor do sinistro vs. FIPE
    final claimRatio = claimValue / vehicleFipeValue;
    if (claimRatio > 0.8) {
      score += 250;
      signals.add(FraudSignal(
        title: 'Valor elevado vs. FIPE',
        description: 'Sinistro de ${(claimRatio * 100).round()}% do valor do veículo.',
        level: FraudRisk.alto,
      ));
    }

    // Regra 4 — Madrugada em zona de risco
    if (claimAfterMidnight && claimInHighRiskZone) {
      score += 200;
      signals.add(const FraudSignal(
        title: 'Ocorrência suspeita',
        description: 'Madrugada + zona de risco: padrão comum em fraude de roubo.',
        level: FraudRisk.alto,
      ));
    }

    // Regra 5 — Score histórico muito baixo
    if (history.score < 400) {
      score += 100;
      signals.add(FraudSignal(
        title: 'Histórico de risco elevado',
        description: 'Score histórico ${history.score}/1000.',
        level: FraudRisk.medio,
      ));
    }

    score = score.clamp(0, 1000);

    FraudRisk level;
    if (score < 200)       level = FraudRisk.baixo;
    else if (score < 450)  level = FraudRisk.medio;
    else if (score < 700)  level = FraudRisk.alto;
    else                   level = FraudRisk.critico;

    return FraudAnalysis(
      fraudScore: score,
      riskLevel: level,
      signals: signals,
      blocked: level == FraudRisk.critico,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD METRICS — dados simulados para o painel admin
// ─────────────────────────────────────────────────────────────────────────────

class ActuarialMetrics {
  final double receitaTotal;
  final double sinistrosPagos;
  final double margemBruta;
  final int totalViagens;
  final int totalSinistros;
  final double taxaSinistralidade;     // sinistros/receita
  final List<RouteMetric> rotasLucrativas;
  final List<RouteMetric> rotasProblematicas;
  final List<CityMetric> cidadesRentaveis;
  final List<VehicleMetric> veiculosRentaveis;

  const ActuarialMetrics({
    required this.receitaTotal,
    required this.sinistrosPagos,
    required this.margemBruta,
    required this.totalViagens,
    required this.totalSinistros,
    required this.taxaSinistralidade,
    required this.rotasLucrativas,
    required this.rotasProblematicas,
    required this.cidadesRentaveis,
    required this.veiculosRentaveis,
  });

  static ActuarialMetrics get demo => ActuarialMetrics(
    receitaTotal: 148720.50,
    sinistrosPagos: 31250.00,
    margemBruta: 117470.50,
    totalViagens: 24830,
    totalSinistros: 87,
    taxaSinistralidade: 0.21,
    rotasLucrativas: [
      RouteMetric(name: 'Serra → Jardim Camburi', trips: 1840, revenue: 12400, margin: 0.72, zone: RiskZone.verde),
      RouteMetric(name: 'Laranjeiras → UFES',     trips: 1520, revenue: 9800,  margin: 0.69, zone: RiskZone.verde),
      RouteMetric(name: 'Serra → Enseada do Suá', trips: 1380, revenue: 9100,  margin: 0.68, zone: RiskZone.verde),
      RouteMetric(name: 'Itaparica → Praia do Canto', trips: 1120, revenue: 8200, margin: 0.66, zone: RiskZone.verde),
    ],
    rotasProblematicas: [
      RouteMetric(name: 'Feu Rosa → Centro VV',   trips: 320, revenue: 4800, margin: 0.12, zone: RiskZone.critica),
      RouteMetric(name: 'Porto Santana → Vitória', trips: 280, revenue: 4200, margin: 0.18, zone: RiskZone.vermelha),
      RouteMetric(name: 'André Carloni → Centro',  trips: 410, revenue: 5200, margin: 0.22, zone: RiskZone.vermelha),
    ],
    cidadesRentaveis: [
      CityMetric(city: 'Serra',       revenue: 52400, trips: 9200, margin: 0.68),
      CityMetric(city: 'Vitória',     revenue: 44100, trips: 7800, margin: 0.61),
      CityMetric(city: 'Vila Velha',  revenue: 31200, trips: 5400, margin: 0.64),
      CityMetric(city: 'Cariacica',   revenue: 14800, trips: 2100, margin: 0.38),
      CityMetric(city: 'Guarapari',   revenue: 6220,  trips: 330,  margin: 0.72),
    ],
    veiculosRentaveis: [
      VehicleMetric(model: 'BYD Atto 2',     fipe: 130000, trips: 1240, revenue: 14800, margin: 0.74),
      VehicleMetric(model: 'Toyota Corolla', fipe: 120000, trips: 1080, revenue: 12200, margin: 0.71),
      VehicleMetric(model: 'Jeep Compass',   fipe: 180000, trips: 890,  revenue: 11400, margin: 0.68),
      VehicleMetric(model: 'Chevrolet Onix', fipe: 85000,  trips: 3200, revenue: 18400, margin: 0.52),
      VehicleMetric(model: 'Honda CB 500',   fipe: 38000,  trips: 420,  revenue: 3800,  margin: 0.28),
    ],
  );
}

class RouteMetric {
  final String name;
  final int trips;
  final double revenue;
  final double margin; // 0–1
  final RiskZone zone;
  const RouteMetric({
    required this.name,
    required this.trips,
    required this.revenue,
    required this.margin,
    required this.zone,
  });
}

class CityMetric {
  final String city;
  final double revenue;
  final int trips;
  final double margin;
  const CityMetric({
    required this.city,
    required this.revenue,
    required this.trips,
    required this.margin,
  });
}

class VehicleMetric {
  final String model;
  final double fipe;
  final int trips;
  final double revenue;
  final double margin;
  const VehicleMetric({
    required this.model,
    required this.fipe,
    required this.trips,
    required this.revenue,
    required this.margin,
  });
}

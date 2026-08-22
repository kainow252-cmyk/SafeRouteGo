// ═══════════════════════════════════════════════════════════════
// SAFEROUTE RISK ENGINE V1
// Motor de precificação inteligente com 5 fatores de risco
// Fórmula: Preço = (km × tarifaBase) × fRegião × fHorário × fClima × fMotorista
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────

enum RiskZone {
  verde,    // ×1.0
  amarela,  // ×1.2
  laranja,  // ×1.5
  vermelha, // ×2.0
  critica;  // ×3.0

  String get label {
    switch (this) {
      case verde:    return 'Verde';
      case amarela:  return 'Amarela';
      case laranja:  return 'Laranja';
      case vermelha: return 'Vermelha';
      case critica:  return 'Crítica';
    }
  }

  double get multiplier {
    switch (this) {
      case verde:    return 1.0;
      case amarela:  return 1.2;
      case laranja:  return 1.5;
      case vermelha: return 2.0;
      case critica:  return 3.0;
    }
  }

  Color get color {
    switch (this) {
      case verde:    return const Color(0xFF22C55E);
      case amarela:  return const Color(0xFFF59E0B);
      case laranja:  return const Color(0xFFF97316);
      case vermelha: return const Color(0xFFEF4444);
      case critica:  return const Color(0xFF7C2D12);
    }
  }

  String get description {
    switch (this) {
      case verde:    return 'Baixo índice criminal, risco mínimo';
      case amarela:  return 'Atenção moderada, furtos ocasionais';
      case laranja:  return 'Alto índice de roubos e colisões';
      case vermelha: return 'Zona crítica — roubos frequentes';
      case critica:  return 'Risco extremo — área de alta violência';
    }
  }
}

enum WeatherCondition {
  sol,
  nublado,
  chuva,
  temporal,
  alagamento;

  String get label {
    switch (this) {
      case sol:        return 'Sol';
      case nublado:    return 'Nublado';
      case chuva:      return 'Chuva';
      case temporal:   return 'Temporal';
      case alagamento: return 'Alagamento';
    }
  }

  double get multiplier {
    switch (this) {
      case sol:        return 1.0;
      case nublado:    return 1.05;
      case chuva:      return 1.2;
      case temporal:   return 1.5;
      case alagamento: return 2.5;
    }
  }

  IconData get icon {
    switch (this) {
      case sol:        return Icons.wb_sunny_rounded;
      case nublado:    return Icons.cloud_rounded;
      case chuva:      return Icons.grain_rounded;
      case temporal:   return Icons.thunderstorm_rounded;
      case alagamento: return Icons.water_rounded;
    }
  }

  Color get color {
    switch (this) {
      case sol:        return const Color(0xFFF59E0B);
      case nublado:    return const Color(0xFF94A3B8);
      case chuva:      return const Color(0xFF3B82F6);
      case temporal:   return const Color(0xFF7C3AED);
      case alagamento: return const Color(0xFF0891B2);
    }
  }
}

enum DriverScoreTier {
  elite,    // 900+ → ×0.85
  gold,     // 800   → ×1.00
  silver,   // 700   → ×1.10
  bronze,   // 600   → ×1.30
  basic;    // 500   → ×1.60

  String get label {
    switch (this) {
      case elite:  return 'Elite';
      case gold:   return 'Ouro';
      case silver: return 'Prata';
      case bronze: return 'Bronze';
      case basic:  return 'Básico';
    }
  }

  double get multiplier {
    switch (this) {
      case elite:  return 0.85;
      case gold:   return 1.00;
      case silver: return 1.10;
      case bronze: return 1.30;
      case basic:  return 1.60;
    }
  }

  String get scoreRange {
    switch (this) {
      case elite:  return '900+';
      case gold:   return '800–899';
      case silver: return '700–799';
      case bronze: return '600–699';
      case basic:  return 'até 599';
    }
  }

  Color get color {
    switch (this) {
      case elite:  return const Color(0xFF06B6D4);
      case gold:   return const Color(0xFFF59E0B);
      case silver: return const Color(0xFF94A3B8);
      case bronze: return const Color(0xFFB45309);
      case basic:  return const Color(0xFFEF4444);
    }
  }

  static DriverScoreTier fromScore(int score) {
    if (score >= 900) return elite;
    if (score >= 800) return gold;
    if (score >= 700) return silver;
    if (score >= 600) return bronze;
    return basic;
  }
}

enum TrafficLevel {
  livre,
  moderado,
  intenso,
  congestionado;

  String get label {
    switch (this) {
      case livre:         return 'Livre';
      case moderado:      return 'Moderado';
      case intenso:       return 'Intenso';
      case congestionado: return 'Congestionado';
    }
  }

  double get multiplier {
    switch (this) {
      case livre:         return 1.0;
      case moderado:      return 1.05;
      case intenso:       return 1.1;
      case congestionado: return 1.2;
    }
  }

  Color get color {
    switch (this) {
      case livre:         return const Color(0xFF22C55E);
      case moderado:      return const Color(0xFFF59E0B);
      case intenso:       return const Color(0xFFF97316);
      case congestionado: return const Color(0xFFEF4444);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// MODELO DE INPUT
// ─────────────────────────────────────────────────────────────

class RiskInput {
  final double distanceKm;
  final RiskZone zone;
  final DateTime departureTime;
  final WeatherCondition weather;
  final int driverScore;
  final TrafficLevel traffic;
  final double vehicleFipeValue; // valor FIPE do veículo
  final String vehicleModel;
  final String planType; // 'basico', 'smart', 'premium'
  final String origin;
  final String destination;

  const RiskInput({
    required this.distanceKm,
    required this.zone,
    required this.departureTime,
    required this.weather,
    required this.driverScore,
    required this.traffic,
    required this.vehicleFipeValue,
    required this.vehicleModel,
    required this.planType,
    required this.origin,
    required this.destination,
  });

  // Input padrão para demonstração (Serra → Vitória, 20h, chovendo)
  static RiskInput get demo => RiskInput(
    distanceKm: 25.0,
    zone: RiskZone.amarela,
    departureTime: DateTime.now().copyWith(hour: 20, minute: 0),
    weather: WeatherCondition.chuva,
    driverScore: 750,
    traffic: TrafficLevel.moderado,
    vehicleFipeValue: 80000.0,
    vehicleModel: 'BYD Atto 2',
    planType: 'smart',
    origin: 'Serra/ES',
    destination: 'Vitória/ES',
  );
}

// ─────────────────────────────────────────────────────────────
// MODELO DE OUTPUT — breakdown completo
// ─────────────────────────────────────────────────────────────

class RiskBreakdown {
  // ── Inputs processados ──────────────────────────────────────
  final double distanceKm;
  final RiskZone zone;
  final int departureHour;
  final WeatherCondition weather;
  final DriverScoreTier driverTier;
  final TrafficLevel traffic;

  // ── Multiplicadores individuais ─────────────────────────────
  final double fatorRegiao;
  final double fatorHorario;
  final double fatorKm;
  final double fatorClima;
  final double fatorMotorista;
  final double fatorTrafico;

  // ── Cálculo base ───────────────────────────────────────────
  final double tarifaBase;       // R$/km configurável
  final double taxaMinima;       // taxa mínima por ativação
  final double baseKm;           // distanceKm × tarifaBase

  // ── Preço final ────────────────────────────────────────────
  final double precoFinal;
  final double multiplicadorTotal;

  // ── Nível de risco global ──────────────────────────────────
  final String nivelRisco;       // Baixo / Médio / Alto / Crítico
  final Color corRisco;

  // ── Franquia dinâmica ──────────────────────────────────────
  final double franquiaBase;
  final double franquiaReducao;  // R$/km extras pagos pelo usuário
  final double franquiaMinima;   // mínimo após redução
  final double franquiaSugerida; // valor sugerido para esta viagem

  const RiskBreakdown({
    required this.distanceKm,
    required this.zone,
    required this.departureHour,
    required this.weather,
    required this.driverTier,
    required this.traffic,
    required this.fatorRegiao,
    required this.fatorHorario,
    required this.fatorKm,
    required this.fatorClima,
    required this.fatorMotorista,
    required this.fatorTrafico,
    required this.tarifaBase,
    required this.taxaMinima,
    required this.baseKm,
    required this.precoFinal,
    required this.multiplicadorTotal,
    required this.nivelRisco,
    required this.corRisco,
    required this.franquiaBase,
    required this.franquiaReducao,
    required this.franquiaMinima,
    required this.franquiaSugerida,
  });

  String get precoFormatado => 'R\$ ${precoFinal.toStringAsFixed(2).replaceAll('.', ',')}';
  String get multiplicadorFormatado => '×${multiplicadorTotal.toStringAsFixed(2)}';
  String get franquiaFormatada => 'R\$ ${franquiaSugerida.toStringAsFixed(0)}';
  String get franquiaBaseFormatada => 'R\$ ${franquiaBase.toStringAsFixed(0)}';
}

// ─────────────────────────────────────────────────────────────
// CONFIGURAÇÃO EDITÁVEL PELO ADMIN
// ─────────────────────────────────────────────────────────────

class RiskEngineConfig {
  final double tarifaBasePorKm;        // padrão: R$0,15/km
  final double taxaMinimaAtivacao;     // padrão: R$1,99
  final double franquiaPorKmExtra;     // padrão: R$0,08/km extra

  // Multiplicadores de região (editáveis no painel admin)
  final Map<RiskZone, double> multiplierRegiao;
  final Map<String, double> multiplierHorario; // 'manha','tarde','noite','madrugada'
  final Map<WeatherCondition, double> multiplierClima;
  final Map<DriverScoreTier, double> multiplierMotorista;
  final Map<TrafficLevel, double> multiplierTrafico;

  // Franquias por faixa de veículo e plano
  final Map<String, Map<String, double>> franquias; // 'faixa' → 'plano' → valor

  const RiskEngineConfig({
    this.tarifaBasePorKm = 0.15,
    this.taxaMinimaAtivacao = 1.99,
    this.franquiaPorKmExtra = 0.08,
    this.multiplierRegiao = const {
      RiskZone.verde:    1.0,
      RiskZone.amarela:  1.2,
      RiskZone.laranja:  1.5,
      RiskZone.vermelha: 2.0,
      RiskZone.critica:  3.0,
    },
    this.multiplierHorario = const {
      'manha':     1.0,
      'tarde':     1.1,
      'noite':     1.5,
      'madrugada': 1.3,
    },
    this.multiplierClima = const {
      WeatherCondition.sol:        1.0,
      WeatherCondition.nublado:    1.05,
      WeatherCondition.chuva:      1.2,
      WeatherCondition.temporal:   1.5,
      WeatherCondition.alagamento: 2.5,
    },
    this.multiplierMotorista = const {
      DriverScoreTier.elite:  0.85,
      DriverScoreTier.gold:   1.00,
      DriverScoreTier.silver: 1.10,
      DriverScoreTier.bronze: 1.30,
      DriverScoreTier.basic:  1.60,
    },
    this.multiplierTrafico = const {
      TrafficLevel.livre:         1.0,
      TrafficLevel.moderado:      1.05,
      TrafficLevel.intenso:       1.1,
      TrafficLevel.congestionado: 1.2,
    },
    this.franquias = const {
      'ate50k': {
        'basico':  1500.0,
        'smart':   1000.0,
        'premium': 500.0,
      },
      '50k_100k': {
        'basico':  2500.0,
        'smart':   1500.0,
        'premium': 750.0,
      },
      '100k_250k': {
        'basico':  4000.0,
        'smart':   2500.0,
        'premium': 1500.0,
      },
      'acima250k': {
        'basico':  6000.0,
        'smart':   4000.0,
        'premium': 2500.0,
      },
    },
  });

  // Singleton com estado mutável para o admin alterar
  static RiskEngineConfig _current = const RiskEngineConfig();
  static RiskEngineConfig get current => _current;
  static void update(RiskEngineConfig config) => _current = config;

  RiskEngineConfig copyWith({
    double? tarifaBasePorKm,
    double? taxaMinimaAtivacao,
    double? franquiaPorKmExtra,
  }) {
    return RiskEngineConfig(
      tarifaBasePorKm: tarifaBasePorKm ?? this.tarifaBasePorKm,
      taxaMinimaAtivacao: taxaMinimaAtivacao ?? this.taxaMinimaAtivacao,
      franquiaPorKmExtra: franquiaPorKmExtra ?? this.franquiaPorKmExtra,
      multiplierRegiao: multiplierRegiao,
      multiplierHorario: multiplierHorario,
      multiplierClima: multiplierClima,
      multiplierMotorista: multiplierMotorista,
      multiplierTrafico: multiplierTrafico,
      franquias: franquias,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOTOR PRINCIPAL
// ─────────────────────────────────────────────────────────────

class RiskEngine {
  static const String version = 'v1.0.0';

  // ── Fator de Horário ────────────────────────────────────────
  static double _calcFatorHorario(int hour, RiskEngineConfig cfg) {
    if (hour >= 6 && hour < 12)  return cfg.multiplierHorario['manha']!;
    if (hour >= 12 && hour < 18) return cfg.multiplierHorario['tarde']!;
    if (hour >= 18 && hour < 24) return cfg.multiplierHorario['noite']!;
    return cfg.multiplierHorario['madrugada']!;
  }

  static String _labelHorario(int hour) {
    if (hour >= 6 && hour < 12)  return 'Manhã (06–12h)';
    if (hour >= 12 && hour < 18) return 'Tarde (12–18h)';
    if (hour >= 18 && hour < 24) return 'Noite (18–24h)';
    return 'Madrugada (00–06h)';
  }

  // ── Fator de Quilometragem ──────────────────────────────────
  static double _calcFatorKm(double km) {
    if (km <= 10)  return 1.0;
    if (km <= 30)  return 1.1;
    if (km <= 100) return 1.3;
    if (km <= 300) return 1.6;
    return 2.0;
  }

  // ── Franquia Dinâmica ───────────────────────────────────────
  static double _calcFranquiaBase(double fipeValue, String planType) {
    final cfg = RiskEngineConfig.current;
    String faixa;
    if (fipeValue <= 50000)       faixa = 'ate50k';
    else if (fipeValue <= 100000) faixa = '50k_100k';
    else if (fipeValue <= 250000) faixa = '100k_250k';
    else                          faixa = 'acima250k';

    return cfg.franquias[faixa]?[planType] ?? 2500.0;
  }

  static double _calcFranquiaSugerida(double franquiaBase, double km, double fipeValue, RiskEngineConfig cfg) {
    // Franquia sugerida = 5% FIPE
    final franquiaFipe = fipeValue * 0.05;
    // Redução pela quilometragem extra paga = R$0,08/km
    final reducaoPorKm = km * cfg.franquiaPorKmExtra;
    // Franquia mínima = 30% da franquia base do plano
    final minima = franquiaBase * 0.3;
    final sugerida = (franquiaFipe - reducaoPorKm).clamp(minima, franquiaFipe);
    return sugerida;
  }

  // ── Nível de risco global ───────────────────────────────────
  static (String, Color) _calcNivelRisco(double multiplicadorTotal) {
    if (multiplicadorTotal <= 1.3) return ('Baixo',   const Color(0xFF22C55E));
    if (multiplicadorTotal <= 2.0) return ('Médio',   const Color(0xFFF59E0B));
    if (multiplicadorTotal <= 3.5) return ('Alto',    const Color(0xFFF97316));
    return ('Crítico', const Color(0xFFEF4444));
  }

  // ── CÁLCULO PRINCIPAL ───────────────────────────────────────
  static RiskBreakdown calculate(RiskInput input) {
    final cfg = RiskEngineConfig.current;
    final driverTier = DriverScoreTier.fromScore(input.driverScore);

    // Multiplicadores individuais
    final fRegiao    = cfg.multiplierRegiao[input.zone] ?? input.zone.multiplier;
    final fHorario   = _calcFatorHorario(input.departureTime.hour, cfg);
    final fKm        = _calcFatorKm(input.distanceKm);
    final fClima     = cfg.multiplierClima[input.weather] ?? input.weather.multiplier;
    final fMotorista = cfg.multiplierMotorista[driverTier] ?? driverTier.multiplier;
    final fTrafico   = cfg.multiplierTrafico[input.traffic] ?? input.traffic.multiplier;

    // Base por km
    final baseKm = input.distanceKm * cfg.tarifaBasePorKm;

    // Fórmula: (km × tarifa) × região × horário × km_fator × clima × motorista × tráfego
    final multiplicadorTotal = fRegiao * fHorario * fKm * fClima * fMotorista * fTrafico;
    final precoCalculado = baseKm * multiplicadorTotal;

    // Preço final = max(taxa mínima, calculado)
    final precoFinal = precoCalculado < cfg.taxaMinimaAtivacao
        ? cfg.taxaMinimaAtivacao
        : precoCalculado;

    // Nível de risco
    final (nivelRisco, corRisco) = _calcNivelRisco(multiplicadorTotal);

    // Franquia
    final franquiaBase = _calcFranquiaBase(input.vehicleFipeValue, input.planType);
    final franquiaMinima = franquiaBase * 0.3;
    final franquiaSugerida = _calcFranquiaSugerida(
        franquiaBase, input.distanceKm, input.vehicleFipeValue, cfg);

    return RiskBreakdown(
      distanceKm: input.distanceKm,
      zone: input.zone,
      departureHour: input.departureTime.hour,
      weather: input.weather,
      driverTier: driverTier,
      traffic: input.traffic,
      fatorRegiao: fRegiao,
      fatorHorario: fHorario,
      fatorKm: fKm,
      fatorClima: fClima,
      fatorMotorista: fMotorista,
      fatorTrafico: fTrafico,
      tarifaBase: cfg.tarifaBasePorKm,
      taxaMinima: cfg.taxaMinimaAtivacao,
      baseKm: baseKm,
      precoFinal: precoFinal,
      multiplicadorTotal: multiplicadorTotal,
      nivelRisco: nivelRisco,
      corRisco: corRisco,
      franquiaBase: franquiaBase,
      franquiaReducao: cfg.franquiaPorKmExtra,
      franquiaMinima: franquiaMinima,
      franquiaSugerida: franquiaSugerida,
    );
  }

  // ── Utilitários ────────────────────────────────────────────
  static String labelHorario(int hour) => _labelHorario(hour);

  static String formatBRL(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  static String formatMultiplier(double v) => '×${v.toStringAsFixed(2)}';

  // ── Análise de rota inteligente ─────────────────────────────
  // Gera insights baseados nos fatores calculados
  static List<RouteInsight> generateInsights(RiskInput input, RiskBreakdown result) {
    final insights = <RouteInsight>[];
    final hour = input.departureTime.hour;

    // Horário
    if (result.fatorHorario >= 1.5) {
      insights.add(RouteInsight(
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFF7C3AED),
        title: 'Horário de risco elevado',
        detail: 'Viagens entre 18h–24h têm ${((result.fatorHorario - 1) * 100).round()}% mais ocorrências de roubo.',
        suggestion: hour < 22
            ? 'Aguarde até após 22h ou saia antes das 18h.'
            : 'Prefira rotas com maior fluxo de veículos.',
      ));
    }

    // Região
    if (result.fatorRegiao >= 1.5) {
      insights.add(RouteInsight(
        icon: Icons.location_on_rounded,
        color: const Color(0xFFF97316),
        title: 'Zona ${input.zone.label} no trajeto',
        detail: 'Índice criminal elevado. Multiplicador de ${RiskEngine.formatMultiplier(result.fatorRegiao)} aplicado.',
        suggestion: 'Mantenha janelas fechadas e evite paradas desnecessárias.',
      ));
    }

    // Clima
    if (result.fatorClima >= 1.2) {
      insights.add(RouteInsight(
        icon: input.weather.icon,
        color: input.weather.color,
        title: '${input.weather.label} detectado',
        detail: 'Condição climática aumenta risco de colisões e alagamentos.',
        suggestion: input.weather == WeatherCondition.alagamento
            ? '⚠️ Verifique pontos de alagamento antes de sair.'
            : 'Reduza velocidade e aumente a distância de segurança.',
      ));
    }

    // Motorista com bônus
    if (result.fatorMotorista < 1.0) {
      insights.add(RouteInsight(
        icon: Icons.star_rounded,
        color: const Color(0xFF06B6D4),
        title: 'Bônus ${input.driverScore >= 900 ? "Elite" : "motorista"} aplicado!',
        detail: 'Score ${input.driverScore} → desconto de ${((1 - result.fatorMotorista) * 100).round()}%.',
        suggestion: 'Continue mantendo seu score acima de ${input.driverScore >= 900 ? "900" : "800"} pontos.',
      ));
    }

    // Tráfego
    if (result.fatorTrafico >= 1.1) {
      insights.add(RouteInsight(
        icon: Icons.traffic_rounded,
        color: input.traffic.color,
        title: 'Trânsito ${input.traffic.label}',
        detail: 'Maior exposição no trânsito aumenta risco de incidentes.',
        suggestion: 'Considere partir em horário alternativo.',
      ));
    }

    // Distância longa
    if (result.fatorKm >= 1.3) {
      insights.add(RouteInsight(
        icon: Icons.route_rounded,
        color: const Color(0xFF1A56DB),
        title: 'Percurso longo (${input.distanceKm.round()} km)',
        detail: 'Trajetos maiores aumentam a exposição ao risco.',
        suggestion: 'Fator KM de ${RiskEngine.formatMultiplier(result.fatorKm)} incluído no cálculo.',
      ));
    }

    return insights;
  }
}

// ─────────────────────────────────────────────────────────────
// INSIGHT DE ROTA
// ─────────────────────────────────────────────────────────────

class RouteInsight {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String suggestion;

  const RouteInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.suggestion,
  });
}

// ─────────────────────────────────────────────────────────────
// ZONAS DO ES — mapeamento de bairros/cidades
// ─────────────────────────────────────────────────────────────

class RiskZoneMap {
  static const Map<String, RiskZone> bairrosES = {
    // Vitória
    'Jardim Camburi':     RiskZone.verde,
    'Praia do Canto':     RiskZone.verde,
    'Barro Vermelho':     RiskZone.amarela,
    'Centro (Vitória)':   RiskZone.laranja,
    'São Pedro':          RiskZone.vermelha,
    'Consolação':         RiskZone.vermelha,
    'Ilha das Caieiras':  RiskZone.vermelha,
    // Serra
    'Laranjeiras':        RiskZone.verde,
    'Jardim Limoeiro':    RiskZone.amarela,
    'Serra Sede':         RiskZone.amarela,
    'Carapina':           RiskZone.laranja,
    'Nova Almeida':       RiskZone.verde,
    'Feu Rosa':           RiskZone.vermelha,
    'André Carloni':      RiskZone.vermelha,
    // Vila Velha
    'Praia de Itaparica':  RiskZone.verde,
    'Coqueiral de Itaparica': RiskZone.verde,
    'Glória':             RiskZone.amarela,
    'Vila Velha Centro':  RiskZone.laranja,
    'Paul':               RiskZone.vermelha,
    // Cariacica
    'Campo Grande':       RiskZone.laranja,
    'Alto Laje':          RiskZone.vermelha,
    'Porto de Santana':   RiskZone.critica,
    // Rodovias
    'BR-101':             RiskZone.amarela,
    'ES-010':             RiskZone.verde,
    'Terceira Ponte':     RiskZone.amarela,
  };

  static RiskZone zoneForLocation(String location) {
    for (final entry in bairrosES.entries) {
      if (location.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return RiskZone.amarela; // padrão
  }
}

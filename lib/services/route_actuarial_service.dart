// ═══════════════════════════════════════════════════════════════
// SAFEROUTE — MOTOR ATUARIAL DE ROTAS v1.0
// Calcula preço de seguro por km para 3 tipos de rota:
//   • Segura   → menor risco, maior distância, preço/km menor
//   • Rápida   → menor tempo, risco médio, preço/km médio
//   • Equilibrada → balanço ótimo risco × tempo × custo
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Configuração global de preços (editável pelo admin) ─────────
class RouteActuarialConfig {
  // Preço base por km para cada tipo de rota (R$/km)
  static double kmPriceSegura       = 0.09;  // mais barata: rota protegida
  static double kmPriceRapida       = 0.14;  // mais cara: risco e stress
  static double kmPriceEquilibrada  = 0.11;  // meio termo

  // Multiplicadores de risco por zona
  static double zoneMultiplierVerde    = 1.00;
  static double zoneMultiplierAmarela  = 1.20;
  static double zoneMultiplierLaranja  = 1.50;
  static double zoneMultiplierVermelha = 1.85;

  // Multiplicadores de horário
  static double timeMultiplierComercial  = 1.00; // 06-19h
  static double timeMultiplierNoite      = 1.25; // 19-23h
  static double timeMultiplierMadrugada  = 1.60; // 23-06h

  // Taxa mínima por viagem (R$)
  static double taxaMinimaViagem = 1.99;

  // Retorna multiplicador de zona
  static double zoneMultiplier(RouteRiskZone zone) {
    switch (zone) {
      case RouteRiskZone.verde:    return zoneMultiplierVerde;
      case RouteRiskZone.amarela:  return zoneMultiplierAmarela;
      case RouteRiskZone.laranja:  return zoneMultiplierLaranja;
      case RouteRiskZone.vermelha: return zoneMultiplierVermelha;
    }
  }

  // Retorna multiplicador de horário
  static double timeMultiplier(DateTime dt) {
    final h = dt.hour;
    if (h >= 6 && h < 19)  return timeMultiplierComercial;
    if (h >= 19 && h < 23) return timeMultiplierNoite;
    return timeMultiplierMadrugada;
  }

  static String timeLabel(DateTime dt) {
    final h = dt.hour;
    if (h >= 6 && h < 19)  return 'Comercial';
    if (h >= 19 && h < 23) return 'Noite';
    return 'Madrugada';
  }
}

// ── Enum de Tipo de Rota ─────────────────────────────────────────
enum RouteType { segura, rapida, equilibrada }

extension RouteTypeExt on RouteType {
  String get label {
    switch (this) {
      case RouteType.segura:       return 'Rota Segura';
      case RouteType.rapida:       return 'Rota Rápida';
      case RouteType.equilibrada:  return 'Rota Equilibrada';
    }
  }

  String get subtitle {
    switch (this) {
      case RouteType.segura:       return 'Menos risco, mais proteção';
      case RouteType.rapida:       return 'Menor tempo, risco moderado';
      case RouteType.equilibrada:  return 'Balanço ideal risco × tempo';
    }
  }

  IconData get icon {
    switch (this) {
      case RouteType.segura:       return Icons.security_rounded;
      case RouteType.rapida:       return Icons.bolt_rounded;
      case RouteType.equilibrada:  return Icons.balance_rounded;
    }
  }

  Color get color {
    switch (this) {
      case RouteType.segura:       return const Color(0xFF22C55E);
      case RouteType.rapida:       return const Color(0xFFF97316);
      case RouteType.equilibrada:  return const Color(0xFF3B82F6);
    }
  }

  Color get bgColor {
    switch (this) {
      case RouteType.segura:       return const Color(0xFFD6F0DF);
      case RouteType.rapida:       return const Color(0xFFFFE0C8);
      case RouteType.equilibrada:  return const Color(0xFFDBEAFE);
    }
  }

  double get baseKmPrice {
    switch (this) {
      case RouteType.segura:       return RouteActuarialConfig.kmPriceSegura;
      case RouteType.rapida:       return RouteActuarialConfig.kmPriceRapida;
      case RouteType.equilibrada:  return RouteActuarialConfig.kmPriceEquilibrada;
    }
  }
}

// ── Enum de Zona de Risco da Rota ───────────────────────────────
enum RouteRiskZone { verde, amarela, laranja, vermelha }

extension RouteRiskZoneExt on RouteRiskZone {
  String get label {
    switch (this) {
      case RouteRiskZone.verde:    return 'Zona Verde';
      case RouteRiskZone.amarela:  return 'Zona Amarela';
      case RouteRiskZone.laranja:  return 'Zona Laranja';
      case RouteRiskZone.vermelha: return 'Zona Vermelha';
    }
  }

  String get riskLabel {
    switch (this) {
      case RouteRiskZone.verde:    return 'Baixo Risco';
      case RouteRiskZone.amarela:  return 'Risco Moderado';
      case RouteRiskZone.laranja:  return 'Risco Alto';
      case RouteRiskZone.vermelha: return 'Risco Crítico';
    }
  }

  Color get fgColor {
    switch (this) {
      case RouteRiskZone.verde:    return const Color(0xFF1B6E35);
      case RouteRiskZone.amarela:  return const Color(0xFF7A5000);
      case RouteRiskZone.laranja:  return const Color(0xFF8B3000);
      case RouteRiskZone.vermelha: return const Color(0xFF8B0000);
    }
  }

  Color get bgColor {
    switch (this) {
      case RouteRiskZone.verde:    return const Color(0xFFD6F0DF);
      case RouteRiskZone.amarela:  return const Color(0xFFFFF3C4);
      case RouteRiskZone.laranja:  return const Color(0xFFFFE0C8);
      case RouteRiskZone.vermelha: return const Color(0xFFFFD6D6);
    }
  }

  int get riskPct {
    switch (this) {
      case RouteRiskZone.verde:    return 12;
      case RouteRiskZone.amarela:  return 28;
      case RouteRiskZone.laranja:  return 52;
      case RouteRiskZone.vermelha: return 78;
    }
  }

  IconData get icon {
    switch (this) {
      case RouteRiskZone.verde:    return Icons.verified_rounded;
      case RouteRiskZone.amarela:  return Icons.warning_amber_rounded;
      case RouteRiskZone.laranja:  return Icons.report_problem_rounded;
      case RouteRiskZone.vermelha: return Icons.dangerous_rounded;
    }
  }
}

// ── Segmento de Risco da Rota ────────────────────────────────────
class RouteRiskSegment {
  final String name;        // Nome do bairro/trecho
  final double kmStart;
  final double kmEnd;
  final RouteRiskZone zone;
  final String description;

  const RouteRiskSegment({
    required this.name,
    required this.kmStart,
    required this.kmEnd,
    required this.zone,
    this.description = '',
  });

  double get length => kmEnd - kmStart;
}

// ── Resultado completo de cotação de uma rota ────────────────────
class RouteActuarialResult {
  final RouteType type;

  // Distância e tempo
  final double distanceKm;
  final int estimatedMinutes;
  final String polylineGeoJson;  // para desenhar no mapa

  // Risco
  final RouteRiskZone dominantZone;  // zona predominante
  final double riskScore;            // 0.0–1.0
  final List<RouteRiskSegment> riskSegments;

  // Fatores de precificação
  final double baseKmPrice;          // R$/km base (configurável)
  final double zoneMultiplier;       // multiplicador de zona
  final double timeMultiplier;       // multiplicador de horário
  final double telemetryBonus;       // desconto por bom histórico

  // Preços calculados
  final double finalKmPrice;         // R$/km final
  final double totalPrice;           // preço total da viagem
  final double savings;              // economia vs rota mais cara

  // Explicação detalhada
  final List<String> highlights;     // pontos positivos
  final List<String> warnings;       // alertas de risco

  // Waypoints para navegação
  final List<Map<String, double>> waypoints;

  const RouteActuarialResult({
    required this.type,
    required this.distanceKm,
    required this.estimatedMinutes,
    this.polylineGeoJson = '',
    required this.dominantZone,
    required this.riskScore,
    this.riskSegments = const [],
    required this.baseKmPrice,
    required this.zoneMultiplier,
    required this.timeMultiplier,
    required this.telemetryBonus,
    required this.finalKmPrice,
    required this.totalPrice,
    this.savings = 0,
    this.highlights = const [],
    this.warnings = const [],
    this.waypoints = const [],
  });

  // Formatadores
  String get distanceFmt => '${distanceKm.toStringAsFixed(1)} km';
  String get timeFmt {
    if (estimatedMinutes < 60) return '${estimatedMinutes} min';
    final h = estimatedMinutes ~/ 60;
    final m = estimatedMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}min';
  }

  String get kmPriceFmt => 'R\$ ${finalKmPrice.toStringAsFixed(3)}/km';

  String get totalPriceFmt =>
      'R\$ ${totalPrice.toStringAsFixed(2).replaceAll('.', ',')}';

  String get savingsFmt =>
      savings > 0 ? '−R\$ ${savings.toStringAsFixed(2).replaceAll('.', ',')}' : '';
}

// ═══════════════════════════════════════════════════════════════
// MOTOR ATUARIAL DE ROTAS — Cálculo principal
// ═══════════════════════════════════════════════════════════════
class RouteActuarialEngine {
  /// Calcula as 3 rotas atuariais para uma viagem
  static List<RouteActuarialResult> calculateRoutes({
    required String origin,
    required String destination,
    double? distanceKmHint,     // distância estimada (do OSRM se disponível)
    double telemetryScore = 850, // score do motorista (0–1000)
    DateTime? departureTime,
  }) {
    final now = departureTime ?? DateTime.now();
    final baseDistance = distanceKmHint ?? _estimateDistance(origin, destination);

    // Cada rota tem características diferentes
    final seguraKm      = baseDistance * 1.18;  // 18% mais longa mas segura
    final rapidaKm      = baseDistance * 0.97;  // praticamente a mesma
    final equilibradaKm = baseDistance * 1.07;  // levemente mais longa

    final seguraMin      = (seguraKm * 3.2).round();   // mais lenta (ruas secundárias)
    final rapidaMin      = (rapidaKm * 2.1).round();   // mais rápida (avenidas)
    final equilibradaMin = (equilibradaKm * 2.6).round(); // intermediária

    // Zonas de risco dominantes por tipo de rota
    const seguraZone      = RouteRiskZone.verde;
    const rapidaZone      = RouteRiskZone.laranja;
    const equilibradaZone = RouteRiskZone.amarela;

    // Bônus de telemetria (até 15% de desconto)
    final telBonus = _telemetryBonus(telemetryScore);
    final timeMult = RouteActuarialConfig.timeMultiplier(now);

    // Calcula as 3 rotas
    final segura     = _buildRoute(RouteType.segura,      seguraKm,      seguraMin,      seguraZone,      timeMult, telBonus, origin, destination);
    final rapida     = _buildRoute(RouteType.rapida,      rapidaKm,      rapidaMin,      rapidaZone,      timeMult, telBonus, origin, destination);
    final equilibrada = _buildRoute(RouteType.equilibrada, equilibradaKm, equilibradaMin, equilibradaZone, timeMult, telBonus, origin, destination);

    // Calcula economia relativa (vs rota mais cara)
    final maxPrice = [segura.totalPrice, rapida.totalPrice, equilibrada.totalPrice].reduce(math.max);

    return [
      _addSavings(segura, maxPrice),
      _addSavings(rapida, maxPrice),
      _addSavings(equilibrada, maxPrice),
    ];
  }

  static RouteActuarialResult _buildRoute(
    RouteType type,
    double km,
    int minutes,
    RouteRiskZone zone,
    double timeMult,
    double telBonus,
    String origin,
    String destination,
  ) {
    final baseKmPrice  = type.baseKmPrice;
    final zoneMult     = RouteActuarialConfig.zoneMultiplier(zone);
    final finalKmPrice = math.max(
      0.02,
      baseKmPrice * zoneMult * timeMult * (1.0 - telBonus),
    );
    final totalPrice = math.max(
      RouteActuarialConfig.taxaMinimaViagem,
      finalKmPrice * km,
    );

    // Segmentos de risco gerados sinteticamente
    final segments = _generateRiskSegments(km, zone);

    // Highlights e warnings baseados no tipo
    final highlights = _buildHighlights(type, zone, telBonus);
    final warnings   = _buildWarnings(type, zone);

    // Waypoints fictícios (pontos da rota para o mapa)
    final waypoints  = _generateWaypoints(type, origin, destination);

    return RouteActuarialResult(
      type:            type,
      distanceKm:      km,
      estimatedMinutes: minutes,
      dominantZone:    zone,
      riskScore:       zone.riskPct / 100.0,
      riskSegments:    segments,
      baseKmPrice:     baseKmPrice,
      zoneMultiplier:  zoneMult,
      timeMultiplier:  timeMult,
      telemetryBonus:  telBonus,
      finalKmPrice:    finalKmPrice,
      totalPrice:      totalPrice,
      highlights:      highlights,
      warnings:        warnings,
      waypoints:       waypoints,
    );
  }

  static RouteActuarialResult _addSavings(RouteActuarialResult r, double maxPrice) {
    final savings = maxPrice - r.totalPrice;
    return RouteActuarialResult(
      type:             r.type,
      distanceKm:       r.distanceKm,
      estimatedMinutes: r.estimatedMinutes,
      dominantZone:     r.dominantZone,
      riskScore:        r.riskScore,
      riskSegments:     r.riskSegments,
      baseKmPrice:      r.baseKmPrice,
      zoneMultiplier:   r.zoneMultiplier,
      timeMultiplier:   r.timeMultiplier,
      telemetryBonus:   r.telemetryBonus,
      finalKmPrice:     r.finalKmPrice,
      totalPrice:       r.totalPrice,
      savings:          savings > 0.01 ? savings : 0,
      highlights:       r.highlights,
      warnings:         r.warnings,
      waypoints:        r.waypoints,
    );
  }

  // ── Geração de segmentos de risco sintéticos ─────────────────
  static List<RouteRiskSegment> _generateRiskSegments(double km, RouteRiskZone dominant) {
    final rng = math.Random(km.round() + dominant.index);
    final segments = <RouteRiskSegment>[];

    final names = ['Bairro Residencial', 'Centro Comercial', 'Av. Principal',
                   'Zona Industrial', 'Área Portuária', 'Parque Urbano',
                   'Rodovia BR', 'Acesso Rápido', 'Bairro Histórico'];

    double cursor = 0;
    int idx = 0;
    while (cursor < km) {
      final segLen = 1.5 + rng.nextDouble() * 3.0;
      final end    = math.min(cursor + segLen, km);

      // Zona varia em torno da dominante
      final zoneOffset = rng.nextInt(3) - 1; // -1, 0, +1
      final zoneIdx    = (dominant.index + zoneOffset).clamp(0, 3);
      final zone       = RouteRiskZone.values[zoneIdx];

      segments.add(RouteRiskSegment(
        name:      names[idx % names.length],
        kmStart:   cursor,
        kmEnd:     end,
        zone:      zone,
        description: zone.riskLabel,
      ));

      cursor = end;
      idx++;
    }
    return segments;
  }

  // ── Waypoints para mapa ──────────────────────────────────────
  static List<Map<String, double>> _generateWaypoints(RouteType type, String origin, String destination) {
    // Coordenadas base de Serra/ES (região padrão do app)
    // Cada tipo de rota tem desvios diferentes
    final base = <Map<String, double>>[
      {'lat': -20.1281, 'lon': -40.3086},
      {'lat': -20.1350, 'lon': -40.3150},
      {'lat': -20.1420, 'lon': -40.3220},
    ];

    switch (type) {
      case RouteType.segura:
        return [
          {'lat': -20.1281, 'lon': -40.3086},
          {'lat': -20.1310, 'lon': -40.3050},  // desvio por bairros residenciais
          {'lat': -20.1380, 'lon': -40.3080},
          {'lat': -20.1440, 'lon': -40.3170},
          {'lat': -20.1500, 'lon': -40.3200},
        ];
      case RouteType.rapida:
        return [
          {'lat': -20.1281, 'lon': -40.3086},
          {'lat': -20.1360, 'lon': -40.3140},  // reto pela avenida principal
          {'lat': -20.1500, 'lon': -40.3200},
        ];
      case RouteType.equilibrada:
        return [
          {'lat': -20.1281, 'lon': -40.3086},
          {'lat': -20.1330, 'lon': -40.3100},
          {'lat': -20.1410, 'lon': -40.3155},
          {'lat': -20.1500, 'lon': -40.3200},
        ];
    }
  }

  // ── Bônus de telemetria ──────────────────────────────────────
  static double _telemetryBonus(double score) {
    if (score >= 950) return 0.15;  // 15% desconto
    if (score >= 900) return 0.12;
    if (score >= 850) return 0.08;
    if (score >= 800) return 0.05;
    if (score >= 700) return 0.02;
    return 0.0;
  }

  // ── Highlights por tipo de rota ──────────────────────────────
  static List<String> _buildHighlights(RouteType type, RouteRiskZone zone, double telBonus) {
    final list = <String>[];
    switch (type) {
      case RouteType.segura:
        list.add('95% do percurso em Zona Verde');
        list.add('Policiamento intensificado');
        list.add('Câmeras de monitoramento');
        if (telBonus > 0) list.add('Bônus telemetria aplicado');
        break;
      case RouteType.rapida:
        list.add('Menor tempo de trajeto');
        list.add('Avenidas principais');
        list.add('Menos semáforos');
        break;
      case RouteType.equilibrada:
        list.add('Equilíbrio risco × tempo');
        list.add('Mix de vias seguras');
        list.add('Custo moderado');
        if (telBonus > 0) list.add('Bônus telemetria aplicado');
        break;
    }
    return list;
  }

  // ── Warnings por tipo de rota ────────────────────────────────
  static List<String> _buildWarnings(RouteType type, RouteRiskZone zone) {
    final list = <String>[];
    if (zone == RouteRiskZone.vermelha || zone == RouteRiskZone.laranja) {
      list.add('Área com histórico de ocorrências');
    }
    switch (type) {
      case RouteType.rapida:
        list.add('Tráfego intenso em horário de pico');
        list.add('Fique atento em cruzamentos');
        break;
      case RouteType.segura:
        if (zone.index >= 2) list.add('Alguns trechos com menor iluminação');
        break;
      case RouteType.equilibrada:
        break;
    }
    return list;
  }

  // ── Estimativa de distância por texto (fallback) ──────────────
  static double _estimateDistance(String origin, String destination) {
    // Fallback simples: estima 15km como padrão de viagem urbana
    return 15.0;
  }
}

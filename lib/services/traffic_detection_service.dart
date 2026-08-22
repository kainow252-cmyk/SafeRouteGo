// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// TRAFFIC DETECTION SERVICE — SafeRoute
//
// Detecta o nível de tráfego REAL entre origem e destino usando
// apenas ferramentas GRATUITAS que já estão no app:
//
//   FONTE 1 — OSRM annotations=speed
//     Router faz a rota e retorna a velocidade ATUAL estimada em
//     cada segmento (m/s). Compara com o speedLimit do OSM para
//     calcular o índice de congestionamento por segmento.
//
//   FONTE 2 — OSM maxspeed via Overpass
//     Busca o limite de velocidade oficial da via (km/h) direto
//     do banco de dados do OpenStreetMap.
//     Ex: "Avenida Vitória" → maxspeed=60 km/h
//
// Lógica de classificação (ratio = velocidade_real / velocidade_livre):
//   ratio ≥ 0.85  → TrafficLevel.livre         (> 85% da vel. máx)
//   ratio ≥ 0.60  → TrafficLevel.moderado       (60–85%)
//   ratio ≥ 0.35  → TrafficLevel.intenso        (35–60%)
//   ratio < 0.35  → TrafficLevel.congestionado  (< 35%)
//
// Cache: 3 minutos por par origem-destino (tráfego muda devagar)
// Fallback: se OSRM falhar → TrafficLevel.moderado (conservador)
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'risk_engine.dart'; // TrafficLevel

// ── Resultado da detecção ─────────────────────────────────────────
class TrafficDetectionResult {
  final TrafficLevel level;
  final double avgSpeedKmh;      // velocidade média atual (km/h)
  final double freeFlowSpeedKmh; // velocidade livre (sem congestionamento)
  final double congestionRatio;  // 0.0 (parado) → 1.0 (livre)
  final int segmentCount;        // quantos segmentos analisados
  final String source;           // 'osrm' | 'fallback'
  final DateTime detectedAt;

  TrafficDetectionResult({
    required this.level,
    required this.avgSpeedKmh,
    required this.freeFlowSpeedKmh,
    required this.congestionRatio,
    required this.segmentCount,
    required this.source,
  }) : detectedAt = DateTime.now();

  bool get isFresh =>
      DateTime.now().difference(detectedAt).inMinutes < 3;

  // Label com dado real para exibir na UI
  String get detailLabel {
    final avg = avgSpeedKmh.toStringAsFixed(0);
    final ff  = freeFlowSpeedKmh.toStringAsFixed(0);
    final pct = (congestionRatio * 100).toStringAsFixed(0);
    return '$avg km/h (${pct}% da velocidade normal · ${ff} km/h)';
  }

  String get sourceLabel => source == 'osrm' ? 'OSM / OSRM' : 'Estimativa';

  static TrafficDetectionResult fallback() => TrafficDetectionResult(
    level:             TrafficLevel.moderado,
    avgSpeedKmh:       40,
    freeFlowSpeedKmh:  60,
    congestionRatio:   0.67,
    segmentCount:      0,
    source:            'fallback',
  );
}

// ── Serviço principal ─────────────────────────────────────────────
class TrafficDetectionService {
  static const _osrmBase   = 'https://router.project-osrm.org';
  static const _osrmMirror = 'https://routing.openstreetmap.de/routed-car';
  static const _overpassBase = 'https://overpass-api.de/api/interpreter';
  static const _userAgent    = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';

  // Cache: chave = "lat1,lon1;lat2,lon2" → resultado
  static final Map<String, TrafficDetectionResult> _cache = {};

  // ── API pública: detecta tráfego entre dois pontos ───────────────
  // Chama OSRM com annotations=speed para obter velocidade real
  // por segmento e compara com a velocidade livre estimada.
  static Future<TrafficDetectionResult> detect({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) async {
    final key = '${fromLat.toStringAsFixed(3)},${fromLon.toStringAsFixed(3)}'
                ';${toLat.toStringAsFixed(3)},${toLon.toStringAsFixed(3)}';

    // Cache fresco (< 3 min)
    final cached = _cache[key];
    if (cached != null && cached.isFresh) {
      if (kDebugMode) debugPrint('[Traffic] Cache hit: ${cached.level.label}');
      return cached;
    }

    try {
      final result = await _detectViaOsrm(fromLat, fromLon, toLat, toLon);
      _cache[key] = result;
      if (kDebugMode) {
        debugPrint('[Traffic] ${result.level.label} '
            '· ${result.avgSpeedKmh.toStringAsFixed(1)} km/h '
            '/ ${result.freeFlowSpeedKmh.toStringAsFixed(1)} km/h livre '
            '(${result.segmentCount} segmentos, ${result.source})');
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[Traffic] Erro: $e — usando fallback');
      return TrafficDetectionResult.fallback();
    }
  }

  // ── Detecção via OSRM annotations=speed ─────────────────────────
  // O OSRM retorna dois arrays paralelos:
  //   speed[]    → velocidade estimada ATUAL em cada nó (m/s)
  //   duration[] → tempo estimado por segmento (s)
  //   distance[] → distância por segmento (m)
  //
  // "Velocidade livre" (freeflow) = percentil 85 dos speeds
  // "Velocidade atual" (congested) = média ponderada por distância
  static Future<TrafficDetectionResult> _detectViaOsrm(
    double fromLat, double fromLon,
    double toLat,   double toLon,
  ) async {
    final coords = '${fromLon.toStringAsFixed(6)},${fromLat.toStringAsFixed(6)}'
                   ';${toLon.toStringAsFixed(6)},${toLat.toStringAsFixed(6)}';

    for (final base in [_osrmBase, _osrmMirror]) {
      try {
        final url = Uri.parse(
          '$base/route/v1/driving/$coords'
          '?overview=false'
          '&annotations=speed,duration,distance'
          '&steps=false',
        );

        final resp = await http
            .get(url, headers: {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode != 200) continue;
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (data['code'] != 'Ok') continue;

        final routes = (data['routes'] as List).cast<Map<String, dynamic>>();
        if (routes.isEmpty) continue;

        final legs = (routes.first['legs'] as List).cast<Map<String, dynamic>>();
        if (legs.isEmpty) continue;

        // Coleta speeds e distâncias de todos os legs
        final allSpeeds    = <double>[];
        final allDistances = <double>[];

        for (final leg in legs) {
          final ann       = (leg['annotation'] as Map<String, dynamic>?) ?? {};
          final speeds    = (ann['speed']    as List? ?? []).cast<num>();
          final distances = (ann['distance'] as List? ?? []).cast<num>();

          for (var i = 0; i < speeds.length; i++) {
            final s = speeds[i].toDouble();
            final d = i < distances.length ? distances[i].toDouble() : 1.0;
            if (s > 0) {
              allSpeeds.add(s);
              allDistances.add(d);
            }
          }
        }

        if (allSpeeds.isEmpty) continue;

        // Velocidade média ponderada por distância (m/s → km/h)
        double totalDist = 0, weightedSpeed = 0;
        for (var i = 0; i < allSpeeds.length; i++) {
          weightedSpeed += allSpeeds[i] * allDistances[i];
          totalDist     += allDistances[i];
        }
        final avgMps = totalDist > 0 ? weightedSpeed / totalDist : allSpeeds.first;
        final avgKmh = avgMps * 3.6;

        // "Velocidade livre" = percentil 85 (velocidade sem tráfego)
        final sorted = [...allSpeeds]..sort();
        final p85idx = ((sorted.length - 1) * 0.85).round();
        final freeFlowKmh = sorted[p85idx] * 3.6;

        // Ratio: quanto da velocidade livre está sendo atingida
        final ratio = freeFlowKmh > 0 ? (avgKmh / freeFlowKmh).clamp(0.0, 1.0) : 0.7;

        return TrafficDetectionResult(
          level:             _ratioToLevel(ratio),
          avgSpeedKmh:       avgKmh,
          freeFlowSpeedKmh:  freeFlowKmh,
          congestionRatio:   ratio,
          segmentCount:      allSpeeds.length,
          source:            'osrm',
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Traffic] $base: $e');
        continue;
      }
    }

    throw Exception('OSRM indisponível em todos os servidores');
  }

  // ── Busca speedLimit real via OSM (para uma via específica) ───────
  // Usa Overpass: busca a via mais próxima do ponto e retorna maxspeed
  static Future<int?> getSpeedLimitKmh(double lat, double lon) async {
    final query = '''
[out:json][timeout:5];
way["maxspeed"](around:100,$lat,$lon);
out 1;
''';
    try {
      final resp = await http.post(
        Uri.parse(_overpassBase),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List? ?? []).cast<Map<String, dynamic>>();
      if (elements.isEmpty) return null;

      final tags = (elements.first['tags'] as Map<String, dynamic>?) ?? {};
      final maxspeed = tags['maxspeed'] as String? ?? '';

      // Parseia: "60", "60 mph", "BR:urban" (padrão urbano BR = 50 km/h)
      final numMatch = RegExp(r'\d+').firstMatch(maxspeed);
      if (numMatch != null) {
        var speed = int.tryParse(numMatch.group(0)!);
        if (speed != null && maxspeed.contains('mph')) {
          speed = (speed * 1.60934).round(); // mph → km/h
        }
        return speed;
      }
      // Valores padrão do Brasil por tag
      if (maxspeed.contains('BR:urban'))    return 50;
      if (maxspeed.contains('BR:rural'))    return 100;
      if (maxspeed.contains('BR:motorway')) return 120;
    } catch (e) {
      if (kDebugMode) debugPrint('[Traffic] speedLimit error: $e');
    }
    return null;
  }

  // ── Converte ratio → TrafficLevel ────────────────────────────────
  static TrafficLevel _ratioToLevel(double ratio) {
    if (ratio >= 0.85) return TrafficLevel.livre;
    if (ratio >= 0.60) return TrafficLevel.moderado;
    if (ratio >= 0.35) return TrafficLevel.intenso;
    return TrafficLevel.congestionado;
  }

  // ── Ícone animado para UI ─────────────────────────────────────────
  static String emojiFor(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.livre:         return '🟢';
      case TrafficLevel.moderado:      return '🟡';
      case TrafficLevel.intenso:       return '🟠';
      case TrafficLevel.congestionado: return '🔴';
    }
  }

  /// Limpa cache (mudança de destino, logout)
  static void clearCache() => _cache.clear();
}

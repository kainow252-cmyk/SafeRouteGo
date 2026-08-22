// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// OSRM ROUTE SERVICE — SafeRoute
//
// Project OSRM (Open Source Routing Machine) é o motor de rotas
// open-source mais rápido do mundo, baseado em OpenStreetMap.
// 100% GRATUITO — sem API key, sem cadastro, sem limites fixos.
//
// Endpoint público: router.project-osrm.org
// Alternativas:   routing.openstreetmap.de (espelho)
//
// Funcionalidades implementadas:
//   • Cálculo de rota carro/pedestre entre dois pontos GPS
//   • Duração e distância totais
//   • Polyline decodificada para exibir no mapa
//   • Instruções de navegação passo-a-passo
//   • ETA com horário de chegada estimado
//
// Endpoint: /route/v1/{profile}/{coords}
//   profile = 'driving' | 'walking' | 'cycling'
//   coords  = "lon1,lat1;lon2,lat2"
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Passo de navegação ────────────────────────────────────────────
class RouteStep {
  final String instruction;
  final double distanceM;
  final double durationS;
  final String maneuverType; // 'turn', 'depart', 'arrive', etc.
  final String? streetName;

  const RouteStep({
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    required this.maneuverType,
    this.streetName,
  });

  String get distanceLabel {
    if (distanceM >= 1000) return '${(distanceM / 1000).toStringAsFixed(1)} km';
    return '${distanceM.toStringAsFixed(0)} m';
  }
}

// ── Rota completa ─────────────────────────────────────────────────
class OsrmRoute {
  final double distanceM;   // distância total em metros
  final double durationS;   // duração total em segundos
  final List<LatLon> polyline; // pontos para desenhar no mapa
  final List<RouteStep> steps;
  final String profile;     // 'driving', 'walking', 'cycling'

  const OsrmRoute({
    required this.distanceM,
    required this.durationS,
    required this.polyline,
    required this.steps,
    required this.profile,
  });

  String get distanceLabel {
    if (distanceM >= 1000) return '${(distanceM / 1000).toStringAsFixed(1)} km';
    return '${distanceM.toStringAsFixed(0)} m';
  }

  String get durationLabel {
    final mins = (durationS / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '${h}h ${m}min' : '${h}h';
  }

  String get etaLabel {
    final arrival = DateTime.now().add(Duration(seconds: durationS.toInt()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Resumo formatado: "12,4 km · 23 min · Chega às 14:35"
  String get summary => '$distanceLabel · $durationLabel · Chega às $etaLabel';
}

// Ponto geográfico simples
class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
}

// ── Serviço principal ─────────────────────────────────────────────
class OsrmRouteService {
  static const _mainServer  = 'https://router.project-osrm.org';
  static const _mirror      = 'https://routing.openstreetmap.de/routed-car';
  static const _userAgent   = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';

  // Cache de rotas (origem+destino+perfil → rota)
  static final Map<String, OsrmRoute> _cache = {};

  // ── Calcula rota entre dois pontos ───────────────────────────────
  static Future<OsrmRoute?> getRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String profile = 'driving', // 'driving' | 'walking' | 'cycling'
  }) async {
    final cacheKey = '${fromLat.toStringAsFixed(4)},${fromLon.toStringAsFixed(4)}'
        ';${toLat.toStringAsFixed(4)},${toLon.toStringAsFixed(4)};$profile';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final coords = '${fromLon.toStringAsFixed(6)},${fromLat.toStringAsFixed(6)}'
        ';${toLon.toStringAsFixed(6)},${toLat.toStringAsFixed(6)}';

    for (final baseUrl in [_mainServer, _mirror]) {
      try {
        final url = Uri.parse(
          '$baseUrl/route/v1/$profile/$coords'
          '?overview=full'         // polyline completa
          '&geometries=polyline6'  // polyline codificada (mais compacta)
          '&steps=true'            // instruções passo-a-passo
          '&language=pt'           // tenta português
          '&annotations=false',
        );

        final response = await http
            .get(url, headers: {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) continue;
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['code'] != 'Ok') {
          if (kDebugMode) debugPrint('[OSRM] code: ${data["code"]} msg: ${data["message"]}');
          continue;
        }

        final routes = (data['routes'] as List? ?? []).cast<Map<String, dynamic>>();
        if (routes.isEmpty) continue;

        final route = routes.first;
        final distanceM = (route['distance'] as num? ?? 0).toDouble();
        final durationS = (route['duration'] as num? ?? 0).toDouble();
        final geometry  = route['geometry'] as String? ?? '';

        // Decodifica polyline6 → lista de LatLon
        final polyline = _decodePolyline6(geometry);

        // Parseia steps
        final steps = <RouteStep>[];
        final legs = (route['legs'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final leg in legs) {
          final legSteps = (leg['steps'] as List? ?? []).cast<Map<String, dynamic>>();
          for (final step in legSteps) {
            final maneuver = (step['maneuver'] as Map<String, dynamic>?) ?? {};
            final instruction = _buildInstruction(step, maneuver);
            steps.add(RouteStep(
              instruction:  instruction,
              distanceM:    (step['distance'] as num? ?? 0).toDouble(),
              durationS:    (step['duration'] as num? ?? 0).toDouble(),
              maneuverType: maneuver['type'] as String? ?? '',
              streetName:   (step['name'] as String?)?.isNotEmpty == true
                                ? step['name'] as String : null,
            ));
          }
        }

        final result = OsrmRoute(
          distanceM: distanceM,
          durationS: durationS,
          polyline:  polyline,
          steps:     steps,
          profile:   profile,
        );

        _cache[cacheKey] = result;
        if (kDebugMode) debugPrint('[OSRM] Rota: ${result.distanceLabel} / ${result.durationLabel}');
        return result;
      } catch (e) {
        if (kDebugMode) debugPrint('[OSRM] $baseUrl error: $e');
        continue;
      }
    }
    return null;
  }

  // ── Decodifica Polyline6 (precisão 1e-6) ─────────────────────────
  // OSRM usa polyline6 (6 casas decimais) em vez do polyline5 padrão.
  // Algoritmo de Encoded Polyline Format do Google (adaptado para 6).
  static List<LatLon> _decodePolyline6(String encoded) {
    final points = <LatLon>[];
    int index = 0;
    int lat = 0, lon = 0;

    while (index < encoded.length) {
      int result = 0, shift = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0; shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlon = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lon += dlon;

      points.add(LatLon(lat / 1e6, lon / 1e6));
    }
    return points;
  }

  // ── Gera instrução legível em português ─────────────────────────
  static String _buildInstruction(
    Map<String, dynamic> step,
    Map<String, dynamic> maneuver,
  ) {
    final type      = maneuver['type']     as String? ?? '';
    final modifier  = maneuver['modifier'] as String? ?? '';
    final streetName = (step['name'] as String?)?.isNotEmpty == true
        ? step['name'] as String : null;
    final distM = (step['distance'] as num? ?? 0).toDouble();

    final dist = distM >= 1000
        ? '${(distM / 1000).toStringAsFixed(1)} km'
        : '${distM.toStringAsFixed(0)} m';

    String action;
    switch (type) {
      case 'depart':   action = 'Siga em frente'; break;
      case 'arrive':   action = 'Chegou ao destino'; break;
      case 'turn':
        switch (modifier) {
          case 'left':        action = 'Vire à esquerda'; break;
          case 'right':       action = 'Vire à direita'; break;
          case 'slight left': action = 'Mantenha à esquerda'; break;
          case 'slight right':action = 'Mantenha à direita'; break;
          case 'sharp left':  action = 'Curva fechada à esquerda'; break;
          case 'sharp right': action = 'Curva fechada à direita'; break;
          case 'uturn':       action = 'Retorne'; break;
          default:            action = 'Vire'; break;
        }
        break;
      case 'merge':     action = 'Entre na pista'; break;
      case 'on ramp':   action = 'Entre na rodovia'; break;
      case 'off ramp':  action = 'Saia da rodovia'; break;
      case 'fork':
        action = modifier.contains('left') ? 'Na bifurcação, mantenha à esquerda'
                                           : 'Na bifurcação, mantenha à direita';
        break;
      case 'end of road':
        action = modifier.contains('left') ? 'No fim da rua, vire à esquerda'
                                           : 'No fim da rua, vire à direita';
        break;
      case 'roundabout':
        final exit = maneuver['exit'] as int? ?? 1;
        action = 'Na rotatória, tome a ${exit}ª saída';
        break;
      default:          action = 'Continue'; break;
    }

    if (streetName != null && type != 'arrive') {
      return '$action na $streetName ($dist)';
    }
    if (type == 'arrive') return action;
    return '$action ($dist)';
  }

  // ── Distância em km (Haversine) ──────────────────────────────────
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Limpa cache (testes / logout)
  static void clearCache() => _cache.clear();
}

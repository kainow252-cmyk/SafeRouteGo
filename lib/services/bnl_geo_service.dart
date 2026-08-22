// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// BnL GEO SERVICE — Boxes'n'Lines Geolocation API
// https://docs.boxesnlines.com/api-reference/#tag/geolocation
//
// 4 endpoints disponíveis:
//  GET /geo/country/fromGps/{lat},{lon}       → "BRA", "USA"…
//  GET /geo/country/{code}/isInCountry        → true/false
//  GET /geo/subdivision/fromGps/{lat},{lon}   → "BR-SP", "BR-RJ"…
//  GET /geo/subdivision/{code}/isInSubdivision → true/false
//
// Retorna UF brasileira instantaneamente (ex: "BR-SP" → "SP")
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BnLGeoService {
  static const _apiKey = 'bnl_nXJHNiMq_WE8015OEO33865Ao369VnAqg3dU1ddw1';
  static const _base = 'https://api.boxesnlines.com';
  static const _headers = {'X-Api-Key': _apiKey};
  static const _timeout = Duration(seconds: 8);

  // Cache simples para não re-bater a API com as mesmas coords
  static final Map<String, _GeoResult> _cache = {};

  // ─────────────────────────────────────────────────────────────────────────
  // ENDPOINT 1: Reverse geocode → país (ISO 3166-1 alpha-3)
  //   GET /geo/country/fromGps/{lat},{lon}
  //   Retorna: "BRA", "USA", "PRT"…
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> getCountryFromGps(double lat, double lon) async {
    final key = 'country|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}';
    if (_cache[key] != null && !_cache[key]!.isStale) {
      return _cache[key]!.value;
    }
    try {
      final uri = Uri.parse('$_base/geo/country/fromGps/$lat,$lon');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final val = jsonDecode(resp.body) as String?;
        _cache[key] = _GeoResult(val);
        return val;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BnL getCountryFromGps: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENDPOINT 2: Reverse geocode → subdivisão (ISO 3166-2)
  //   GET /geo/subdivision/fromGps/{lat},{lon}
  //   Retorna: "BR-SP", "BR-RJ", "US-CA"…
  //
  //   Para o Brasil retorna o código UF diretamente (BR-SP → SP)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> getSubdivisionFromGps(double lat, double lon) async {
    final key = 'sub|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}';
    if (_cache[key] != null && !_cache[key]!.isStale) {
      return _cache[key]!.value;
    }
    try {
      final uri = Uri.parse('$_base/geo/subdivision/fromGps/$lat,$lon');
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final val = jsonDecode(resp.body) as String?;
        _cache[key] = _GeoResult(val);
        return val; // ex: "BR-SP"
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BnL getSubdivisionFromGps: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENDPOINT 3: Está no Brasil?
  //   GET /geo/country/{code}/isInCountry?latitude=&longitude=
  //   code: ISO 3166-1 alpha-3 (BRA)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> isInBrazil(double lat, double lon) async {
    final key = 'inBRA|${lat.toStringAsFixed(2)}|${lon.toStringAsFixed(2)}';
    if (_cache[key] != null && !_cache[key]!.isStale) {
      return _cache[key]!.value == 'true';
    }
    try {
      final uri = Uri.parse(
        '$_base/geo/country/BRA/isInCountry?latitude=$lat&longitude=$lon',
      );
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final val = jsonDecode(resp.body) as bool? ?? false;
        _cache[key] = _GeoResult(val.toString());
        return val;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BnL isInBrazil: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENDPOINT 4: Está na subdivisão?
  //   GET /geo/subdivision/{code}/isInSubdivision?latitude=&longitude=
  //   code: ISO 3166-2 (BR-SP, BR-RJ…)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> isInSubdivision(
    String subdivCode,
    double lat,
    double lon,
  ) async {
    final key = 'inSub|$subdivCode|${lat.toStringAsFixed(2)}|${lon.toStringAsFixed(2)}';
    if (_cache[key] != null && !_cache[key]!.isStale) {
      return _cache[key]!.value == 'true';
    }
    try {
      final uri = Uri.parse(
        '$_base/geo/subdivision/$subdivCode/isInSubdivision?latitude=$lat&longitude=$lon',
      );
      final resp = await http.get(uri, headers: _headers).timeout(_timeout);
      if (resp.statusCode == 200) {
        final val = jsonDecode(resp.body) as bool? ?? false;
        _cache[key] = _GeoResult(val.toString());
        return val;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BnL isInSubdivision: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER: GPS → UF brasileira (código 2 letras)
  //   Usa getSubdivisionFromGps e extrai "SP" de "BR-SP"
  //   Retorna null se fora do Brasil
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> getUFFromGps(double lat, double lon) async {
    final subdiv = await getSubdivisionFromGps(lat, lon);
    if (subdiv == null) return null;
    // "BR-SP" → "SP", "BR-RJ" → "RJ"
    if (subdiv.startsWith('BR-') && subdiv.length == 5) {
      return subdiv.substring(3);
    }
    return null; // fora do Brasil
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER: GPS → resultado completo (país + UF + isBrazil)
  //   Faz 2 calls em paralelo: country + subdivision
  // ─────────────────────────────────────────────────────────────────────────
  static Future<GpsGeoResult> getFullGeoFromGps(double lat, double lon) async {
    try {
      final results = await Future.wait([
        getCountryFromGps(lat, lon),
        getSubdivisionFromGps(lat, lon),
      ]);

      final country = results[0];   // "BRA"
      final subdiv = results[1];    // "BR-SP"

      final isBrazil = country == 'BRA';
      String? uf;
      if (isBrazil && subdiv != null && subdiv.startsWith('BR-') && subdiv.length == 5) {
        uf = subdiv.substring(3);
      }

      return GpsGeoResult(
        lat: lat,
        lon: lon,
        country: country,
        subdivision: subdiv,
        uf: uf,
        isBrazil: isBrazil,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('BnL getFullGeoFromGps: $e');
      return GpsGeoResult(lat: lat, lon: lon);
    }
  }

  static void clearCache() => _cache.clear();
}

// ─────────────────────────────────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────────────────────────────────

class GpsGeoResult {
  final double lat;
  final double lon;
  final String? country;       // "BRA", "USA"…
  final String? subdivision;   // "BR-SP", "US-CA"…
  final String? uf;            // "SP", "RJ"… (só Brasil)
  final bool isBrazil;

  const GpsGeoResult({
    required this.lat,
    required this.lon,
    this.country,
    this.subdivision,
    this.uf,
    this.isBrazil = false,
  });

  String get ufDisplay => uf ?? '??';

  String get countryDisplay {
    const names = {
      'BRA': 'Brasil', 'USA': 'EUA', 'ARG': 'Argentina',
      'URY': 'Uruguai', 'PRY': 'Paraguai', 'BOL': 'Bolívia',
      'PER': 'Peru', 'COL': 'Colômbia', 'VEN': 'Venezuela',
      'GUY': 'Guiana', 'SUR': 'Suriname', 'GUF': 'Guiana Francesa',
      'PRT': 'Portugal', 'ESP': 'Espanha', 'GBR': 'Reino Unido',
    };
    return names[country] ?? country ?? 'Desconhecido';
  }

  String get ufFullName {
    const names = {
      'AC': 'Acre', 'AL': 'Alagoas', 'AM': 'Amazonas', 'AP': 'Amapá',
      'BA': 'Bahia', 'CE': 'Ceará', 'DF': 'Distrito Federal',
      'ES': 'Espírito Santo', 'GO': 'Goiás', 'MA': 'Maranhão',
      'MG': 'Minas Gerais', 'MS': 'Mato Grosso do Sul', 'MT': 'Mato Grosso',
      'PA': 'Pará', 'PB': 'Paraíba', 'PE': 'Pernambuco', 'PI': 'Piauí',
      'PR': 'Paraná', 'RJ': 'Rio de Janeiro', 'RN': 'Rio Grande do Norte',
      'RO': 'Rondônia', 'RR': 'Roraima', 'RS': 'Rio Grande do Sul',
      'SC': 'Santa Catarina', 'SE': 'Sergipe', 'SP': 'São Paulo',
      'TO': 'Tocantins',
    };
    return names[uf] ?? uf ?? 'Estado desconhecido';
  }

  @override
  String toString() =>
      'GpsGeoResult(lat:$lat, lon:$lon, country:$country, subdiv:$subdivision, uf:$uf)';
}

class _GeoResult {
  final String? value;
  final DateTime _created;

  _GeoResult(this.value) : _created = DateTime.now();

  // Cache expira em 5 minutos (usuário pode ter se movido para outro estado)
  bool get isStale =>
      DateTime.now().difference(_created) > const Duration(minutes: 5);
}

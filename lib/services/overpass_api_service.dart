// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// OVERPASS API SERVICE — SafeRoute
//
// Overpass API é o motor oficial de busca do OpenStreetMap (OSM).
// 100% GRATUITA — sem API key, sem cadastro, sem limites fixos.
//
// Casos de uso:
//   • Busca por nome de POI (Shopping Vitória, Hospital X, etc.)
//   • Busca de estabelecimentos por tipo e proximidade
//   • Localização exata de pontos específicos que Nominatim não indexa
//
// Estratégia de query (Overpass QL):
//   - nwr = nodes + ways + relations (cobre tudo)
//   - ["name"~"termo",i] = busca case-insensitive no nome
//   - (around:raio,lat,lon) = restringe a X metros do ponto GPS
//   - out center = retorna centroide de polígonos (shoppings, etc.)
//
// Rate limit sugerido: max 1 req/segundo por IP
// Servidor: overpass-api.de (principal) + overpass.kumi.systems (espelho)
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'address_search_service.dart';

// ── Resultado de POI do Overpass ─────────────────────────────────
class OverpassPoi {
  final String osmId;
  final String osmType; // 'node', 'way', 'relation'
  final String name;
  final double lat;
  final double lon;
  final String? amenity;      // hospital, parking, fuel, etc.
  final String? shop;         // supermarket, mall, clothes, etc.
  final String? tourism;      // hotel, museum, attraction, etc.
  final String? highway;      // bus_stop, etc.
  final String? brand;        // Petrobras, Shell, etc.
  final String? street;
  final String? housenumber;
  final String? city;
  final String? postcode;
  final String? phone;
  final String? website;
  final String? openingHours;

  const OverpassPoi({
    required this.osmId,
    required this.osmType,
    required this.name,
    required this.lat,
    required this.lon,
    this.amenity,
    this.shop,
    this.tourism,
    this.highway,
    this.brand,
    this.street,
    this.housenumber,
    this.city,
    this.postcode,
    this.phone,
    this.website,
    this.openingHours,
  });

  // Ícone para exibir na UI
  IconHint get iconHint {
    if (amenity == 'hospital' || amenity == 'clinic') return IconHint.hospital;
    if (amenity == 'police') return IconHint.police;
    if (amenity == 'fuel') return IconHint.fuel;
    if (amenity == 'parking') return IconHint.parking;
    if (amenity == 'school' || amenity == 'university') return IconHint.school;
    if (amenity == 'bank' || amenity == 'atm') return IconHint.bank;
    if (amenity == 'restaurant' || amenity == 'cafe' || amenity == 'fast_food') return IconHint.food;
    if (shop == 'mall' || shop == 'supermarket') return IconHint.shopping;
    if (tourism != null) return IconHint.tourism;
    return IconHint.poi;
  }

  // Subtítulo formatado
  String get subtitle {
    final parts = <String>[];
    if (brand != null && brand != name) parts.add(brand!);
    final addr = <String>[];
    if (street != null) addr.add(street!);
    if (housenumber != null) addr.add(housenumber!);
    if (addr.isNotEmpty) parts.add(addr.join(', '));
    if (city != null) parts.add(city!);
    return parts.isNotEmpty ? parts.join(' · ') : _typeLabel;
  }

  String get _typeLabel {
    if (amenity != null) return _ptLabel(amenity!);
    if (shop != null) return _ptLabel(shop!);
    if (tourism != null) return _ptLabel(tourism!);
    return 'Local';
  }

  static String _ptLabel(String tag) {
    const map = {
      'hospital': 'Hospital', 'clinic': 'Clínica', 'doctors': 'Médico',
      'police': 'Delegacia', 'fire_station': 'Bombeiros',
      'fuel': 'Posto de gasolina', 'parking': 'Estacionamento',
      'school': 'Escola', 'university': 'Universidade',
      'bank': 'Banco', 'atm': 'Caixa eletrônico',
      'restaurant': 'Restaurante', 'cafe': 'Café', 'fast_food': 'Fast food',
      'mall': 'Shopping', 'supermarket': 'Supermercado',
      'hotel': 'Hotel', 'museum': 'Museu', 'attraction': 'Atração turística',
      'bus_station': 'Terminal de ônibus', 'pharmacy': 'Farmácia',
    };
    return map[tag] ?? tag.replaceAll('_', ' ');
  }

  // Converte para AddressResult (compatível com o restante do app)
  AddressResult toAddressResult() => AddressResult(
    title: name,
    subtitle: subtitle,
    lat: lat,
    lon: lon,
    isCity: false,
  );
}

enum IconHint { hospital, police, fuel, parking, school, bank, food, shopping, tourism, poi }

// ── Serviço principal ─────────────────────────────────────────────
class OverpassApiService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';
  static const _mirror   = 'https://overpass.kumi.systems/api/interpreter';
  static const _userAgent = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';

  // Cache em memória (query → resultados)
  static final Map<String, List<OverpassPoi>> _cache = {};

  // ── 1. Busca POI por nome (SEM restrição geográfica) ──────────────
  // Uso: "Shopping Vitória", "Hospital X", "Petrobras"
  // Retorna até `limit` resultados
  static Future<List<OverpassPoi>> searchByName(
    String name, {
    int limit = 10,
    double? nearLat,
    double? nearLon,
    double radiusKm = 50.0,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return [];

    final cacheKey = 'name:${cleanName.toLowerCase()}:${nearLat?.toStringAsFixed(2)}:${nearLon?.toStringAsFixed(2)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Monta query Overpass QL
    String query;
    if (nearLat != null && nearLon != null) {
      final radiusM = (radiusKm * 1000).toInt();
      // Busca próxima ao GPS do usuário
      query = '''
[out:json][timeout:8];
(
  nwr["name"~"${_escapeOql(cleanName)}",i](around:$radiusM,$nearLat,$nearLon);
);
out center $limit;
''';
    } else {
      // Busca nacional (mais lenta — só para nomes muito específicos)
      query = '''
[out:json][timeout:10];
(
  nwr["name"~"^${_escapeOql(cleanName)}\$",i]["name"]["name"~"${_escapeOql(cleanName)}",i];
);
out center $limit;
''';
    }

    try {
      final results = await _runQuery(query);
      if (results != null) {
        _cache[cacheKey] = results;
        return results;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Overpass] searchByName error: $e');
    }
    return [];
  }

  // ── 2. Busca POI por tipo próximo ao usuário ──────────────────────
  // Uso: hospitais próximos, postos de gasolina, delegacias
  // tag: 'amenity=hospital', 'shop=mall', 'tourism=hotel'
  static Future<List<OverpassPoi>> searchByType({
    required String tag,   // ex: 'amenity=hospital'
    required double lat,
    required double lon,
    double radiusKm = 10.0,
    int limit = 10,
  }) async {
    final radiusM = (radiusKm * 1000).toInt();
    final cacheKey = 'type:$tag:${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Divide tag em chave=valor
    final parts = tag.split('=');
    if (parts.length != 2) return [];
    final key = parts[0].trim();
    final value = parts[1].trim();

    final query = '''
[out:json][timeout:8];
(
  nwr["$key"="$value"](around:$radiusM,$lat,$lon);
);
out center $limit;
''';

    try {
      final results = await _runQuery(query);
      if (results != null) {
        _cache[cacheKey] = results;
        return results;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Overpass] searchByType error: $e');
    }
    return [];
  }

  // ── 3. Busca emergência — hospitais + delegacias + bombeiros ──────
  // Chamada única para o formulário de sinistro
  static Future<Map<String, List<OverpassPoi>>> searchEmergencyNearby({
    required double lat,
    required double lon,
    double radiusKm = 15.0,
  }) async {
    final radiusM = (radiusKm * 1000).toInt();
    final query = '''
[out:json][timeout:10];
(
  nwr["amenity"~"^(hospital|clinic|police|fire_station)\$"](around:$radiusM,$lat,$lon);
);
out center 20;
''';
    final all = await _runQuery(query) ?? [];
    final result = <String, List<OverpassPoi>>{
      'hospital': [],
      'police':   [],
      'fire':     [],
    };
    for (final poi in all) {
      if (poi.amenity == 'hospital' || poi.amenity == 'clinic') {
        result['hospital']!.add(poi);
      } else if (poi.amenity == 'police') {
        result['police']!.add(poi);
      } else if (poi.amenity == 'fire_station') {
        result['fire']!.add(poi);
      }
    }
    return result;
  }

  // ── Executa query e parseia resultado ────────────────────────────
  static Future<List<OverpassPoi>?> _runQuery(String query) async {
    // Tenta endpoint principal, depois espelho
    for (final endpoint in [_endpoint, _mirror]) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': _userAgent,
          },
          body: 'data=${Uri.encodeComponent(query)}',
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) continue;
        final data = json.decode(response.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List? ?? []).cast<Map<String, dynamic>>();
        final pois = elements
            .map(_parseElement)
            .where((p) => p != null && p.name.isNotEmpty)
            .cast<OverpassPoi>()
            .toList();
        if (kDebugMode) debugPrint('[Overpass] ${pois.length} POIs encontrados');
        return pois;
      } catch (e) {
        if (kDebugMode) debugPrint('[Overpass] $endpoint falhou: $e');
        continue;
      }
    }
    return null;
  }

  // ── Parseia elemento OSM → OverpassPoi ───────────────────────────
  static OverpassPoi? _parseElement(Map<String, dynamic> el) {
    try {
      final type = el['type'] as String? ?? 'node';
      final id   = el['id']?.toString() ?? '';
      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
      final name = (tags['name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      // Coordenadas — nodes têm lat/lon direto, ways/relations têm 'center'
      double lat, lon;
      if (type == 'node') {
        lat = (el['lat'] as num? ?? 0).toDouble();
        lon = (el['lon'] as num? ?? 0).toDouble();
      } else {
        final center = el['center'] as Map<String, dynamic>?;
        if (center == null) return null;
        lat = (center['lat'] as num? ?? 0).toDouble();
        lon = (center['lon'] as num? ?? 0).toDouble();
      }
      if (lat == 0 && lon == 0) return null;

      return OverpassPoi(
        osmId:        id,
        osmType:      type,
        name:         name,
        lat:          lat,
        lon:          lon,
        amenity:      tags['amenity']          as String?,
        shop:         tags['shop']             as String?,
        tourism:      tags['tourism']          as String?,
        highway:      tags['highway']          as String?,
        brand:        tags['brand']            as String?,
        street:       tags['addr:street']      as String?,
        housenumber:  tags['addr:housenumber'] as String?,
        city:         tags['addr:city']        as String?,
        postcode:     tags['addr:postcode']    as String?,
        phone:        tags['phone']            as String?,
        website:      tags['website']          as String?,
        openingHours: tags['opening_hours']    as String?,
      );
    } catch (e) {
      return null;
    }
  }

  // Escapa caracteres especiais para Overpass QL regex
  static String _escapeOql(String s) {
    var r = s;
    r = r.replaceAll('\\', '\\\\');
    r = r.replaceAll('"', '\\"');
    r = r.replaceAll('[', '\\[');
    r = r.replaceAll(']', '\\]');
    r = r.replaceAll('(', '\\(');
    r = r.replaceAll(')', '\\)');
    r = r.replaceAll('.', '\\.');
    return r;
  }

  /// Limpa cache (testes / logout)
  static void clearCache() => _cache.clear();
}

// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// PHOTON API SERVICE — SafeRoute
//
// Photon é uma API de geocodificação aberta do Komoot, construída
// sobre dados do OpenStreetMap.
// 100% GRATUITA — sem API key, sem cadastro.
//
// Casos de uso no SafeRoute:
//   • Autocomplete rápido enquanto o usuário digita (< 300ms)
//   • Barra de busca que sugere "Shopp..." → "Shopping Vitória"
//   • Geocodificação de endereços e POIs
//   • Complemento ao Mapbox quando query é POI específico
//
// Endpoint: https://photon.komoot.io/api/
// Parâmetros principais:
//   q     = termo de busca
//   lat   = latitude para priorizar resultados próximos
//   lon   = longitude para priorizar resultados próximos
//   limit = máx resultados
//   lang  = idioma (pt, en, de, fr...)
//   bbox  = caixa delimitadora opcional (lon_min,lat_min,lon_max,lat_max)
//
// Rate limit: generoso (~10 req/s), mas use debounce de 300ms
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'address_search_service.dart';

// ── Resultado Photon ──────────────────────────────────────────────
class PhotonResult {
  final String osmId;
  final String osmType;   // N/W/R
  final String name;
  final double lat;
  final double lon;
  final String? street;
  final String? housenumber;
  final String? city;
  final String? district;   // bairro
  final String? county;     // município
  final String? state;
  final String? country;
  final String? postcode;
  final String? osmKey;     // amenity, shop, tourism, highway...
  final String? osmValue;   // hospital, mall, museum, residential...

  const PhotonResult({
    required this.osmId,
    required this.osmType,
    required this.name,
    required this.lat,
    required this.lon,
    this.street,
    this.housenumber,
    this.city,
    this.district,
    this.county,
    this.state,
    this.country,
    this.postcode,
    this.osmKey,
    this.osmValue,
  });

  // Subtítulo legível para a UI
  String get subtitle {
    final parts = <String>[];
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (city != null && city!.isNotEmpty)          parts.add(city!);
    if (state != null && state!.isNotEmpty)         parts.add(state!);
    return parts.isNotEmpty ? parts.join(' — ') : (country ?? '');
  }

  // Título completo com número se disponível
  String get displayTitle {
    if (street != null && name == street && housenumber != null) {
      return '$street, $housenumber';
    }
    return name;
  }

  bool get isPoi => osmKey != null && osmKey != 'place';
  bool get isAddress => osmKey == null || osmKey == 'place';

  // Converte para AddressResult (compatível com o app inteiro)
  AddressResult toAddressResult() => AddressResult(
    title: displayTitle,
    subtitle: subtitle,
    lat: lat,
    lon: lon,
    isCity: osmValue == 'city' || osmValue == 'town',
    cep: postcode,
  );

  factory PhotonResult.fromJson(Map<String, dynamic> json) {
    final props = (json['properties'] as Map<String, dynamic>?) ?? {};
    final geo   = (json['geometry']   as Map<String, dynamic>?) ?? {};
    final coords = (geo['coordinates'] as List?)?.cast<num>() ?? [0, 0];

    return PhotonResult(
      osmId:       props['osm_id']?.toString() ?? '',
      osmType:     props['osm_type']  as String? ?? 'N',
      name:        props['name']      as String? ??
                   props['street']    as String? ??
                   props['city']      as String? ?? '',
      lat:         coords.length > 1 ? coords[1].toDouble() : 0,
      lon:         coords.isNotEmpty  ? coords[0].toDouble() : 0,
      street:      props['street']    as String?,
      housenumber: props['housenumber'] as String?,
      city:        props['city']      as String?,
      district:    props['district']  as String?,
      county:      props['county']    as String?,
      state:       props['state']     as String?,
      country:     props['country']   as String?,
      postcode:    props['postcode']  as String?,
      osmKey:      props['osm_key']   as String?,
      osmValue:    props['osm_value'] as String?,
    );
  }
}

// ── Serviço principal ─────────────────────────────────────────────
class PhotonApiService {
  static const _baseUrl  = 'https://photon.komoot.io/api/';
  static const _userAgent = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';

  // Cache memória (query+coords → resultados)
  static final Map<String, List<PhotonResult>> _cache = {};

  // ── 1. Autocomplete / Geocodificação ────────────────────────────
  // Principal chamada para barra de busca.
  // nearLat/nearLon rankeia resultados próximos ao usuário.
  // countryCode filtra por país (padrão 'BR').
  static Future<List<PhotonResult>> search(
    String query, {
    double? nearLat,
    double? nearLon,
    int limit = 8,
    String lang = 'pt',
    String? countryCode, // 'BR' — aplica bbox aproximado para o Brasil
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final cacheKey = '$q:${nearLat?.toStringAsFixed(1)}:${nearLon?.toStringAsFixed(1)}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final params = <String, String>{
      'q': q,
      'limit': limit.toString(),
      'lang': lang,
    };

    if (nearLat != null && nearLon != null) {
      params['lat'] = nearLat.toStringAsFixed(6);
      params['lon'] = nearLon.toStringAsFixed(6);
    }

    // Restringe ao Brasil por bbox para evitar resultados internacionais
    if (countryCode == 'BR' || (nearLat == null && countryCode != null)) {
      // Brasil: lon ~-73.98..-28.85, lat ~-33.75..5.27
      params['bbox'] = '-73.98,-33.75,-28.85,5.27';
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];
      final data = json.decode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List? ?? []).cast<Map<String, dynamic>>();

      final results = features
          .map((f) {
            try { return PhotonResult.fromJson(f); } catch (_) { return null; }
          })
          .where((r) => r != null && r.name.isNotEmpty && r.lat != 0)
          .cast<PhotonResult>()
          .toList();

      if (kDebugMode) debugPrint('[Photon] "${q}" → ${results.length} resultados');
      _cache[cacheKey] = results;
      return results;
    } catch (e) {
      if (kDebugMode) debugPrint('[Photon] search error: $e');
      return [];
    }
  }

  // ── 2. Busca POI específico (Shopping, Hospital, etc.) ──────────
  // Wrapper com filtro por osm_key para resultados mais relevantes
  static Future<List<PhotonResult>> searchPoi(
    String name, {
    double? nearLat,
    double? nearLon,
    int limit = 8,
  }) async {
    final all = await search(
      name,
      nearLat: nearLat,
      nearLon: nearLon,
      limit: limit + 4, // pega extras para filtrar
      countryCode: 'BR',
    );
    // Prioriza POIs (amenity, shop, tourism) sobre lugares genéricos
    final pois = all.where((r) =>
        r.osmKey != null &&
        ['amenity', 'shop', 'tourism', 'leisure', 'building'].contains(r.osmKey)).toList();
    if (pois.isNotEmpty) return pois.take(limit).toList();
    return all.take(limit).toList();
  }

  // ── 3. Converte lista Photon → AddressResult ────────────────────
  static List<AddressResult> toAddressResults(List<PhotonResult> results) {
    return results
        .where((r) => r.lat != 0 && r.lon != 0)
        .map((r) => r.toAddressResult())
        .toList();
  }

  /// Limpa cache (testes / logout)
  static void clearCache() => _cache.clear();
}

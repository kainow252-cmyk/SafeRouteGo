// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// MAPBOX SEARCH BOX SERVICE — SafeRoute
//
// Integração com Mapbox Search Box API v1:
//   /suggest  → autocomplete em tempo real (retorna sugestões sem coords)
//   /retrieve → coordenadas reais ao selecionar uma sugestão
//   /forward  → busca direta com coordenadas (sem session token)
//
// Arquitetura de sessão (billing):
//   • Cada sessão de busca tem um session_token único (UUIDv4 simplificado)
//   • /suggest e /retrieve da mesma sessão são cobrados como 1 request
//   • session_token é rotacionado a cada nova sessão de busca
//
// Vantagens sobre Nominatim/ViaCEP:
//   • Retorna TODOS os bairros corretamente (suburb, quarter, city_district)
//   • Coordenadas reais no nível da rua (rooftop accuracy)
//   • Proximidade GPS embarcada: results rankeados por distância do usuário
//   • Resultados em pt-BR nativamente
//   • CEP correto nos resultados
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'address_search_service.dart'; // reutiliza AddressResult

// Helper: acessa campo aninhado de contexto Mapbox com segurança de tipos
// ctx['place']['name'] → _mapGet(ctx, 'place', 'name')
dynamic _mapGet(Map<String, dynamic> ctx, String key, String field) {
  final inner = ctx[key];
  if (inner == null) return null;
  if (inner is Map) return inner[field];
  return null;
}

// ── Sugestão Mapbox (intermediária — sem coords) ───────────────────
class MapboxSuggestion {
  final String mapboxId;
  final String name;
  final String placeFormatted; // "Parque Jacaraípe, Serra - ES, 29175"
  final String fullAddress;    // "Rua Vitória, Parque Jacaraípe, Serra - ES, 29175"
  final String featureType;    // "address", "street", "poi", etc.
  final String? postcode;
  final String? neighborhood;
  final String? place;

  const MapboxSuggestion({
    required this.mapboxId,
    required this.name,
    required this.placeFormatted,
    required this.fullAddress,
    required this.featureType,
    this.postcode,
    this.neighborhood,
    this.place,
  });

  /// Subtítulo formatado para exibição na lista
  String get subtitle {
    if (fullAddress.isNotEmpty && fullAddress != name) {
      // Remove o name do início do fullAddress para evitar repetição
      final rest = fullAddress.startsWith(name)
          ? fullAddress.substring(name.length).replaceFirst(RegExp(r'^[,\s]+'), '')
          : placeFormatted;
      return rest.isNotEmpty ? rest : placeFormatted;
    }
    return placeFormatted;
  }

  factory MapboxSuggestion.fromJson(Map<String, dynamic> j) {
    final ctx = (j['context'] as Map<String, dynamic>?) ?? {};
    return MapboxSuggestion(
      mapboxId:       j['mapbox_id']        as String? ?? '',
      name:           j['name']             as String? ?? '',
      placeFormatted: j['place_formatted']  as String? ?? '',
      fullAddress:    j['full_address']     as String? ??
                      '${j['name'] ?? ''} ${j['place_formatted'] ?? ''}'.trim(),
      featureType:    j['feature_type']     as String? ?? '',
      postcode:       _mapGet(ctx, 'postcode', 'name') as String?,
      neighborhood:   _mapGet(ctx, 'neighborhood', 'name') as String?,
      place:          _mapGet(ctx, 'place', 'name') as String?,
    );
  }
}

// ── Serviço principal ──────────────────────────────────────────────
class MapboxSearchService {
  static const _token =
      'pk.PLACEHOLDER_MAPBOX_TOKEN_SAFEROUTE';
  static const _baseUrl = 'https://api.mapbox.com/search/searchbox/v1';
  static const _userAgent = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';

  // Session token: rotacionado a cada nova sessão de busca
  // Agrupa /suggest + /retrieve como 1 cobrança
  static String _sessionToken = _newToken();
  static int _suggestCountInSession = 0;
  static const _maxSuggestsPerSession = 50; // rotaciona após 50 suggests

  // Cache em memória para suggest (evita roundtrips duplicados)
  static final Map<String, List<MapboxSuggestion>> _suggestCache = {};
  // Cache em memória para retrieve (evita cobrar 2x pelo mesmo ID)
  static final Map<String, AddressResult> _retrieveCache = {};

  static String _newToken() {
    // UUIDv4 simplificado — suficiente para billing
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'saferoute-${now.toRadixString(16)}-${(now * 1337).toRadixString(16).substring(0, 8)}';
  }

  /// Rotaciona o session_token quando necessário
  static void _maybeRotateToken() {
    _suggestCountInSession++;
    if (_suggestCountInSession >= _maxSuggestsPerSession) {
      _sessionToken = _newToken();
      _suggestCountInSession = 0;
    }
  }

  /// Rotaciona explicitamente ao iniciar nova sessão de busca (nova tela)
  static void newSession() {
    _sessionToken = _newToken();
    _suggestCountInSession = 0;
  }

  // ── 1. SUGGEST — autocomplete em tempo real ───────────────────────
  // Retorna sugestões sem coordenadas. Chame /retrieve ao selecionar.
  // proximity: "lon,lat" do usuário para rankear por proximidade
  static Future<List<MapboxSuggestion>> suggest(
    String query, {
    String? proximity,   // ex: "-40.3073,-20.1286"
    String country = 'br',
    String language = 'pt',
    int limit = 8,
    String? types,       // ex: "address,street,neighborhood"
  }) async {
    final q = query.trim();
    if (q.length < 3) return [];

    final cacheKey = '${q.toLowerCase()}_${proximity ?? ''}_${types ?? ''}';
    if (_suggestCache.containsKey(cacheKey)) return _suggestCache[cacheKey]!;

    _maybeRotateToken();

    try {
      final params = <String, String>{
        'q':             q,
        'country':       country,
        'language':      language,
        'limit':         limit.toString(),
        'session_token': _sessionToken,
        'access_token':  _token,
      };
      if (proximity != null) params['proximity'] = proximity;
      if (types != null)     params['types']     = types;

      final uri = Uri.parse('$_baseUrl/suggest').replace(queryParameters: params);
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(MapboxSuggestion.fromJson)
          .where((s) => s.mapboxId.isNotEmpty && s.name.isNotEmpty)
          .toList();

      _suggestCache[cacheKey] = suggestions;
      return suggestions;
    } catch (e) {
      if (kDebugMode) debugPrint('[MapboxSearch] suggest error: $e');
      return [];
    }
  }

  // ── 2. RETRIEVE — coordenadas reais ao selecionar sugestão ────────
  // Converte MapboxSuggestion → AddressResult com lat/lon reais.
  // Deve usar o MESMO session_token do suggest que gerou o ID.
  static Future<AddressResult?> retrieve(MapboxSuggestion suggestion) async {
    if (_retrieveCache.containsKey(suggestion.mapboxId)) {
      return _retrieveCache[suggestion.mapboxId];
    }

    try {
      final uri = Uri.parse('$_baseUrl/retrieve/${suggestion.mapboxId}')
          .replace(queryParameters: {
        'session_token': _sessionToken,
        'access_token':  _token,
      });

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data    = json.decode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List? ?? []).cast<Map<String, dynamic>>();
      if (features.isEmpty) return null;

      final feature   = features.first;
      final props     = (feature['properties'] as Map<String, dynamic>?) ?? {};
      final coords    = (feature['geometry']?['coordinates'] as List?) ?? [];
      final coordsObj = (props['coordinates'] as Map<String, dynamic>?) ?? {};
      final ctx       = (props['context']     as Map<String, dynamic>?) ?? {};

      final lon = (coords.isNotEmpty ? coords[0] : coordsObj['longitude']) as num? ?? 0;
      final lat = (coords.length > 1 ? coords[1] : coordsObj['latitude'])  as num? ?? 0;

      if (lat == 0 && lon == 0) return null;

      final neighborhood = _mapGet(ctx, 'neighborhood', 'name') as String? ?? '';
      final place        = _mapGet(ctx, 'place', 'name') as String? ??
                           _mapGet(ctx, 'locality', 'name') as String? ?? '';
      final region       = _mapGet(ctx, 'region', 'region_code') as String? ?? '';
      final postcode     = _mapGet(ctx, 'postcode', 'name') as String? ?? '';

      final titleParts = <String>[];
      if ((props['name'] as String? ?? '').isNotEmpty) {
        titleParts.add(props['name'] as String);
      } else if ((props['full_address'] as String? ?? '').isNotEmpty) {
        titleParts.add((props['full_address'] as String).split(',').first.trim());
      } else {
        titleParts.add(suggestion.name);
      }

      final subParts = <String>[];
      if (neighborhood.isNotEmpty) subParts.add(neighborhood);
      if (place.isNotEmpty)        subParts.add(place);
      if (region.isNotEmpty)       subParts.add(region);

      final result = AddressResult(
        title:    titleParts.join(', '),
        subtitle: subParts.isNotEmpty ? subParts.join(' — ') : suggestion.placeFormatted,
        lat:      lat.toDouble(),
        lon:      lon.toDouble(),
        isCity:   false,
        cep:      postcode.isNotEmpty ? postcode : null,
      );

      _retrieveCache[suggestion.mapboxId] = result;
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('[MapboxSearch] retrieve error: $e');
      return null;
    }
  }

  // ── 3. FORWARD — busca direta com coordenadas (sem /retrieve) ─────
  // Útil quando não há sessão interativa (ex: busca por CEP, batch).
  // Retorna AddressResult diretamente com coords.
  static Future<List<AddressResult>> forward(
    String query, {
    String? proximity,
    String country = 'br',
    String language = 'pt',
    int limit = 5,
    String? types,
  }) async {
    final q = query.trim();
    if (q.length < 3) return [];

    final cacheKey = 'fwd_${q.toLowerCase()}_${proximity ?? ''}';
    // Reutiliza cache de retrieve se disponível (mesma query)
    // Não há cache de forward — cada chamada é cobrada separada

    try {
      final params = <String, String>{
        'q':            q,
        'country':      country,
        'language':     language,
        'limit':        limit.toString(),
        'access_token': _token,
      };
      if (proximity != null) params['proximity'] = proximity;
      if (types != null)     params['types']     = types;

      final uri = Uri.parse('$_baseUrl/forward').replace(queryParameters: params);
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data     = json.decode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List? ?? []).cast<Map<String, dynamic>>();
      final results  = <AddressResult>[];
      final seen     = <String>{};

      for (final feature in features) {
        final props  = (feature['properties'] as Map<String, dynamic>?) ?? {};
        final coords = (feature['geometry']?['coordinates'] as List?) ?? [];
        if (coords.length < 2) continue;

        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        if (lat == 0 && lon == 0) continue;

        final ctx          = (props['context'] as Map<String, dynamic>?) ?? {};
        final neighborhood = _mapGet(ctx, 'neighborhood', 'name') as String? ?? '';
        final place        = _mapGet(ctx, 'place', 'name') as String? ??
                             _mapGet(ctx, 'locality', 'name') as String? ?? '';
        final region       = _mapGet(ctx, 'region', 'region_code') as String? ?? '';
        final postcode     = _mapGet(ctx, 'postcode', 'name') as String? ?? '';

        final name = (props['name'] as String? ?? '').trim();
        final title = name.isNotEmpty ? name
            : (props['full_address'] as String? ?? '').split(',').first.trim();
        if (title.isEmpty) continue;

        final subParts = <String>[];
        if (neighborhood.isNotEmpty) subParts.add(neighborhood);
        if (place.isNotEmpty)        subParts.add(place);
        if (region.isNotEmpty)       subParts.add(region);

        final subtitle = subParts.isNotEmpty
            ? subParts.join(' — ')
            : (props['place_formatted'] as String? ?? '');

        final key = '${title.toLowerCase()}${subtitle.toLowerCase()}';
        if (!seen.add(key)) continue;

        results.add(AddressResult(
          title:    title,
          subtitle: subtitle,
          lat:      lat,
          lon:      lon,
          isCity:   false,
          cep:      postcode.isNotEmpty ? postcode : null,
        ));
      }

      return results;
    } catch (e) {
      if (kDebugMode) debugPrint('[MapboxSearch] forward error: $e');
      return [];
    }
  }

  /// Limpa caches de sessão (chamar ao fechar a tela de busca)
  static void clearSessionCache() {
    _suggestCache.clear();
    // Mantém _retrieveCache (coords já pagas, reutilizáveis)
  }
}

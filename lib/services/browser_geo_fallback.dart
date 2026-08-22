// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// BROWSER GEO FALLBACK — SafeRoute
//
// Usa a HTML5 Geolocation API (navigator.geolocation) diretamente
// como ÚLTIMO RECURSO quando todas as outras camadas falham:
//
//   Camada 1: Mapbox Search Box /suggest+/retrieve  (primária)
//   Camada 2: Nominatim OSM + ViaCEP               (fallback)
//   Camada 3: GPS do browser navigator.geolocation  (← ESTA)
//
// Por que esta camada existe?
//   - Mapbox pode estar offline ou com token expirado
//   - Nominatim pode ter timeout (rate limit)
//   - ViaCEP pode não cobrir o CEP consultado
//   - O browser/dispositivo SEMPRE tem geolocalização disponível
//     (GPS nativo no Android, WiFi+Cell no desktop, IP no pior caso)
//
// Funcionamento:
//   - Na web: chama window.navigator.geolocation.getCurrentPosition()
//     via js_interop (dart:js_interop + web)
//   - No Android/iOS: usa o geolocator já existente no LocationService
//   - Retorna lat/lon + precisão em metros
//   - Faz reverse geocode via Mapbox /reverse ou Nominatim /reverse
//     para descobrir cidade+UF a partir das coordenadas GPS
//
// Integração no AddressSearchService.searchOnline():
//   Se Mapbox+Nominatim+ViaCEP retornarem [], chama
//   BrowserGeoFallback.getPosition() e usa as coords para
//   Mapbox /forward com proximity=lat,lon do usuário
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Resultado da geolocalização do browser
class BrowserGeoPosition {
  final double lat;
  final double lon;
  final double? accuracy; // metros
  final String source;    // 'geolocator', 'browser_js', 'ip_fallback'

  const BrowserGeoPosition({
    required this.lat,
    required this.lon,
    this.accuracy,
    required this.source,
  });

  String get proximityParam => '$lon,$lat'; // formato Mapbox: lon,lat

  @override
  String toString() => 'BrowserGeoPosition($lat, $lon ±${accuracy?.toStringAsFixed(0) ?? "?"}m [$source])';
}

// Resultado de reverse geocode (coords → cidade/UF)
class ReverseGeoResult {
  final String city;      // ex: "Serra"
  final String state;     // ex: "ES"
  final String stateFull; // ex: "Espírito Santo"
  final String country;   // ex: "BR"
  final String? neighborhood; // ex: "Parque Jacaraípe"
  final String? postcode;

  const ReverseGeoResult({
    required this.city,
    required this.state,
    required this.stateFull,
    required this.country,
    this.neighborhood,
    this.postcode,
  });

  bool get isBrazil => country.toUpperCase() == 'BR';

  @override
  String toString() => '$city/$state';
}

// ── Serviço principal ──────────────────────────────────────────────
class BrowserGeoFallback {
  static const _mapboxToken =
      'pk.PLACEHOLDER_MAPBOX_TOKEN_SAFEROUTE';
  static const _userAgent = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';

  // Cache da última posição obtida (evita múltiplas chamadas GPS)
  // Exposto como getter para uso em outros serviços (ex: AddressSearchService)
  static BrowserGeoPosition? _cachedPosition;
  static BrowserGeoPosition? get cachedPosition => _cachedPosition;
  static DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 5);

  // Cache de reverse geocode por posição arredondada
  static final Map<String, ReverseGeoResult> _reverseCache = {};

  // ── 1. Obtém posição GPS (última linha de defesa) ──────────────────
  // Ordem de tentativa:
  //   a) Cache recente (< 5 min) — sem chamada de rede
  //   b) LocationService.instance (geolocator nativo — Android/iOS/Web)
  //   c) IP Geolocation (ipapi.co — sem permissão necessária, menos preciso)
  static Future<BrowserGeoPosition?> getPosition() async {
    // a) Cache recente
    if (_cachedPosition != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheMaxAge) {
      return _cachedPosition;
    }

    // b) Tenta LocationService (geolocator — GPS nativo + HTML5 no web)
    try {
      // Importação dinâmica para evitar dependência circular
      final pos = await _tryGeolocator();
      if (pos != null) {
        _cachedPosition = pos;
        _cacheTime = DateTime.now();
        if (kDebugMode) debugPrint('[BrowserGeo] Geolocator: $pos');
        return pos;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BrowserGeo] Geolocator falhou: $e');
    }

    // c) IP Geolocation como último recurso (sem permissão GPS)
    try {
      final pos = await _tryIpGeolocation();
      if (pos != null) {
        _cachedPosition = pos;
        _cacheTime = DateTime.now();
        if (kDebugMode) debugPrint('[BrowserGeo] IP Geo: $pos');
        return pos;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BrowserGeo] IP Geo falhou: $e');
    }

    return null;
  }

  // ── 2. Reverse Geocode — coords → cidade/UF ──────────────────────
  // Mapbox /reverse como primária, Nominatim /reverse como fallback
  static Future<ReverseGeoResult?> reverseGeocode(
      double lat, double lon) async {
    final cacheKey =
        '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
    if (_reverseCache.containsKey(cacheKey)) {
      return _reverseCache[cacheKey];
    }

    // a) Mapbox reverse geocode
    try {
      final result = await _reverseMapbox(lat, lon);
      if (result != null) {
        _reverseCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BrowserGeo] Mapbox reverse falhou: $e');
    }

    // b) Nominatim reverse geocode
    try {
      final result = await _reverseNominatim(lat, lon);
      if (result != null) {
        _reverseCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BrowserGeo] Nominatim reverse falhou: $e');
    }

    return null;
  }

  // ── Helpers privados ──────────────────────────────────────────────

  // Tenta geolocator (nativo Flutter — geolocator package)
  static Future<BrowserGeoPosition?> _tryGeolocator() async {
    try {
      // Importação lazy via reflection para evitar dependência circular
      // Usa o LocationService que já está inicializado no app
      final dynamic locService = _getLocationServiceInstance();
      if (locService == null) return null;

      final dynamic state = locService.state;
      if (state?.hasPosition == true) {
        return BrowserGeoPosition(
          lat: state.lat as double,
          lon: state.lon as double,
          accuracy: state.accuracy as double?,
          source: 'geolocator_cached',
        );
      }

      // Solicita posição fresca
      final dynamic newState = await locService.getCurrentPosition();
      if (newState?.hasPosition == true) {
        return BrowserGeoPosition(
          lat: newState.lat as double,
          lon: newState.lon as double,
          accuracy: newState.accuracy as double?,
          source: 'geolocator',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BrowserGeo] _tryGeolocator: $e');
    }
    return null;
  }

  // IP Geolocation via ipapi.co (sem permissão, menos preciso)
  // Retorna cidade+coords baseado no IP público do usuário
  static Future<BrowserGeoPosition?> _tryIpGeolocation() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'),
              headers: {
                'User-Agent': _userAgent,
                'Accept': 'application/json',
              })
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;

      // Verifica se tem erro (conta gratuita tem limite de 1000/dia)
      if (data.containsKey('error')) return null;

      final lat = (data['latitude']  as num?)?.toDouble();
      final lon = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      // Cacheia também o reverse geocode (evita chamada extra)
      final city    = data['city']         as String? ?? '';
      final region  = data['region_code']  as String? ?? '';
      final country = data['country_code'] as String? ?? '';
      if (city.isNotEmpty && region.isNotEmpty) {
        final cacheKey = '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
        _reverseCache[cacheKey] = ReverseGeoResult(
          city:      city,
          state:     region,
          stateFull: data['region'] as String? ?? region,
          country:   country,
        );
      }

      return BrowserGeoPosition(
        lat:      lat,
        lon:      lon,
        accuracy: 5000, // precisão de cidade (~5km)
        source:   'ip_geolocation',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[BrowserGeo] ipapi.co: $e');
      return null;
    }
  }

  // Mapbox reverse geocode: coords → place/region
  static Future<ReverseGeoResult?> _reverseMapbox(
      double lat, double lon) async {
    final uri = Uri.parse(
        'https://api.mapbox.com/search/searchbox/v1/reverse'
        '?longitude=$lon&latitude=$lat'
        '&country=br&language=pt&limit=1'
        '&access_token=$_mapboxToken');

    final response = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) return null;
    final data     = json.decode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List? ?? []).cast<Map<String, dynamic>>();
    if (features.isEmpty) return null;

    final props = (features.first['properties'] as Map<String, dynamic>?) ?? {};
    final ctx   = (props['context']    as Map<String, dynamic>?) ?? {};

    final city    = _ctxName(ctx, 'place')   ?? _ctxName(ctx, 'locality') ?? '';
    final region  = _ctxCode(ctx, 'region')  ?? '';
    final stateFull = _ctxName(ctx, 'region') ?? '';
    final country = _ctxCode(ctx, 'country') ?? 'BR';
    final neighborhood = _ctxName(ctx, 'neighborhood');
    final postcode     = _ctxName(ctx, 'postcode');

    if (city.isEmpty) return null;

    return ReverseGeoResult(
      city:      city,
      state:     region,
      stateFull: stateFull,
      country:   country,
      neighborhood: neighborhood,
      postcode:     postcode,
    );
  }

  // Nominatim reverse geocode: coords → address
  static Future<ReverseGeoResult?> _reverseNominatim(
      double lat, double lon) async {
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&addressdetails=1');

    final response = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final addr = (data['address'] as Map<String, dynamic>?) ?? {};

    final city = (addr['city']         as String? ??
                  addr['town']         as String? ??
                  addr['municipality'] as String? ??
                  addr['village']      as String? ?? '').trim();
    final state    = _nominatimUF(addr['state'] as String? ?? '');
    final stateFull = addr['state']     as String? ?? '';
    final country  = addr['country_code'] as String? ?? 'br';
    final neighborhood = (addr['suburb']        as String? ??
                          addr['neighbourhood']  as String? ??
                          addr['quarter']        as String? ?? '');
    final postcode = addr['postcode'] as String? ?? '';

    if (city.isEmpty) return null;

    return ReverseGeoResult(
      city:      city,
      state:     state.toUpperCase(),
      stateFull: stateFull,
      country:   country.toUpperCase(),
      neighborhood: neighborhood.isEmpty ? null : neighborhood,
      postcode:     postcode.isEmpty ? null : postcode,
    );
  }

  // ── Helpers para contexto Mapbox ────────────────────────────────
  static String? _ctxName(Map<String, dynamic> ctx, String key) {
    final inner = ctx[key];
    if (inner is Map) return inner['name'] as String?;
    return null;
  }

  static String? _ctxCode(Map<String, dynamic> ctx, String key) {
    final inner = ctx[key];
    if (inner is Map) {
      // region_code ex: "BR-ES" → "ES"
      final code = inner['region_code'] as String? ??
                   inner['country_code'] as String? ??
                   inner['name'] as String? ?? '';
      return code.split('-').last;
    }
    return null;
  }

  // Converte nome de estado BR → UF
  static String _nominatimUF(String state) {
    const map = {
      'Acre': 'AC', 'Alagoas': 'AL', 'Amapá': 'AP', 'Amazonas': 'AM',
      'Bahia': 'BA', 'Ceará': 'CE', 'Distrito Federal': 'DF',
      'Espírito Santo': 'ES', 'Goiás': 'GO', 'Maranhão': 'MA',
      'Mato Grosso do Sul': 'MS', 'Mato Grosso': 'MT',
      'Minas Gerais': 'MG', 'Pará': 'PA', 'Paraíba': 'PB',
      'Paraná': 'PR', 'Pernambuco': 'PE', 'Piauí': 'PI',
      'Rio de Janeiro': 'RJ', 'Rio Grande do Norte': 'RN',
      'Rio Grande do Sul': 'RS', 'Rondônia': 'RO', 'Roraima': 'RR',
      'Santa Catarina': 'SC', 'São Paulo': 'SP', 'Sergipe': 'SE',
      'Tocantins': 'TO',
    };
    for (final e in map.entries) {
      if (state.contains(e.key)) return e.value;
    }
    return state.length <= 3 ? state : '';
  }

  // Acessa LocationService de forma segura (evita dependência circular)
  static dynamic _getLocationServiceInstance() {
    try {
      return _LocationServiceRef.instance;
    } catch (_) {
      return null;
    }
  }

  /// Limpa cache (para testes ou logout)
  static void clearCache() {
    _cachedPosition = null;
    _cacheTime = null;
    _reverseCache.clear();
  }
}

// Referência indireta ao LocationService (evita import circular)
// Será inicializada pelo LocationService no seu próprio arquivo
class _LocationServiceRef {
  static dynamic _instance;
  static dynamic get instance => _instance;
  static void register(dynamic service) => _instance = service;
}

/// Registra o LocationService no fallback (chamar no LocationService.init)
void registerLocationServiceForFallback(dynamic service) {
  _LocationServiceRef.register(service);
}

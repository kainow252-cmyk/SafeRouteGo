// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════
// NOMINATIM SEARCH SERVICE
// Busca híbrida: banco Brasil 29.866 lugares + OSM/BrasilAPI em tempo real
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'brazil_places_data.dart';
import 'location_service.dart';

// ── Modelo de lugar ────────────────────────────────────────────
class PlaceResult {
  final String name;
  final String subtitle;
  final String city;
  final String dist;
  final String zone; // verde/amarela/laranja/vermelha
  final String iconType; // route/location/hospital/school/shopping/beach/park/bus/flight/gas
  final double lat;
  final double lon;
  final List<String> tags;
  final bool isLocal; // true = banco local, false = API em tempo real

  const PlaceResult({
    required this.name,
    required this.subtitle,
    required this.city,
    required this.dist,
    required this.zone,
    required this.iconType,
    required this.lat,
    required this.lon,
    this.tags = const [],
    this.isLocal = true,
  });

  // Ícone Flutter a partir do tipo
  IconData get icon {
    switch (iconType) {
      case 'route':
        return Icons.route_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'beach':
        return Icons.beach_access_rounded;
      case 'park':
        return Icons.park_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'gas':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  // Busca multi-campo
  bool matches(String q) {
    final low = q.toLowerCase().trim();
    if (low.isEmpty) return false;
    // Normaliza removendo acentos simples para melhorar busca
    final normName = _normalize(name);
    final normSub = _normalize(subtitle);
    final normQ = _normalize(low);
    return normName.contains(normQ) ||
        normSub.contains(normQ) ||
        tags.any((t) => _normalize(t).contains(normQ));
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('á', 'a').replaceAll('â', 'a').replaceAll('ã', 'a').replaceAll('à', 'a')
        .replaceAll('é', 'e').replaceAll('ê', 'e').replaceAll('è', 'e')
        .replaceAll('í', 'i').replaceAll('î', 'i')
        .replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o')
        .replaceAll('ú', 'u').replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
  }

  // Score de relevância (maior = melhor)
  int relevanceScore(String q) {
    final normName = _normalize(name);
    final normQ = _normalize(q.toLowerCase().trim());
    if (normName == normQ) return 100;
    if (normName.startsWith(normQ)) return 80;
    if (normName.contains(normQ)) return 60;
    return 40;
  }

  // ── Distância real via Haversine (metros) ─────────────────────
  // Usa a posição GPS atual do LocationService
  double distanceMeters({double? userLat, double? userLon}) {
    final uLat = userLat ?? LocationService.instance.state.lat;
    final uLon = userLon ?? LocationService.instance.state.lon;
    if (uLat == null || uLon == null) return double.infinity;
    if (lat == 0.0 && lon == 0.0) return double.infinity;
    return _haversineMeters(uLat, uLon, lat, lon);
  }

  // Distância formatada: "340 m", "1,2 km", "45 km"
  String distanceLabel({double? userLat, double? userLon}) {
    final m = distanceMeters(userLat: userLat, userLon: userLon);
    if (m.isInfinite) return '';
    if (m < 1000) return '${m.round()} m';
    final km = m / 1000;
    if (km < 10) return '${km.toStringAsFixed(1)} km'.replaceAll('.', ',');
    return '${km.round()} km';
  }

  // Fórmula Haversine — distância real na superfície esférica da Terra
  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // raio da Terra em metros
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  String toString() => '$name — $subtitle';
}

// ── Serviço principal ──────────────────────────────────────────
class NominatimSearchService {
  static const _userAgent = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';
  static const _viewbox = '-41.9,-21.3,-39.5,-17.8';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org/search';

  // Debounce timer para API
  static Timer? _debounce;

  // Cache de buscas API (evita requisições repetidas)
  static final Map<String, List<PlaceResult>> _apiCache = {};

  // ── Busca local no banco (29.866 lugares) ─────────────────────
  // Ordena por: relevância textual PRIMEIRO, depois proximidade GPS
  static List<PlaceResult> searchLocal(String query, {int limit = 20}) {
    if (query.trim().isEmpty) return [];

    final gps = LocationService.instance.state;
    final userLat = gps.lat;
    final userLon = gps.lon;
    final hasGps = userLat != null && userLon != null;

    final results = kBrazilDb
        .where((p) => p.matches(query))
        .toList();

    results.sort((a, b) {
      final scoreA = a.relevanceScore(query);
      final scoreB = b.relevanceScore(query);

      // 1) Relevância textual é sempre prioritária
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);

      // 2) Mesma relevância → ordena por distância GPS real
      if (hasGps) {
        final dA = a.distanceMeters(userLat: userLat, userLon: userLon);
        final dB = b.distanceMeters(userLat: userLat, userLon: userLon);
        return dA.compareTo(dB);
      }

      // 3) Sem GPS → desempate por dist string legada
      final dA = double.tryParse(a.dist.replaceAll(' km', '')) ?? 999;
      final dB = double.tryParse(b.dist.replaceAll(' km', '')) ?? 999;
      return dA.compareTo(dB);
    });

    return results.take(limit).toList();
  }

  // ── Busca na API Nominatim — BRASIL INTEIRO ───────────────────
  static Future<List<PlaceResult>> searchApi(String query) async {
    final normQ = query.trim();
    if (normQ.length < 3) return [];

    if (_apiCache.containsKey(normQ)) return _apiCache[normQ]!;

    try {
      // Sem viewbox, sem filtro de estado — Brasil inteiro
      final uri = Uri.parse(_nominatimBase).replace(queryParameters: {
        'q':             normQ,
        'format':        'json',
        'addressdetails':'1',
        'limit':         '12',
        'countrycodes':  'br',
        'dedupe':        '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];

      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      final results = <PlaceResult>[];

      for (final item in data) {
        final addr = (item['address'] as Map<String, dynamic>?) ?? {};

        // Nome: para endereços com número o campo 'name' vem vazio
        // → montar a partir do address (house_number + road)
        String name = (item['name'] as String? ?? '').trim();
        final road        = (addr['road']         as String? ?? '').trim();
        final houseNumber = (addr['house_number']  as String? ?? '').trim();
        if (name.isEmpty && road.isNotEmpty) {
          name = houseNumber.isNotEmpty ? '$road, $houseNumber' : road;
        }
        if (name.length < 3) continue;

        final state  = (addr['state']   as String? ?? '').trim();
        final stateCode = _stateCode(state);

        final city = (addr['city']    as String? ??
                      addr['town']    as String? ??
                      addr['municipality'] as String? ??
                      addr['village'] as String? ??
                      state).trim();

        final suburb = (addr['suburb']        as String? ??
                        addr['quarter']       as String? ??
                        addr['neighbourhood'] as String? ??
                        addr['city_district'] as String? ??
                        '').trim();

        final lat    = double.tryParse(item['lat'] as String? ?? '') ?? -15.0;
        final lon    = double.tryParse(item['lon'] as String? ?? '') ?? -50.0;
        final distKm = _estimateDistance(lat, lon);

        final parts = <String>[];
        if (suburb.isNotEmpty) parts.add(suburb);
        if (city.isNotEmpty)   parts.add(city);
        if (stateCode.isNotEmpty) parts.add(stateCode);
        final subtitle = parts.join(' — ');

        results.add(PlaceResult(
          name:     name,
          subtitle: subtitle,
          city:     city,
          dist:     distKm < 1 ? '< 1 km' : '${distKm.round()} km',
          zone:     _getZone(city, suburb),
          iconType: _getIconType(name),
          lat:      lat,
          lon:      lon,
          tags:     _buildApiTags(name, city, suburb),
          isLocal:  false,
        ));
      }

      _apiCache[normQ] = results;
      return results;
    } catch (e) {
      return [];
    }
  }

  // Converte nome do estado para sigla (UF)
  static String _stateCode(String state) {
    const map = {
      'Acre':'AC','Alagoas':'AL','Amapá':'AP','Amazonas':'AM',
      'Bahia':'BA','Ceará':'CE','Distrito Federal':'DF',
      'Espírito Santo':'ES','Goiás':'GO','Maranhão':'MA',
      'Mato Grosso do Sul':'MS','Mato Grosso':'MT','Minas Gerais':'MG',
      'Pará':'PA','Paraíba':'PB','Paraná':'PR','Pernambuco':'PE',
      'Piauí':'PI','Rio de Janeiro':'RJ','Rio Grande do Norte':'RN',
      'Rio Grande do Sul':'RS','Rondônia':'RO','Roraima':'RR',
      'Santa Catarina':'SC','São Paulo':'SP','Sergipe':'SE','Tocantins':'TO',
    };
    for (final e in map.entries) {
      if (state.contains(e.key)) return e.value;
    }
    return state.length <= 3 ? state : '';
  }

  // ── Busca híbrida (local + API) com deduplicação ──────────────
  static Future<List<PlaceResult>> searchHybrid(
    String query, {
    int localLimit = 15,
    int apiLimit = 8,
    required void Function(List<PlaceResult> apiResults) onApiResults,
  }) async {
    if (query.trim().isEmpty) return [];

    // 1) Resultado local imediato
    final localResults = searchLocal(query, limit: localLimit);

    // 2) API em background (debounced)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final apiResults = await searchApi(query);
      if (apiResults.isEmpty) return;

      // Deduplicar: remover API results que já estão no local
      final localNames = localResults.map((r) => PlaceResult._normalize(r.name)).toSet();
      final newApiResults = apiResults
          .where((r) => !localNames.contains(PlaceResult._normalize(r.name)))
          .take(apiLimit)
          .toList();

      if (newApiResults.isNotEmpty) {
        onApiResults([...localResults, ...newApiResults]);
      }
    });

    return localResults;
  }

  // ── Helpers ───────────────────────────────────────────────────
  // Distância a partir do GPS atual (ou Brasília como fallback)
  static double _estimateDistance(double lat, double lon) {
    final gps = LocationService.instance.state;
    final lat1 = gps.lat ?? -15.7801; // Brasília como fallback
    final lon1 = gps.lon ?? -47.9292;
    return PlaceResult._haversineMeters(lat1, lon1, lat, lon) / 1000; // km
  }

  static String _getZone(String city, String suburb) {
    final cl = city.toLowerCase();
    final sl = suburb.toLowerCase();
    const critical = ['resistencia', 'sao pedro', 'jabour', 'planalto serrano', 'andre carloni'];
    const high = ['carapina', 'maruipe', 'bonfim', 'consolacao', 'itarare', 'alto lage'];
    const safe = ['laranjeiras', 'jardim camburi', 'praia do canto', 'itaparica', 'camburi',
      'mata da praia', 'bento ferreira', 'goiabeiras', 'praia da costa'];
    for (final c in critical) {
      if (sl.contains(c) || cl.contains(c)) return 'vermelha';
    }
    for (final h in high) {
      if (sl.contains(h) || cl.contains(h)) return 'laranja';
    }
    for (final s in safe) {
      if (sl.contains(s)) return 'verde';
    }
    if (cl.contains('cariacica')) return 'laranja';
    return 'amarela';
  }

  static String _getIconType(String name) {
    final nl = name.toLowerCase();
    if (nl.contains('av.') || nl.contains('avenida') || nl.contains('rodovia') ||
        nl.contains('rua') || nl.contains('estrada') || nl.contains('br-') ||
        nl.contains('es-') || nl.contains('ponte')) return 'route';
    if (nl.contains('hospital') || nl.contains('santa casa') || nl.contains('upa') ||
        nl.contains('ubs') || nl.contains('clinica')) return 'hospital';
    if (nl.contains('escola') || nl.contains('ufes') || nl.contains('universidade') ||
        nl.contains('faculdade') || nl.contains('colegio')) return 'school';
    if (nl.contains('shopping') || nl.contains('mall')) return 'shopping';
    if (nl.contains('aeroporto') || nl.contains('airport')) return 'flight';
    if (nl.contains('praia') || nl.contains('orla')) return 'beach';
    if (nl.contains('parque') || nl.contains('praça') || nl.contains('praca') ||
        nl.contains('jardim')) return 'park';
    if (nl.contains('terminal') || nl.contains('rodoviaria') || nl.contains('onibus')) return 'bus';
    if (nl.contains('posto') || nl.contains('gasolina')) return 'gas';
    return 'location';
  }

  static List<String> _buildApiTags(String name, String city, String suburb) {
    final tags = <String>[];
    final words = name.toLowerCase().split(RegExp(r'\s+'));
    for (final w in words) {
      if (w.length > 2 && !['rua', 'av.', 'avenida', 'de', 'da', 'do', 'das', 'dos'].contains(w)) {
        tags.add(w);
      }
    }
    if (city.isNotEmpty) tags.add(city.toLowerCase());
    if (suburb.isNotEmpty) tags.add(suburb.toLowerCase());
    return tags.take(6).toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// BANCO BRASIL v3.0 — 29.866 lugares reais
// BrasilAPI IBGE (8.276 municípios) + OSM Overpass (21.590 estradas)
// Motorway, trunk, primary, secondary, tertiary — todos 27 UFs
// ═══════════════════════════════════════════════════════════════
final List<PlaceResult> kBrazilDb = _buildBrazilDb();

List<PlaceResult> _buildBrazilDb() {
  return kRawBrazilData.map((r) {
    // Formato: [name, subtitle, city, uf, dist, zone, iconType, lat, lon, ...tags]
    final lat = double.tryParse(r.length > 7 ? r[7] : '0') ?? 0.0;
    final lon = double.tryParse(r.length > 8 ? r[8] : '0') ?? 0.0;
    return PlaceResult(
      name:     r[0],
      subtitle: r[1],
      city:     r[2],
      dist:     r.length > 4 ? r[4] : '',
      zone:     r.length > 5 ? r[5] : 'amarela',
      iconType: r.length > 6 ? r[6] : 'location',
      lat:      lat,
      lon:      lon,
      tags:     r.length > 9 ? r.sublist(9) : const [],
      isLocal:  true,
    );
  }).toList();
}

// ═══════════════════════════════════════════════════════════════
// BRAZIL SEARCH SERVICE
// Busca em tempo real com fallback duplo:
//   1º BrasilAPI CEP v2  → retorna coords lat/lon reais
//   2º ViaCEP            → fallback se BrasilAPI falhar
// ═══════════════════════════════════════════════════════════════
class BrazilSearchService {
  static const _headers = {'User-Agent': 'SafeRouteGo/2.0 (contato@saferoutego.com.br)'};
  static final Map<String, List<PlaceResult>> _cache = {};

  // Capitais de cada UF (primeira = capital)
  static const _ufCapitals = <String, String>{
    'AC': 'Rio Branco',    'AL': 'Maceió',         'AM': 'Manaus',
    'AP': 'Macapá',        'BA': 'Salvador',        'CE': 'Fortaleza',
    'DF': 'Brasília',      'ES': 'Vitória',         'GO': 'Goiânia',
    'MA': 'São Luís',      'MG': 'Belo Horizonte',  'MS': 'Campo Grande',
    'MT': 'Cuiabá',        'PA': 'Belém',           'PB': 'João Pessoa',
    'PE': 'Recife',        'PI': 'Teresina',        'PR': 'Curitiba',
    'RJ': 'Rio de Janeiro','RN': 'Natal',           'RO': 'Porto Velho',
    'RR': 'Boa Vista',     'RS': 'Porto Alegre',    'SC': 'Florianópolis',
    'SE': 'Aracaju',       'SP': 'São Paulo',       'TO': 'Palmas',
  };

  // UFs prioritárias quando não há UF detectada na query
  static const _defaultUfs = ['SP', 'RJ', 'MG', 'RS', 'PR', 'BA', 'ES', 'SC', 'GO', 'PE', 'CE'];

  /// Detecta UF no texto da query (ex: "rua tal SP" ou "avenida paulista/SP")
  static String? _detectUf(String query) {
    final upper = query.toUpperCase().trim();
    final match = RegExp(r'[/,\-\s]([A-Z]{2})$').firstMatch(upper);
    if (match != null && _ufCapitals.containsKey(match.group(1))) {
      return match.group(1);
    }
    for (final uf in _ufCapitals.keys) {
      if (upper.endsWith(' $uf') || upper.endsWith('/$uf')) return uf;
    }
    return null;
  }

  /// Remove UF do final da query para isolar o termo de busca
  static String _stripUf(String query) =>
      query.replaceAll(RegExp(r'[/,\-\s][A-Za-z]{2}$'), '').trim();

  // ── 1ª FONTE: BrasilAPI CEP v2 ────────────────────────────
  // Busca por CEP direto — retorna coords reais
  // Usada quando o usuário digita um CEP (8 dígitos)
  static Future<List<PlaceResult>> _searchBrasilApiCep(String cep) async {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length != 8) return [];
    try {
      final url = 'https://brasilapi.com.br/api/cep/v2/$cleanCep';
      final response = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final d = json.decode(response.body) as Map<String, dynamic>;
      if (d.containsKey('message')) return []; // erro da API

      final street      = (d['street']       as String? ?? '').trim();
      final neighborhood= (d['neighborhood'] as String? ?? '').trim();
      final city        = (d['city']         as String? ?? '').trim();
      final state       = (d['state']        as String? ?? '').trim();
      if (street.isEmpty || city.isEmpty) return [];

      // Coordenadas reais — diferencial do BrasilAPI CEP v2!
      final coords = (d['location'] as Map<String, dynamic>?)
          ?['coordinates'] as Map<String, dynamic>? ?? {};
      final lat = (coords['latitude']  as num?)?.toDouble() ?? 0.0;
      final lon = (coords['longitude'] as num?)?.toDouble() ?? 0.0;

      final subtitle = neighborhood.isNotEmpty
          ? '$neighborhood — $city/$state'
          : '$city/$state';

      return [PlaceResult(
        name:     street,
        subtitle: subtitle,
        city:     city,
        dist:     '',
        zone:     'amarela',
        iconType: _icon(street),
        lat:      lat,
        lon:      lon,
        tags:     [street.toLowerCase(), neighborhood.toLowerCase(),
                   city.toLowerCase(), state.toLowerCase(), cleanCep],
        isLocal:  false,
      )];
    } catch (_) {
      return [];
    }
  }

  // ── 2ª FONTE: BrasilAPI IBGE municípios ───────────────────
  // Quando a query parece ser o nome de uma cidade
  static Future<List<PlaceResult>> _searchBrasilApiIbge(String query, String uf) async {
    try {
      final url = 'https://brasilapi.com.br/api/ibge/municipios/v1/$uf';
      final response = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      final normQ = _norm(query);
      final results = <PlaceResult>[];

      for (final item in data) {
        final nome = ((item['nome'] as String?) ?? '').trim();
        if (nome.isEmpty) continue;
        if (!_norm(nome).contains(normQ)) continue;

        results.add(PlaceResult(
          name:     nome,
          subtitle: '$uf',
          city:     nome,
          dist:     '',
          zone:     'amarela',
          iconType: 'location',
          lat:      0.0,
          lon:      0.0,
          tags:     [_norm(nome), uf.toLowerCase()],
          isLocal:  false,
        ));
        if (results.length >= 5) break;
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ── 3ª FONTE: ViaCEP por logradouro ───────────────────────
  // Fallback: busca endereços por UF + cidade + termo
  static Future<List<PlaceResult>> _searchViaCep(
      String term, String uf, String city) async {
    try {
      final url = 'https://viacep.com.br/ws/$uf/'
          '${Uri.encodeComponent(city)}/'
          '${Uri.encodeComponent(term)}/json/';

      final response = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return [];
      final body = response.body.trim();
      if (body.isEmpty || body.startsWith('{')) return [];

      final List<dynamic> data = json.decode(body) as List<dynamic>;
      final results = <PlaceResult>[];
      final seen = <String>{};

      for (final item in data) {
        if (results.length >= 8) break;
        final m = item as Map<String, dynamic>;
        final logradouro = (m['logradouro'] as String? ?? '').trim();
        final bairro     = (m['bairro']     as String? ?? '').trim();
        final localidade = (m['localidade'] as String? ?? city).trim();
        final itemUf     = (m['uf']         as String? ?? uf).trim();
        final cep        = (m['cep']        as String? ?? '').trim();

        if (logradouro.length < 3) continue;
        if (!seen.add('${_norm(logradouro)}_${_norm(bairro)}_$itemUf')) continue;

        final subtitle = bairro.isNotEmpty
            ? '$bairro — $localidade/$itemUf'
            : '$localidade/$itemUf';

        results.add(PlaceResult(
          name:     logradouro,
          subtitle: subtitle,
          city:     localidade,
          dist:     '',
          zone:     'amarela',
          iconType: _icon(logradouro),
          lat:      0.0, // ViaCEP não retorna coords
          lon:      0.0,
          tags:     [
            if (bairro.isNotEmpty) bairro.toLowerCase(),
            localidade.toLowerCase(),
            itemUf.toLowerCase(),
            if (cep.isNotEmpty) cep,
          ],
          isLocal:  false,
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ── BUSCA PRINCIPAL — orquestra as 3 fontes ───────────────
  static Future<List<PlaceResult>> searchViaCep(String query) async {
    final normQ = query.trim();
    if (normQ.length < 3) return [];

    final cacheKey = normQ.toLowerCase();
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final results   = <PlaceResult>[];
    final seenNames = <String>{};

    void addAll(List<PlaceResult> items) {
      for (final r in items) {
        final key = _norm(r.name + r.subtitle);
        if (seenNames.add(key)) results.add(r);
      }
    }

    // 1) CEP digitado? → BrasilAPI CEP v2 direto (coords reais)
    final cleanDigits = normQ.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length == 8) {
      final cepResults = await _searchBrasilApiCep(normQ);
      addAll(cepResults);
      if (results.isNotEmpty) {
        _cache[cacheKey] = results;
        return results;
      }
    }

    // Detectar UF e isolar termo
    final detectedUf = _detectUf(normQ);
    final term = detectedUf != null ? _stripUf(normQ) : normQ;
    if (term.length < 3) return [];

    final ufsToSearch = detectedUf != null ? [detectedUf] : _defaultUfs;

    // 2) Para cada UF: tentar BrasilAPI IBGE (cidades) + ViaCEP (logradouros)
    //    Ambas em paralelo para velocidade máxima
    final futures = <Future<List<PlaceResult>>>[];
    for (final uf in ufsToSearch) {
      final capital = _ufCapitals[uf] ?? '';
      if (capital.isEmpty) continue;
      // BrasilAPI IBGE — encontra municípios pelo nome
      futures.add(_searchBrasilApiIbge(term, uf));
      // ViaCEP — encontra logradouros na capital
      futures.add(_searchViaCep(term, uf, capital));
    }

    // Aguarda todas em paralelo (com timeout global de 6s)
    try {
      final allResults = await Future.wait(futures)
          .timeout(const Duration(seconds: 6));
      for (final r in allResults) {
        addAll(r);
      }
    } catch (_) {
      // timeout parcial — usar o que chegou
    }

    // Limitar a 15 resultados e cachear
    final limited = results.take(15).toList();
    _cache[cacheKey] = limited;
    return limited;
  }

  static String _norm(String s) => s.toLowerCase()
      .replaceAll('á','a').replaceAll('â','a').replaceAll('ã','a')
      .replaceAll('é','e').replaceAll('ê','e').replaceAll('í','i')
      .replaceAll('ó','o').replaceAll('ô','o').replaceAll('õ','o')
      .replaceAll('ú','u').replaceAll('ç','c');

  static String _icon(String name) {
    final nl = name.toLowerCase();
    if (RegExp(r'av\.|avenida|rodovia|rua |estrada|br-|sp-|mg-|es-|go-|via ').hasMatch(nl)) return 'route';
    if (RegExp(r'hospital|ubs|upa|clinica|santa casa').hasMatch(nl)) return 'hospital';
    if (RegExp(r'escola|universidade|faculdade|colegio|ifes|ifba').hasMatch(nl)) return 'school';
    if (RegExp(r'shopping|mall|center').hasMatch(nl)) return 'shopping';
    if (RegExp(r'aeroporto|airport').hasMatch(nl)) return 'flight';
    if (RegExp(r'praia|orla|litoral').hasMatch(nl)) return 'beach';
    if (RegExp(r'parque|pra[cç]a|jardim|bosque').hasMatch(nl)) return 'park';
    if (RegExp(r'terminal|rodoviaria|onibus|metro').hasMatch(nl)) return 'bus';
    if (RegExp(r'posto|gasolina').hasMatch(nl)) return 'gas';
    return 'location';
  }
}

// ═══════════════════════════════════════════════════════════════
// BANCO LOCAL — 432 lugares reais do ES (OpenStreetMap)
// ═══════════════════════════════════════════════════════════════
final List<PlaceResult> kEsPlacesDb = _buildEsDb();

List<PlaceResult> _buildEsDb() {
  // Dados raw: [name, subtitle, city, dist, zone, iconType, lat, lon, ...tags]
  const raw = _kRawEsData;
  return raw.map((r) => PlaceResult(
    name: r[0],
    subtitle: r[1],
    city: r[2],
    dist: r[3],
    zone: r[4],
    iconType: r[5],
    lat: double.parse(r[6]),
    lon: double.parse(r[7]),
    tags: r.length > 8 ? r.sublist(8) : const [],
    isLocal: true,
  )).toList();
}
const List<List<String>> _kRawEsData = [
  ['Rua Vitória', 'Bairro de Fátima — Serra/ES', 'Serra', '11 km', 'amarela', 'route', '-20.2476543', '-40.2683719', 'vitória', 'serra', 'bairro', 'fátima'],
  ['Rua Vitória', 'Vila Velha/ES', 'Vila Velha', '23 km', 'amarela', 'route', '-20.3577017', '-40.3032522', 'vitória', 'vila velha'],
  ['Rua Vitória', 'São Mateus/ES', 'São Mateus', '165 km', 'amarela', 'route', '-18.7712764', '-39.7562758', 'vitória', 'são mateus'],
  ['Rua Vitória', 'Morada do Ribeirão — São Mateus/ES', 'São Mateus', '166 km', 'amarela', 'route', '-18.7252174', '-39.8547146', 'vitória', 'são mateus', 'morada', 'ribeirão'],
  ['Rua Vitória', 'Cidade Nova da Serra — Serra/ES', 'Serra', '15 km', 'amarela', 'route', '-20.0428787', '-40.3871901', 'vitória', 'serra', 'cidade', 'nova'],
  ['Rua Vitória', 'Planalto Serrano — Serra/ES', 'Serra', '3 km', 'vermelha', 'route', '-20.1278662', '-40.2800388', 'vitória', 'serra', 'planalto', 'serrano'],
  ['Rua Vitória', 'Alterosas — Serra/ES', 'Serra', '8 km', 'amarela', 'route', '-20.1852389', '-40.2331083', 'vitória', 'serra', 'alterosas'],
  ['Rua Vitória', 'São Marcos — Serra/ES', 'Serra', '4 km', 'amarela', 'route', '-20.1230238', '-40.3190210', 'vitória', 'serra', 'são', 'marcos'],
  ['Rua Vitória', 'Vila Nova de Colares — Serra/ES', 'Serra', '11 km', 'laranja', 'route', '-20.1813105', '-40.2066819', 'vitória', 'serra', 'vila', 'nova', 'colares'],
  ['Rua Vitória', 'Serramar — Serra/ES', 'Serra', '15 km', 'amarela', 'route', '-20.0567269', '-40.2024900', 'vitória', 'serra', 'serramar'],
  ['Rua Vitória', 'Parque Jacaraípe — Serra/ES', 'Serra', '12 km', 'amarela', 'route', '-20.1520631', '-40.1906866', 'vitória', 'serra', 'parque', 'jacaraípe'],
  ['Rua Vitória', 'Mata da Serra — Serra/ES', 'Serra', '6 km', 'amarela', 'route', '-20.1578304', '-40.2498508', 'vitória', 'serra', 'mata'],
  ['Rua Vitória', 'Serra Centro — Serra/ES', 'Serra', '3 km', 'amarela', 'route', '-20.1270958', '-40.3092752', 'vitória', 'serra', 'centro'],
  ['Rua Serra', 'Brunella II — Vila Velha/ES', 'Vila Velha', '33 km', 'amarela', 'route', '-20.4450980', '-40.3480819', 'serra', 'vila velha', 'brunella'],
  ['Rua Serra', 'Cidade Nova da Serra — Serra/ES', 'Serra', '16 km', 'amarela', 'route', '-20.0394889', '-40.3915358', 'serra', 'cidade', 'nova'],
  ['Rua Serra', 'Morada Bethânia — Viana/ES', 'Viana', '29 km', 'amarela', 'route', '-20.3859062', '-40.4068452', 'serra', 'viana', 'morada', 'bethânia'],
  ['Rua Serra', 'Vista Linda — Cariacica/ES', 'Cariacica', '28 km', 'laranja', 'route', '-20.3917465', '-40.3746411', 'serra', 'cariacica', 'vista', 'linda'],
  ['Rua Serra', 'Nova Brasília — Cariacica/ES', 'Cariacica', '22 km', 'laranja', 'route', '-20.3257080', '-40.3891685', 'serra', 'cariacica', 'nova', 'brasília'],
  ['Rua Serra', 'Barra do Riacho — Aracruz/ES', 'Aracruz', '39 km', 'amarela', 'route', '-19.8718448', '-40.0821436', 'serra', 'aracruz', 'barra', 'riacho'],
  ['Rua Vila Velha', 'Barcelona — Serra/ES', 'Serra', '5 km', 'amarela', 'route', '-20.1728452', '-40.2593489', 'vila', 'velha', 'serra', 'barcelona'],
  ['Rua Vila Velha', 'Vista Linda — Cariacica/ES', 'Cariacica', '28 km', 'laranja', 'route', '-20.3933616', '-40.3744790', 'vila', 'velha', 'cariacica', 'vista', 'linda'],
  ['Rua Vila Velha', 'Nova Brasília — Cariacica/ES', 'Cariacica', '22 km', 'laranja', 'route', '-20.3253203', '-40.3933031', 'vila', 'velha', 'cariacica', 'nova', 'brasília'],
  ['Rua Vila Velha', 'Morada Bethânia — Viana/ES', 'Viana', '29 km', 'amarela', 'route', '-20.3844513', '-40.4073577', 'vila', 'velha', 'viana', 'morada', 'bethânia'],
  ['Rua Vila Velha', 'Vila Bandeirantes — Cariacica/ES', 'Cariacica', '22 km', 'laranja', 'route', '-20.3287271', '-40.3924975', 'vila', 'velha', 'cariacica', 'bandeirantes'],
  ['Rua Vila Velha', 'São Gabriel — Guarapari/ES', 'Guarapari', '60 km', 'amarela', 'route', '-20.6407195', '-40.5237189', 'vila', 'velha', 'guarapari', 'são', 'gabriel'],
  ['Rua Vila Velha', 'Presidente Kennedy/ES', 'Presidente Kennedy', '145 km', 'amarela', 'route', '-21.2768764', '-40.9649487', 'vila', 'velha', 'presidente kennedy'],
  ['Rua Vila Velha', 'Boa Vista — Pedro Canário/ES', 'Pedro Canário', '208 km', 'amarela', 'route', '-18.3075247', '-39.9527006', 'vila', 'velha', 'pedro canário', 'boa', 'vista'],
  ['Rua Vila Velha', 'Vila Residêncial Samarco — Anchieta/ES', 'Anchieta', '82 km', 'amarela', 'route', '-20.8109264', '-40.6374366', 'vila', 'velha', 'anchieta', 'residêncial', 'samarco'],
  ['Rua Vila Velha', 'Vila Velha/ES', 'Vila Velha', '26 km', 'amarela', 'route', '-20.3834192', '-40.3150914', 'vila', 'velha', 'vila velha'],
  ['Rua Domingos Martins', 'Vista Linda — Cariacica/ES', 'Cariacica', '28 km', 'laranja', 'route', '-20.3930079', '-40.3750600', 'domingos', 'martins', 'cariacica', 'vista', 'linda'],
  ['Rua Cariacica', 'Zumbi — Cachoeiro de Itapemirim/ES', 'Cachoeiro de Itapemirim', '121 km', 'amarela', 'route', '-20.8496582', '-41.1318713', 'cariacica', 'cachoeiro de itapemirim', 'zumbi'],
  ['Rua Cariacica', 'José Rodrigues Maciel — Linhares/ES', 'Linhares', '90 km', 'amarela', 'route', '-19.3770479', '-40.0654689', 'cariacica', 'linhares', 'josé', 'rodrigues', 'maciel'],
  ['Rua Cariacica', 'São Marcos — Colatina/ES', 'Colatina', '80 km', 'amarela', 'route', '-19.5250647', '-40.6663865', 'cariacica', 'colatina', 'são', 'marcos'],
  ['Rua Cariacica', 'Maria Ismênia — Colatina/ES', 'Colatina', '77 km', 'amarela', 'route', '-19.5447013', '-40.6360836', 'cariacica', 'colatina', 'maria', 'ismênia'],
  ['Rua Cariacica', 'Jardim da Serra — Serra/ES', 'Serra', '4 km', 'amarela', 'route', '-20.1184464', '-40.3164688', 'cariacica', 'serra', 'jardim'],
  ['Rua Cariacica', 'Reis Magos — Serra/ES', 'Serra', '15 km', 'amarela', 'route', '-20.0572811', '-40.2002157', 'cariacica', 'serra', 'reis', 'magos'],
  ['Rua Cariacica', 'Belvedere — Serra/ES', 'Serra', '7 km', 'amarela', 'route', '-20.0984336', '-40.3395366', 'cariacica', 'serra', 'belvedere'],
  ['Rua Cariacica', 'Jardim Botânico — Cariacica/ES', 'Cariacica', '28 km', 'laranja', 'route', '-20.3885048', '-40.3716208', 'cariacica', 'jardim', 'botânico'],
  ['Rua Cariacica', 'Vila Capixaba — Cariacica/ES', 'Cariacica', '23 km', 'laranja', 'route', '-20.3349200', '-40.3997407', 'cariacica', 'vila', 'capixaba'],
  ['Rua Cariacica', 'Morada Bethânia — Viana/ES', 'Viana', '29 km', 'amarela', 'route', '-20.3842871', '-40.4062205', 'cariacica', 'viana', 'morada', 'bethânia'],
  ['Rua Cariacica', 'Nova Esperança — Cariacica/ES', 'Cariacica', '16 km', 'laranja', 'route', '-20.2663640', '-40.3910475', 'cariacica', 'nova', 'esperança'],
  ['Rua Leopoldina', 'Boa Sorte — Cariacica/ES', 'Cariacica', '23 km', 'laranja', 'route', '-20.3497615', '-40.3657706', 'leopoldina', 'cariacica', 'boa', 'sorte'],
  ['Avenida Cariacica', 'Prolar — Cariacica/ES', 'Cariacica', '19 km', 'laranja', 'route', '-20.2604004', '-40.4282516', 'cariacica', 'prolar'],
  ['Avenida Vitória', 'Forte São João — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3170093', '-40.3239363', 'vitória', 'forte', 'são', 'joão'],
  ['Avenida Vitória', 'Romão — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3157649', '-40.3231581', 'vitória', 'romão'],
  ['Avenida Vitória', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3103737', '-40.3056546', 'vitória', 'bento', 'ferreira'],
  ['Avenida Vitória', 'Ilha de Santa Maria — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3113171', '-40.3179263', 'vitória', 'ilha', 'santa', 'maria'],
  ['Avenida Vitória', 'Horto — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3101600', '-40.3106321', 'vitória', 'horto'],
  ['Avenida Vitória', 'Consolação — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3105411', '-40.3132532', 'vitória', 'consolação'],
  ['Avenida Vitória', 'Nazareth — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3108526', '-40.3154231', 'vitória', 'nazareth'],
  ['Avenida Vitória', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3109748', '-40.3155070', 'vitória', 'monte', 'belo'],
  ['Avenida Serra Pelada', 'Vila Velha/ES', 'Vila Velha', '24 km', 'amarela', 'route', '-20.3623782', '-40.3559363', 'serra', 'pelada', 'vila velha'],
  ['Avenida Serra do Caparaó', 'Praia da Baleia — Serra/ES', 'Serra', '10 km', 'amarela', 'route', '-20.1625269', '-40.2113232', 'serra', 'caparaó', 'praia', 'baleia'],
  ['Avenida Vila Velha', 'Centro — Pedro Canário/ES', 'Pedro Canário', '209 km', 'amarela', 'route', '-18.3025075', '-39.9550051', 'vila', 'velha', 'pedro canário', 'centro'],
  ['Avenida Robert Kennedy', 'Vila Velha/ES', 'Vila Velha', '20 km', 'amarela', 'route', '-20.3266965', '-40.3519799', 'robert', 'kennedy', 'vila velha'],
  ['Rua Engenheiro Guilherme José Monjardim Varejão', 'Enseada do Suá — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3158516', '-40.2901563', 'engenheiro', 'guilherme', 'josé', 'monjardim', 'varejão', 'vitória', 'enseada'],
  ['Rua José Luiz de Matos', 'Maruípe — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2950092', '-40.3175081', 'josé', 'luiz', 'matos', 'vitória', 'maruípe'],
  ['Rua José Luiz Gabeira', 'Barro Vermelho — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2942012', '-40.2987648', 'josé', 'luiz', 'gabeira', 'vitória', 'barro', 'vermelho'],
  ['Rua Barcelo Loyola', 'São José — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2829376', '-40.3304051', 'barcelo', 'loyola', 'vitória', 'são', 'josé'],
  ['Rua José Mathias do Nascimento', 'Santa Tereza — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3151171', '-40.3501080', 'josé', 'mathias', 'nascimento', 'vitória', 'santa', 'tereza'],
  ['Rua José Cassiano dos Santos', 'Maruípe — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3035867', '-40.3230105', 'josé', 'cassiano', 'santos', 'vitória', 'maruípe'],
  ['Rua José Daniel Nunes', 'Joana Darc — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2876834', '-40.3145312', 'josé', 'daniel', 'nunes', 'vitória', 'joana', 'darc'],
  ['Rua José Rufino de Morais', 'Inhanguetá — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.2980200', '-40.3481834', 'josé', 'rufino', 'morais', 'vitória', 'inhanguetá'],
  ['Rua José Martins da Silva', 'Romão — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3132718', '-40.3273278', 'josé', 'martins', 'silva', 'vitória', 'romão'],
  ['Rua José Farias', 'Santa Luíza — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2917326', '-40.3003500', 'josé', 'farias', 'vitória', 'santa', 'luíza'],
  ['Rua José Rodrigues de Oliveira', 'Quadro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3172008', '-40.3501881', 'josé', 'rodrigues', 'oliveira', 'vitória', 'quadro'],
  ['Rua João José Cabas', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2733361', '-40.2877839', 'joão', 'josé', 'cabas', 'vitória', 'mata', 'praia'],
  ['Rua José Marcelino', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3200315', '-40.3368261', 'josé', 'marcelino', 'vitória', 'centro'],
  ['Rua Doutor José Benjamim Costa', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3201963', '-40.3383002', 'doutor', 'josé', 'benjamim', 'costa', 'vitória', 'centro'],
  ['Rua José Malta', 'Fradinhos — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3063720', '-40.3276167', 'josé', 'malta', 'vitória', 'fradinhos'],
  ['Rua Pedro Nolasco', 'Vila Rubim — Vitória/ES', 'Vitória', '20 km', 'amarela', 'route', '-20.3211338', '-40.3455061', 'pedro', 'nolasco', 'vitória', 'vila', 'rubim'],
  ['Rua Pedro Carlos de Souza', 'Ilha de Santa Maria — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3157690', '-40.3208924', 'pedro', 'carlos', 'souza', 'vitória', 'ilha', 'santa', 'maria'],
  ['Rua Pedro José Vieira', 'Santo Antônio — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3096230', '-40.3552109', 'pedro', 'josé', 'vieira', 'vitória', 'santo', 'antônio'],
  ['Rua Pedro Palácios', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3206637', '-40.3385674', 'pedro', 'palácios', 'vitória', 'centro'],
  ['Rua Pedro Botti', 'Consolação — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3070052', '-40.3135842', 'pedro', 'botti', 'vitória', 'consolação'],
  ['Rua Pedro Lima do Rosário', 'Gurigica — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3083672', '-40.3042179', 'pedro', 'lima', 'rosário', 'vitória', 'gurigica'],
  ['Rua São Pedro', 'Nova Palestina — Vitória/ES', 'Vitória', '14 km', 'vermelha', 'route', '-20.2715578', '-40.3250838', 'são', 'pedro', 'vitória', 'nova', 'palestina'],
  ['Rua João Pedro da Silva', 'Joana Darc — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2893398', '-40.3173968', 'joão', 'pedro', 'silva', 'vitória', 'joana', 'darc'],
  ['Rua São Pedro', 'Vila Rubim — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3184103', '-40.3479723', 'são', 'pedro', 'vitória', 'vila', 'rubim'],
  ['Rua Pedro Bandeira', 'Redenção — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2764270', '-40.3293914', 'pedro', 'bandeira', 'vitória', 'redenção'],
  ['Rua Pedro Fonseca', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3157348', '-40.3135657', 'pedro', 'fonseca', 'vitória', 'monte', 'belo'],
  ['Rua Pedro Carlos de Souza', 'Forte São João — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3140294', '-40.3209012', 'pedro', 'carlos', 'souza', 'vitória', 'forte', 'são', 'joão'],
  ['Avenida Pedro Feu Rosa', 'Jardim da Penha — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2847792', '-40.3004595', 'pedro', 'feu', 'rosa', 'vitória', 'jardim', 'penha'],
  ['Rua das Flores', 'Nova Palestina — Vitória/ES', 'Vitória', '14 km', 'vermelha', 'route', '-20.2725863', '-40.3259444', 'flores', 'vitória', 'nova', 'palestina'],
  ['Rua João Vitória', 'Santa Martha — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2896269', '-40.3108569', 'joão', 'vitória', 'santa', 'martha'],
  ['Rua Santa Rita de Cássia', 'Bairro de Lourdes — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3078159', '-40.3165266', 'santa', 'rita', 'cássia', 'vitória', 'bairro', 'lourdes'],
  ['Rua Santa Luiza', 'Santa Cecília — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3022879', '-40.3214056', 'santa', 'luiza', 'vitória', 'cecília'],
  ['Rua Santa Rita de Cássia', 'Resistência — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2731736', '-40.3206629', 'santa', 'rita', 'cássia', 'vitória', 'resistência'],
  ['Rua Santa Cruz', 'Resistência — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2733941', '-40.3197224', 'santa', 'cruz', 'vitória', 'resistência'],
  ['Rua Santa Cecília', 'Santa Clara — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3182263', '-40.3438816', 'santa', 'cecília', 'vitória', 'clara'],
  ['Rua Santa Clara', 'Santa Clara — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3187193', '-40.3459618', 'santa', 'clara', 'vitória'],
  ['Rua Antônio Keffer', 'Santa Martha — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2837419', '-40.3123983', 'antônio', 'keffer', 'vitória', 'santa', 'martha'],
  ['Rua Santa Priscila', 'Maria Ortiz — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2602464', '-40.2998164', 'santa', 'priscila', 'vitória', 'maria', 'ortiz'],
  ['Travessa Santa Alexanderina', 'São José — Vitória/ES', 'Vitória', '15 km', 'amarela', 'location', '-20.2812400', '-40.3297108', 'travessa', 'santa', 'alexanderina', 'vitória', 'são', 'josé'],
  ['Rua Alexandrina Rosa Correia', 'Redenção — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2805406', '-40.3295483', 'alexandrina', 'rosa', 'correia', 'vitória', 'redenção'],
  ['Rua Nova Jerusalém', 'Nova Palestina — Vitória/ES', 'Vitória', '14 km', 'vermelha', 'route', '-20.2743270', '-40.3289487', 'nova', 'jerusalém', 'vitória', 'palestina'],
  ['Rua Nova', 'São Benedito — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3036770', '-40.3062724', 'nova', 'vitória', 'são', 'benedito'],
  ['Rua Horácio Dias dos Santos', 'Santo Antônio — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3089716', '-40.3556308', 'horácio', 'dias', 'santos', 'vitória', 'santo', 'antônio'],
  ['Rua Gelú Vervloet dos Santos', 'Aeroporto — Vitória/ES', 'Vitória', '13 km', 'amarela', 'route', '-20.2652589', '-40.2711509', 'gelú', 'vervloet', 'santos', 'vitória', 'aeroporto'],
  ['Rua Leocádia Pedra dos Santos', 'Enseada do Suá — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3155636', '-40.2907238', 'leocádia', 'pedra', 'santos', 'vitória', 'enseada', 'suá'],
  ['Rua Anélia Santos', 'Redenção — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2800870', '-40.3304405', 'anélia', 'santos', 'vitória', 'redenção'],
  ['Rua Licinio dos Santos Conte', 'Enseada do Suá — Vitória/ES', 'Vitória', '19 km', 'verde', 'route', '-20.3169942', '-40.2994444', 'licinio', 'santos', 'conte', 'vitória', 'enseada', 'suá'],
  ['Rua Soldado Abílio Santos', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3177848', '-40.3393284', 'soldado', 'abílio', 'santos', 'vitória', 'centro'],
  ['Rua João Venancio dos Santos', 'Caratoíra — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3142683', '-40.3548185', 'joão', 'venancio', 'santos', 'vitória', 'caratoíra'],
  ['Rua Ariosto Silva Santos', 'Santa Tereza — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3138991', '-40.3494391', 'ariosto', 'silva', 'santos', 'vitória', 'santa', 'tereza'],
  ['Rua Felicidade Correia dos Santos', 'São Pedro — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2801272', '-40.3344564', 'felicidade', 'correia', 'santos', 'vitória', 'são', 'pedro'],
  ['Rua Felicidade Correia dos Santos', 'Ilha das Caieiras — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2793548', '-40.3342408', 'felicidade', 'correia', 'santos', 'vitória', 'ilha', 'das', 'caieiras'],
  ['Rua Felicidade Correia dos Santos', 'Santo André — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2803942', '-40.3341617', 'felicidade', 'correia', 'santos', 'vitória', 'santo', 'andré'],
  ['Rua Walter dos Santos Gonçalves', 'Enseada do Suá — Vitória/ES', 'Vitória', '19 km', 'verde', 'route', '-20.3177930', '-40.2904739', 'walter', 'santos', 'gonçalves', 'vitória', 'enseada', 'suá'],
  ['Rua José Cassiano dos Santos', 'Fradinhos — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3055642', '-40.3239005', 'josé', 'cassiano', 'santos', 'vitória', 'fradinhos'],
  ['Avenida João dos Santos Filho', 'Ilha de Santa Maria — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3131419', '-40.3192742', 'joão', 'santos', 'filho', 'vitória', 'ilha', 'santa', 'maria'],
  ['Rua Francisco Florêncio', 'São Cristóvão — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2921831', '-40.3191011', 'francisco', 'florêncio', 'vitória', 'são', 'cristóvão'],
  ['Rua Francisco Eugênio Mussiello', 'Jardim da Penha — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2802427', '-40.2947229', 'francisco', 'eugênio', 'mussiello', 'vitória', 'jardim', 'penha'],
  ['Rua José Francisco Bertholdo', 'Santos Dumont — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3025523', '-40.3169606', 'josé', 'francisco', 'bertholdo', 'vitória', 'santos', 'dumont'],
  ['Rua Francisco Rubim', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3122878', '-40.3055238', 'francisco', 'rubim', 'vitória', 'bento', 'ferreira'],
  ['Rua Cais de São Francisco', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3200222', '-40.3406255', 'cais', 'são', 'francisco', 'vitória', 'centro'],
  ['Rua Francisco Mercadante', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2754695', '-40.2994040', 'francisco', 'mercadante', 'vitória', 'mata', 'praia'],
  ['Rua Francisco Araújo', 'Centro — Vitória/ES', 'Vitória', '20 km', 'amarela', 'route', '-20.3214340', '-40.3399588', 'francisco', 'araújo', 'vitória', 'centro'],
  ['Rua Francisco Perreira da Silva', 'Tabuazeiro — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2946213', '-40.3222440', 'francisco', 'perreira', 'silva', 'vitória', 'tabuazeiro'],
  ['Rua Francisco Rubim', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3138985', '-40.3121631', 'francisco', 'rubim', 'vitória', 'monte', 'belo'],
  ['Rua Francisco Costa Firme', 'Tabuazeiro — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2944006', '-40.3200772', 'francisco', 'costa', 'firme', 'vitória', 'tabuazeiro'],
  ['Rua Francisco Pereira de Lucena', 'Tabuazeiro — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2935054', '-40.3213826', 'francisco', 'pereira', 'lucena', 'vitória', 'tabuazeiro'],
  ['Rua José Francisco de Oliveira', 'Santo André — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2781867', '-40.3313849', 'josé', 'francisco', 'oliveira', 'vitória', 'santo', 'andré'],
  ['Rua Francisco de Araújo Machado', 'Maria Ortiz — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2606429', '-40.2978422', 'francisco', 'araújo', 'machado', 'vitória', 'maria', 'ortiz'],
  ['Rua Antônio Borges', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2730523', '-40.2890467', 'antônio', 'borges', 'vitória', 'mata', 'praia'],
  ['Rua Antônio Santos', 'Maruípe — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2940613', '-40.3170686', 'antônio', 'santos', 'vitória', 'maruípe'],
  ['Rua Antônio Lisboa do Nascimento', 'Goiabeiras — Vitória/ES', 'Vitória', '13 km', 'verde', 'route', '-20.2685815', '-40.2990434', 'antônio', 'lisboa', 'nascimento', 'vitória', 'goiabeiras'],
  ['Rua Loren Reno', 'Parque Moscoso — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3171970', '-40.3411121', 'loren', 'reno', 'vitória', 'parque', 'moscoso'],
  ['Rua Professor Carlos Leonardo Kulnig', 'Maria Ortiz — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2565257', '-40.2934443', 'professor', 'carlos', 'leonardo', 'kulnig', 'vitória', 'maria', 'ortiz'],
  ['Rua Waldomiro Antônio Pereira', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2788303', '-40.2893796', 'waldomiro', 'antônio', 'pereira', 'vitória', 'mata', 'praia'],
  ['Rua Antônio Araújo Lyra', 'Jardim Camburi — Vitória/ES', 'Vitória', '13 km', 'verde', 'route', '-20.2640401', '-40.2686034', 'antônio', 'araújo', 'lyra', 'vitória', 'jardim', 'camburi'],
  ['Rua Antônio Aleixo', 'Consolação — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3089454', '-40.3143010', 'antônio', 'aleixo', 'vitória', 'consolação'],
  ['Rua Antônio Caliari', 'Boa Vista — Vitória/ES', 'Vitória', '13 km', 'amarela', 'route', '-20.2714202', '-40.2983854', 'antônio', 'caliari', 'vitória', 'boa', 'vista'],
  ['Rua Antônio Campos', 'Bela Vista — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3065150', '-40.3502756', 'antônio', 'campos', 'vitória', 'bela', 'vista'],
  ['Rua Antonino Ribeiro', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2742518', '-40.2869378', 'antonino', 'ribeiro', 'vitória', 'mata', 'praia'],
  ['Rua Álvaro Andrade Leitão', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2747108', '-40.2884434', 'álvaro', 'andrade', 'leitão', 'vitória', 'mata', 'praia'],
  ['Rua Antônio Nunes Marquês', 'Cabral — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3152430', '-40.3488283', 'antônio', 'nunes', 'marquês', 'vitória', 'cabral'],
  ['Rua Alencar Pereira Nascimento', 'Ariovaldo Favalessa — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3139966', '-40.3569144', 'alencar', 'pereira', 'nascimento', 'vitória', 'ariovaldo', 'favalessa'],
  ['Rua Doutor Antônio Honório', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3141804', '-40.3028466', 'doutor', 'antônio', 'honório', 'vitória', 'bento', 'ferreira'],
  ['Rua Manoel Vivácqua', 'Jabour — Vitória/ES', 'Vitória', '12 km', 'vermelha', 'route', '-20.2566152', '-40.2919761', 'manoel', 'vivácqua', 'vitória', 'jabour'],
  ['Rua Manoel da Silva', 'Tabuazeiro — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2914485', '-40.3231474', 'manoel', 'silva', 'vitória', 'tabuazeiro'],
  ['Rua Manoel Ferreira Constatino', 'Bela Vista — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3006024', '-40.3482775', 'manoel', 'ferreira', 'constatino', 'vitória', 'bela', 'vista'],
  ['Rua Manoel Francisco Ribeiro', 'Consolação — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3073553', '-40.3099832', 'manoel', 'francisco', 'ribeiro', 'vitória', 'consolação'],
  ['Rua Manoel Rosindo da Silva', 'São Pedro — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2846624', '-40.3360774', 'manoel', 'rosindo', 'silva', 'vitória', 'são', 'pedro'],
  ['Rua Manoel Salustiano de Souza', 'Santa Martha — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2865988', '-40.3107897', 'manoel', 'salustiano', 'souza', 'vitória', 'santa', 'martha'],
  ['Rua Manoel Pinheiro', 'São Cristóvão — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2954186', '-40.3147717', 'manoel', 'pinheiro', 'vitória', 'são', 'cristóvão'],
  ['Rua Manoel Botelho', 'Inhanguetá — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3012527', '-40.3476170', 'manoel', 'botelho', 'vitória', 'inhanguetá'],
  ['Rua Manoel Julião', 'Cabral — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3175341', '-40.3479720', 'manoel', 'julião', 'vitória', 'cabral'],
  ['Rua Soldado Manoel Furtado', 'Santo Antônio — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3086427', '-40.3542727', 'soldado', 'manoel', 'furtado', 'vitória', 'santo', 'antônio'],
  ['Rua Rufino Manoel do Oliveira', 'Consolação — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3071383', '-40.3117176', 'rufino', 'manoel', 'oliveira', 'vitória', 'consolação'],
  ['Rua Manoel Marques de Moraes', 'Andorinhas — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2885332', '-40.3061089', 'manoel', 'marques', 'moraes', 'vitória', 'andorinhas'],
  ['Rua Engenheiro Manoel dos Passos Barros', 'Mário Cypreste — Vitória/ES', 'Vitória', '20 km', 'amarela', 'route', '-20.3195496', '-40.3527859', 'engenheiro', 'manoel', 'passos', 'barros', 'vitória', 'mário', 'cypreste'],
  ['Rua Milton Manoel dos Santos', 'Jardim Camburi — Vitória/ES', 'Vitória', '13 km', 'verde', 'route', '-20.2610006', '-40.2602559', 'milton', 'manoel', 'santos', 'vitória', 'jardim', 'camburi'],
  ['Rua Professor Mário Bodart', 'Maria Ortiz — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2583766', '-40.3000733', 'professor', 'mário', 'bodart', 'vitória', 'maria', 'ortiz'],
  ['Rua Mário Benezath', 'Santa Cecília — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3005691', '-40.3209360', 'mário', 'benezath', 'vitória', 'santa', 'cecília'],
  ['Rua Desembargador Mário da Silva Nunes', 'Enseada do Suá — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3162384', '-40.2895682', 'desembargador', 'mário', 'silva', 'nunes', 'vitória', 'enseada', 'suá'],
  ['Rua Dorival Rosindo da Silva', 'Bela Vista — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3051562', '-40.3486901', 'dorival', 'rosindo', 'silva', 'vitória', 'bela', 'vista'],
  ['Rua Mário Rosendo', 'Bela Vista — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3041902', '-40.3487015', 'mário', 'rosendo', 'vitória', 'bela', 'vista'],
  ['Rua Mário Miranda de Madureira', 'Segurança do Lar — Vitória/ES', 'Vitória', '13 km', 'amarela', 'route', '-20.2628695', '-40.2965502', 'mário', 'miranda', 'madureira', 'vitória', 'segurança', 'lar'],
  ['Rua Mário de Oliveira Silva', 'Fonte Grande — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3145362', '-40.3380847', 'mário', 'oliveira', 'silva', 'vitória', 'fonte', 'grande'],
  ['Rua Mário Cipreste', 'Mário Cypreste — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3153312', '-40.3579997', 'mário', 'cipreste', 'vitória', 'cypreste'],
  ['Rua Mário Loureiro Nunes', 'Bonfim — Vitória/ES', 'Vitória', '17 km', 'laranja', 'route', '-20.3016317', '-40.3143295', 'mário', 'loureiro', 'nunes', 'vitória', 'bonfim'],
  ['Rua Mário Teixeira Nascimento', 'Estrelinha — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.2952050', '-40.3469398', 'mário', 'teixeira', 'nascimento', 'vitória', 'estrelinha'],
  ['Rua Doutor Mário Ferreira Casanova', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3110835', '-40.3106711', 'doutor', 'mário', 'ferreira', 'casanova', 'vitória', 'bento'],
  ['Servidão Jadir Correa dos Santos', 'Mário Cypreste — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3153816', '-40.3573897', 'servidão', 'jadir', 'correa', 'santos', 'vitória', 'mário', 'cypreste'],
  ['Praça Mário Aristides Freire', 'Jucutuquara — Vitória/ES', 'Vitória', '18 km', 'amarela', 'park', '-20.3088199', '-40.3197828', 'praça', 'mário', 'aristides', 'freire', 'vitória', 'jucutuquara'],
  ['Rua Carlos Moreira Lima', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3133133', '-40.3052836', 'carlos', 'moreira', 'lima', 'vitória', 'bento', 'ferreira'],
  ['Rua Carlos Delegado Guerra Pinto', 'Jardim Camburi — Vitória/ES', 'Vitória', '13 km', 'verde', 'route', '-20.2649081', '-40.2699264', 'carlos', 'delegado', 'guerra', 'pinto', 'vitória', 'jardim', 'camburi'],
  ['Rua Carlos Alves', 'Gurigica — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3104089', '-40.3036958', 'carlos', 'alves', 'vitória', 'gurigica'],
  ['Rua Carlos Alves', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3104717', '-40.3036545', 'carlos', 'alves', 'vitória', 'bento', 'ferreira'],
  ['Rua Carlos Moreira Lima', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3155357', '-40.3151884', 'carlos', 'moreira', 'lima', 'vitória', 'monte', 'belo'],
  ['Rua Luiz Carlos Grecco', 'Ilha de Santa Maria — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3172901', '-40.3201052', 'luiz', 'carlos', 'grecco', 'vitória', 'ilha', 'santa', 'maria'],
  ['Rua Carlos Martins', 'Jardim Camburi — Vitória/ES', 'Vitória', '13 km', 'verde', 'route', '-20.2591380', '-40.2696113', 'carlos', 'martins', 'vitória', 'jardim', 'camburi'],
  ['Rua Professor Walter Oliveira Passos', 'Maria Ortiz — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2559676', '-40.2962895', 'professor', 'walter', 'oliveira', 'passos', 'vitória', 'maria', 'ortiz'],
  ['Rua Paulo de Vasconcellos', 'Maria Ortiz — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2562238', '-40.2925297', 'paulo', 'vasconcellos', 'vitória', 'maria', 'ortiz'],
  ['Rua Paulo de Vasconcellos', 'Jabour — Vitória/ES', 'Vitória', '12 km', 'vermelha', 'route', '-20.2592795', '-40.2945802', 'paulo', 'vasconcellos', 'vitória', 'jabour'],
  ['Rua Oscar Paulo da Silva', 'Jesus de Nazareth — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3167255', '-40.3003582', 'oscar', 'paulo', 'silva', 'vitória', 'jesus', 'nazareth'],
  ['Rua Apóstolo São Paulo', 'São José — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2815485', '-40.3321453', 'apóstolo', 'são', 'paulo', 'vitória', 'josé'],
  ['Rua São Paulo', 'Santo André — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2795941', '-40.3324863', 'são', 'paulo', 'vitória', 'santo', 'andré'],
  ['Rua Paulo Muller', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3132466', '-40.3033971', 'paulo', 'muller', 'vitória', 'bento', 'ferreira'],
  ['Rua Apóstolo São Paulo', 'Santo André — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2803869', '-40.3322713', 'apóstolo', 'são', 'paulo', 'vitória', 'santo', 'andré'],
  ['Rua João Paulo Coutinho', 'Cabral — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3162469', '-40.3488770', 'joão', 'paulo', 'coutinho', 'vitória', 'cabral'],
  ['Rua São Paulo', 'São José — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2827185', '-40.3320233', 'são', 'paulo', 'vitória', 'josé'],
  ['Rua Paulo Delazare', 'Santa Martha — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2846994', '-40.3115194', 'paulo', 'delazare', 'vitória', 'santa', 'martha'],
  ['Rua Oscar Paulo da Silva', 'Enseada do Suá — Vitória/ES', 'Vitória', '19 km', 'verde', 'route', '-20.3172926', '-40.2998630', 'oscar', 'paulo', 'silva', 'vitória', 'enseada', 'suá'],
  ['Rua Nestor Marçal de Lima', 'Maria Ortiz — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2552823', '-40.2924184', 'nestor', 'marçal', 'lima', 'vitória', 'maria', 'ortiz'],
  ['Rua Silvio Tristão Aguiar', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2743977', '-40.2851505', 'silvio', 'tristão', 'aguiar', 'vitória', 'mata', 'praia'],
  ['Tribunal de Justiça do Espírito Santo', 'Enseada do Suá — Vitória/ES', 'Vitória', '18 km', 'verde', 'location', '-20.3139988', '-40.2922971', 'tribunal', 'justiça', 'espírito', 'santo', 'vitória', 'enseada', 'suá'],
  ['Escola do Espírito Santo de Serviços Público', 'República — Vitória/ES', 'Vitória', '14 km', 'amarela', 'school', '-20.2719293', '-40.2940835', 'escola', 'espírito', 'santo', 'serviços', 'público', 'vitória', 'república'],
  ['Palácio Fonte Grande Governo do Espírito Santo', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3168551', '-40.3372907', 'palácio', 'fonte', 'grande', 'governo', 'espírito', 'santo', 'vitória'],
  ['Faculdade de Música do Espírito Santo "Maurício de Oliveira"', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3201288', '-40.3287490', 'faculdade', 'música', 'espírito', 'santo', '"maurício', 'oliveira"', 'vitória'],
  ['Companhia Docas do Espírito Santo', 'Centro — Vitória/ES', 'Vitória', '20 km', 'amarela', 'location', '-20.3238397', '-40.3476488', 'companhia', 'docas', 'espírito', 'santo', 'vitória', 'centro'],
  ['Capitania das Portos do Espírito Santo', 'Enseada do Suá — Vitória/ES', 'Vitória', '19 km', 'verde', 'location', '-20.3178873', '-40.2970292', 'capitania', 'portos', 'espírito', 'santo', 'vitória', 'enseada', 'suá'],
  ['Ministério Público da República e Espírito Santo', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3197126', '-40.3336583', 'ministério', 'público', 'república', 'espírito', 'santo', 'vitória', 'centro'],
  ['5ª Vara Criminal de Vitória - VEPEMA', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3199506', '-40.3389213', 'vara', 'criminal', 'vitória', 'vepema', 'centro'],
  ['Banestes', 'Goiabeiras — Vitória/ES', 'Vitória', '13 km', 'verde', 'location', '-20.2665249', '-40.2981947', 'banestes', 'vitória', 'goiabeiras'],
  ['Banestes', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'location', '-20.3151217', '-40.3115776', 'banestes', 'vitória', 'monte', 'belo'],
  ['Departamento de Produção Mineral 20˚ Distrito do Espírito Santo', 'Enseada do Suá — Vitória/ES', 'Vitória', '19 km', 'verde', 'location', '-20.3168151', '-40.2931597', 'departamento', 'produção', 'mineral', '20˚', 'distrito', 'espírito', 'santo'],
  ['Escola Penitenciária do Espírito Santo', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'school', '-20.3127471', '-40.3059468', 'escola', 'penitenciária', 'espírito', 'santo', 'vitória', 'bento', 'ferreira'],
  ['Superintendência da PRF no Espírito Santo', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3192622', '-40.3297417', 'superintendência', 'prf', 'espírito', 'santo', 'vitória', 'centro'],
  ['Banestes', 'Praia do Suá — Vitória/ES', 'Vitória', '18 km', 'amarela', 'location', '-20.3117647', '-40.3009790', 'banestes', 'vitória', 'praia', 'suá'],
  ['Praia do Canto', 'Praia do Canto — Vitória/ES', 'Vitória', '16 km', 'verde', 'beach', '-20.2982860', '-40.2946647', 'praia', 'canto', 'vitória'],
  ['Jardim Camburi', 'Jardim Camburi — Vitória/ES', 'Vitória', '13 km', 'verde', 'location', '-20.2599804', '-40.2678940', 'jardim', 'camburi', 'vitória'],
  ['Bento Ferreira', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'location', '-20.3153408', '-40.3069497', 'bento', 'ferreira', 'vitória'],
  ['Mata da Praia', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'verde', 'beach', '-20.2760095', '-40.2939889', 'mata', 'praia', 'vitória'],
  ['Goiabeiras', 'Goiabeiras — Vitória/ES', 'Vitória', '13 km', 'verde', 'location', '-20.2706118', '-40.3028593', 'goiabeiras', 'vitória'],
  ['Distrito Goiabeiras', 'Vitória/ES', 'Vitória', '13 km', 'amarela', 'location', '-20.2651464', '-40.2695153', 'distrito', 'goiabeiras', 'vitória'],
  ['Enseada do Suá', 'Enseada do Suá — Vitória/ES', 'Vitória', '18 km', 'verde', 'location', '-20.3133066', '-40.2922293', 'enseada', 'suá', 'vitória'],
  ['Santa Lúcia', 'Santa Lúcia — Vitória/ES', 'Vitória', '17 km', 'amarela', 'location', '-20.3028247', '-40.3006106', 'santa', 'lúcia', 'vitória'],
  ['Santa Lúcia', 'Jardim Camburi — Vitória/ES', 'Vitória', '12 km', 'verde', 'location', '-20.2550725', '-40.2675678', 'santa', 'lúcia', 'vitória', 'jardim', 'camburi'],
  ['Jucutuquara', 'Jucutuquara — Vitória/ES', 'Vitória', '18 km', 'verde', 'location', '-20.3088122', '-40.3193274', 'jucutuquara', 'vitória'],
  ['Santo Antônio', 'Santo Antônio — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3080868', '-40.3550045', 'santo', 'antônio', 'vitória'],
  ['Maruípe', 'Maruípe — Vitória/ES', 'Vitória', '16 km', 'amarela', 'location', '-20.2963157', '-40.3198376', 'maruípe', 'vitória'],
  ['Região Administrativa IV - Maruípe', 'Vitória/ES', 'Vitória', '16 km', 'amarela', 'location', '-20.2923181', '-40.3170573', 'região', 'administrativa', 'maruípe', 'vitória'],
  ['Consolação', 'Consolação — Vitória/ES', 'Vitória', '17 km', 'amarela', 'location', '-20.3062550', '-40.3123350', 'consolação', 'vitória'],
  ['Resistência', 'Resistência — Vitória/ES', 'Vitória', '14 km', 'amarela', 'location', '-20.2710424', '-40.3186833', 'resistência', 'vitória'],
  ['São Pedro', 'São Pedro — Vitória/ES', 'Vitória', '15 km', 'amarela', 'location', '-20.2820175', '-40.3368799', 'são', 'pedro', 'vitória'],
  ['Região de Laranjeiras', 'Serra/ES', 'Serra', '8 km', 'amarela', 'location', '-20.2001421', '-40.2520064', 'região', 'laranjeiras', 'serra'],
  ['Bairro das Laranjeiras', 'Bairro das Laranjeiras — Serra/ES', 'Serra', '12 km', 'verde', 'location', '-20.1272367', '-40.1906812', 'bairro', 'laranjeiras', 'serra', 'das'],
  ['Laranjeiras Velha', 'Laranjeiras Velha — Serra/ES', 'Serra', '5 km', 'verde', 'location', '-20.1832062', '-40.2721078', 'laranjeiras', 'velha', 'serra'],
  ['Morada de Laranjeiras', 'Morada de Laranjeiras — Serra/ES', 'Serra', '10 km', 'verde', 'location', '-20.1949384', '-40.2225932', 'morada', 'laranjeiras', 'serra'],
  ['Parque Residencial Laranjeiras', 'Parque Residencial Laranjeiras — Serra/ES', 'Serra', '7 km', 'verde', 'park', '-20.1970038', '-40.2541242', 'parque', 'residencial', 'laranjeiras', 'serra'],
  ['Colina de Laranjeiras', 'Colina de Laranjeiras — Serra/ES', 'Serra', '6 km', 'verde', 'location', '-20.1875546', '-40.2574677', 'colina', 'laranjeiras', 'serra'],
  ['Praça Colina das Laranjeiras', 'Colina de Laranjeiras — Serra/ES', 'Serra', '6 km', 'verde', 'park', '-20.1876814', '-40.2579492', 'praça', 'colina', 'laranjeiras', 'serra'],
  ['Condominio Recreio das Laranjeiras', 'Taquara I — Serra/ES', 'Serra', '6 km', 'laranja', 'location', '-20.1851918', '-40.2642859', 'condominio', 'recreio', 'laranjeiras', 'serra', 'taquara'],
  ['Condomínio Via Laranjeiras', 'Morada de Laranjeiras — Serra/ES', 'Serra', '10 km', 'verde', 'location', '-20.1980407', '-40.2279167', 'condomínio', 'via', 'laranjeiras', 'serra', 'morada'],
  ['Praça Villaggio Laranjeiras', 'Planalto Carapina — Serra/ES', 'Serra', '7 km', 'laranja', 'park', '-20.1996994', '-40.2651187', 'praça', 'villaggio', 'laranjeiras', 'serra', 'planalto', 'carapina'],
  ['Avenida Laranjeiras', 'Condomínio — Serra/ES', 'Serra', '3 km', 'amarela', 'route', '-20.1440483', '-40.2724986', 'laranjeiras', 'serra', 'condomínio'],
  ['Avenida das Laranjeiras', 'Civit II — Serra/ES', 'Serra', '9 km', 'amarela', 'route', '-20.1982527', '-40.2367357', 'laranjeiras', 'serra', 'civit'],
  ['Rua Laranjeiras', 'Boa Vista I — Serra/ES', 'Serra', '15 km', 'amarela', 'route', '-20.0604814', '-40.1935311', 'laranjeiras', 'serra', 'boa', 'vista'],
  ['Rua das Laranjeiras', 'Boa Vista I — Serra/ES', 'Serra', '15 km', 'amarela', 'route', '-20.0611315', '-40.1942351', 'laranjeiras', 'serra', 'boa', 'vista'],
  ['Rua Laranjeiras', 'São João — Serra/ES', 'Serra', '16 km', 'amarela', 'route', '-20.0584017', '-40.1944580', 'laranjeiras', 'serra', 'são', 'joão'],
  ['Região de Carapina', 'Serra/ES', 'Serra', '9 km', 'amarela', 'location', '-20.2289737', '-40.2799316', 'região', 'carapina', 'serra'],
  ['Carapina I', 'Carapina I — Serra/ES', 'Serra', '11 km', 'laranja', 'location', '-20.2438885', '-40.2676266', 'carapina', 'serra'],
  ['Carapina Grande', 'Carapina Grande — Serra/ES', 'Serra', '9 km', 'laranja', 'location', '-20.2254098', '-40.2778279', 'carapina', 'grande', 'serra'],
  ['Nova Carapina I', 'Nova Carapina I — Serra/ES', 'Serra', '4 km', 'laranja', 'location', '-20.1556254', '-40.2679154', 'nova', 'carapina', 'serra'],
  ['Nova Carapina II', 'Nova Carapina II — Serra/ES', 'Serra', '3 km', 'laranja', 'location', '-20.1511297', '-40.2710162', 'nova', 'carapina', 'serra'],
  ['Central Carapina', 'Central Carapina — Serra/ES', 'Serra', '8 km', 'laranja', 'location', '-20.2194255', '-40.2753505', 'central', 'carapina', 'serra'],
  ['Planalto Carapina', 'Planalto Carapina — Serra/ES', 'Serra', '7 km', 'laranja', 'location', '-20.2075676', '-40.2685258', 'planalto', 'carapina', 'serra'],
  ['Jardim Carapina', 'Jardim Carapina — Serra/ES', 'Serra', '9 km', 'laranja', 'location', '-20.2320656', '-40.2844941', 'jardim', 'carapina', 'serra'],
  ['Boa Vista (Carapina)', 'Boa Vista (Carapina) — Serra/ES', 'Serra', '10 km', 'laranja', 'location', '-20.2364242', '-40.2802052', 'boa', 'vista', '(carapina)', 'serra'],
  ['Pavilhão de Carapina', 'Jardim Carapina — Serra/ES', 'Serra', '9 km', 'laranja', 'location', '-20.2315537', '-40.2808858', 'pavilhão', 'carapina', 'serra', 'jardim'],
  ['Condomínio Residencial Carapina B1', 'Morada de Laranjeiras — Serra/ES', 'Serra', '9 km', 'verde', 'location', '-20.1963749', '-40.2331482', 'condomínio', 'residencial', 'carapina', 'serra', 'morada', 'laranjeiras'],
  ['Nova Almeida', 'Serra/ES', 'Serra', '15 km', 'amarela', 'location', '-20.0585100', '-40.1959950', 'nova', 'almeida', 'serra'],
  ['Jardim Limoeiro', 'Jardim Limoeiro — Serra/ES', 'Serra', '8 km', 'amarela', 'location', '-20.2180358', '-40.2663839', 'jardim', 'limoeiro', 'serra'],
  ['Defensoria Pública do Estado do Espírito Santo', 'Centro — Mimoso do Sul/ES', 'Mimoso do Sul', '156 km', 'amarela', 'location', '-21.0614768', '-41.3669378', 'defensoria', 'pública', 'estado', 'espírito', 'santo', 'mimoso do sul', 'centro'],
  ['Manguinhos', 'Manguinhos — Serra/ES', 'Serra', '12 km', 'amarela', 'location', '-20.1928430', '-40.1980170', 'manguinhos', 'serra'],
  ['Praia de Itaparica', 'Vila Velha/ES', 'Vila Velha', '25 km', 'amarela', 'beach', '-20.3715102', '-40.3025992', 'praia', 'itaparica', 'vila velha'],
  ['Praia de Itaparica', 'Praia de Itaparica — Vila Velha/ES', 'Vila Velha', '24 km', 'verde', 'beach', '-20.3696296', '-40.3039078', 'praia', 'itaparica', 'vila velha'],
  ['Coqueiral de Itaparica', 'Coqueiral de Itaparica — Vila Velha/ES', 'Vila Velha', '24 km', 'verde', 'location', '-20.3635331', '-40.3038749', 'coqueiral', 'itaparica', 'vila velha'],
  ['Nova Itaparica', 'Nova Itaparica — Vila Velha/ES', 'Vila Velha', '25 km', 'verde', 'location', '-20.3758183', '-40.3179478', 'nova', 'itaparica', 'vila velha'],
  ['Jockey de Itaparica', 'Jockey de Itaparica — Vila Velha/ES', 'Vila Velha', '27 km', 'verde', 'location', '-20.3881237', '-40.3175077', 'jockey', 'itaparica', 'vila velha'],
  ['Praia do Coqueiral de Itaparica', 'Vila Velha/ES', 'Vila Velha', '27 km', 'amarela', 'beach', '-20.3910247', '-40.3136216', 'praia', 'coqueiral', 'itaparica', 'vila velha'],
  ['Segunda Etapa - Condomínio Itaparica Sol', 'Coqueiral de Itaparica — Vila Velha/ES', 'Vila Velha', '24 km', 'verde', 'location', '-20.3674366', '-40.3055739', 'segunda', 'etapa', 'condomínio', 'itaparica', 'sol', 'vila velha', 'coqueiral'],
  ['Villaggio Itaparica', 'Vila Velha/ES', 'Vila Velha', '25 km', 'amarela', 'location', '-20.3785964', '-40.3087413', 'villaggio', 'itaparica', 'vila velha'],
  ['Centro Comercial de Itaparica', 'Vila Velha/ES', 'Vila Velha', '24 km', 'amarela', 'location', '-20.3617330', '-40.2997826', 'centro', 'comercial', 'itaparica', 'vila velha'],
  ['Bella Itaparica', 'Vila Velha/ES', 'Vila Velha', '25 km', 'amarela', 'location', '-20.3725368', '-40.3068239', 'bella', 'itaparica', 'vila velha'],
  ['Itaparica Top Business', 'Vila Velha/ES', 'Vila Velha', '25 km', 'amarela', 'location', '-20.3778614', '-40.3081187', 'itaparica', 'top', 'business', 'vila velha'],
  ['Itaparica Ocean Front', 'Vila Velha/ES', 'Vila Velha', '25 km', 'amarela', 'location', '-20.3789605', '-40.3087613', 'itaparica', 'ocean', 'front', 'vila velha'],
  ['Itaparica Exclusive', 'Vila Velha/ES', 'Vila Velha', '25 km', 'amarela', 'location', '-20.3781629', '-40.3082344', 'itaparica', 'exclusive', 'vila velha'],
  ['Costa de Itaparica', 'Vila Velha/ES', 'Vila Velha', '26 km', 'amarela', 'location', '-20.3803147', '-40.3099950', 'costa', 'itaparica', 'vila velha'],
  ['Praça Rodrigo Figueiredo da Rosa', 'Vila Velha/ES', 'Vila Velha', '24 km', 'amarela', 'park', '-20.3643273', '-40.3039697', 'praça', 'rodrigo', 'figueiredo', 'rosa', 'vila velha'],
  ['Praia da Costa', 'Praia da Costa — Vila Velha/ES', 'Vila Velha', '21 km', 'verde', 'beach', '-20.3350315', '-40.2824025', 'praia', 'costa', 'vila velha'],
  ['Praia da Costa', 'Jardim Praia da Costa — Vila Velha/ES', 'Vila Velha', '21 km', 'verde', 'beach', '-20.3394605', '-40.2823722', 'praia', 'costa', 'vila velha', 'jardim'],
  ['Região 01 - Centro', 'Vila Velha/ES', 'Vila Velha', '21 km', 'amarela', 'location', '-20.3363655', '-40.2935825', 'região', 'centro', 'vila velha'],
  ['Centro de Vila Velha', 'Centro de Vila Velha — Vila Velha/ES', 'Vila Velha', '21 km', 'amarela', 'location', '-20.3363548', '-40.2935892', 'centro', 'vila', 'velha', 'vila velha'],
  ['Terra Vermelha', 'Terra Vermelha — Vila Velha/ES', 'Vila Velha', '33 km', 'amarela', 'location', '-20.4434487', '-40.3514806', 'terra', 'vermelha', 'vila velha'],
  ['Barra do Jucu', 'Barra do Jucu — Vila Velha/ES', 'Vila Velha', '31 km', 'amarela', 'location', '-20.4285117', '-40.3251852', 'barra', 'jucu', 'vila velha'],
  ['Avenida Fernando Ferrari', 'Solon Borges — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2619194', '-40.2941040', 'fernando', 'ferrari', 'vitória', 'solon', 'borges'],
  ['Avenida Fernando Ferrari', 'Jabour — Vitória/ES', 'Vitória', '12 km', 'vermelha', 'route', '-20.2573330', '-40.2908966', 'fernando', 'ferrari', 'vitória', 'jabour'],
  ['Avenida Fernando Ferrari', 'Segurança do Lar — Vitória/ES', 'Vitória', '13 km', 'amarela', 'route', '-20.2643296', '-40.2961590', 'fernando', 'ferrari', 'vitória', 'segurança', 'lar'],
  ['Avenida Fernando Ferrari', 'Goiabeiras — Vitória/ES', 'Vitória', '14 km', 'verde', 'route', '-20.2720501', '-40.3010768', 'fernando', 'ferrari', 'vitória', 'goiabeiras'],
  ['Avenida Fernando Ferrari', 'Aeroporto — Vitória/ES', 'Vitória', '12 km', 'amarela', 'route', '-20.2575753', '-40.2908963', 'fernando', 'ferrari', 'vitória', 'aeroporto'],
  ['Avenida Fernando Ferrari', 'Jardim da Penha — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2806530', '-40.3015349', 'fernando', 'ferrari', 'vitória', 'jardim', 'penha'],
  ['Avenida Fernando Ferrari', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'verde', 'route', '-20.2758683', '-40.3008058', 'fernando', 'ferrari', 'vitória', 'mata', 'praia'],
  ['Avenida Fernando Ferrari', 'Boa Vista — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2733886', '-40.3007345', 'fernando', 'ferrari', 'vitória', 'boa', 'vista'],
  ['Avenida Adalberto Simão Nader', 'Aeroporto — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2726500', '-40.2854715', 'adalberto', 'simão', 'nader', 'vitória', 'aeroporto'],
  ['Avenida Adalberto Simão Nader', 'República — Vitória/ES', 'Vitória', '13 km', 'amarela', 'route', '-20.2707365', '-40.2888755', 'adalberto', 'simão', 'nader', 'vitória', 'república'],
  ['Avenida Adalberto Simão Nader', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'verde', 'route', '-20.2730593', '-40.2849140', 'adalberto', 'simão', 'nader', 'vitória', 'mata', 'praia'],
  ['Avenida Adalberto Simão Nader', 'Goiabeiras — Vitória/ES', 'Vitória', '13 km', 'verde', 'route', '-20.2664713', '-40.2960818', 'adalberto', 'simão', 'nader', 'vitória', 'goiabeiras'],
  ['Avenida Adalberto Simão Nader', 'Segurança do Lar — Vitória/ES', 'Vitória', '13 km', 'amarela', 'route', '-20.2648031', '-40.2967816', 'adalberto', 'simão', 'nader', 'vitória', 'segurança', 'lar'],
  ['Avenida Professor Fernando Duarte Rabelo', 'Segurança do Lar — Vitória/ES', 'Vitória', '13 km', 'amarela', 'route', '-20.2645119', '-40.2970163', 'professor', 'fernando', 'duarte', 'rabelo', 'vitória', 'segurança', 'lar'],
  ['Avenida Leitão da Silva', 'Santa Lúcia — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3080741', '-40.3027084', 'leitão', 'silva', 'vitória', 'santa', 'lúcia'],
  ['Avenida Leitão da Silva', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3144345', '-40.3019444', 'leitão', 'silva', 'vitória', 'bento', 'ferreira'],
  ['Avenida Leitão da Silva', 'Gurigica — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3036730', '-40.3034901', 'leitão', 'silva', 'vitória', 'gurigica'],
  ['Avenida Leitão da Silva', 'Itararé — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2964022', '-40.3045067', 'leitão', 'silva', 'vitória', 'itararé'],
  ['Avenida Leitão da Silva', 'Santa Luíza — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2905124', '-40.3053473', 'leitão', 'silva', 'vitória', 'santa', 'luíza'],
  ['Avenida Leitão da Silva', 'Praia do Suá — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3129078', '-40.3020277', 'leitão', 'silva', 'vitória', 'praia', 'suá'],
  ['Primeira Igreja Batista de Vitória', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3204741', '-40.3295048', 'primeira', 'igreja', 'batista', 'vitória', 'centro'],
  ['Capela Nossa Senhora da Vitória', 'Forte São João — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3170326', '-40.3235269', 'capela', 'nossa', 'senhora', 'vitória', 'forte', 'são', 'joão'],
  ['Palácio Atílio Vivácqua Prefeitura Municipal de Vitória', 'Bento Ferreira — Vitória/ES', 'Vitória', '19 km', 'verde', 'location', '-20.3174948', '-40.3100295', 'palácio', 'atílio', 'vivácqua', 'prefeitura', 'municipal', 'vitória', 'bento'],
  ['Câmara Municipal de Vitória', 'Bento Ferreira — Vitória/ES', 'Vitória', '19 km', 'verde', 'location', '-20.3176709', '-40.3105894', 'câmara', 'municipal', 'vitória', 'bento', 'ferreira'],
  ['Vitória Saúde', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'location', '-20.3151950', '-40.3030383', 'vitória', 'saúde', 'bento', 'ferreira'],
  ['SICRES - Cooperativa de Crédito dos Servidores Públicos Municipais da Grande Vitória', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'location', '-20.3151916', '-40.3020654', 'sicres', 'cooperativa', 'crédito', 'servidores', 'públicos', 'municipais', 'grande'],
  ['Prefeitura Municipal de Vitória', 'Bento Ferreira — Vitória/ES', 'Vitória', '19 km', 'verde', 'location', '-20.3183305', '-40.3099543', 'prefeitura', 'municipal', 'vitória', 'bento', 'ferreira'],
  ['1º Juizado Especial Federal de Vitória', 'Monte Belo — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3166851', '-40.3124743', 'juizado', 'especial', 'federal', 'vitória', 'monte', 'belo'],
  ['Ponte da Passagem', 'Goiabeiras — Vitória/ES', 'Vitória', '15 km', 'verde', 'route', '-20.2858368', '-40.3038944', 'ponte', 'passagem', 'vitória', 'goiabeiras'],
  ['Ponte da Passagem', 'Santa Luíza — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2858953', '-40.3037291', 'ponte', 'passagem', 'vitória', 'santa', 'luíza'],
  ['Aeroporto', 'Aeroporto — Vitória/ES', 'Vitória', '12 km', 'amarela', 'flight', '-20.2572650', '-40.2820934', 'aeroporto', 'vitória'],
  ['Aeroporto', 'Jabour — Vitória/ES', 'Vitória', '12 km', 'vermelha', 'flight', '-20.2561943', '-40.2902874', 'aeroporto', 'vitória', 'jabour'],
  ['Shopping Vitória', 'Mário Cypreste — Vitória/ES', 'Vitória', '20 km', 'amarela', 'shopping', '-20.3193072', '-40.3516930', 'shopping', 'vitória', 'mário', 'cypreste'],
  ['Shopping Vitória', 'Enseada do Suá — Vitória/ES', 'Vitória', '18 km', 'verde', 'shopping', '-20.3127734', '-40.2878519', 'shopping', 'vitória', 'enseada', 'suá'],
  ['Shopping Laranjeiras', 'Parque Residencial Laranjeiras — Serra/ES', 'Serra', '7 km', 'verde', 'shopping', '-20.1968835', '-40.2549330', 'shopping', 'laranjeiras', 'serra', 'parque', 'residencial'],
  ['Universidade Federal do Espírito Santo', 'Goiabeiras — Vitória/ES', 'Vitória', '14 km', 'verde', 'school', '-20.2771567', '-40.3045093', 'universidade', 'federal', 'espírito', 'santo', 'vitória', 'goiabeiras'],
  ['UFES', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'verde', 'school', '-20.2769716', '-40.3007023', 'ufes', 'vitória', 'mata', 'praia'],
  ['Santa Casa de Misericórdia de Vitória', 'Vila Rubim — Vitória/ES', 'Vitória', '20 km', 'amarela', 'hospital', '-20.3207616', '-40.3445260', 'santa', 'casa', 'misericórdia', 'vitória', 'vila', 'rubim'],
  ['Escola Superior de Ciências da Santa Casa de Misericórdia de Vitória', 'Santa Luíza — Vitória/ES', 'Vitória', '16 km', 'amarela', 'hospital', '-20.2926339', '-40.3014697', 'escola', 'superior', 'ciências', 'santa', 'casa', 'misericórdia', 'vitória'],
  ['Hospital Universitário Cassiano Antônio de Moraes', 'Santos Dumont — Vitória/ES', 'Vitória', '17 km', 'amarela', 'hospital', '-20.2997031', '-40.3183506', 'hospital', 'universitário', 'cassiano', 'antônio', 'moraes', 'vitória', 'santos'],
  ['Hospital Universitário - UFES', 'Bonfim — Vitória/ES', 'Vitória', '16 km', 'laranja', 'hospital', '-20.2968609', '-40.3158458', 'hospital', 'universitário', 'ufes', 'vitória', 'bonfim'],
  ['Terminal Jacaraípe - JCA', 'Estância Monazítica — Serra/ES', 'Serra', '12 km', 'amarela', 'bus', '-20.1591635', '-40.1959493', 'terminal', 'jacaraípe', 'jca', 'serra', 'estância', 'monazítica'],
  ['Terminal Carapina', 'Rosário de Fátima — Serra/ES', 'Serra', '10 km', 'amarela', 'bus', '-20.2307345', '-40.2700303', 'terminal', 'carapina', 'serra', 'rosário', 'fátima'],
  ['Rodoviária', 'Ilha do Príncipe — Vitória/ES', 'Vitória', '20 km', 'amarela', 'location', '-20.3218150', '-40.3531933', 'rodoviária', 'vitória', 'ilha', 'príncipe'],
  ['CIPTC - Centro Integrado da Perícia Técnica e Científica', 'Alto Lage — Cariacica/ES', 'Cariacica', '22 km', 'laranja', 'location', '-20.3350785', '-40.3772752', 'ciptc', 'centro', 'integrado', 'perícia', 'técnica', 'científica', 'cariacica'],
  ['Centro Multiuso Maria Ambrósia de Jesus', 'Alice Coutinho — Cariacica/ES', 'Cariacica', '19 km', 'laranja', 'location', '-20.2653367', '-40.4255987', 'centro', 'multiuso', 'maria', 'ambrósia', 'jesus', 'cariacica', 'alice'],
  ['Centro Regional de Especialidades Metropolitano', 'Jardim América — Cariacica/ES', 'Cariacica', '21 km', 'laranja', 'location', '-20.3296994', '-40.3554857', 'centro', 'regional', 'especialidades', 'metropolitano', 'cariacica', 'jardim', 'américa'],
  ['CPID - Centro de Pesquisa, Inovação e Desenvolvimento', 'Itaquari — Cariacica/ES', 'Cariacica', '21 km', 'laranja', 'location', '-20.3311642', '-40.3611876', 'cpid', 'centro', 'pesquisa,', 'inovação', 'desenvolvimento', 'cariacica', 'itaquari'],
  ['Centro de Referência de Assistência Social - Bela Aurora', 'Bela Aurora — Cariacica/ES', 'Cariacica', '24 km', 'laranja', 'location', '-20.3517445', '-40.3665182', 'centro', 'referência', 'assistência', 'social', 'bela', 'aurora', 'cariacica'],
  ['Centro de Atenção Psicosocial Moxuara', 'Tucum — Cariacica/ES', 'Cariacica', '20 km', 'laranja', 'location', '-20.3138979', '-40.3813353', 'centro', 'atenção', 'psicosocial', 'moxuara', 'cariacica', 'tucum'],
  ['Centro Educacional Para Vida', 'Parque Gramado — Cariacica/ES', 'Cariacica', '25 km', 'laranja', 'location', '-20.3551745', '-40.3887120', 'centro', 'educacional', 'para', 'vida', 'cariacica', 'parque', 'gramado'],
  ['Centro Educacional São Geraldo', 'São Geraldo — Cariacica/ES', 'Cariacica', '23 km', 'laranja', 'location', '-20.3453501', '-40.3813331', 'centro', 'educacional', 'são', 'geraldo', 'cariacica'],
  ['CMEI Rafael Capucho Mazioli', 'Alto da Boa Vista — Cariacica/ES', 'Cariacica', '20 km', 'laranja', 'location', '-20.3230252', '-40.3610706', 'cmei', 'rafael', 'capucho', 'mazioli', 'cariacica', 'alto', 'boa'],
  ['CE Alegria do Saber', 'Jardim América — Cariacica/ES', 'Cariacica', '22 km', 'laranja', 'location', '-20.3370559', '-40.3574468', 'alegria', 'saber', 'cariacica', 'jardim', 'américa'],
  ['CMEI Ana Lúcia Ferreira da Silva', 'Itaquari — Cariacica/ES', 'Cariacica', '21 km', 'laranja', 'location', '-20.3250483', '-40.3605357', 'cmei', 'ana', 'lúcia', 'ferreira', 'silva', 'cariacica', 'itaquari'],
  ['CMEI Vinicius de Moraes', 'Sotelândia — Cariacica/ES', 'Cariacica', '24 km', 'laranja', 'location', '-20.3572353', '-40.3613742', 'cmei', 'vinicius', 'moraes', 'cariacica', 'sotelândia'],
  ['CRAS - Bela Aurora', 'Bela Aurora — Cariacica/ES', 'Cariacica', '24 km', 'laranja', 'location', '-20.3524446', '-40.3637429', 'cras', 'bela', 'aurora', 'cariacica'],
  ['CE Pedacinho do Céu', 'Oriente — Cariacica/ES', 'Cariacica', '22 km', 'laranja', 'location', '-20.3275472', '-40.3816927', 'pedacinho', 'céu', 'cariacica', 'oriente'],
  ['CAEE Padre Gabriel Maire', 'Morada de Santa Fé — Cariacica/ES', 'Cariacica', '24 km', 'laranja', 'location', '-20.3467904', '-40.3883218', 'caee', 'padre', 'gabriel', 'maire', 'cariacica', 'morada', 'santa'],
  ['Itacibá', 'Itacibá — Cariacica/ES', 'Cariacica', '21 km', 'laranja', 'location', '-20.3234049', '-40.3737316', 'itacibá', 'cariacica'],
  ['Alto Lage', 'Alto Lage — Cariacica/ES', 'Cariacica', '22 km', 'laranja', 'location', '-20.3307749', '-40.3700604', 'alto', 'lage', 'cariacica'],
  ['Campo Grande', 'Campo Grande — Cariacica/ES', 'Cariacica', '23 km', 'laranja', 'location', '-20.3403595', '-40.3871139', 'campo', 'grande', 'cariacica'],
  ['Praia do Morro', 'Praia do Morro — Guarapari/ES', 'Guarapari', '59 km', 'amarela', 'beach', '-20.6511658', '-40.4850515', 'praia', 'morro', 'guarapari'],
  ['Centro', 'Centro — Guarapari/ES', 'Guarapari', '62 km', 'amarela', 'location', '-20.6711320', '-40.4994027', 'centro', 'guarapari'],
  ['Muquiçaba', 'Muquiçaba — Guarapari/ES', 'Guarapari', '61 km', 'amarela', 'location', '-20.6618236', '-40.4989993', 'muquiçaba', 'guarapari'],
  ['Centro', 'Centro — Cachoeiro de Itapemirim/ES', 'Cachoeiro de Itapemirim', '119 km', 'amarela', 'location', '-20.8500786', '-41.1135739', 'centro', 'cachoeiro de itapemirim'],
  ['Gilberto Machado', 'Gilberto Machado — Cachoeiro de Itapemirim/ES', 'Cachoeiro de Itapemirim', '120 km', 'amarela', 'location', '-20.8557036', '-41.1180441', 'gilberto', 'machado', 'cachoeiro de itapemirim'],
  ['Centro', 'Centro — Linhares/ES', 'Linhares', '87 km', 'amarela', 'location', '-19.4008559', '-40.0667993', 'centro', 'linhares'],
  ['Juparanã', 'Juparanã — Linhares/ES', 'Linhares', '89 km', 'amarela', 'hospital', '-19.3814542', '-40.0733157', 'juparanã', 'linhares'],
  ['Lagoa Juparanã', 'Linhares/ES', 'Linhares', '100 km', 'amarela', 'hospital', '-19.2616408', '-40.1496254', 'lagoa', 'juparanã', 'linhares'],
  ['Avenida Vitória', 'Jucutuquara — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3115716', '-40.3199979', 'vitória', 'jucutuquara'],
  ['Avenida Vitória', 'Cruzamento — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3121838', '-40.3204731', 'vitória', 'cruzamento'],
  ['Avenida Brasil', 'Resistência — Vitória/ES', 'Vitória', '14 km', 'amarela', 'route', '-20.2719193', '-40.3197759', 'brasil', 'vitória', 'resistência'],
  ['Beco Joca Pereira dos Santos 1', 'Resistência — Vitória/ES', 'Vitória', '14 km', 'amarela', 'location', '-20.2705349', '-40.3195437', 'beco', 'joca', 'pereira', 'santos', 'vitória', 'resistência'],
  ['Avenida Jerônimo Monteiro', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3191033', '-40.3317161', 'jerônimo', 'monteiro', 'vitória', 'centro'],
  ['Avenida Nossa Senhora da Penha', 'Santa Lúcia — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.2993394', '-40.2995003', 'nossa', 'senhora', 'penha', 'vitória', 'santa', 'lúcia'],
  ['Avenida Nossa Senhora da Penha', 'Barro Vermelho — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2980477', '-40.2999117', 'nossa', 'senhora', 'penha', 'vitória', 'barro', 'vermelho'],
  ['Avenida Nossa Senhora da Penha', 'Praia do Canto — Vitória/ES', 'Vitória', '17 km', 'verde', 'route', '-20.3018236', '-40.2983881', 'nossa', 'senhora', 'penha', 'vitória', 'praia', 'canto'],
  ['Avenida Nossa Senhora da Penha', 'Santa Luíza — Vitória/ES', 'Vitória', '16 km', 'amarela', 'route', '-20.2916044', '-40.3026930', 'nossa', 'senhora', 'penha', 'vitória', 'santa', 'luíza'],
  ['Avenida Nossa Senhora da Penha', 'Andorinhas — Vitória/ES', 'Vitória', '15 km', 'amarela', 'route', '-20.2872596', '-40.3043201', 'nossa', 'senhora', 'penha', 'vitória', 'andorinhas'],
  ['Avenida Saturnino de Brito', 'Praia do Canto — Vitória/ES', 'Vitória', '16 km', 'verde', 'route', '-20.2980665', '-40.2918468', 'saturnino', 'brito', 'vitória', 'praia', 'canto'],
  ['Avenida Saturnino de Brito', 'Enseada do Suá — Vitória/ES', 'Vitória', '17 km', 'verde', 'route', '-20.3036918', '-40.2920446', 'saturnino', 'brito', 'vitória', 'enseada', 'suá'],
  ['Avenida Saturnino de Brito - Pista Lateral', 'Praia do Canto — Vitória/ES', 'Vitória', '17 km', 'verde', 'route', '-20.3047054', '-40.2929228', 'saturnino', 'brito', 'pista', 'lateral', 'vitória', 'praia', 'canto'],
  ['Avenida Saturnino de Brito', 'Santa Helena — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3052069', '-40.2929062', 'saturnino', 'brito', 'vitória', 'santa', 'helena'],
  ['Avenida Saturnino de Brito', 'Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3028228', '-40.2915348', 'saturnino', 'brito', 'vitória'],
  ['Rua Moacir Avidos', 'Praia do Canto — Vitória/ES', 'Vitória', '17 km', 'verde', 'route', '-20.3007155', '-40.2932231', 'moacir', 'avidos', 'vitória', 'praia', 'canto'],
  ['Rua do Rosário', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3194598', '-40.3345395', 'rosário', 'vitória', 'centro'],
  ['Rua Sete de Setembro', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3162972', '-40.3379337', 'sete', 'setembro', 'vitória', 'centro'],
  ['Rua 7 de Setembro', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3188950', '-40.3363013', 'setembro', 'vitória', 'centro'],
  ['Rua Treze de Maio', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3194919', '-40.3358344', 'treze', 'maio', 'vitória', 'centro'],
  ['Rua Filomeno Ribeiro', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3155199', '-40.3384210', 'filomeno', 'ribeiro', 'vitória', 'centro'],
  ['Rua Soldado Benoni Falcão Gouvêa', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3150760', '-40.3386775', 'soldado', 'benoni', 'falcão', 'gouvêa', 'vitória', 'centro'],
  ['Rua Henrique Novaes', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3188584', '-40.3290179', 'henrique', 'novaes', 'vitória', 'centro'],
  ['Rua Barão Monjardim', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3195337', '-40.3282319', 'barão', 'monjardim', 'vitória', 'centro'],
  ['Rua Nestor Gomes', 'Centro — Vitória/ES', 'Vitória', '20 km', 'amarela', 'route', '-20.3216655', '-40.3395980', 'nestor', 'gomes', 'vitória', 'centro'],
  ['Escadaria da Misericórdia', 'Centro — Vitória/ES', 'Vitória', '20 km', 'amarela', 'location', '-20.3213995', '-40.3387543', 'escadaria', 'misericórdia', 'vitória', 'centro'],
  ['Rua São Luiz', 'Nova Palestina — Vitória/ES', 'Vitória', '14 km', 'vermelha', 'route', '-20.2746479', '-40.3261876', 'são', 'luiz', 'vitória', 'nova', 'palestina'],
  ['Rua Constante Sodré', 'Santa Lúcia — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3016500', '-40.2999030', 'constante', 'sodré', 'vitória', 'santa', 'lúcia'],
  ['Rua Constante Sodré', 'Praia do Canto — Vitória/ES', 'Vitória', '17 km', 'verde', 'route', '-20.2994812', '-40.2983381', 'constante', 'sodré', 'vitória', 'praia', 'canto'],
  ['Rua Constante Sodré', 'Barro Vermelho — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3001799', '-40.2989382', 'constante', 'sodré', 'vitória', 'barro', 'vermelho'],
  ['Rua Presidente Pedreira', 'Parque Moscoso — Vitória/ES', 'Vitória', '20 km', 'amarela', 'route', '-20.3210391', '-40.3421305', 'presidente', 'pedreira', 'vitória', 'parque', 'moscoso'],
  ['Avenida Florentino Avidos', 'Parque Moscoso — Vitória/ES', 'Vitória', '20 km', 'amarela', 'route', '-20.3214770', '-40.3422181', 'florentino', 'avidos', 'vitória', 'parque', 'moscoso'],
  ['Rua Graciano Neves', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'route', '-20.3167110', '-40.3370682', 'graciano', 'neves', 'vitória', 'centro'],
  ['Rua Chafic Murad', 'Bento Ferreira — Vitória/ES', 'Vitória', '18 km', 'verde', 'route', '-20.3139167', '-40.3047332', 'chafic', 'murad', 'vitória', 'bento', 'ferreira'],
  ['Rua Chafic Murad', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3160398', '-40.3126070', 'chafic', 'murad', 'vitória', 'monte', 'belo'],
  ['Avenida Carlos Moreira Lima', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3158101', '-40.3140463', 'carlos', 'moreira', 'lima', 'vitória', 'monte', 'belo'],
  ['Rua Gastão Villá', 'Monte Belo — Vitória/ES', 'Vitória', '18 km', 'amarela', 'route', '-20.3154296', '-40.3145113', 'gastão', 'villá', 'vitória', 'monte', 'belo'],
  ['Rua José Teixeira', 'Santa Lúcia — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3023276', '-40.3012576', 'josé', 'teixeira', 'vitória', 'santa', 'lúcia'],
  ['Rua José Teixeira', 'Praia do Canto — Vitória/ES', 'Vitória', '17 km', 'verde', 'route', '-20.3056394', '-40.2961799', 'josé', 'teixeira', 'vitória', 'praia', 'canto'],
  ['Rua José Teixeira', 'Santa Helena — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3070711', '-40.2938822', 'josé', 'teixeira', 'vitória', 'santa', 'helena'],
  ['Rua Fortunato Ramos', 'Santa Lúcia — Vitória/ES', 'Vitória', '17 km', 'amarela', 'route', '-20.3046650', '-40.2976896', 'fortunato', 'ramos', 'vitória', 'santa', 'lúcia'],
  ['Praça Costa Pereira', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'park', '-20.3200186', '-40.3354631', 'praça', 'costa', 'pereira', 'vitória', 'centro'],
  ['Praça dos Namorados', 'Praia do Canto — Vitória/ES', 'Vitória', '17 km', 'verde', 'park', '-20.2997801', '-40.2914042', 'praça', 'namorados', 'vitória', 'praia', 'canto'],
  ['Avenida Doutor Marcos Daniel Santos', 'Enseada do Suá — Vitória/ES', 'Vitória', '17 km', 'verde', 'route', '-20.3028381', '-40.2897184', 'doutor', 'marcos', 'daniel', 'santos', 'vitória', 'enseada', 'suá'],
  ['Praça do Papa', 'Enseada do Suá — Vitória/ES', 'Vitória', '19 km', 'verde', 'park', '-20.3171564', '-40.2949468', 'praça', 'papa', 'vitória', 'enseada', 'suá'],
  ['Parque Pedra da Cebola', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'verde', 'park', '-20.2767436', '-40.2975619', 'parque', 'pedra', 'cebola', 'vitória', 'mata', 'praia'],
  ['Parque Moscoso', 'Parque Moscoso — Vitória/ES', 'Vitória', '19 km', 'amarela', 'park', '-20.3199474', '-40.3427114', 'parque', 'moscoso', 'vitória'],
  ['Catedral Metropolitana de Vitória', 'Centro — Vitória/ES', 'Vitória', '19 km', 'amarela', 'location', '-20.3199497', '-40.3371031', 'catedral', 'metropolitana', 'vitória', 'centro'],
  ['Convento de Nossa Senhora da Penha', 'Prainha — Vila Velha/ES', 'Vila Velha', '20 km', 'amarela', 'location', '-20.3293225', '-40.2870728', 'convento', 'nossa', 'senhora', 'penha', 'vila velha', 'prainha'],
  ['Convento da Penha', 'Prainha — Vila Velha/ES', 'Vila Velha', '20 km', 'amarela', 'location', '-20.3327286', '-40.2912965', 'convento', 'penha', 'vila velha', 'prainha'],
  ['Rodovia José Ribeiro Tristão', 'Ilha do Sol — Guarapari/ES', 'Guarapari', '43 km', 'amarela', 'route', '-20.5277580', '-40.3802268', 'rodovia', 'josé', 'ribeiro', 'tristão', 'guarapari', 'ilha', 'sol'],
  ['Rodovia José Ribeiro Tristão', 'Vila Velha/ES', 'Vila Velha', '42 km', 'amarela', 'route', '-20.5213076', '-40.3713244', 'rodovia', 'josé', 'ribeiro', 'tristão', 'vila velha'],
  ['Rodovia José Ribeiro Tristão', 'Residencial Ybapuã — Vila Velha/ES', 'Vila Velha', '42 km', 'amarela', 'route', '-20.5184989', '-40.3671904', 'rodovia', 'josé', 'ribeiro', 'tristão', 'vila velha', 'residencial', 'ybapuã'],
  ['Rodovia José Ribeiro Tristão', 'Recanto da Sereia — Guarapari/ES', 'Guarapari', '43 km', 'amarela', 'route', '-20.5278866', '-40.3801440', 'rodovia', 'josé', 'ribeiro', 'tristão', 'guarapari', 'recanto', 'sereia'],
  ['Rodovia José Ribeiro Tristão', 'Quintas de Ybapuã — Vila Velha/ES', 'Vila Velha', '41 km', 'amarela', 'route', '-20.5099822', '-40.3639588', 'rodovia', 'josé', 'ribeiro', 'tristão', 'vila velha', 'quintas', 'ybapuã'],
  ['Rodovia José Ribeiro Tristão', 'Morada Itanhangá — Vila Velha/ES', 'Vila Velha', '37 km', 'amarela', 'route', '-20.4767073', '-40.3527992', 'rodovia', 'josé', 'ribeiro', 'tristão', 'vila velha', 'morada', 'itanhangá'],
  ['Rodovia José Ribeiro Tristão', 'Morada de Interlagos II — Vila Velha/ES', 'Vila Velha', '40 km', 'amarela', 'route', '-20.5062137', '-40.3641190', 'rodovia', 'josé', 'ribeiro', 'tristão', 'vila velha', 'morada', 'interlagos'],
  ['Rodovia Governador Mário Covas', 'Vila Velha/ES', 'Vila Velha', '39 km', 'amarela', 'route', '-20.4586933', '-40.4650302', 'rodovia', 'governador', 'mário', 'covas', 'vila velha'],
  ['Rodovia Governador Mário Covas', 'Itapemirim/ES', 'Itapemirim', '118 km', 'amarela', 'route', '-20.8969450', '-41.0512814', 'rodovia', 'governador', 'mário', 'covas', 'itapemirim'],
  ['Rodovia Governador Mário Covas', 'Mimoso do Sul/ES', 'Mimoso do Sul', '163 km', 'amarela', 'route', '-21.2220515', '-41.3086231', 'rodovia', 'governador', 'mário', 'covas', 'mimoso do sul'],
  ['Rodovia Governador Mário Covas', 'Pedro Canário/ES', 'Pedro Canário', '223 km', 'amarela', 'route', '-18.1793530', '-39.9210945', 'rodovia', 'governador', 'mário', 'covas', 'pedro canário'],
  ['Rodovia Governador Mário Covas', 'Cachoeiro de Itapemirim/ES', 'Cachoeiro de Itapemirim', '118 km', 'amarela', 'route', '-20.9012420', '-41.0577157', 'rodovia', 'governador', 'mário', 'covas', 'cachoeiro de itapemirim'],
  ['ES-010', 'Linhares/ES', 'Linhares', '111 km', 'amarela', 'route', '-19.3292740', '-39.7219124', 'es-010', 'linhares'],
  ['ES-010;ES-358', 'Linhares/ES', 'Linhares', '123 km', 'amarela', 'route', '-19.2011416', '-39.7254554', 'es-010;es-358', 'linhares'],
  ['ES-010', 'Pontal do Ipiranga — Linhares/ES', 'Linhares', '124 km', 'amarela', 'route', '-19.2001098', '-39.7180409', 'es-010', 'linhares', 'pontal', 'ipiranga'],
  ['ES-440', 'Linhares/ES', 'Linhares', '75 km', 'amarela', 'route', '-19.6542070', '-39.8443864', 'es-440', 'linhares'],
  ['Rodovia Othovarino Duarte Santos', 'São Mateus/ES', 'São Mateus', '167 km', 'amarela', 'route', '-18.7322620', '-39.8068560', 'rodovia', 'othovarino', 'duarte', 'santos', 'são mateus'],
  ['Rodovia Othovarino Duarte Santos', 'Pedra Dagua — São Mateus/ES', 'São Mateus', '167 km', 'amarela', 'route', '-18.7319559', '-39.8081869', 'rodovia', 'othovarino', 'duarte', 'santos', 'são mateus', 'pedra', 'dagua'],
  ['Rodovia Charrua', 'São Mateus/ES', 'São Mateus', '148 km', 'amarela', 'route', '-18.9156905', '-39.7888286', 'rodovia', 'charrua', 'são mateus'],
  ['Rua Sete de Setembro', 'Campinho da Serra II — Serra/ES', 'Serra', '1 km', 'amarela', 'route', '-20.1474748', '-40.2939136', 'sete', 'setembro', 'serra', 'campinho'],
  ['Rua Sete de Setembro', 'Carapina Grande — Serra/ES', 'Serra', '9 km', 'laranja', 'route', '-20.2254313', '-40.2770793', 'sete', 'setembro', 'serra', 'carapina', 'grande'],
  ['Rua Sete de Setembro', 'Jardim Tropical — Serra/ES', 'Serra', '6 km', 'amarela', 'route', '-20.2017685', '-40.2730727', 'sete', 'setembro', 'serra', 'jardim', 'tropical'],
  ['Rua 7 de Setembro', 'Taquara II — Serra/ES', 'Serra', '6 km', 'amarela', 'route', '-20.1805051', '-40.2564720', 'setembro', 'serra', 'taquara'],
  ['Rua Sete de Setembro', 'Morada dos Lagos — Vila Velha/ES', 'Vila Velha', '32 km', 'amarela', 'route', '-20.4271606', '-40.3692883', 'sete', 'setembro', 'vila velha', 'morada', 'dos', 'lagos'],
  ['Rua Sete de Setembro', 'Vila Velha/ES', 'Vila Velha', '33 km', 'amarela', 'route', '-20.4395326', '-40.3602578', 'sete', 'setembro', 'vila velha'],
  ['Rua 7 de Setembro', 'Salamim — Vila Velha/ES', 'Vila Velha', '21 km', 'amarela', 'route', '-20.3364136', '-40.2981736', 'setembro', 'vila velha', 'salamim'],
  ['Terminal de Vila Velha', 'Forte São João — Vitória/ES', 'Vitória', '20 km', 'amarela', 'bus', '-20.3240817', '-40.3287909', 'terminal', 'vila', 'velha', 'vitória', 'forte', 'são', 'joão'],
  ['Centro Esportivo Tancredo de Almeida Neves', 'Mário Cypreste — Vitória/ES', 'Vitória', '20 km', 'amarela', 'location', '-20.3205667', '-40.3547423', 'centro', 'esportivo', 'tancredo', 'almeida', 'neves', 'vitória', 'mário'],
  ['Centro de Convenções', 'Aeroporto — Vitória/ES', 'Vitória', '13 km', 'amarela', 'location', '-20.2691503', '-40.2831317', 'centro', 'convenções', 'vitória', 'aeroporto'],
  ['Auditório do Centro de Artes', 'Goiabeiras — Vitória/ES', 'Vitória', '14 km', 'amarela', 'location', '-20.2797048', '-40.3020259', 'auditório', 'centro', 'artes', 'vitória', 'goiabeiras'],
  ['Centro de Artes', 'Goiabeiras — Vitória/ES', 'Vitória', '14 km', 'amarela', 'location', '-20.2793895', '-40.3028494', 'centro', 'artes', 'vitória', 'goiabeiras'],
  ['Centro de Ciências Exatas', 'Goiabeiras — Vitória/ES', 'Vitória', '14 km', 'amarela', 'location', '-20.2755050', '-40.3035726', 'centro', 'ciências', 'exatas', 'vitória', 'goiabeiras'],
  ['Centro de Educação', 'Goiabeiras — Vitória/ES', 'Vitória', '14 km', 'amarela', 'location', '-20.2741781', '-40.3048246', 'centro', 'educação', 'vitória', 'goiabeiras'],
  ['Centro de Educação Física e Desportos', 'Goiabeiras — Vitória/ES', 'Vitória', '15 km', 'amarela', 'location', '-20.2809885', '-40.3037576', 'centro', 'educação', 'física', 'desportos', 'vitória', 'goiabeiras'],
  ['Centro Municipal de Educação Infantil Nelcy da Silva Braga', 'São Cristóvão — Vitória/ES', 'Vitória', '16 km', 'amarela', 'location', '-20.2941730', '-40.3129062', 'centro', 'municipal', 'educação', 'infantil', 'nelcy', 'silva', 'braga'],
  ['Centro Automotivo DF de Brito', 'Mário Cypreste — Vitória/ES', 'Vitória', '20 km', 'amarela', 'location', '-20.3184876', '-40.3562351', 'centro', 'automotivo', 'brito', 'vitória', 'mário', 'cypreste'],
  ['Centro de Atenção Psicosocial', 'Ilha de Santa Maria — Vitória/ES', 'Vitória', '18 km', 'amarela', 'location', '-20.3142033', '-40.3173728', 'centro', 'atenção', 'psicosocial', 'vitória', 'ilha', 'santa', 'maria'],
  ['Ilha do Frade', 'Ilha do Frade — Vitória/ES', 'Vitória', '17 km', 'amarela', 'location', '-20.3018287', '-40.2827175', 'ilha', 'frade', 'vitória'],
  ['Ilha do Boi', 'Vitória/ES', 'Vitória', '18 km', 'amarela', 'location', '-20.3105442', '-40.2807253', 'ilha', 'boi', 'vitória'],
  ['Ilha do Boi', 'Ilha do Boi — Vitória/ES', 'Vitória', '18 km', 'amarela', 'location', '-20.3107425', '-40.2841729', 'ilha', 'boi', 'vitória'],
  ['Pedra da Cebola', 'Mata da Praia — Vitória/ES', 'Vitória', '14 km', 'amarela', 'location', '-20.2754992', '-40.2984083', 'pedra', 'cebola', 'vitória', 'mata', 'praia'],
  ['Curva da Jurema', 'Enseada do Suá — Vitória/ES', 'Vitória', '18 km', 'amarela', 'location', '-20.3100962', '-40.2872568', 'curva', 'jurema', 'vitória', 'enseada', 'suá'],
  ['Morro do Moreno', 'Vila Velha/ES', 'Vila Velha', '20 km', 'amarela', 'location', '-20.3258668', '-40.2771634', 'morro', 'moreno', 'vila velha'],
  ['Porto de Praia Mole', 'Parque Industrial — Vitória/ES', 'Vitória', '17 km', 'amarela', 'beach', '-20.2896455', '-40.2350039', 'porto', 'praia', 'mole', 'vitória', 'parque', 'industrial'],
];

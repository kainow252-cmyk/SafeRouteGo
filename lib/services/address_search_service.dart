// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// ADDRESS SEARCH SERVICE — SafeRoute
// Arquitetura igual 99/Uber:
//   1. Banco local IBGE: 5.570 municípios com coords reais (offline)
//   2. Nominatim OSM: ruas, números, bairros — Brasil inteiro (online)
//   3. ViaCEP fallback: quando Nominatim não cobre o endereço
//
// NORMALIZAÇÃO (D):
//   • Remove acentos antes de consultar APIs
//   • Expande abreviações: R.→Rua, Av.→Avenida, Trv→Travessa...
//   • Remove pontuação extra e espaços duplos
//   • Mantém query legível no cache key
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'municipios_brasil.dart';
import 'browser_geo_fallback.dart';
import 'mapbox_search_service.dart';
import 'photon_api_service.dart';
import 'overpass_api_service.dart';

// ── Resultado de busca ─────────────────────────────────────────────
class AddressResult {
  final String title;       // Rua Vitória, 17 / Campinas / Serra
  final String subtitle;    // Bela Vista — São Paulo/SP
  final double lat;
  final double lon;
  final bool isCity;        // true = município do banco local
  final String? cep;

  const AddressResult({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lon,
    this.isCity = false,
    this.cep,
  });

  @override
  String toString() => '$title — $subtitle';
}

// ── Serviço principal ──────────────────────────────────────────────
class AddressSearchService {
  static const _userAgent = 'SafeRouteGo/1.0 (contato@saferoutego.com.br)';
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/search';

  // Cache em memória (sessão atual)
  static final Map<String, List<AddressResult>> _cache = {};
  // Cache persistido (SharedPreferences) — carregado uma vez
  static bool _persistCacheLoaded = false;
  static const _kPersistCache = 'address_cache_v1';
  static const _maxPersistEntries = 80;

  /// Carrega cache persistido do SharedPreferences (chamada única)
  static Future<void> _ensurePersistCacheLoaded() async {
    if (_persistCacheLoaded) return;
    _persistCacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPersistCache);
      if (raw == null) return;
      final Map<String, dynamic> stored = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in stored.entries) {
        if (_cache.containsKey(entry.key)) continue;
        final list = (entry.value as List).cast<Map<String, dynamic>>();
        _cache[entry.key] = list.map((j) => AddressResult(
          title: j['title'] as String,
          subtitle: j['subtitle'] as String,
          lat: (j['lat'] as num).toDouble(),
          lon: (j['lon'] as num).toDouble(),
          isCity: j['isCity'] as bool? ?? false,
          cep: j['cep'] as String?,
        )).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AddressCache] load error: $e');
    }
  }

  /// Persiste cache atual no SharedPreferences (assíncrono, não bloqueia)
  static void _persistCache() {
    Future.microtask(() async {
      try {
        // Pega apenas as entradas não-vazias, limita a _maxPersistEntries
        final toSave = Map.fromEntries(
          _cache.entries
              .where((e) => e.value.isNotEmpty)
              .take(_maxPersistEntries),
        );
        final encoded = jsonEncode(toSave.map((k, v) => MapEntry(k,
          v.map((r) => {
            'title': r.title, 'subtitle': r.subtitle,
            'lat': r.lat, 'lon': r.lon,
            'isCity': r.isCity, if (r.cep != null) 'cep': r.cep,
          }).toList(),
        )));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPersistCache, encoded);
      } catch (e) {
        if (kDebugMode) debugPrint('[AddressCache] persist error: $e');
      }
    });
  }

  // ── 1. Busca local de municípios (instantânea, offline) ────────
  static List<AddressResult> searchCities(String query) {
    final q = _norm(query);
    if (q.length < 2) return [];

    final results = <AddressResult>[];

    // Percorre TODO o array — sem break antecipado.
    // Essencial para garantir que capitais como SP (linha ~4861)
    // não sejam cortadas pelo limite de 20 antes de serem encontradas.
    for (final m in kMunicipiosBrasil) {
      final nome = m[0] as String;
      final uf   = m[1] as String;
      final lat  = (m[2] as num).toDouble();
      final lon  = (m[3] as num).toDouble();
      final cap  = m[4] as bool;

      final nomeNorm = _norm(nome);

      // Match: nome contém a query, ou "nome UF" contém a query
      if (!nomeNorm.contains(q) && !_norm('$nome $uf').contains(q)) continue;

      final subtitle = cap ? 'Capital — $uf' : uf;
      results.add(AddressResult(
        title:    nome,
        subtitle: subtitle,
        lat:      lat,
        lon:      lon,
        isCity:   true,
      ));
    }

    // ── Ordenação com 3 níveis de prioridade ─────────────────────────
    // 1º — match exato do nome ("são paulo" == "são paulo")      score 0
    // 2º — capital que começa com a query                        score 1
    // 3º — qualquer cidade que começa com a query               score 2
    // 4º — capital que contém a query                           score 3
    // 5º — demais cidades que contêm a query                    score 4
    // Em empate: nome alfabético
    results.sort((a, b) {
      final aNorm  = _norm(a.title);
      final bNorm  = _norm(b.title);
      final aCap   = a.subtitle.startsWith('Capital');
      final bCap   = b.subtitle.startsWith('Capital');
      final aExact = aNorm == q ? 0 : 1;
      final bExact = bNorm == q ? 0 : 1;

      int score(bool exact, bool starts, bool cap) {
        if (exact && cap)    return 0; // capital com nome exato → TOPO
        if (exact)           return 1; // cidade com nome exato (não capital)
        if (starts && cap)   return 2; // capital começando com query
        if (starts)          return 3; // cidade começando com query
        if (cap)             return 4; // capital contendo query
        return 5;                      // demais
      }

      final sa = score(aExact == 0, aNorm.startsWith(q), aCap);
      final sb = score(bExact == 0, bNorm.startsWith(q), bCap);
      if (sa != sb) return sa.compareTo(sb);
      return a.title.compareTo(b.title);
    });

    return results.take(8).toList();
  }

  // ── 2. Busca Nominatim — ruas, números, bairros (online) ───────
  static Future<List<AddressResult>> searchAddress(String query) async {
    await _ensurePersistCacheLoaded(); // carrega cache persistido se necessário
    final qOrig = query.trim();
    if (qOrig.length < 4) return [];

    // Normaliza antes de consultar: expande abreviações + remove acentos
    final q = _normalizeQuery(qOrig);

    // IMPORTANTE: cacheKey usa a query NORMALIZADA completa
    // (inclui cidade injetada, se houver) para não confundir
    // "Rua Goias" (vazio) com "Rua Goias Serra ES" (encontrado).
    final cacheKey = _norm(q);
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Tenta com a query normalizada (com abreviações expandidas)
    final results = await _searchNominatim(q);
    if (results.isNotEmpty) {
      _cache[cacheKey] = results;
      _persistCache(); // salva no disco de forma assíncrona
      return results;
    }
    // Fallback: tenta com a query original (sem normalização)
    if (q != _norm(qOrig)) {
      final origKey = _norm(qOrig);
      if (_cache.containsKey(origKey)) return _cache[origKey]!;
      final fallback = await _searchNominatim(qOrig);
      _cache[origKey] = fallback;
      _cache[cacheKey] = fallback; // compartilha resultado
      if (fallback.isNotEmpty) _persistCache();
      return fallback;
    }
    // Só cacheia vazio se realmente não há cidade injetada
    _cache[cacheKey] = [];
    return [];
  }

  /// Busca de logradouro com cidade injetada do GPS.
  ///
  /// ESTRATÉGIA EM 3 CAMADAS (ordem testada empiricamente):
  ///
  ///   1. BUSCA LIVRE  q="<logradouro> <cidade> <estado>"
  ///      → Full-text search no display_name completo do OSM.
  ///      → Funciona para TODOS os bairros: suburb, city_district, quarter, etc.
  ///      → "rua vitoria parque jacaraipe Serra ES" → retorna Parque Jacaraípe ✅
  ///
  ///   2. BUSCA ESTRUTURADA  street= + city= + state=
  ///      → Fallback para quando a busca livre retorna 0 resultados.
  ///      → Mais precisa para desambiguação de números de rua.
  ///      → Tenta city=<município> e depois city=<bairro da query>.
  ///
  ///   3. BUSCA LIVRE SEM BAIRRO  q="<logradouro> <cidade> <estado>"
  ///      → Fallback final sem bairro — captura ruas em qualquer bairro da cidade.
  static Future<List<AddressResult>> searchAddressStructured({
    required String street,
    required String city,
    required String state,
    String? suburb, // bairro detectado na query (passado pelo UI como dica extra)
  }) async {
    await _ensurePersistCacheLoaded();
    final streetNorm = _normalizeQuery(street);
    final cacheKey   = _norm('$streetNorm $city $state');
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // ── CAMADA 1: busca LIVRE com logradouro + cidade + estado ───────────
    // Esta é a mais eficaz: o Nominatim faz full-text no display_name completo,
    // então encontra ruas em qualquer bairro (suburb, quarter, city_district).
    // Ex: "rua vitoria parque jacaraipe Serra espirito santo" → ✅ CEP 29175-508
    final freeQuery = '$streetNorm $city $state';
    final freeKey   = _norm(freeQuery);
    List<AddressResult> results;

    if (_cache.containsKey(freeKey)) {
      results = _cache[freeKey]!;
    } else {
      results = await _searchNominatim(freeQuery);
      _cache[freeKey] = results;
    }

    if (results.isNotEmpty) {
      _cache[cacheKey] = results;
      _persistCache();
      return results;
    }

    // ── CAMADA 2a: busca estruturada city=<município> ─────────────────────
    // Útil quando a busca livre falha por ambiguidade com número de rua.
    final structKey = _norm('struct $streetNorm $city $state');
    if (_cache.containsKey(structKey)) {
      results = _cache[structKey]!;
    } else {
      results = await _searchNominatimStructured(streetNorm, city, state);
      _cache[structKey] = results;
    }
    if (results.isNotEmpty) {
      _cache[cacheKey] = results;
      _persistCache();
      return results;
    }

    // ── CAMADA 2b: busca estruturada city=<bairro da query> ──────────────
    // Fallback extra para quando município não resolve: usa o bairro como city.
    if (suburb != null && suburb.isNotEmpty) {
      final suburbNorm = _normalizeQuery(suburb);
      final subKey     = _norm('struct $streetNorm $suburbNorm $state');
      if (_cache.containsKey(subKey)) {
        results = _cache[subKey]!;
      } else {
        results = await _searchNominatimStructured(streetNorm, suburbNorm, state);
        _cache[subKey] = results;
      }
      if (results.isNotEmpty) {
        _cache[cacheKey] = results;
        _persistCache();
        return results;
      }
    }

    // ── CAMADA 3: busca livre SEM bairro — só logradouro + cidade ─────────
    // Útil quando o usuário digitou apenas o nome da rua sem bairro.
    // Ex: "rua vitoria Serra espirito santo" → retorna todas as Rua Vitória em Serra
    // Só entra aqui se street != freeQuery (ou seja, havia bairro no street)
    final shortStreet = _extractOnlyLogradouro(streetNorm);
    if (shortStreet.isNotEmpty && shortStreet != streetNorm) {
      final shortFree = '$shortStreet $city $state';
      final shortKey  = _norm(shortFree);
      if (_cache.containsKey(shortKey)) {
        results = _cache[shortKey]!;
      } else {
        results = await _searchNominatim(shortFree);
        _cache[shortKey] = results;
      }
      if (results.isNotEmpty) {
        _cache[cacheKey] = results;
        _persistCache();
        return results;
      }
    }

    _cache[cacheKey] = [];
    return [];
  }

  /// Remove palavras de bairro do logradouro, mantendo apenas tipo + nome da rua.
  /// Ex: "rua vitoria parque jacaraipe" → "rua vitoria"
  /// Heurística: tipo de logradouro (1ª palavra) + até 2 palavras seguintes.
  static String _extractOnlyLogradouro(String normalized) {
    final tokens = normalized.trim().split(RegExp(r'\s+'));
    if (tokens.length <= 3) return normalized; // curto demais, retorna inteiro
    // Pega tipo + nome (primeiras 3 palavras), descarta o resto (provável bairro)
    return tokens.take(3).join(' ');
  }

  static Future<List<AddressResult>> _searchNominatimStructured(
      String street, String city, String state) async {
    try {
      final uri = Uri.parse(_nominatimUrl).replace(queryParameters: {
        'street':         street,
        'city':           city,
        'state':          state,
        'format':         'json',
        'addressdetails': '1',
        'limit':          '10',
        'countrycodes':   'br',
        'dedupe':         '1',
      });

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];
      return _parseNominatimResponse(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('AddressSearchService._searchNominatimStructured error: $e');
      return [];
    }
  }

  static Future<List<AddressResult>> _searchNominatim(String q) async {
    try {
      final uri = Uri.parse(_nominatimUrl).replace(queryParameters: {
        'q':              q,
        'format':         'json',
        'addressdetails': '1',
        'limit':          '10',
        'countrycodes':   'br',
        'dedupe':         '1',
      });

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];
      return _parseNominatimResponse(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('AddressSearchService._searchNominatim error: $e');
      return [];
    }
  }

  /// Parser unificado da resposta JSON do Nominatim (usado por ambos os métodos)
  static List<AddressResult> _parseNominatimResponse(String body) {
    final List<dynamic> data = json.decode(body) as List<dynamic>;
    final results = <AddressResult>[];
    final seen = <String>{};

    for (final item in data) {
      final addr = (item['address'] as Map<String, dynamic>?) ?? {};

      // Montar título: para endereços com número o 'name' vem vazio
      String title = (item['name'] as String? ?? '').trim();
      final road        = (addr['road']         as String? ?? '').trim();
      final houseNumber = (addr['house_number']  as String? ?? '').trim();
      if (title.isEmpty && road.isNotEmpty) {
        title = houseNumber.isNotEmpty ? '$road, $houseNumber' : road;
      }
      if (title.length < 2) continue;

      final state  = (addr['state']       as String? ?? '').trim();
      final uf     = _stateToUF(state);
      final city   = (addr['city']        as String? ??
                      addr['town']        as String? ??
                      addr['municipality'] as String? ??
                      addr['village']     as String? ??
                      state).trim();
      final suburb = (addr['suburb']        as String? ??
                      addr['quarter']       as String? ??
                      addr['neighbourhood'] as String? ??
                      addr['city_district'] as String? ??
                      '').trim();
      final cep = (addr['postcode'] as String? ?? '').trim();

      final lat = double.tryParse(item['lat'] as String? ?? '') ?? 0;
      final lon = double.tryParse(item['lon'] as String? ?? '') ?? 0;

      // Montar subtítulo
      final parts = <String>[];
      if (suburb.isNotEmpty) parts.add(suburb);
      if (city.isNotEmpty)   parts.add(city);
      if (uf.isNotEmpty)     parts.add(uf);
      final subtitle = parts.join(' — ');

      // Deduplicar
      final key = _norm(title + subtitle);
      if (!seen.add(key)) continue;

      results.add(AddressResult(
        title:    title,
        subtitle: subtitle,
        lat:      lat,
        lon:      lon,
        isCity:   false,
        cep:      cep.isNotEmpty ? cep : null,
      ));
    }

    return results;
  }

  // ── 3. ViaCEP fallback — ruas de bairros não cobertos pelo OSM ─
  // Ex: "Rua Goiás, Estância Monazítica, Serra ES"
  static Future<List<AddressResult>> searchViaCep(String query) async {
    final q = query.trim();
    if (q.length < 4) return [];

    final cacheKey = 'viacep_${q.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      // Tenta extrair UF + cidade + logradouro da query
      // Formato: "Rua X, Bairro, Cidade - UF" ou "Rua X Cidade UF"
      String uf = '';
      String cidade = '';
      String rua = '';

      // Detecta UF no final (2 letras maiúsculas)
      final ufMatch = RegExp(r'\b([A-Z]{2})\b').allMatches(q);
      if (ufMatch.isNotEmpty) {
        uf = ufMatch.last.group(1)!;
      } else {
        // tenta pelo nome do estado
        const estados = {
          'espírito santo': 'ES', 'espirito santo': 'ES', ' es ': 'ES',
          'são paulo': 'SP', 'sao paulo': 'SP', 'rio de janeiro': 'RJ',
          'minas gerais': 'MG', 'bahia': 'BA', 'paraná': 'PR', 'parana': 'PR',
        };
        final qLow = q.toLowerCase();
        for (final e in estados.entries) {
          if (qLow.contains(e.key)) { uf = e.value; break; }
        }
      }

      // Extrai cidade — procura nos municípios o que aparece na query
      final qNorm = _norm(q);
      for (final m in kMunicipiosBrasil) {
        final nome = m[0] as String;
        final mUf  = m[1] as String;
        if (uf.isNotEmpty && mUf != uf) continue;
        if (qNorm.contains(_norm(nome))) {
          cidade = nome;
          break;
        }
      }

      // Extrai logradouro — tudo antes do bairro/cidade
      if (cidade.isNotEmpty) {
        final cidIdx = q.toLowerCase().indexOf(cidade.toLowerCase());
        if (cidIdx > 0) rua = q.substring(0, cidIdx).replaceAll(RegExp(r'[,\-]+$'), '').trim();
      }
      if (rua.isEmpty) {
        // Tenta: pega primeira parte (antes da primeira vírgula ou 4 palavras)
        final parts = q.split(RegExp(r'[,\-]'));
        if (parts.isNotEmpty) rua = parts[0].trim();
      }

      if (uf.isEmpty || cidade.isEmpty || rua.isEmpty) return [];

      // Monta URL ViaCEP
      final cidadeEnc = Uri.encodeComponent(cidade);
      final ruaEnc    = Uri.encodeComponent(rua);
      final url = 'https://viacep.com.br/ws/$uf/$cidadeEnc/$ruaEnc/json/';

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];
      final body = response.body.trim();
      if (body.startsWith('{')) return []; // erro da API

      final List<dynamic> data = json.decode(body) as List<dynamic>;
      final results = <AddressResult>[];
      final seen = <String>{};

      // Pegar coords da cidade (banco local) como base
      double baseLat = 0, baseLon = 0;
      for (final m in kMunicipiosBrasil) {
        if (_norm(m[0] as String) == _norm(cidade) && m[1] == uf) {
          baseLat = (m[2] as num).toDouble();
          baseLon = (m[3] as num).toDouble();
          break;
        }
      }

      for (final item in data) {
        final logradouro  = (item['logradouro']  as String? ?? '').trim();
        final bairro      = (item['bairro']      as String? ?? '').trim();
        final localidade  = (item['localidade']  as String? ?? '').trim();
        final cep         = (item['cep']         as String? ?? '').trim();
        final itemUf      = (item['uf']          as String? ?? uf).trim();

        if (logradouro.isEmpty) continue;

        final title    = logradouro;
        final subParts = <String>[];
        if (bairro.isNotEmpty)    subParts.add(bairro);
        if (localidade.isNotEmpty) subParts.add(localidade);
        if (itemUf.isNotEmpty)    subParts.add(itemUf);
        final subtitle = subParts.join(' — ');

        final key = _norm(title + subtitle);
        if (!seen.add(key)) continue;

        results.add(AddressResult(
          title:    title,
          subtitle: subtitle,
          lat:      baseLat,   // coords da cidade como aproximação
          lon:      baseLon,
          isCity:   false,
          cep:      cep.isNotEmpty ? cep : null,
        ));

        if (results.length >= 8) break;
      }

      _cache[cacheKey] = results;
      return results;

    } catch (e) {
      if (kDebugMode) debugPrint('AddressSearchService.searchViaCep error: $e');
      return [];
    }
  }

  // ── 4. Busca híbrida — cidades locais + endereços online ───────
  // Retorna cidades instantaneamente, endereços via callback async
  static List<AddressResult> searchLocalImmediate(String query) {
    return searchCities(query);
  }

  /// Busca online: Nominatim → Photon → Overpass → ViaCEP → BrowserGeo+Mapbox.
  /// Se a query contiver um CEP (8 dígitos), faz lookup direto primeiro.
  /// Detecta automaticamente queries de POI (ex: "Shopping Vitória")
  /// e prioriza Overpass+Photon para obter coords reais do local.
  static Future<List<AddressResult>> searchOnline(String query) async {
    // ── CEP direto: "29175-508" ou "29175508" ──────────────────────
    final cepMatch = RegExp(r'\b(\d{5})-?(\d{3})\b').firstMatch(query);
    if (cepMatch != null) {
      final cep = '${cepMatch.group(1)}${cepMatch.group(2)}';
      final byCep = await searchByCep(cep);
      if (byCep.isNotEmpty) return byCep;
    }

    // ── Detecta se é busca de POI (Shopping, Hospital, Posto, etc.) ─
    // POIs têm palavras-chave típicas no início da query
    final isPoi = _looksLikePoi(query);

    if (isPoi) {
      // Para POIs: Photon é mais rápido, Overpass é mais preciso
      final photonPoi = await searchPoi(query);
      if (photonPoi.isNotEmpty) return photonPoi;
    }

    // ── Nominatim (OSM full-text) ───────────────────────────────────
    final nominatim = await searchAddress(query);
    if (nominatim.isNotEmpty) return nominatim;

    // ── Photon (Komoot) — geocodificação rápida BR ──────────────────
    try {
      final pos = BrowserGeoFallback.cachedPosition; // usa cache se disponível
      final photon = await PhotonApiService.search(
        query,
        nearLat: pos?.lat,
        nearLon: pos?.lon,
        limit: 8,
        countryCode: 'BR',
      );
      if (photon.isNotEmpty) {
        if (kDebugMode) debugPrint('[AddressSearch] Photon: ${photon.length} resultados');
        return PhotonApiService.toAddressResults(photon);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AddressSearch] Photon error: $e');
    }

    // ── ViaCEP (bairros sem cobertura OSM) ──────────────────────────
    final viaCep = await searchViaCep(query);
    if (viaCep.isNotEmpty) return viaCep;

    // ── Último recurso: GPS do dispositivo + Mapbox /forward ────────
    try {
      if (kDebugMode) debugPrint('[AddressSearch] BrowserGeoFallback ativado para: "$query"');
      final pos = await BrowserGeoFallback.getPosition();
      if (pos != null) {
        final results = await MapboxSearchService.forward(
          query,
          proximity: pos.proximityParam,
          country: 'br',
          language: 'pt',
          limit: 5,
        );
        if (kDebugMode) debugPrint('[AddressSearch] Mapbox forward: ${results.length} resultados');
        return results;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AddressSearch] BrowserGeoFallback error: $e');
    }

    return [];
  }

  /// Busca POI específico: Photon (rápido) + Overpass (preciso) em paralelo.
  /// Retorna lista deduplicada ordenada por relevância.
  static Future<List<AddressResult>> searchPoi(String query, {
    double? nearLat,
    double? nearLon,
  }) async {
    // Usa posição em cache se não fornecida
    double? lat = nearLat;
    double? lon = nearLon;
    if (lat == null || lon == null) {
      final cached = BrowserGeoFallback.cachedPosition;
      lat = cached?.lat;
      lon = cached?.lon;
    }

    // Executa Photon e Overpass em paralelo para velocidade máxima
    final results = await Future.wait([
      PhotonApiService.searchPoi(query, nearLat: lat, nearLon: lon),
      OverpassApiService.searchByName(query, nearLat: lat, nearLon: lon, radiusKm: 100),
    ]);

    final photonResults  = results[0] as List<PhotonResult>;
    final overpassResults = results[1] as List<OverpassPoi>;

    final combined = <AddressResult>[];
    final seen = <String>{};

    // Overpass primeiro (coords rooftop mais precisas)
    for (final poi in overpassResults) {
      final key = _norm(poi.name);
      if (seen.add(key)) combined.add(poi.toAddressResult());
    }

    // Photon complementa
    for (final r in photonResults) {
      final key = _norm(r.name);
      if (seen.add(key)) combined.add(r.toAddressResult());
    }

    if (kDebugMode) {
      debugPrint('[AddressSearch] POI "${query}": '
          '${overpassResults.length} Overpass + ${photonResults.length} Photon '
          '= ${combined.length} únicos');
    }
    return combined;
  }

  // ── Detecta se query parece ser um POI ───────────────────────────
  /// Público para uso em trip_flow_screens e outros lugares
  static bool looksLikePoi(String query) => _looksLikePoi(query);

  static bool _looksLikePoi(String query) {
    final q = _norm(query).toLowerCase();
    const poiWords = [
      'shopping', 'mall', 'hospital', 'clinica', 'upa', 'ups',
      'posto', 'petrob', 'shell', 'ipiranga', 'supermercado',
      'extra', 'carrefour', 'walmart', 'assai', 'atacadao',
      'hotel', 'pousada', 'aeroporto', 'terminal', 'rodoviaria',
      'delegacia', 'policia', 'bombeiro', 'pronto-socorro',
      'escola', 'colegio', 'universidade', 'faculdade', 'ufes',
      'banco', 'bradesco', 'itau', 'caixa', 'bb ', 'santander',
      'farmacia', 'drogaria', 'droga',
    ];
    return poiWords.any((w) => q.contains(w));
  }

  /// Lookup direto de endereço pelo CEP (ViaCEP) — retorna
  /// um único AddressResult com coordenadas da cidade.
  static Future<List<AddressResult>> searchByCep(String cep) async {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length != 8) return [];

    final cacheKey = 'cep_$cleanCep';
    await _ensurePersistCacheLoaded();
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      final response = await http
          .get(Uri.parse('https://viacep.com.br/ws/$cleanCep/json/'),
              headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];
      final body = response.body.trim();
      if (body.contains('"erro"')) return []; // CEP inválido

      final Map<String, dynamic> data =
          json.decode(body) as Map<String, dynamic>;
      final logradouro = (data['logradouro'] as String? ?? '').trim();
      final bairro     = (data['bairro']     as String? ?? '').trim();
      final localidade = (data['localidade'] as String? ?? '').trim();
      final uf         = (data['uf']         as String? ?? '').trim();

      if (logradouro.isEmpty && localidade.isEmpty) return [];

      final title = logradouro.isNotEmpty ? logradouro : localidade;
      final parts = <String>[];
      if (bairro.isNotEmpty)    parts.add(bairro);
      if (localidade.isNotEmpty) parts.add(localidade);
      if (uf.isNotEmpty)        parts.add(uf);
      final subtitle = parts.join(' — ');

      // Coords da cidade (banco local) como aproximação
      double baseLat = 0, baseLon = 0;
      for (final m in kMunicipiosBrasil) {
        if (_norm(m[0] as String) == _norm(localidade) && m[1] == uf) {
          baseLat = (m[2] as num).toDouble();
          baseLon = (m[3] as num).toDouble();
          break;
        }
      }

      // Se temos logradouro, tenta refinar coords via Nominatim
      if (logradouro.isNotEmpty && localidade.isNotEmpty) {
        final refined = await _searchNominatimStructured(
            _normalizeQuery(logradouro), localidade, uf);
        if (refined.isNotEmpty) {
          // Prefere o resultado do Nominatim (coords reais da rua)
          final result = [
            AddressResult(
              title:    title,
              subtitle: subtitle,
              lat:      refined.first.lat,
              lon:      refined.first.lon,
              isCity:   false,
              cep:      cleanCep,
            )
          ];
          _cache[cacheKey] = result;
          _persistCache();
          return result;
        }
      }

      final result = [
        AddressResult(
          title:    title,
          subtitle: subtitle,
          lat:      baseLat,
          lon:      baseLon,
          isCity:   false,
          cep:      cleanCep,
        )
      ];
      _cache[cacheKey] = result;
      if (baseLat != 0) _persistCache();
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('AddressSearchService.searchByCep error: $e');
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Normalização leve — apenas remove acentos + lowercase
  /// Usada para comparações internas e cache keys
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a').replaceAll('à', 'a')
      .replaceAll('â', 'a').replaceAll('ã', 'a')
      .replaceAll('é', 'e').replaceAll('ê', 'e')
      .replaceAll('í', 'i').replaceAll('î', 'i')
      .replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o')
      .replaceAll('ú', 'u').replaceAll('û', 'u')
      .replaceAll('ç', 'c');

  /// Normalização completa para envio às APIs:
  ///   1. Remove acentos
  ///   2. Expande abreviações comuns (R. → Rua, Av. → Avenida, etc.)
  ///   3. Remove pontuação extra e espaços duplos
  ///   4. Remove sufixo "- UF" duplicado se o estado já estiver escrito
  static String _normalizeQuery(String raw) {
    String s = _norm(raw); // lowercase + sem acentos

    // Expande abreviações — ordem importa: mais específicas primeiro
    final Map<RegExp, String> abrevs = {
      // Logradouros
      RegExp(r'\br\.\s*'): 'rua ',
      RegExp(r'\bav\.\s*'): 'avenida ',
      RegExp(r'\bave\.\s*'): 'avenida ',
      RegExp(r'\btrv\.?\s*'): 'travessa ',
      RegExp(r'\btrv\.\s*'): 'travessa ',
      RegExp(r'\btra\.\s*'): 'travessa ',
      RegExp(r'\balm\.?\s*'): 'alameda ',
      RegExp(r'\blg\.?\s*'): 'largo ',
      RegExp(r'\bpca\.?\s*'): 'praca ',
      RegExp(r'\bprc\.?\s*'): 'praca ',
      RegExp(r'\best\.\s*'): 'estrada ',
      RegExp(r'\brod\.?\s*'): 'rodovia ',
      RegExp(r'\bpq\.?\s*'): 'parque ',
      RegExp(r'\bbc\.?\s*'): 'beco ',
      RegExp(r'\bvl\.?\s*'): 'vila ',
      RegExp(r'\bjd\.?\s*'): 'jardim ',
      RegExp(r'\bbl\.?\s*'): 'bloco ',
      // Estados abreviados → escreve por extenso para melhor match
      RegExp(r'\-\s*am\b'): 'amazonas',
      RegExp(r'\-\s*pa\b'): 'para',
      RegExp(r'\-\s*ro\b'): 'rondonia',
      RegExp(r'\-\s*rr\b'): 'roraima',
      RegExp(r'\-\s*ap\b'): 'amapa',
      RegExp(r'\-\s*to\b'): 'tocantins',
      RegExp(r'\-\s*ma\b'): 'maranhao',
      RegExp(r'\-\s*pi\b'): 'piaui',
      RegExp(r'\-\s*ce\b'): 'ceara',
      RegExp(r'\-\s*rn\b'): 'rio grande do norte',
      RegExp(r'\-\s*pb\b'): 'paraiba',
      RegExp(r'\-\s*pe\b'): 'pernambuco',
      RegExp(r'\-\s*al\b'): 'alagoas',
      RegExp(r'\-\s*se\b'): 'sergipe',
      RegExp(r'\-\s*ba\b'): 'bahia',
      RegExp(r'\-\s*mg\b'): 'minas gerais',
      RegExp(r'\-\s*es\b'): 'espirito santo',
      RegExp(r'\-\s*rj\b'): 'rio de janeiro',
      RegExp(r'\-\s*sp\b'): 'sao paulo',
      RegExp(r'\-\s*pr\b'): 'parana',
      RegExp(r'\-\s*sc\b'): 'santa catarina',
      RegExp(r'\-\s*rs\b'): 'rio grande do sul',
      RegExp(r'\-\s*ms\b'): 'mato grosso do sul',
      RegExp(r'\-\s*mt\b'): 'mato grosso',
      RegExp(r'\-\s*go\b'): 'goias',
      RegExp(r'\-\s*df\b'): 'distrito federal',
      RegExp(r'\-\s*ac\b'): 'acre',
    };

    for (final entry in abrevs.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }

    // Remove vírgulas e traços desnecessários, colapsa espaços
    s = s.replaceAll(RegExp(r'[,]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  static String _stateToUF(String state) {
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
}

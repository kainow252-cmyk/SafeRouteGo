// ═══════════════════════════════════════════════════════════════
// SAFEROUTE — TRIP FLOW SCREENS
// Destino → Cotação (Actuarial Engine V2) → Confirmação
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/mapbox_map_widget.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/vehicle_picker_widget.dart';
import '../services/risk_engine.dart';
import '../services/actuarial_engine.dart';
import '../services/safe_map_engine.dart';
import '../services/nominatim_search_service.dart';
import '../services/address_search_service.dart';
import '../services/mapbox_search_service.dart';
import '../services/photon_api_service.dart';
import '../services/overpass_api_service.dart';
import '../services/osrm_route_service.dart';
import '../services/location_service.dart';
import '../services/municipios_brasil.dart';
import '../services/traffic_detection_service.dart';
import '../services/atuario_virtual_engine.dart';
import '../services/driver_profile_service.dart';
import '../services/trip_insurance_engine.dart';
import '../providers/app_state.dart';

// ══════════════════════════════════════════════════════════════
// MODELO DE LUGAR — busca local + API híbrida
// ══════════════════════════════════════════════════════════════
class _PlaceEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String dist;
  final RiskZone zone;
  final bool isFrequent;
  final bool isRecent;
  final List<String> tags;
  final bool isApiResult;
  final double? lat;   // coordenadas reais para ordenar por distância
  final double? lon;

  const _PlaceEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dist,
    required this.zone,
    this.isFrequent = false,
    this.isRecent = false,
    this.tags = const [],
    this.isApiResult = false,
    this.lat,
    this.lon,
  });

  // Construtor a partir de PlaceResult (banco real OSM)
  // distLabel: distância real calculada via Haversine (ex: "1,2 km", "340 m")
  factory _PlaceEntry.fromPlaceResult(PlaceResult r, {String? distLabel}) {
    return _PlaceEntry(
      icon: r.icon,
      title: r.name,
      subtitle: r.subtitle,
      dist: distLabel ?? r.dist, // usa distância GPS real se disponível
      zone: _zoneFromString(r.zone),
      tags: r.tags,
      isApiResult: !r.isLocal,
    );
  }

  static RiskZone _zoneFromString(String z) {
    switch (z) {
      case 'verde':    return RiskZone.verde;
      case 'laranja':  return RiskZone.laranja;
      case 'vermelha': return RiskZone.vermelha;
      case 'critica':  return RiskZone.critica;
      default:         return RiskZone.amarela;
    }
  }

  // Busca unificada em todos os campos (com normalização)
  bool matches(String q) {
    final low = _norm(q);
    return _norm(title).contains(low) ||
        _norm(subtitle).contains(low) ||
        tags.any((t) => _norm(t).contains(low));
  }

  static String _norm(String s) {
    return s.toLowerCase()
        .replaceAll('á', 'a').replaceAll('â', 'a').replaceAll('ã', 'a').replaceAll('à', 'a')
        .replaceAll('é', 'e').replaceAll('ê', 'e')
        .replaceAll('í', 'i').replaceAll('î', 'i')
        .replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o')
        .replaceAll('ú', 'u').replaceAll('û', 'u')
        .replaceAll('ç', 'c');
  }

  int relevanceScore(String q) {
    final nt = _norm(title), nq = _norm(q);
    if (nt == nq) return 100;
    if (nt.startsWith(nq)) return 80;
    if (nt.contains(nq)) return 60;
    return 40;
  }
}

// ── Lugares fixos (recentes + frequentes) ──────────────────────
const List<_PlaceEntry> _kFixedPlaces = [
  // RECENTES — coords reais para que _fatorGeograficoGps funcione corretamente
  _PlaceEntry(icon: Icons.location_on_rounded, title: 'Vitória',
      subtitle: 'Capital — ES', dist: '27 km', zone: RiskZone.amarela,
      lat: -20.3155, lon: -40.3128,
      isRecent: true, tags: ['vitoria', 'centro', 'capital', 'es']),
  _PlaceEntry(icon: Icons.location_on_rounded, title: 'Vila Velha',
      subtitle: 'ES', dist: '32 km', zone: RiskZone.laranja,
      lat: -20.3297, lon: -40.2922,
      isRecent: true, tags: ['vila velha', 'shopping', 'vv', 'es']),
  _PlaceEntry(icon: Icons.location_on_rounded, title: 'Guarapari',
      subtitle: 'ES', dist: '78 km', zone: RiskZone.verde,
      lat: -20.6753, lon: -40.4986,
      isRecent: true, tags: ['guarapari', 'praia', 'morro', 'es']),
  // FREQUENTES
  _PlaceEntry(icon: Icons.work_rounded, title: 'Trabalho',
      subtitle: 'Av. Jerônimo Monteiro, 500 — Vitória', dist: '22 km', zone: RiskZone.amarela,
      lat: -20.3191, lon: -40.3378,
      isFrequent: true, tags: ['jeronimo monteiro', 'avenida', 'vitoria', 'escritorio']),
  _PlaceEntry(icon: Icons.home_rounded, title: 'Casa',
      subtitle: 'Rua das Laranjeiras, 120 — Serra', dist: '3 km', zone: RiskZone.verde,
      lat: -20.1278, lon: -40.3072,
      isFrequent: true, tags: ['laranjeiras', 'rua', 'serra', 'residencia']),
];



// ══════════════════════════════════════════════════════════════
// DESTINO — com busca funcional
// ══════════════════════════════════════════════════════════════
class DestinationScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSelectDestination;

  const DestinationScreen({super.key, required this.onBack, required this.onSelectDestination});

  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  bool _isTyping = false;
  bool _isSearchingApi = false;

  // ── Posição GPS do usuário (para ordenar por proximidade) ──
  double? _userLat;
  double? _userLon;
  String? _userUF;       // ex: "ES", "SP" — prioriza resultados da UF atual
  bool _gpsReady = false;

  // Resultados combinados: banco local + API
  List<_PlaceEntry> _localResults = [];
  List<_PlaceEntry> _apiResults = [];

  // Mapbox: sugestões pendentes de /retrieve (aguardando seleção do usuário)
  // mapbox_id → MapboxSuggestion (para chamar /retrieve ao clicar)
  final Map<String, MapboxSuggestion> _mapboxPending = {};

  // Timer para debounce da busca na API (Timer real, não Future.delayed)
  Timer? _debounceTimer;



  // Obtém posição GPS atual para ordenar resultados por proximidade
  Future<void> _initGps() async {
    // Reusa posição já obtida (LocationService é singleton)
    final existing = LocationService.instance.state;
    if (existing.hasPosition) {
      if (mounted) {
        setState(() {
          _userLat = existing.lat;
          _userLon = existing.lon;
          _userUF  = existing.geo?.uf ?? _userUF;
          _gpsReady = true;
        });
      }
      return;
    }

    // Solicita nova leitura
    final loc = await LocationService.instance.getCurrentPosition();
    if (mounted && loc.hasPosition) {
      setState(() {
        _userLat = loc.lat;
        _userLon = loc.lon;
        _userUF  = loc.geo?.uf ?? _userUF;
        _gpsReady = true;
      });
      // Salva origem no TripSession para TrafficDetectionService
      TripSession.current.setOrigin(lat: loc.lat!, lon: loc.lon!);
      // Re-ordena resultados já exibidos se o usuário já digitou algo
      if (_localResults.isNotEmpty || _apiResults.isNotEmpty) _onQueryChanged();
    } else if (mounted) {
      // GPS indisponível (web/emulador): confirma fallback Serra/ES
      setState(() { _gpsReady = true; });
      if (_localResults.isNotEmpty || _apiResults.isNotEmpty) _onQueryChanged();
    }
  }

  // ── Palavras genéricas → NÃO consulta o banco de municípios ──
  // Quando o usuário digita "rua", "av", "avenida" etc., não faz sentido
  // mostrar cidades com essas sílabas no nome (Araruama, Aruanã...).
  // Vai direto para Nominatim/ViaCEP que retorna logradouros reais.
  // Inclui abreviações normalizadas (r. → rua, av. → avenida etc.)
  static const _kLogradouroWords = {
    // tipos completos
    'rua', 'avenida', 'travessa', 'rodovia', 'estrada',
    'alameda', 'largo', 'praca', 'viela', 'beco', 'servidao',
    'via', 'passagem', 'passarela', 'viaduto', 'ponte', 'tunel',
    'parque', 'jardim', 'vila', 'bloco', 'quadra', 'setor',
    // abreviações sem ponto (após normalização _norm já remove acentos)
    'av', 'ave', 'trv', 'tra', 'rod', 'est', 'alm', 'pca', 'prc',
    'lg', 'pq', 'vl', 'jd', 'bl', 'qd',
    // prefixos parciais (usuário ainda digitando)
    'aven', 'aveni', 'avenid',
    'trav', 'traves',
    'estr', 'estra',
    'rodo', 'rodov',
  };

  bool get _queryIsLogradouro {
    // Normaliza a query (sem acentos, sem pontos) antes de comparar
    final q = _norm(_query).replaceAll('.', '').trim();
    return _kLogradouroWords.any((w) => q == w || q.startsWith('$w '));
  }

  void _onQueryChanged() {
    final q = _controller.text.trim();
    setState(() {
      _query = q.toLowerCase();
      _isTyping = q.isNotEmpty;
      if (q.isEmpty) {
        _localResults = [];
        _apiResults = [];
        _isSearchingApi = false;
      }
    });

    if (q.isEmpty) return;

    // 1) Banco local IBGE — só para buscas de CIDADE/BAIRRO
    //    Se o usuário digitou "rua", "av", "avenida" etc. → pula o banco,
    //    vai direto para Nominatim/ViaCEP que retorna logradouros reais.
    if (!_queryIsLogradouro) {
      final cities = AddressSearchService.searchLocalImmediate(q);
      setState(() {
        _localResults = cities.map((r) {
          final distLabel = _distLabel(r.lat, r.lon);
          return _PlaceEntry(
            icon: Icons.location_city_rounded,
            title: r.title,
            subtitle: r.subtitle,
            dist: distLabel,
            zone: RiskZone.amarela,
            isApiResult: false,
            lat: r.lat,
            lon: r.lon,
          );
        }).toList();
        // Reordena por proximidade SOMENTE se não houver capital nos resultados.
        // Capitais (ex: São Paulo/SP) têm prioridade sobre proximidade geográfica
        // — sem isso, cidades menores mais próximas ao usuário (ES) sobem na lista.
        final temCapital = cities.any((r) => r.subtitle.startsWith('Capital'));
        if (!temCapital) _sortByProximity(_localResults);
      });
    } else {
      setState(() => _localResults = []);
    }

    // 2) Nominatim/ViaCEP — ruas, números, bairros (debounce 500ms)
    _debounceTimer?.cancel(); // Timer real — cancel() funciona de verdade
    // Para logradouros, começa a buscar com 3+ chars; para outros, 4+
    final minLen = _queryIsLogradouro ? 3 : 4;
    if (q.length >= minLen) {
      setState(() => _isSearchingApi = true);
      // Captura snapshots AGORA — evita race condition com _query
      final querySnapshot = q;
      final isLogradouroSnapshot = _queryIsLogradouro;
      _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
        final efUF  = _userUF  ?? 'ES';
        final efLat = _userLat ?? -20.1278;
        final efLon = _userLon ?? -40.3072;
        final proximity = '$efLon,$efLat'; // Mapbox usa lon,lat

        // ══════════════════════════════════════════════════════════════
        // CAMADA 1 — Mapbox Search Box /suggest (primária)
        // Retorna sugestões rankeadas por proximidade GPS para QUALQUER
        // tipo de endereço (rua, bairro, CEP, POI, cidade, etc.)
        // Funciona independente de como o bairro está indexado no OSM.
        // ══════════════════════════════════════════════════════════════
        final mapboxSuggestions = await MapboxSearchService.suggest(
          querySnapshot,
          proximity: proximity,
          country: 'br',
          language: 'pt',
          limit: 8,
          // Para logradouros: foca em address e street
          // Para outros: aceita todos os tipos
          types: isLogradouroSnapshot
              ? 'address,street,neighborhood'
              : null,
        );

        // Descarta se o usuário já digitou outra coisa
        if (!mounted || _controller.text.trim().toLowerCase() != querySnapshot.toLowerCase()) return;

        if (mapboxSuggestions.isNotEmpty) {
          // Converte sugestões em _PlaceEntry SEM coordenadas (ainda)
          // Coordenadas serão obtidas via /retrieve ao clicar
          _mapboxPending.clear();
          final localTitles = _localResults.map((e) => _norm(e.title + e.subtitle)).toSet();
          final mapboxEntries = <_PlaceEntry>[];

          for (final s in mapboxSuggestions) {
            _mapboxPending[s.mapboxId] = s; // guarda para /retrieve depois
            final subtitle = s.subtitle;
            final key = _norm(s.name + subtitle);
            if (localTitles.contains(key)) continue;

            // Estimativa de coordenadas: centro da cidade do GPS (só para ordenar)
            // Coords reais virão via /retrieve ao selecionar
            mapboxEntries.add(_PlaceEntry(
              icon: _iconForType(s.featureType),
              title: s.name,
              subtitle: subtitle,
              dist: '', // sem distância antes do /retrieve
              zone: RiskZone.amarela,
              isApiResult: true,
              lat: efLat, // placeholder — substitui ao clicar
              lon: efLon,
            ));
          }

          if (!mounted) return;
          setState(() {
            _apiResults = mapboxEntries;
            _isSearchingApi = false;
          });
          return; // Mapbox funcionou, não precisa de fallbacks
        }

        // ══════════════════════════════════════════════════════════════
        // CAMADA 2a — Photon+Overpass para POIs (Shopping, Hospital…)
        // Detecta automaticamente queries de ponto específico e busca
        // via Komoot Photon + Overpass OSM em paralelo (ambos gratuitos)
        // ══════════════════════════════════════════════════════════════
        if (AddressSearchService.looksLikePoi(querySnapshot)) {
          final poiResults = await AddressSearchService.searchPoi(
            querySnapshot,
            nearLat: efLat,
            nearLon: efLon,
          );
          if (!mounted || _controller.text.trim().toLowerCase() != querySnapshot.toLowerCase()) return;
          if (poiResults.isNotEmpty) {
            final localTitlesP = _localResults.map((e) => _norm(e.title + e.subtitle)).toSet();
            final poiEntries = poiResults
                .where((r) => !localTitlesP.contains(_norm(r.title + r.subtitle)))
                .map((r) => _PlaceEntry(
                  icon: _iconForPoi(r.subtitle),
                  title: r.title,
                  subtitle: r.subtitle,
                  dist: _distLabel(r.lat, r.lon),
                  zone: RiskZone.amarela,
                  isApiResult: true,
                  lat: r.lat,
                  lon: r.lon,
                ))
                .take(10)
                .toList();
            _sortByProximity(poiEntries);
            if (!mounted) return;
            setState(() {
              _apiResults = poiEntries;
              _isSearchingApi = false;
            });
            return; // POI encontrado — não precisa de mais fallbacks
          }
        }

        // ══════════════════════════════════════════════════════════════
        // CAMADA 2b — Nominatim OSM (fallback se Mapbox falhar/offline)
        // ══════════════════════════════════════════════════════════════
        List<AddressResult> online;
        if (isLogradouroSnapshot) {
          final cidadeProxima = _cidadeMaisProximaEf(efLat, efLon, efUF);
          final cidadeStr = cidadeProxima ?? 'Serra';
          final suburbFromQuery = _extractSuburbFromQuery(querySnapshot, cidadeStr);
          online = await AddressSearchService.searchAddressStructured(
            street: querySnapshot,
            city:   cidadeStr,
            state:  efUF,
            suburb: suburbFromQuery,
          );
          if (online.isEmpty) {
            online = await AddressSearchService.searchViaCep('$querySnapshot $cidadeStr $efUF');
          }
        } else {
          online = await AddressSearchService.searchOnline(querySnapshot);
        }

        if (!mounted || _controller.text.trim().toLowerCase() != querySnapshot.toLowerCase()) return;
        final localTitles2 = _localResults.map((e) => _norm(e.title + e.subtitle)).toSet();
        final apiEntries = online
            .where((r) => !localTitles2.contains(_norm(r.title + r.subtitle)))
            .map((r) => _PlaceEntry(
              icon: Icons.signpost_rounded,
              title: r.title,
              subtitle: r.subtitle,
              dist: _distLabel(r.lat, r.lon),
              zone: RiskZone.amarela,
              isApiResult: true,
              lat: r.lat,
              lon: r.lon,
            ))
            .take(12)
            .toList();
        _sortByProximity(apiEntries);
        if (!mounted) return;
        setState(() {
          _apiResults = apiEntries;
          _isSearchingApi = false;
        });
      });
    } else {
      setState(() { _apiResults = []; _isSearchingApi = false; });
    }
  }

  // ── Calcula distância em km até a posição do usuário ──────────
  double? _distKm(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    if (_userLat == null || _userLon == null) return null;
    const r = 6371.0;
    final dLat = (lat - _userLat!) * math.pi / 180;
    final dLon = (lon - _userLon!) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_userLat! * math.pi / 180) * math.cos(lat * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ── Cidade mais próxima do GPS no banco IBGE (para injetar na query) ─
  // Retorna apenas o nome da cidade, ex: "Serra"
  // Recebe uf/lat/lon explicitamente para não depender do state (thread-safe)
  String? _cidadeMaisProximaEf(double userLat, double userLon, String uf) {
    String? melhorNome;
    double melhorDist = double.infinity;
    for (final m in kMunicipiosBrasil) {
      final mUf = m[1] as String;
      if (mUf != uf) continue; // só UF informada
      final lat = (m[2] as num).toDouble();
      final lon = (m[3] as num).toDouble();
      final dist = _distKmRaw(userLat, userLon, lat, lon);
      if (dist < melhorDist) {
        melhorDist = dist;
        melhorNome = m[0] as String;
      }
    }
    return melhorNome;
  }

  // ── Extrai bairro/distrito da query para fallback Nominatim ─────
  // Problema: Nominatim indexa bairros como suburb= (não como city=).
  // Solução: quando o usuário digita o bairro junto ao logradouro,
  // extraímos e passamos como parâmetro suburb ao searchAddressStructured.
  //
  // Heurística: se a query tem 3+ tokens e o último bloco de 2+ tokens
  // NÃO é o nome da cidade GPS → é provavelmente um bairro.
  // Ex: "rua vitoria parque jacaraipe" → cidade="Serra", bairro="parque jacaraipe"
  // Ex: "avenida central 500"         → sem bairro (apenas número)
  // Ex: "rua das flores"              → sem bairro (só 3 tokens, puro nome de rua)
  String? _extractSuburbFromQuery(String query, String cidadeGps) {
    final tokens = _norm(query).trim().split(RegExp(r'\s+'));
    // Precisa de pelo menos 4 tokens: "rua nome bairro1 bairro2"
    if (tokens.length < 4) return null;

    // Remove tipo de logradouro (1ª palavra) e verifica se o restante
    // tem mais de 1 "bloco" que parece bairro
    // Pega as últimas 2 palavras como candidato a bairro
    final lastTwo  = tokens.sublist(tokens.length - 2).join(' ');
    final lastThree = tokens.sublist(tokens.length - 3).join(' ');

    // Descarta se o candidato é número (ex: "500" ou "2 a")
    final isNumeric = RegExp(r'^\d').hasMatch(lastTwo);
    if (isNumeric) return null;

    // Descarta se o candidato é igual (normalizado) à cidade GPS
    if (_norm(lastTwo) == _norm(cidadeGps)) return null;
    if (_norm(lastThree) == _norm(cidadeGps)) return null;

    // Descarta se o candidato é uma palavra genérica de logradouro
    final genericWords = {
      'norte', 'sul', 'leste', 'oeste', 'centro', 'central',
      'nova', 'novo', 'velha', 'velho', 'grande', 'pequena',
    };
    if (genericWords.contains(lastTwo.split(' ').last)) return null;

    // Heurística final: se o candidato tem ao menos 6 chars total → bairro
    if (lastTwo.replaceAll(' ', '').length >= 6) return lastTwo;
    return null;
  }

  // Haversine estático (não depende do _userLat/_userLon do state)
  double _distKmRaw(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ── Rótulo de distância legível ───────────────────────────────
  String _distLabel(double? lat, double? lon) {
    final km = _distKm(lat, lon);
    if (km == null) return '';
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  // ── Ordena lista por distância do usuário (mais próximo primeiro) ─
  void _sortByProximity(List<_PlaceEntry> list) {
    if (_userLat == null || _userLon == null) return;
    list.sort((a, b) {
      final da = _distKm(a.lat, a.lon) ?? double.infinity;
      final db = _distKm(b.lat, b.lon) ?? double.infinity;
      return da.compareTo(db);
    });
  }

  // ── Handler de seleção: resolve coords via Mapbox /retrieve ─────
  // Se o resultado veio do Mapbox suggest (sem coords reais), chama
  // /retrieve para obter coordenadas precisas antes de navegar.
  // Para resultados Nominatim/local, navega diretamente.
  Future<void> _onSelectPlace(_PlaceEntry place) async {
    // ── Tira o foco do campo PRIMEIRO (evita que o teclado bloqueie o tap) ──
    FocusScope.of(context).unfocus();
    _focusNode.unfocus();

    // Procura se este tile tem uma sugestão Mapbox pendente
    // Match por título+subtítulo (como usamos para criar o tile)
    MapboxSuggestion? pending;
    for (final s in _mapboxPending.values) {
      if (_norm(s.name) == _norm(place.title) &&
          _norm(s.subtitle) == _norm(place.subtitle)) {
        pending = s;
        break;
      }
    }

    if (pending != null) {
      // Mostra loading breve enquanto obtém coords reais
      if (mounted) setState(() => _isSearchingApi = true);

      final result = await MapboxSearchService.retrieve(pending);

      if (mounted) setState(() => _isSearchingApi = false);

      if (result != null && (result.lat != 0 || result.lon != 0)) {
        // Atualiza coordenadas do tile nos resultados exibidos
        // (para _distLabel mostrar distância real se o usuário voltar)
        final idx = _apiResults.indexWhere((e) =>
            _norm(e.title + e.subtitle) == _norm(place.title + place.subtitle));
        if (idx >= 0 && mounted) {
          setState(() {
            _apiResults[idx] = _PlaceEntry(
              icon: _apiResults[idx].icon,
              title: result.title,
              subtitle: result.subtitle,
              dist: _distLabel(result.lat, result.lon),
              zone: _apiResults[idx].zone,
              isApiResult: true,
              lat: result.lat,
              lon: result.lon,
            );
          });
        }
      }
    }

    // ── Salva coords + label no TripSession ──────────────────────
    // SEMPRE salva o label (nome real do destino) para que
    // _fatorGeografico() e destinoLabel usem o nome correto.
    // Se tiver coords, salva completo; se não, só label.
    final finalLat = place.lat;
    final finalLon = place.lon;
    if (finalLat != null && finalLon != null) {
      TripSession.current.setDestination(
        lat: finalLat,
        lon: finalLon,
        label: place.title,
      );
    } else {
      // Sem coords mas com nome — salva só o label
      TripSession.current.destLabel = place.title;
    }

    // Salva também a origem (GPS atual)
    if (_userLat != null && _userLon != null) {
      TripSession.current.setOrigin(lat: _userLat!, lon: _userLon!);
    }

    // Navega independente de termos coords ou não
    widget.onSelectDestination();
  }

  // Ícone por tipo Mapbox (feature_type)
  static IconData _iconForType(String type) {
    switch (type) {
      case 'poi':          return Icons.place_rounded;
      case 'neighborhood': return Icons.location_city_rounded;
      case 'street':       return Icons.signpost_rounded;
      case 'address':      return Icons.home_rounded;
      case 'place':        return Icons.location_city_rounded;
      default:             return Icons.location_on_rounded;
    }
  }

  // Ícone baseado no subtítulo/tipo do POI (Overpass+Photon)
  static IconData _iconForPoi(String subtitle) {
    final s = subtitle.toLowerCase();
    if (s.contains('hospital') || s.contains('clínica') || s.contains('saúde')) return Icons.local_hospital_rounded;
    if (s.contains('policia') || s.contains('delegacia') || s.contains('police')) return Icons.local_police_rounded;
    if (s.contains('bombeiro') || s.contains('fire')) return Icons.local_fire_department_rounded;
    if (s.contains('gasolina') || s.contains('posto') || s.contains('fuel')) return Icons.local_gas_station_rounded;
    if (s.contains('shopping') || s.contains('mall')) return Icons.shopping_bag_rounded;
    if (s.contains('supermercado') || s.contains('mercado')) return Icons.shopping_cart_rounded;
    if (s.contains('farmacia') || s.contains('drogaria')) return Icons.medical_services_rounded;
    if (s.contains('banco') || s.contains('caixa') || s.contains('bank') || s.contains('atm')) return Icons.account_balance_rounded;
    if (s.contains('restaurante') || s.contains('cafe') || s.contains('fast food')) return Icons.restaurant_rounded;
    if (s.contains('hotel') || s.contains('pousada')) return Icons.hotel_rounded;
    if (s.contains('escola') || s.contains('colegio') || s.contains('universidade')) return Icons.school_rounded;
    if (s.contains('aeroporto') || s.contains('airport')) return Icons.flight_rounded;
    if (s.contains('rodoviaria') || s.contains('terminal')) return Icons.directions_bus_rounded;
    if (s.contains('estacionamento') || s.contains('parking')) return Icons.local_parking_rounded;
    return Icons.place_rounded;
  }

  String _norm(String s) => s.toLowerCase()
      .replaceAll('á','a').replaceAll('â','a').replaceAll('ã','a').replaceAll('à','a')
      .replaceAll('é','e').replaceAll('ê','e')
      .replaceAll('í','i').replaceAll('î','i')
      .replaceAll('ó','o').replaceAll('ô','o').replaceAll('õ','o')
      .replaceAll('ú','u').replaceAll('û','u')
      .replaceAll('ç','c');

  /// Lista final unificada, deduplicada.
  /// NÃO reordena por proximidade aqui — a ordenação por relevância
  /// já foi feita em _onQueryChanged (searchCities scoring 6 níveis).
  /// Reordenar por GPS aqui destruiria a capital que veio no topo.
  List<_PlaceEntry> get _allResults {
    final seen = <String>{};
    final out = <_PlaceEntry>[];
    for (final e in [..._localResults, ..._apiResults]) {
      final key = _norm(e.title + e.subtitle);
      if (seen.add(key)) out.add(e);
    }
    return out;
  }

  List<_PlaceEntry> get _recentes => _kFixedPlaces.where((p) => p.isRecent).toList();
  List<_PlaceEntry> get _frequentes => _kFixedPlaces.where((p) => p.isFrequent).toList();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    MapboxSearchService.clearSessionCache(); // limpa cache de suggest da sessão
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    MapboxSearchService.newSession(); // inicia nova sessão de billing
    _userLat = -20.1278;
    _userLon = -40.3072;
    _userUF  = 'ES';
    _gpsReady = false;
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // NÃO força foco automático — o usuário toca no campo quando quiser
      // _focusNode.requestFocus();  ← removido: bloqueava taps nos tiles
      _initGps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // ══ HEADER PREMIUM ═══════════════════════════════════════
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16, topPad + 14, 16, 16),
            child: Column(
              children: [
                // Linha topo: botão voltar + título
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF1A2340)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Nova viagem',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                    const Spacer(),
                    if (_isSearchingApi)
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Card de rota (origem → destino)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E8F0), width: 1.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: [
                      // Origem
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.my_location_rounded,
                              size: 16,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Minha localização',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9AA3B2),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  )),
                                Text('Serra/ES',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A2340),
                                  )),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Divisor com linha tracejada
                      Padding(
                        padding: const EdgeInsets.only(left: 15, top: 6, bottom: 6),
                        child: Row(
                          children: [
                            Column(
                              children: List.generate(3, (i) => Container(
                                width: 1.5, height: 4,
                                margin: const EdgeInsets.only(bottom: 3),
                                color: const Color(0xFFCDD2DE),
                              )),
                            ),
                          ],
                        ),
                      ),

                      // Destino (campo de busca)
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: _isTyping
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isTyping
                                  ? Icons.search_rounded
                                  : Icons.location_on_rounded,
                              size: 16,
                              color: _isTyping
                                  ? AppTheme.primary
                                  : const Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: false,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A2340),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Para onde vai?',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF1A2340).withValues(alpha: 0.35),
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty) widget.onSelectDestination();
                              },
                            ),
                          ),
                          if (_isTyping)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                _focusNode.requestFocus();
                              },
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE4E8F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF6B7280)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ══ LISTA DE RESULTADOS / SUGESTÕES ══════════════════════
          Expanded(
            child: _isTyping ? _buildSearchResults() : _buildDefaultList(),
          ),
        ],
      ),
    );
  }

  // ── Resultados da busca em tempo real ──────────────────────────
  Widget _buildSearchResults() {
    final results = _allResults; // locais + API, deduplicado

    // Spinner enquanto a API ViaCEP está sendo consultada
    if (_isSearchingApi && results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            SizedBox(height: 12),
            Text('Buscando em todo o Brasil…',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      // Estado vazio — nenhum resultado no banco + API
      final suggestions = _kFixedPlaces
          .where((p) => p.isRecent || p.isFrequent)
          .take(3)
          .toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Nenhum resultado para "$_query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tente: bairro, rua, avenida, cidade ou estado (ex: "av paulista SP")',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.tips_and_updates_rounded, size: 13, color: AppTheme.primary),
                    const SizedBox(width: 5),
                    Text('Tente pesquisar por:', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.text)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      'rua', 'avenida', 'bairro', 'praia',
                      'hospital', 'shopping', 'brasília', 'são paulo',
                    ].map((s) => GestureDetector(
                      onTap: () {
                        _controller.text = s;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: s.length));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(s, style: const TextStyle(
                          fontSize: 12, color: AppTheme.primary,
                          fontWeight: FontWeight.w500)),
                      ),
                    )).toList(),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Text('Recentes e frequentes:', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    ...suggestions.map((p) => _PlaceTile(
                      place: p,
                      onTap: () => _onSelectPlace(p),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Lista de resultados com cabeçalho premium ─────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho: contagem + badge GPS
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 10),
          child: Row(
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${results.length}',
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A2340)),
                    ),
                    TextSpan(
                      text: ' resultado${results.length != 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9AA3B2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_gpsReady && _userLat != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded, size: 10, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 3),
                      Text(
                        _userUF != null ? '· $_userUF' : 'próximo',
                        style: const TextStyle(
                          fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (_isSearchingApi)
                Row(children: [
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 5),
                  const Text('buscando…',
                    style: TextStyle(fontSize: 10, color: Color(0xFF9AA3B2))),
                ]),
            ],
          ),
        ),
        // Card agrupado com os resultados
        Flexible(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: results.length,
                  itemBuilder: (ctx, i) {
                    final place = results[i];
                    return _PlaceTile(
                      place: place,
                      query: _query,
                      onTap: () => _onSelectPlace(place),
                      isLast: i == results.length - 1,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Lista padrão: recentes + frequentes (sem query ativa) ────
  Widget _buildDefaultList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Seção Recentes
          _SectionHeader(icon: Icons.access_time_rounded, label: 'Recentes'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                ..._recentes.asMap().entries.map((e) => _PlaceTile(
                  place: e.value,
                  onTap: () => _onSelectPlace(e.value),
                  isLast: e.key == _recentes.length - 1,
                )),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Seção Frequentes
          _SectionHeader(icon: Icons.star_rounded, label: 'Frequentes'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                ..._frequentes.asMap().entries.map((e) => _PlaceTile(
                  place: e.value,
                  onTap: () => _onSelectPlace(e.value),
                  isLast: e.key == _frequentes.length - 1,
                )),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Banner GPS / cobertura
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _gpsReady
                    ? [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)]
                    : [const Color(0xFFE8EEF9), const Color(0xFFEFF3FB)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _gpsReady
                    ? const Color(0xFFA5D6A7)
                    : AppTheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _gpsReady
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                        : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _gpsReady ? Icons.near_me_rounded : Icons.public_rounded,
                    size: 16,
                    color: _gpsReady ? const Color(0xFF2E7D32) : AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _gpsReady
                        ? 'Ordenado por proximidade${_userUF != null ? " · $_userUF" : ""} — 29.866 lugares'
                        : 'Cobertura nacional — 29.866 cidades + ViaCEP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _gpsReady ? const Color(0xFF2E7D32) : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile de lugar PREMIUM ─────────────────────────────────────
class _PlaceTile extends StatelessWidget {
  final _PlaceEntry place;
  final VoidCallback onTap;
  final String? query;
  final bool isLast;

  const _PlaceTile({
    required this.place,
    required this.onTap,
    this.query,
    this.isLast = false,
  });

  // Cor sólida legível para cada zona
  Color get _zoneFg {
    switch (place.zone.label.toLowerCase()) {
      case 'verde': return const Color(0xFF1B6E35);
      case 'amarela': return const Color(0xFF7A5000);
      case 'laranja': return const Color(0xFF8B3000);
      case 'vermelha': return const Color(0xFF8B0000);
      default: return const Color(0xFF1A2340);
    }
  }

  Color get _zoneBg {
    switch (place.zone.label.toLowerCase()) {
      case 'verde': return const Color(0xFFD6F0DF);
      case 'amarela': return const Color(0xFFFFF3C4);
      case 'laranja': return const Color(0xFFFFE0C8);
      case 'vermelha': return const Color(0xFFFFD6D6);
      default: return const Color(0xFFECEFF4);
    }
  }

  Color get _iconBg => _zoneBg;
  Color get _iconColor => _zoneFg;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(
            bottom: BorderSide(color: Color(0xFFF0F2F7), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Ícone com fundo colorido por zona
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(place.icon, color: _iconColor, size: 19),
            ),
            const SizedBox(width: 12),

            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(
                    text: place.title,
                    query: query,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2340),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _HighlightText(
                    text: place.subtitle,
                    query: query,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9AA3B2),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Coluna direita: distância + zona
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge distância
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _zoneBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    place.dist,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _zoneFg,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Label zona
                Text(
                  'Zona ${place.zone.label}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _zoneFg.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Texto com highlight da query
class _HighlightText extends StatelessWidget {
  final String text;
  final String? query;
  final TextStyle style;

  const _HighlightText({required this.text, required this.style, this.query});

  @override
  Widget build(BuildContext context) {
    if (query == null || query!.isEmpty) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query!);
    if (idx == -1) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: [
        TextSpan(text: text.substring(0, idx)),
        TextSpan(
          text: text.substring(idx, idx + query!.length),
          style: style.copyWith(
            color: AppTheme.primary,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(text: text.substring(idx + query!.length)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9AA3B2)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9AA3B2),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// COTAÇÃO — com Risk Engine V1 integrado
// ══════════════════════════════════════════════════════════════
class QuoteScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onActivate;

  const QuoteScreen({super.key, required this.onBack, required this.onActivate});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  // Estado dos seletores
  WeatherCondition _weather = WeatherCondition.chuva;
  RiskZone _zone = RiskZone.amarela;
  TrafficLevel _traffic = TrafficLevel.moderado;
  bool _showBreakdown = false;
  bool _showInsights = false;
  bool _showActuarial = false;

  // ── Detecção automática de tráfego ─────────────────────────────
  TrafficDetectionResult? _trafficResult; // null = ainda detectando
  bool _trafficDetecting = false;         // spinner no badge
  bool _trafficOverridden = false;        // true = usuário escolheu manualmente

  // Rota selecionada pelo usuário
  RouteAlternative? _selectedRoute;

  // Pontuação fixa (será dinâmica em versão futura)
  static const int _score = 750;

  // Veículo selecionado via FIPE (substitui _fipe hardcoded)
  VehicleSelection? _vehicleSel;

  // Getters para retrocompatibilidade com RiskEngine / ActuarialEngine
  double get _fipe => _vehicleSel?.valorFipe ?? 130000.0;
  String get _vehicleModel => _vehicleSel != null
      ? '${_vehicleSel!.marcaNome} ${_vehicleSel!.modeloNome}'
      : 'BYD Atto 2';
  int get _anoModelo => _vehicleSel?.anoModelo ?? 2022;
  int get _idadeVeiculo => _vehicleSel?.idadeVeiculo ?? (DateTime.now().year - 2022);
  double get _franquiaDinamica => _vehicleSel?.franquia ?? 0;

  late RiskBreakdown _result;
  late List<RouteInsight> _insights;
  ActuarialResult? _actuarialResult;       // Motor atuarial V2
  SafeScoreOutput? _safeScoreOutput;       // SafeMap score V1
  AtuarioResult?      _atuarioVirtualResult;   // Atuário Virtual (IA oculta) — V3
  TripInsuranceResult? _tripInsuranceResult;   // Motor de Viagem (IA oculta) — V4 com APIs reais
  bool _showAtuarioVirtual = false;            // expansão do card

  // km real: Haversine entre coords do TripSession (origem GPS → destino escolhido).
  // Se ambas coords disponíveis → distância real.
  // Caso contrário → km da rota selecionada (rotas ES fixas) ou fallback 27.5.
  double get _km {
    final s = TripSession.current;
    if (s.originLat != null && s.originLon != null &&
        s.destLat   != null && s.destLon   != null) {
      return _haversineKm(s.originLat!, s.originLon!, s.destLat!, s.destLon!);
    }
    return _selectedRoute?.km ?? 27.5;
  }

  /// Distância Haversine em km entre dois pontos lat/lon.
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // raio Terra km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    // Fator 1.35 → converte linha reta em distância rodoviária estimada
    return r * c * 1.35;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;

  // Labels dinâmicos — refletem o destino real escolhido pelo usuário
  String get _origemUI  => TripSession.current.originLat != null
      ? 'Minha localização' : 'Serra/ES';
  String get _destinoUI => TripSession.current.destLabel
      ?? (TripSession.current.destLat != null ? 'Destino GPS' : 'Vitória/ES');

  @override
  void initState() {
    super.initState();
    // Inicializa rotas com distância real do TripSession (Haversine)
    // e dados do perfil do motorista para o Motor V3 (AtuárioVirtual).
    final profile = DriverProfileService.instance.profile;
    final theftIdx = _calcTheftIndex(_vehicleModel, _fipe);
    final session  = TripSession.current;
    final routes = ESRouteGenerator.generateAlternatives(
      weather: _weather,
      traffic: _traffic,
      driverScore: _score,
      fipeValue: _fipe,
      kmReal: _km > 28 ? _km : null, // só passa se for destino real (>28km = fora ES local)
      destination: _destinoUI,
      // Dados para Motor V3 — preço atuarial preciso
      cidadeDestino:  session.destLabel ?? 'Vitória',
      idadeCondutor:  profile.idade,
      cnhAnos:        profile.cnhAnos,
      sinistros3Anos: profile.sinistros3Anos,
      multas12Meses:  profile.multas12Meses,
      acidentes3Anos: profile.acidentes3Anos,
      kmMes:          profile.kmMes,
      theftIndex:     theftIdx,
      anoModelo:      _anoModelo,
    );
    _selectedRoute = routes[0]; // Rápida como padrão
    _recalculate();

    // ── Detecção automática de tráfego via OSRM ─────────────────
    // Dispara após o frame para não bloquear a renderização inicial
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectTraffic());

    // ── Motor de Viagem V4 (TripInsuranceEngine) — APIs reais ────
    // Dispara em paralelo: OpenWeather + OSRM + crime + acidentes + FIPE
    // O usuário NÃO vê este processo — só o preço final muda silenciosamente
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTripInsurance());
  }

  /// Detecta tráfego real via OSRM annotations=speed.
  /// Usa coords do TripSession (origem GPS + destino selecionado).
  /// Se não há coords disponíveis, usa fallback (Serra→Vitória ES).
  Future<void> _detectTraffic() async {
    if (!mounted) return;
    setState(() => _trafficDetecting = true);

    try {
      final session = TripSession.current;

      // Usa coords reais se disponíveis, senão fallback Serra→Vitória
      final fromLat = session.originLat ?? -20.1278;
      final fromLon = session.originLon ?? -40.3072;
      final toLat   = session.destLat   ?? -20.3155;
      final toLon   = session.destLon   ?? -40.3128;

      final result = await TrafficDetectionService.detect(
        fromLat: fromLat, fromLon: fromLon,
        toLat: toLat,     toLon: toLon,
      );

      if (!mounted) return;
      setState(() {
        _trafficResult   = result;
        _trafficDetecting = false;
        // Só atualiza o nível se usuário NÃO escolheu manualmente
        if (!_trafficOverridden) {
          _traffic = result.level;
          _recalculate();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _trafficDetecting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MOTOR DE VIAGEM V4  (TripInsuranceEngine — IA OCULTA)
  // Dispara APIs reais em paralelo. Usuário vê apenas o preço final.
  // Roda no background — nunca bloqueia a UI.
  // ═══════════════════════════════════════════════════════════════
  Future<void> _runTripInsurance() async {
    if (!mounted) return;
    try {
      final session = TripSession.current;
      final profile = DriverProfileService.instance.profile;

      // Coordenadas reais do TripSession; fallback Serra→Vitória ES
      final fromLat = session.originLat ?? -20.1278;
      final fromLon = session.originLon ?? -40.3072;
      final toLat   = session.destLat   ?? -20.3155;
      final toLon   = session.destLon   ?? -40.3128;

      // Labels de origem/destino: usa o nome real salvo no TripSession.
      // Crítico para o motor V4 (GPS) e V3 (nome cidade) calcularem
      // o fator geográfico correto (ex: 'São Paulo' → fGeo 3.2×).
      final origemLabel  = session.originLat != null ? 'Origem GPS'                 : 'Serra/ES';
      final destinoLabel = session.destLabel ?? (session.destLat != null ? 'Destino GPS' : 'Vitória/ES');

      final result = await TripInsuranceEngine.calculate(
        fromLat:      fromLat,
        fromLon:      fromLon,
        toLat:        toLat,
        toLon:        toLon,
        origemLabel:  origemLabel,
        destinoLabel: destinoLabel,
        distanciaKm:  _km,
        fipeValor:    _fipe,
        anoModelo:    _anoModelo,
        vehicleModel: _vehicleModel,
        condutor:     profile,
      );

      if (!mounted) return;
      // Atualiza silenciosamente — sem rebuildagem agressiva da tela inteira
      setState(() => _tripInsuranceResult = result);

    } catch (_) {
      // Motor V4 oculto — silencia qualquer erro, nunca quebra a tela principal
    }
  }

  void _recalculate() {
    final zone = _selectedRoute != null
        ? _selectedRoute!.dominantZone
        : _zone;
    final input = RiskInput(
      distanceKm: _km,
      zone: zone,
      departureTime: DateTime.now(), // hora real do sistema
      weather: _weather,
      driverScore: _score,
      traffic: _traffic,
      vehicleFipeValue: _fipe,
      vehicleModel: _vehicleModel,
      planType: 'smart',
      origin: _origemUI,
      destination: _destinoUI,
    );
    _result   = RiskEngine.calculate(input);
    _zone     = zone;
    _insights = RiskEngine.generateInsights(input, _result);

    // Motor Atuarial V2 — agora com dados FIPE reais
    final actuarialInput = ActuarialInput(
      distanceKm: _km,
      departureTime: DateTime.now(), // hora real do sistema
      weather: _weather,
      vehicleModel: _vehicleModel,
      vehicleFipeValue: _fipe,
      anoModelo: _anoModelo,
      idadeVeiculo: _idadeVeiculo,
      marcaFipe: _vehicleSel?.marcaNome ?? 'BYD',
      codigoFipe: _vehicleSel?.codigoFipe ?? '',
      franquiaDinamica: _franquiaDinamica,
      driverAge: 28,
      driverHistory: const DriverHistory(score: _score),
      telemetry: const TelemetryData(score: 950),
      traffic: _traffic,
      planType: 'equilibrado',
    );
    _actuarialResult = ActuarialEngine.calculate(actuarialInput);

    // SafeMap Score V1 — score de rota 0-100
    final safeInput = SafeScoreInput(
      originCity: TripSession.current.originLat != null ? 'Minha localização' : 'Serra',
      destinationCity: TripSession.current.destLabel ?? 'Vitória',
      viaStreets: ['Av. Norte Sul', 'Terceira Ponte', 'Av. Jerônimo Monteiro'],
      vehicleModel: _vehicleModel,
      hour: DateTime.now().hour, // hora real do sistema
      driverAge: 28,
      driverHistoryScore: _score,
      weatherScore: _weather == WeatherCondition.sol ? 0
          : _weather == WeatherCondition.nublado ? 200
          : _weather == WeatherCondition.chuva ? 500
          : _weather == WeatherCondition.temporal ? 800
          : 1000,
      planType: 'equilibrado',
    );
    _safeScoreOutput = SafeScoreEngine.calculate(
      input: safeInput,
      distanceKm: _km,
    );

    // ── ATUÁRIO VIRTUAL (IA OCULTA) — calcula automaticamente ──────
    // Usa todos os dados já disponíveis: FIPE, GPS, hora real, tráfego OSRM
    // Nenhuma tela adicional, nenhum input manual do usuário.
    try {
      final driverProfile = DriverProfileService.instance.profile;
      final session = TripSession.current;
      final theftIndex = _calcTheftIndex(_vehicleModel, _fipe);
      final cepRisk    = _calcCepRisk(session.originLat, session.originLon);

      final atuInput = AtuarioVirtualEngine.buildInputFromContext(
        fipeValor:      _fipe,
        anoModelo:      _anoModelo,
        vehicleModel:   _vehicleModel,
        theftIndex:     theftIndex,
        distanciaKm:    _km,
        kmMes:          driverProfile.kmMes,
        zonaRota:       zone,
        clima:          _weather,
        transito:       _traffic,
        cepRiskScore:   cepRisk,
        // Usa o nome real do destino salvo no TripSession para que
        // _fatorGeografico() calcule corretamente (ex: 'São Paulo' → 3.2×).
        // 'Destino GPS' não casa com nenhuma cidade e retornaria fGeo=1.4×.
        cidadeOrigem:   session.originLat != null ? 'Minha localização' : 'Serra',
        cidadeDestino:  session.destLabel ?? (session.destLat != null ? 'Destino GPS' : 'Vitória'),
        idadeCondutor:  driverProfile.idade,
        cnhAnos:        driverProfile.cnhAnos,
        sinistros3Anos: driverProfile.sinistros3Anos,
        multas12Meses:  driverProfile.multas12Meses,
        acidentes3Anos: driverProfile.acidentes3Anos,
        temGaragem:     false,
        temRastreador:  false,
      );
      _atuarioVirtualResult = AtuarioVirtualEngine.calculate(atuInput);
    } catch (_) {
      // Engine oculta — silencia erros, nunca quebra a tela
    }
  }

  // ── Helpers do Atuário Virtual ─────────────────────────────────────────

  /// Índice de roubo heurístico baseado no modelo/marca (0.0–1.0)
  double _calcTheftIndex(String model, double fipe) {
    final m = model.toLowerCase();
    // Modelos muito visados no ES
    if (m.contains('strada') || m.contains('saveiro') || m.contains('hilux') ||
        m.contains('ranger') || m.contains('s10')) return 0.78;
    if (m.contains('onix') || m.contains('hb20') || m.contains('kwid') ||
        m.contains('gol') || m.contains('argo')) return 0.65;
    if (m.contains('byd') || m.contains('atto') || m.contains('dolphin') ||
        m.contains('seagull')) return 0.45;
    if (m.contains('bmw') || m.contains('mercedes') || m.contains('audi') ||
        m.contains('volvo') || m.contains('land rover')) return 0.72;
    // Por valor FIPE
    if (fipe > 250000) return 0.70;
    if (fipe > 100000) return 0.55;
    if (fipe < 40000)  return 0.30;
    return 0.50; // padrão médio
  }

  /// Score CEP heurístico baseado em coordenadas GPS (0–1000)
  /// Usa coordenadas para inferir região do ES.
  int _calcCepRisk(double? lat, double? lon) {
    if (lat == null || lon == null) return 350; // padrão ES interior
    // Regiões de alto risco no ES (aprox.)
    // Vitória centro / Vila Velha / Cariacica
    if (lat > -20.35 && lat < -20.20 && lon > -40.38 && lon < -40.25) return 650;
    // Serra / Carapina
    if (lat > -20.17 && lat < -20.08 && lon > -40.30 && lon < -40.22) return 480;
    // Praia da Costa / Jardim Camburi
    if (lat > -20.28 && lat < -20.22 && lon > -40.30 && lon < -40.27) return 250;
    // Cariacica / Viana (mais perigoso)
    if (lat > -20.35 && lat < -20.25 && lon > -40.47 && lon < -40.38) return 720;
    return 400; // padrão ES urbano
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Mapa com rotas inteligentes
          Stack(
            children: [
              MapboxRouteMap(
                height: 310,
                // Coords reais do TripSession — mapa mostra rota correta
                origin: TripSession.current.originLat != null
                    ? LatLng(TripSession.current.originLat!, TripSession.current.originLon!)
                    : const LatLng(-20.1286, -40.3073),
                destination: TripSession.current.destLat != null
                    ? LatLng(TripSession.current.destLat!, TripSession.current.destLon!)
                    : const LatLng(-20.3155, -40.3128),
                originLabel: _origemUI,
                destinationLabel: _destinoUI,
                weather: _weather,
                traffic: _traffic,
                driverScore: _score,
                kmReal: _km > 28 ? _km : null,
                destinationName: _destinoUI,
                // Dados para Motor V3 — preço atuarial preciso
                fipeValue:      _fipe,
                anoModelo:      _anoModelo,
                theftIndex:     _calcTheftIndex(_vehicleModel, _fipe),
                cidadeDestino:  TripSession.current.destLabel ?? 'Vitória',
                idadeCondutor:  DriverProfileService.instance.profile.idade,
                cnhAnos:        DriverProfileService.instance.profile.cnhAnos,
                sinistros3Anos: DriverProfileService.instance.profile.sinistros3Anos,
                multas12Meses:  DriverProfileService.instance.profile.multas12Meses,
                acidentes3Anos: DriverProfileService.instance.profile.acidentes3Anos,
                kmMes:          DriverProfileService.instance.profile.kmMes,
                onRouteSelected: (route) {
                  setState(() {
                    _selectedRoute = route;
                    _recalculate();
                  });
                },
              ),
              // Botão voltar
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                child: GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: AppTheme.shadowMd,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: AppTheme.text, size: 17),
                  ),
                ),
              ),
            ],
          ),

          // Banner da rota selecionada
          if (_selectedRoute != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _selectedRoute!.routeColor.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(_selectedRoute!.type.icon, size: 14, color: _selectedRoute!.routeColor),
                  const SizedBox(width: 6),
                  Text(
                    _selectedRoute!.type.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _selectedRoute!.routeColor),
                  ),
                  Text(
                    ' · via ${_selectedRoute!.via}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedRoute!.kmFormatado} · ${_selectedRoute!.timeFormatado}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _selectedRoute!.riskColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

          // Cartão da cotação
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusXl),
                  topRight: Radius.circular(AppTheme.radiusXl),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, -4))],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  children: [
                    // Handle
                    Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 14),

                    // Resumo rota
                    Row(
                      children: [
                        Expanded(child: _routePoint(AppTheme.green, 'Origem', _origemUI)),
                        const Icon(Icons.arrow_forward_rounded, color: AppTheme.textMuted, size: 16),
                        Expanded(child: _routePoint(AppTheme.red, 'Destino', _destinoUI)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stats da rota (dinâmicos)
                    Row(
                      children: [
                        _routeStat(Icons.route_rounded, '${_km.toStringAsFixed(1)} km', 'Distância', false),
                        const SizedBox(width: 8),
                        _routeStat(Icons.access_time_rounded,
                            _selectedRoute?.timeFormatado ?? '35min', 'Estimativa', false),
                        const SizedBox(width: 8),
                        _routeStat(
                          Icons.shield_rounded,
                          _result.nivelRisco,
                          'Risco',
                          true,
                          color: _result.corRisco,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── SELETORES INTERATIVOS (afetam o mapa + preço) ──
                    // Badge "IA" indica que o Atuário Virtual usa este valor
                    _SelectorRow(
                      label: 'Clima',
                      icon: _weather.icon,
                      iconColor: _weather.color,
                      value: _weather.label,
                      multiplier: _weather.multiplier,
                      onTap: () => _showWeatherPicker(),
                      iaBadge: _atuarioVirtualResult != null,
                    ),
                    const SizedBox(height: 8),
                    _SelectorRow(
                      label: 'Zona da Rota',
                      icon: Icons.location_on_rounded,
                      iconColor: _selectedRoute?.riskColor ?? _zone.color,
                      value: _selectedRoute != null
                          ? 'Zona ${_selectedRoute!.dominantZone.label} · ${_selectedRoute!.type.label}'
                          : 'Zona ${_zone.label}',
                      multiplier: _selectedRoute?.dominantZone.multiplier ?? _zone.multiplier,
                      onTap: () => _showZonePicker(),
                      iaBadge: _atuarioVirtualResult != null,
                    ),
                    const SizedBox(height: 8),
                    _TrafficAutoRow(
                      traffic: _traffic,
                      detecting: _trafficDetecting,
                      result: _trafficResult,
                      overridden: _trafficOverridden,
                      onOverrideTap: () => _showTrafficPicker(),
                      onResetAuto: _resetTrafficToAuto,
                    ),

                    const SizedBox(height: 10),

                    // ── SELETOR DE VEÍCULO (FIPE em tempo real) ──────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('VEÍCULO',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted, letterSpacing: 0.06)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_sync_rounded, size: 9, color: AppTheme.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Tabela FIPE ${DateTime.now().year}',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        VehicleDisplayCard(
                          selection: _vehicleSel,
                          onTap: () async {
                            final sel = await VehiclePickerWidget.show(context, current: _vehicleSel);
                            if (sel != null && mounted) {
                              setState(() { _vehicleSel = sel; });
                              _recalculate();
                            }
                          },
                        ),
                        if (_vehicleSel != null) ...[
                          const SizedBox(height: 6),
                          // Mini breakdown FIPE
                          Row(children: [
                            _fipeChip(
                              'Franquia: ${_vehicleSel!.franquiaFormatada}',
                              Icons.shield_outlined,
                              AppTheme.primary,
                            ),
                            const SizedBox(width: 6),
                            _fipeChip(
                              '×${_vehicleSel!.fatorIdade.toStringAsFixed(2)} Risco Veículo',
                              Icons.trending_up_rounded,
                              _vehicleSel!.fatorIdadeColor,
                            ),
                          ]),
                        ],
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── COBERTURAS ──────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COBERTURAS INCLUÍDAS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.06)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: ['Roubo', 'Furto', 'Colisão', 'Terceiros', 'Assist. 24h'].map((c) =>
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: AppTheme.green, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded, color: AppTheme.green, size: 11),
                                  const SizedBox(width: 5),
                                  Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.greenDark)),
                                ],
                              ),
                            )
                          ).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── BREAKDOWN DE PREÇO ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          // Header do breakdown
                          GestureDetector(
                            onTap: () => setState(() => _showBreakdown = !_showBreakdown),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, size: 15, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('COMPOSIÇÃO DO PREÇO',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.04)),
                                  const Spacer(),
                                  Icon(_showBreakdown ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                      size: 18, color: AppTheme.primary),
                                ],
                              ),
                            ),
                          ),

                          if (_showBreakdown) ...[
                            Container(height: 1, color: AppTheme.border),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  _priceRow('${_km.toStringAsFixed(1)} km × R\$ ${_result.tarifaBase.toStringAsFixed(2)}/km',
                                      RiskEngine.formatBRL(_result.baseKm), false),
                                  _priceRow('Zona ${_zone.label} (${RiskEngine.formatMultiplier(_result.fatorRegiao)})',
                                      '+${(((_result.fatorRegiao - 1) * _result.baseKm)).toStringAsFixed(2).replaceAll('.', ',')}', false),
                                  _priceRow('Noite 20h (${RiskEngine.formatMultiplier(_result.fatorHorario)})',
                                      '+${(((_result.fatorHorario - 1) * _result.baseKm * _result.fatorRegiao)).toStringAsFixed(2).replaceAll('.', ',')}', false),
                                  _priceRow('${_weather.label} (${RiskEngine.formatMultiplier(_result.fatorClima)})',
                                      '+${(((_result.fatorClima - 1) * _result.baseKm * _result.fatorRegiao * _result.fatorHorario)).toStringAsFixed(2).replaceAll('.', ',')}', false),
                                  if (_result.fatorMotorista < 1.0)
                                    _priceRow('⭐ Bônus Score $_score (${RiskEngine.formatMultiplier(_result.fatorMotorista)})',
                                        '−R\$ ${((_result.baseKm * _result.fatorRegiao * _result.fatorHorario * _result.fatorKm * _result.fatorClima * (1 - _result.fatorMotorista))).toStringAsFixed(2).replaceAll('.', ',')}', true),
                                ],
                              ),
                            ),
                          ],

                          // Total
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Valor da Proteção',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text)),
                                    Text('Multiplicador total: ${_result.multiplicadorFormatado}',
                                        style: TextStyle(fontSize: 10, color: _result.corRisco)),
                                  ],
                                ),
                                Text(_result.precoFormatado,
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── FRANQUIA ──────────────────────────────────────
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 15, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                children: [
                                  const TextSpan(text: 'Franquia dinâmica: '),
                                  TextSpan(
                                    text: _result.franquiaFormatada,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accent),
                                  ),
                                  TextSpan(
                                    text: ' (base: ${_result.franquiaBaseFormatada})',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ATUÁRIO VIRTUAL — card removido da UI por decisão de produto.
                    // Cálculo interno mantido (usado pelo motor de preço V3).

                    // ── ANÁLISE ATUARIAL V2 ──────────────────────────────
                    if (_actuarialResult != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _showActuarial = !_showActuarial),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.analytics_rounded, size: 15, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Motor Atuarial IA V2',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                            color: Color(0xFF7C3AED))),
                                    Text(
                                      'Risco sinistro: ${_actuarialResult!.probs.fmt(_actuarialResult!.probs.pTotal)} · ${_actuarialResult!.probs.pTotalLabel}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _actuarialResult!.probs.pTotalColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _actuarialResult!.probs.fmt(_actuarialResult!.probs.pTotal),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                                      color: _actuarialResult!.probs.pTotalColor),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(_showActuarial ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  size: 16, color: const Color(0xFF8B5CF6)),
                            ],
                          ),
                        ),
                      ),
                      if (_showActuarial) ...[
                        const SizedBox(height: 8),
                        _ActuarialMiniPanel(result: _actuarialResult!),
                      ],
                    ],

                    // ── SAFE MAP SCORE ────────────────────────────────────
                    if (_safeScoreOutput != null) ...[
                      const SizedBox(height: 10),
                      _SafeScoreWidget(output: _safeScoreOutput!),
                    ],

                    // ── INSIGHTS ────────────────────────────────────────
                    if (_insights.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => setState(() => _showInsights = !_showInsights),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.yellow.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.yellow.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insights_rounded, size: 15, color: AppTheme.yellow),
                              const SizedBox(width: 8),
                              Text('${_insights.length} alertas de risco identificados',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.yellow)),
                              const Spacer(),
                              Icon(_showInsights ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  size: 16, color: AppTheme.yellow),
                            ],
                          ),
                        ),
                      ),
                      if (_showInsights)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: _insights.map((i) => _InsightMini(insight: i)).toList(),
                          ),
                        ),
                    ],

                    const SizedBox(height: 16),
                    PrimaryButton(text: 'Ativar Proteção', icon: Icons.shield_rounded, onTap: widget.onActivate),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded, color: AppTheme.green, size: 13),
                        const SizedBox(width: 6),
                        const Text('Apólice emitida por seguradora autorizada pela SUSEP',
                            style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Seletores (bottom sheets) ──────────────────────────────

  void _showWeatherPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Condição Climática',
        items: WeatherCondition.values.map((w) => _PickerItem(
          icon: w.icon, label: w.label,
          sublabel: RiskEngine.formatMultiplier(w.multiplier),
          color: w.color, selected: _weather == w,
          onTap: () { setState(() { _weather = w; _recalculate(); }); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  void _showZonePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Zona de Risco',
        items: RiskZone.values.map((z) => _PickerItem(
          icon: Icons.location_on_rounded, label: 'Zona ${z.label}',
          sublabel: z.description,
          color: z.color, selected: _zone == z,
          onTap: () { setState(() { _zone = z; _recalculate(); }); Navigator.pop(context); },
        )).toList(),
      ),
    );
  }

  void _showTrafficPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Condição do Trânsito',
        subtitle: _trafficResult != null && _trafficResult!.source == 'osrm'
            ? 'Detectado: ${_trafficResult!.detailLabel}'
            : null,
        items: TrafficLevel.values.map((t) => _PickerItem(
          icon: Icons.traffic_rounded, label: t.label,
          sublabel: RiskEngine.formatMultiplier(t.multiplier),
          color: t.color, selected: _traffic == t,
          onTap: () {
            setState(() {
              _traffic = t;
              _trafficOverridden = true; // marcando override manual
              _recalculate();
            });
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  /// Reseta para detecção automática (botão no badge)
  void _resetTrafficToAuto() {
    if (_trafficResult != null) {
      setState(() {
        _trafficOverridden = false;
        _traffic = _trafficResult!.level;
        _recalculate();
      });
    } else {
      // Re-detecta se ainda não temos resultado
      _detectTraffic();
    }
  }

  // ── Widgets internos ─────────────────────────────────────

  Widget _routePoint(Color dotColor, String label, String value) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text)),
          ],
        ),
      ],
    );
  }

  Widget _routeStat(IconData icon, String value, String label, bool isRisk, {Color? color}) {
    final c = color ?? (isRisk ? AppTheme.yellow : AppTheme.primary);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isRisk ? c : AppTheme.text)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _fipeChip(String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, bool isDiscount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12,
              color: isDiscount ? AppTheme.greenDark : AppTheme.textMuted))),
          Text(value, style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDiscount ? AppTheme.greenDark : AppTheme.textMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Selector Row — clima, zona, tráfego
// ─────────────────────────────────────────────────────────────
class _SelectorRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final double multiplier;
  final VoidCallback onTap;
  final bool iaBadge; // true = mostra badge "IA" (Atuário Virtual usa este valor)

  const _SelectorRow({
    required this.label, required this.value, required this.icon,
    required this.iconColor, required this.multiplier, required this.onTap,
    this.iaBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted)),
                      if (iaBadge) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('IA',
                              style: TextStyle(fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7C3AED))),
                        ),
                      ],
                    ],
                  ),
                  Text(value, style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppTheme.text)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(RiskEngine.formatMultiplier(multiplier),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: iconColor)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 16,
                color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Traffic Auto Row — badge com dado real + override manual
// ─────────────────────────────────────────────────────────────
class _TrafficAutoRow extends StatelessWidget {
  final TrafficLevel traffic;
  final bool detecting;
  final TrafficDetectionResult? result;
  final bool overridden;
  final VoidCallback onOverrideTap;
  final VoidCallback onResetAuto;

  const _TrafficAutoRow({
    required this.traffic,
    required this.detecting,
    required this.result,
    required this.overridden,
    required this.onOverrideTap,
    required this.onResetAuto,
  });

  @override
  Widget build(BuildContext context) {
    final isAuto = result != null && result!.source == 'osrm' && !overridden;
    final emoji  = TrafficDetectionService.emojiFor(traffic);

    return GestureDetector(
      onTap: onOverrideTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isAuto
                ? traffic.color.withValues(alpha: 0.4)
                : AppTheme.border,
            width: isAuto ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Ícone com badge automático
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: traffic.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: detecting
                      ? Padding(
                          padding: const EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: traffic.color),
                        )
                      : Icon(Icons.traffic_rounded, color: traffic.color, size: 15),
                ),
                // Badge AUTO (ponto verde)
                if (isAuto)
                  Positioned(
                    right: -3, top: -3,
                    child: Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface2, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('TRÂNSITO', style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted)),
                      const SizedBox(width: 4),
                      // Badge: AUTO ou MANUAL
                      if (isAuto)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('AUTO', style: TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w700,
                              color: Colors.green)),
                        )
                      else if (overridden)
                        GestureDetector(
                          onTap: onResetAuto,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 8,
                                    color: AppTheme.primary),
                                const SizedBox(width: 2),
                                Text('AUTO', style: TextStyle(
                                    fontSize: 8, fontWeight: FontWeight.w600,
                                    color: AppTheme.primary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detecting
                        ? 'Detectando...'
                        : '$emoji ${traffic.label}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppTheme.text),
                  ),
                  // Dado real (velocidade + fonte) se disponível
                  if (result != null && !detecting)
                    Text(
                      result!.detailLabel,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
            // Multiplicador de preço
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: traffic.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                RiskEngine.formatMultiplier(traffic.multiplier),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: traffic.color),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 16,
                color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Picker Sheet
// ─────────────────────────────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final String title;
  final String? subtitle; // linha extra (ex: dado real de tráfego)
  final List<_PickerItem> items;
  const _PickerSheet({required this.title, required this.items, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text)),
          if (subtitle != null) ...[            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(
                fontSize: 11, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 14),
          ...items,
        ],
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PickerItem({
    required this.icon, required this.label, required this.sublabel,
    required this.color, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.text)),
                  Text(sublabel, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Insight Mini (inline na cotação)
// ─────────────────────────────────────────────────────────────
class _InsightMini extends StatelessWidget {
  final RouteInsight insight;
  const _InsightMini({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: insight.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: insight.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, color: insight.color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: insight.color)),
                Text(insight.suggestion, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CONFIRMAÇÃO (com valores do Risk Engine)
// ══════════════════════════════════════════════════════════════
class ConfirmScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onStart;

  const ConfirmScreen({super.key, required this.onBack, required this.onStart});

  @override
  Widget build(BuildContext context) {
    // Recalcular com o input padrão da demo
    final result = RiskEngine.calculate(RiskInput.demo);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Confirmar Viagem', onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _PulsingShield(),
                  const SizedBox(height: 16),
                  const Text('Tudo pronto!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.text)),
                  const SizedBox(height: 6),
                  const Text('Você está prestes a iniciar uma viagem protegida.',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),

                  // Resumo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: Column(
                      children: [
                        _confirmRow(Icons.location_on_rounded, 'Destino',
                            TripSession.current.destLabel
                            ?? (TripSession.current.destLat != null ? 'Destino GPS' : 'Vitória/ES')),
                        _confirmRow(Icons.route_rounded, 'Distância', '25 km'),
                        _confirmRow(Icons.access_time_rounded, 'Saída', '20:00 · Noite'),
                        _confirmRow(Icons.grain_rounded, 'Clima', 'Chuva'),
                        _confirmRow(Icons.qr_code_rounded, 'Pagamento', 'PIX automático'),
                        _confirmRow(Icons.account_balance_rounded, 'Franquia', result.franquiaFormatada),
                        const Divider(color: AppTheme.border, height: 20),
                        // Multiplicador
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Multiplicador total', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: result.corRisco.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(result.multiplicadorFormatado,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: result.corRisco)),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 16),
                              const SizedBox(width: 6),
                              const Text('Valor', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
                            ]),
                            Text(result.precoFormatado,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Coberturas
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _coveragePill(Icons.shield_rounded, 'Roubo'),
                      _coveragePill(Icons.car_crash_rounded, 'Colisão'),
                      _coveragePill(Icons.people_rounded, 'Terceiros'),
                      _coveragePill(Icons.headset_mic_rounded, '24h'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(text: 'Iniciar Proteção', icon: Icons.play_arrow_rounded, onTap: onStart),
                  const SizedBox(height: 10),
                  GhostButton(text: 'Cancelar', onTap: onBack),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: AppTheme.primary, size: 15),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
          ]),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text)),
        ],
      ),
    );
  }

  Widget _coveragePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 12),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ],
      ),
    );
  }
}

class _PulsingShield extends StatefulWidget {
  @override
  State<_PulsingShield> createState() => _PulsingShieldState();
}

class _PulsingShieldState extends State<_PulsingShield> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryAccentGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 42),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PAINEL ATUARIAL MINI — exibido na QuoteScreen
// ─────────────────────────────────────────────────────────────────

class _ActuarialMiniPanel extends StatelessWidget {
  final ActuarialResult result;
  const _ActuarialMiniPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final commission = CommissionEngine.calculate(r.precoFinal);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Row(
            children: [
              Icon(Icons.security_rounded, size: 13, color: Color(0xFF8B5CF6)),
              SizedBox(width: 5),
              Text('PROBABILIDADES DE SINISTRO (IA)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted, letterSpacing: 0.06)),
            ],
          ),
          const SizedBox(height: 8),

          // Grid de probabilidades
          Row(
            children: [
              _ProbChip('Roubo',     r.probs.pRoubo,    Icons.car_crash_rounded),
              const SizedBox(width: 6),
              _ProbChip('Furto',     r.probs.pFurto,    Icons.no_transfer_rounded),
              const SizedBox(width: 6),
              _ProbChip('Colisão',   r.probs.pColisao,  Icons.merge_rounded),
              const SizedBox(width: 6),
              _ProbChip('Terceiros', r.probs.pTerceiros, Icons.people_rounded),
            ],
          ),

          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFF8B5CF6).withValues(alpha: 0.1)),
          const SizedBox(height: 8),

          // Franquia inteligente
          Row(
            children: [
              const Icon(Icons.shield_moon_rounded, size: 12, color: AppTheme.accent),
              const SizedBox(width: 5),
              Text('Franquia calculada: ',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text(r.franquiaFormatada,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accent)),
              const Spacer(),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: r.riskZone.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(r.nivelRisco,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: r.riskZone.color)),
            ],
          ),

          const SizedBox(height: 6),

          // Divisão de receita compacta
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 5),
              Text('Seguradora: ${commission.seguradoraFmt}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              const SizedBox(width: 8),
              Text('SixTech: ${commission.sixtechFmt}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              const Spacer(),
              Text('Fundo: ${commission.fundoSinistroFmt}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProbChip extends StatelessWidget {
  final String label;
  final double prob;
  final IconData icon;
  const _ProbChip(this.label, this.prob, this.icon);

  Color get _color {
    if (prob < 0.01) return const Color(0xFF22C55E);
    if (prob < 0.05) return const Color(0xFFF59E0B);
    if (prob < 0.10) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _color, size: 14),
            const SizedBox(height: 2),
            Text('${(prob * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _color)),
            Text(label,
                style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFE MAP SCORE WIDGET — exibido na QuoteScreen
// ─────────────────────────────────────────────────────────────────────────────

class _SafeScoreWidget extends StatelessWidget {
  final SafeScoreOutput output;
  const _SafeScoreWidget({required this.output});

  Color get _scoreColor {
    if (output.safeTripScore.score >= 80) return const Color(0xFF22C55E);
    if (output.safeTripScore.score >= 60) return const Color(0xFF84CC16);
    if (output.safeTripScore.score >= 40) return const Color(0xFFF59E0B);
    if (output.safeTripScore.score >= 20) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final cls = SafeScoreClass.fromScore(output.routeRiskScore);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scoreColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, size: 15, color: Color(0xFF00C2A8)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Safe Map Score',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFF00796B))),
                    Text('Rota: ${cls.label} · Score ${output.routeRiskScore}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              // Safe Score badge (0–100)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _scoreColor, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${output.safeTripScore.score}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                            color: _scoreColor)),
                    Text('/100',
                        style: TextStyle(fontSize: 7, color: _scoreColor.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4 sub-scores
          Row(
            children: [
              _SubScore(label: 'Rota', value: output.routeRiskScore, invert: true),
              const SizedBox(width: 4),
              _SubScore(label: 'Veículo', value: output.vehicleRiskScore, invert: true),
              const SizedBox(width: 4),
              _SubScore(label: 'Horário', value: output.timeRiskScore, invert: true),
              const SizedBox(width: 4),
              _SubScore(label: 'Motorista', value: output.driverRiskScore, invert: true),
            ],
          ),
          if (output.saferRoute != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alt_route_rounded, size: 13, color: Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rota mais segura disponível: ${output.saferRoute!.name} '
                      '(+${(output.saferRoute!.distanceKm - output.fasterRoute!.distanceKm).toStringAsFixed(1)} km)',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Top insight
          if (output.insights.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(output.insights.first.icon, size: 12,
                    color: output.insights.first.color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(output.insights.first.body,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SubScore extends StatelessWidget {
  final String label;
  final int value;
  final bool invert;
  const _SubScore({required this.label, required this.value, this.invert = false});

  @override
  Widget build(BuildContext context) {
    // For invert=true: high score = bad (risk scale), show inverted color
    final displayScore = invert ? (1000 - value).clamp(0, 1000) : value;
    final cls = SafeScoreClass.fromScore(invert ? value : (1000 - value).clamp(0, 1000));
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: cls.bgColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            Text('${(displayScore / 10).toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cls.color)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ATUÁRIO VIRTUAL CARD — exibe resultado da IA oculta de forma explicável
// ═══════════════════════════════════════════════════════════════════════════

class _AtuarioVirtualCard extends StatefulWidget {
  final AtuarioResult result;
  final bool expanded;
  final VoidCallback onToggle;
  final TripInsuranceResult? tripResult; // V4 — dados reais das APIs (opcional)

  const _AtuarioVirtualCard({
    required this.result,
    required this.expanded,
    required this.onToggle,
    this.tripResult,
  });

  @override
  State<_AtuarioVirtualCard> createState() => _AtuarioVirtualCardState();
}

class _AtuarioVirtualCardState extends State<_AtuarioVirtualCard> {
  // Painel interno — ativado só por tap longo no corpo expandido.
  // Nenhum botão, nenhum label, nenhuma dica visual para o usuário final.
  bool _showEngenharia = false;

  AtuarioResult get result => widget.result;

  // Helper interno — dot + label de seção (só dentro do card)
  Widget _labelDot(String text, Color color) => Row(children: [
    Container(width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        color: AppTheme.textMuted, letterSpacing: 0.05)),
  ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: result.corClasse.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: result.corClasse.withValues(alpha: 0.30), width: 1.5),
      ),
      child: Column(
        children: [
          // ── Header (sempre visível) ───────────────────────────
          GestureDetector(
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  // Ícone motor
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: result.corClasse.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.psychology_rounded, size: 17,
                        color: result.corClasse),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('ATUÁRIO VIRTUAL',
                                style: TextStyle(fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textMuted,
                                    letterSpacing: 0.05)),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('IA OCULTA',
                                  style: TextStyle(fontSize: 7,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF7C3AED),
                                      letterSpacing: 0.05)),
                            ),
                          ],
                        ),
                        Text(
                          '${result.scoreLabel} · ${result.classeRisco} · ${result.premioViagemFmt}/viagem',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: result.corClasse),
                        ),
                      ],
                    ),
                  ),
                  // Score pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: result.corClasse.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      result.scoreLabel,
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: result.corClasse),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    widget.expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18, color: result.corClasse,
                  ),
                ],
              ),
            ),
          ),

          // ── Corpo expansível ─────────────────────────────────
          if (widget.expanded) ...[
            Container(height: 1, color: result.corClasse.withValues(alpha: 0.15)),
            // tap longo em qualquer ponto do corpo → painel interno
            GestureDetector(
              onLongPress: () => setState(() => _showEngenharia = !_showEngenharia),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AtuarioScoreGauge(result: result),
                    const SizedBox(height: 14),
                    _PremioBreakdownCard(result: result),
                    const SizedBox(height: 14),

                    if (result.aumentam.isNotEmpty) ...[
                      _labelDot('FATORES QUE ELEVAM O RISCO', const Color(0xFFEF4444)),
                      const SizedBox(height: 6),
                      ...result.aumentam.take(4).map((f) => _FatorRow(fator: f)),
                    ],

                    if (result.reduzem.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _labelDot('FATORES QUE REDUZEM O RISCO', const Color(0xFF22C55E)),
                      const SizedBox(height: 6),
                      ...result.reduzem.take(3).map((f) => _FatorRow(fator: f)),
                    ],

                    const SizedBox(height: 12),
                    _ProbRow(probs: result.probs),

                    // ── PAINEL INTERNO ─────────────────────────────────
                    // Visível apenas via tap longo. Sem título visível ao usuário.
                    if (_showEngenharia) ...[
                      const SizedBox(height: 16),
                      _ModoEngenhariaPanel(
                        r: result,
                        tripResult: widget.tripResult,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Score Gauge visual — barra 0–100 com marcação do score atual
// ─────────────────────────────────────────────────────────────
class _AtuarioScoreGauge extends StatelessWidget {
  final AtuarioResult result;
  const _AtuarioScoreGauge({required this.result});

  @override
  Widget build(BuildContext context) {
    final pct = result.scoreAtuarial / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Score Atuarial: ${result.scoreLabel}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: result.corClasse),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: result.corClasse.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result.classeRisco,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: result.corClasse),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Barra gradiente com marcador
        Stack(
          children: [
            // Fundo gradiente
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF22C55E), // verde 0
                    Color(0xFF84CC16), // lima 20
                    Color(0xFFF59E0B), // âmbar 40
                    Color(0xFFF97316), // laranja 60
                    Color(0xFFEF4444), // vermelho 80–100
                  ],
                ),
              ),
            ),
            // Marcador do score
            Positioned(
              left: pct * (MediaQuery.of(context).size.width - 56),
              child: Container(
                width: 14, height: 14,
                margin: const EdgeInsets.only(top: -3),
                decoration: BoxDecoration(
                  color: result.corClasse,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: result.corClasse.withValues(alpha: 0.4),
                        blurRadius: 4)
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Labels dos extremos
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 — Baixo', style: TextStyle(fontSize: 9, color: Color(0xFF22C55E))),
            Text('100 — Crítico', style: TextStyle(fontSize: 9, color: Color(0xFFEF4444))),
          ],
        ),
        const SizedBox(height: 6),
        Text(result.descricaoClasse,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Fórmula atuarial: Risco + Despesas + Reserva + Margem
// ─────────────────────────────────────────────────────────────
class _PremioBreakdownCard extends StatelessWidget {
  final AtuarioResult result;
  const _PremioBreakdownCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final total = result.riscoEsperado +
        result.despesasAdmin +
        result.reservaTecnica +
        result.margemLucro;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_rounded, size: 13, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('FÓRMULA ATUARIAL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted, letterSpacing: 0.05)),
            ],
          ),
          const SizedBox(height: 10),
          _formulaRow(
            'Risco Esperado',
            'P(sinistro) × Custo médio',
            result.riscoEsperado,
            total,
            const Color(0xFFEF4444),
            Icons.warning_amber_rounded,
          ),
          _divider(),
          _formulaRow(
            'Despesas Admin.',
            '12% do prêmio técnico',
            result.despesasAdmin,
            total,
            const Color(0xFFF97316),
            Icons.business_center_rounded,
          ),
          _divider(),
          _formulaRow(
            'Reserva Técnica',
            '10% — margem de segurança',
            result.reservaTecnica,
            total,
            const Color(0xFFF59E0B),
            Icons.savings_rounded,
          ),
          _divider(),
          _formulaRow(
            'Margem de Lucro',
            '8% operacional',
            result.margemLucro,
            total,
            const Color(0xFF84CC16),
            Icons.trending_up_rounded,
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PRÊMIO ANUAL ESTIMADO',
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                    Text('${result.premioPorKmFmt}/km · ${result.premioMensalFmt}/mês',
                        style: const TextStyle(fontSize: 9,
                            color: AppTheme.textMuted)),
                  ],
                ),
                Text(result.premioAnualFmt,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: AppTheme.primary)),
              ],
            ),
          ),
          // Franquia atuarial
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 11,
                  color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text('Franquia calculada: ${result.franquiaFmt}',
                  style: const TextStyle(fontSize: 10,
                      color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formulaRow(String label, String desc, double value,
      double total, Color color, IconData icon) {
    final pct = total > 0 ? (value / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600, color: color)),
                Text(desc, style: const TextStyle(fontSize: 9,
                    color: AppTheme.textLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('R\$ ${value.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: color)),
              // Barra proporcional
              Container(
                width: 40, height: 3,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        height: 1,
        color: AppTheme.border,
      );
}

// ─────────────────────────────────────────────────────────────
// Linha de fator explicável — nome + delta badge + motivo
// ─────────────────────────────────────────────────────────────
class _FatorRow extends StatelessWidget {
  final FatorExplicavel fator;
  const _FatorRow({required this.fator});

  @override
  Widget build(BuildContext context) {
    final isAumenta = fator.tipo == FatorTipo.aumenta;
    final isReduz   = fator.tipo == FatorTipo.reduz;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: fator.cor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: fator.cor.withValues(alpha: 0.18), width: 1),
        ),
        child: Row(
          children: [
            // Ícone
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: fator.cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(fator.icone, size: 13, color: fator.cor),
            ),
            const SizedBox(width: 8),
            // Nome + motivo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fator.nome,
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.text)),
                  Text(fator.motivo,
                      style: const TextStyle(fontSize: 9,
                          color: AppTheme.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Delta badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: fator.cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isAumenta ? '+${fator.pontos.toStringAsFixed(0)}'
                    : isReduz ? '-${fator.pontos.toStringAsFixed(0)}'
                    : '±0',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: fator.cor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Probabilidades de sinistro — chips
// ─────────────────────────────────────────────────────────────
class _ProbRow extends StatelessWidget {
  final ProbSinistro probs;
  const _ProbRow({required this.probs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PROBABILIDADES ANUAIS DE SINISTRO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: AppTheme.textMuted, letterSpacing: 0.05)),
        const SizedBox(height: 6),
        Row(
          children: [
            _probChip('Roubo', probs.pRoubo, const Color(0xFFEF4444)),
            const SizedBox(width: 4),
            _probChip('Furto', probs.pFurto, const Color(0xFFF97316)),
            const SizedBox(width: 4),
            _probChip('Colisão', probs.pColisao, const Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            _probChip('3ºs', probs.pTerceiros, const Color(0xFF3B82F6)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('P(ao menos 1 evento/ano)',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text(probs.fmt(probs.pTotal),
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w800, color: AppTheme.text)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _probChip(String label, double p, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(probs.fmt(p),
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(
                fontSize: 8, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINEL INTERNO DE ENGENHARIA ATUARIAL
//
// Acesso: tap longo no corpo do _AtuarioVirtualCard expandido.
// Visível APENAS internamente. O usuário final nunca sabe que existe.
// Mostra o fluxo completo idêntico ao de uma seguradora profissional:
//   Score Base 100 → multiplicadores → raw → normalização → índice
//   → probabilidades por cobertura → fórmula prêmio → R$ final
// ═══════════════════════════════════════════════════════════════════════════
class _ModoEngenhariaPanel extends StatelessWidget {
  final AtuarioResult r;
  final TripInsuranceResult? tripResult; // V4 — dados reais das APIs (opcional)
  const _ModoEngenhariaPanel({required this.r, this.tripResult});

  @override
  Widget build(BuildContext context) {
    // ── Recalcula multiplicadores individuais para exibição ──────────────
    // (espelha a lógica do AtuarioVirtualEngine sem duplicar estado)
    final scoreRaw  = r.scoreAtuarial;                     // 0–100 já calculado
    final scoreNorm = scoreRaw;                            // score já normalizado
    final idxRisco  = (scoreNorm / 100 * 3.0).clamp(0, 3.0); // 0–3.0 índice

    // Componentes do prêmio
    final risco    = r.riscoEsperado;
    final despesas = r.despesasAdmin;
    final reserva  = r.reservaTecnica;
    final margem   = r.margemLucro;
    final total    = risco + despesas + reserva + margem;

    // Probabilidades
    final p = r.probs;

    return Container(
      decoration: BoxDecoration(
        // Visual monocromático tipo terminal — propositalmente sem cor
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── CABEÇALHO INTERNO ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const Text('MOTOR ATUARIAL',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B), letterSpacing: 0.08)),
                const SizedBox(width: 6),
                // Badge que indica se dados reais de API estão disponíveis
                if (tripResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('V4 LIVE',
                        style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800,
                            color: Color(0xFF22C55E), letterSpacing: 0.06)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('V3 HEUR',
                        style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                            color: Color(0xFF475569), letterSpacing: 0.06)),
                  ),
                const Spacer(),
                Text(
                  '${tripResult != null ? 'v4.0' : 'v3.1'} · ${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 8, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
          _divLine(),

          // ── BLOCO 1: ENTRADA ────────────────────────────────────────────
          _block(
            label: '01  ENTRADA',
            children: [
              _row2('Origem → Destino', '${r.origemLabel} → ${r.destinoLabel}'),
              _row2('Distância', '${r.distanciaKm.toStringAsFixed(1)} km'),
              _row2('Horário', '${DateTime.now().hour.toString().padLeft(2,'0')}h${DateTime.now().minute.toString().padLeft(2,'0')}'),
              _row2('Calculado em', _fmtDt(r.calculadoEm)),
            ],
          ),
          _divLine(),

          // ── BLOCO 2: MULTIPLICADORES ────────────────────────────────────
          _block(
            label: '02  MULTIPLICADORES  (Score Base = 100)',
            children: [
              // Extrai os fatores individuais do resultado para montar tabela
              ..._buildMultTable(r),
              _divDash(),
              _rowCalc('Score Raw',
                  '${(scoreRaw * 10).toStringAsFixed(0)}',
                  const Color(0xFFF59E0B)),
              _rowCalc('Normaliz. (÷10)',
                  scoreNorm.toStringAsFixed(1),
                  const Color(0xFF94A3B8)),
              _rowCalc('Índice de Risco',
                  '${idxRisco.toStringAsFixed(2)} / 3.0',
                  _colorScore(scoreNorm), bold: true),
              _rowCalc('Classe',
                  r.classeRisco.toUpperCase(),
                  r.corClasse, bold: true),
            ],
          ),
          _divLine(),

          // ── BLOCO 3: PROBABILIDADES ─────────────────────────────────────
          _block(
            label: '03  PROBABILIDADES ATUARIAIS  (% ao ano)',
            children: [
              _row2Colored('Colisão',       p.fmt(p.pColisao),   const Color(0xFFF59E0B)),
              _row2Colored('Roubo',         p.fmt(p.pRoubo),     const Color(0xFFEF4444)),
              _row2Colored('Furto',         p.fmt(p.pFurto),     const Color(0xFFF97316)),
              _row2Colored('Danos a 3ºs',   p.fmt(p.pTerceiros), const Color(0xFF3B82F6)),
              _divDash(),
              _row2Colored('P(ao menos 1)', p.fmt(p.pTotal),     const Color(0xFFE2E8F0), bold: true),
              _divDash(),
              _row2Colored('Custo Esperado', p.fmtBRL(p.custoMedioEsperado), const Color(0xFFE2E8F0)),
            ],
          ),
          _divLine(),

          // ── BLOCO 4: FÓRMULA DO PRÊMIO ──────────────────────────────────
          _block(
            label: '04  FÓRMULA  Prêmio = P×Sev + Op + Res + Luc',
            children: [
              _fmlaRow('Risco Esperado',   'P(sinistro) × Custo médio',      risco,    const Color(0xFFEF4444)),
              _fmlaRow('Operação (12%)',    '12% do prêmio técnico',          despesas, const Color(0xFFF97316)),
              _fmlaRow('Reserva Téc (10%)','10% — margem de segurança',       reserva,  const Color(0xFFF59E0B)),
              _fmlaRow('Margem (8%)',       '8% lucro operacional',           margem,   const Color(0xFF84CC16)),
              _divDash(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PRÊMIO ANUAL TOTAL',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                            color: Color(0xFFE2E8F0), letterSpacing: 0.04)),
                    Text('R\$ ${total.toStringAsFixed(2).replaceAll('.',',')}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                            color: Color(0xFF38BDF8))),
                  ],
                ),
              ),
              _row2Colored('Prêmio/viagem',  r.premioViagemFmt,  const Color(0xFF38BDF8), bold: true),
              _row2Colored('Prêmio/mês',     r.premioMensalFmt,  const Color(0xFF94A3B8)),
              _row2Colored('Prêmio/km',      r.premioPorKmFmt,   const Color(0xFF94A3B8)),
              _row2Colored('Franquia',        r.franquiaFmt,      const Color(0xFF64748B)),
            ],
          ),
          _divLine(),

          // ── BLOCO 5: SAÍDA JSON (como uma seguradora real retornaria) ──
          _block(
            label: '05  OUTPUT  (formato API interna)',
            children: [
              if (tripResult != null) ...[
                // JSON com dados reais do V4
                _jsonLine('{'),
                _jsonLine('  "engine": "trip_insurance_v4",'),
                _jsonLine('  "rota": "${tripResult!.origem} → ${tripResult!.destino}",'),
                _jsonLine('  "distancia_km": ${tripResult!.distanciaKm.toStringAsFixed(1)},'),
                _jsonLine('  "score_risco": ${tripResult!.scoreNormalizado.toStringAsFixed(1)},'),
                _jsonLine('  "nivel": "${tripResult!.nivelRisco}",'),
                _jsonLine('  "prob_colisao": ${(tripResult!.probs.colisao * 100).toStringAsFixed(2)},'),
                _jsonLine('  "prob_roubo": ${(tripResult!.probs.roubo * 100).toStringAsFixed(2)},'),
                _jsonLine('  "prob_furto": ${(tripResult!.probs.furto * 100).toStringAsFixed(2)},'),
                _jsonLine('  "prob_total_viagem": ${(tripResult!.probs.pTotal * 100).toStringAsFixed(4)},'),
                _jsonLine('  "custo_esperado": ${tripResult!.probs.custoEsperadoViagem.toStringAsFixed(2)},'),
                _jsonLine('  "premio_viagem": ${tripResult!.premioViagem.toStringAsFixed(2)},'),
                _jsonLine('  "premio_anual": ${tripResult!.premioAnual.toStringAsFixed(2)},'),
                _jsonLine('  "premio_mensal": ${tripResult!.premioMensal.toStringAsFixed(2)},'),
                _jsonLine('  "franquia": ${tripResult!.franquia.toStringAsFixed(2)},'),
                _jsonLine('  "fatores": {'),
                _jsonLine('    "clima": ${tripResult!.fatorClima.factor.toStringAsFixed(2)},'),
                _jsonLine('    "transito": ${tripResult!.fatorTransito.factor.toStringAsFixed(2)},'),
                _jsonLine('    "crime": ${tripResult!.fatorCrime.factor.toStringAsFixed(2)},'),
                _jsonLine('    "acidentes": ${tripResult!.fatorAcidentes.factor.toStringAsFixed(2)},'),
                _jsonLine('    "veiculo": ${tripResult!.fatorVeiculo.factor.toStringAsFixed(2)},'),
                _jsonLine('    "condutor": ${tripResult!.fatorCondutor.factor.toStringAsFixed(2)}'),
                _jsonLine('  }'),
                _jsonLine('}'),
              ] else ...[
                // JSON com dados do motor V3 (heurístico)
                _jsonLine('{'),
                _jsonLine('  "engine": "atuario_virtual_v3",'),
                _jsonLine('  "rota": "${r.origemLabel} → ${r.destinoLabel}",'),
                _jsonLine('  "score_risco": ${scoreNorm.toStringAsFixed(1)},'),
                _jsonLine('  "nivel": "${r.classeRisco.toLowerCase()}",'),
                _jsonLine('  "prob_roubo": ${(p.pRoubo * 100).toStringAsFixed(1)},'),
                _jsonLine('  "prob_colisao": ${(p.pColisao * 100).toStringAsFixed(1)},'),
                _jsonLine('  "prob_total": ${(p.pTotal * 100).toStringAsFixed(1)},'),
                _jsonLine('  "custo_esperado": ${p.custoMedioEsperado.toStringAsFixed(2)},'),
                _jsonLine('  "premio_viagem": ${r.premioViagem.toStringAsFixed(2)},'),
                _jsonLine('  "premio_anual": ${r.premioAnual.toStringAsFixed(2)},'),
                _jsonLine('  "franquia": ${r.franquia.toStringAsFixed(2)}'),
                _jsonLine('}'),
              ],
            ],
          ),

          // ── BLOCO 6: FONTES V4 — APIs REAIS (só quando TripInsuranceResult disponível) ──
          if (tripResult != null) ...[
            _divLine(),
            _block(
              label: '06  FONTES V4  (APIs reais em paralelo)',
              children: [
                _apiSourceRow(
                  fonte: 'CLIMA',
                  source: tripResult!.fatorClima.source,
                  label: tripResult!.fatorClima.label,
                  factor: tripResult!.fatorClima.factorFmt,
                  isLive: tripResult!.fatorClima.isLive,
                ),
                _apiSourceRow(
                  fonte: 'TRÂNSITO',
                  source: tripResult!.fatorTransito.source,
                  label: tripResult!.fatorTransito.label,
                  factor: tripResult!.fatorTransito.factorFmt,
                  isLive: tripResult!.fatorTransito.isLive,
                ),
                _apiSourceRow(
                  fonte: 'CRIME',
                  source: tripResult!.fatorCrime.source,
                  label: tripResult!.fatorCrime.label,
                  factor: tripResult!.fatorCrime.factorFmt,
                  isLive: tripResult!.fatorCrime.isLive,
                ),
                _apiSourceRow(
                  fonte: 'ACIDENTES',
                  source: tripResult!.fatorAcidentes.source,
                  label: tripResult!.fatorAcidentes.label,
                  factor: tripResult!.fatorAcidentes.factorFmt,
                  isLive: tripResult!.fatorAcidentes.isLive,
                ),
                _apiSourceRow(
                  fonte: 'VEÍCULO',
                  source: tripResult!.fatorVeiculo.source,
                  label: tripResult!.fatorVeiculo.label,
                  factor: tripResult!.fatorVeiculo.factorFmt,
                  isLive: tripResult!.fatorVeiculo.isLive,
                ),
                _apiSourceRow(
                  fonte: 'CONDUTOR',
                  source: tripResult!.fatorCondutor.source,
                  label: tripResult!.fatorCondutor.label,
                  factor: tripResult!.fatorCondutor.factorFmt,
                  isLive: tripResult!.fatorCondutor.isLive,
                ),
                _divDash(),
                // Segmentos de rota
                if (tripResult!.segmentos.isNotEmpty) ...[
                  _row2('Segmentos da rota', '${tripResult!.segmentos.length} trechos'),
                  ...tripResult!.segmentos.map((s) =>
                    _row2Colored(
                      '  ${s.nome}',
                      '${(s.kmShare * 100).toStringAsFixed(0)}% · ×${(s.crimeFactor * s.accidentFactor).toStringAsFixed(2)}',
                      const Color(0xFF64748B),
                    ),
                  ),
                  _divDash(),
                ],
                // Comparativo V4 vs V3
                _row2Colored('Score V4 (APIs)',     tripResult!.scoreLabel,        const Color(0xFF38BDF8), bold: true),
                _row2Colored('Score V3 (heur.)',    r.scoreLabel,                  const Color(0xFF64748B)),
                _row2Colored('Prêmio V4/viagem',   tripResult!.premioViagemFmt,   const Color(0xFF22C55E), bold: true),
                _row2Colored('Prêmio V3/viagem',   r.premioViagemFmt,             const Color(0xFF475569)),
              ],
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Monta tabela de multiplicadores a partir dos fatores ──────────────
  static List<Widget> _buildMultTable(AtuarioResult r) {
    final all = r.fatores;
    if (all.isEmpty) return [_row2Colored('(sem fatores)', '—', const Color(0xFF475569))];
    return all.take(8).map((f) {
      final sinal = f.tipo == FatorTipo.aumenta ? '+' : f.tipo == FatorTipo.reduz ? '−' : '±';
      final cor   = f.tipo == FatorTipo.aumenta
          ? const Color(0xFFF87171)
          : f.tipo == FatorTipo.reduz
              ? const Color(0xFF4ADE80)
              : const Color(0xFF94A3B8);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(f.nome,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('$sinal${f.pontos.toStringAsFixed(0)} pts',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: cor)),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ── Constrói string de multiplicadores para exibição ──────────────────
  static String _multStr(AtuarioResult r) {
    final mults = r.fatores.take(4).map((f) {
      final v = f.tipo == FatorTipo.aumenta
          ? 1 + f.pontos / 100
          : f.tipo == FatorTipo.reduz
              ? 1 - f.pontos / 100
              : 1.0;
      return v.toStringAsFixed(2);
    }).join(' × ');
    return mults.isEmpty ? '...' : '$mults × ...';
  }

  // ── Helpers de layout ─────────────────────────────────────────────────
  static Widget _block({required String label, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                  color: Color(0xFF475569), letterSpacing: 0.06)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  static Widget _divLine() =>
      Container(height: 1, color: const Color(0xFF1E293B));

  static Widget _divDash() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: List.generate(30,
        (_) => Expanded(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: 1, color: const Color(0xFF1E293B))))),
  );

  static Widget _row2(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        Text(v, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
            color: Color(0xFFCBD5E1))),
      ],
    ),
  );

  static Widget _row2Colored(String k, String v, Color vc,
      {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            Text(v,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: vc)),
          ],
        ),
      );

  static Widget _rowCalc(String label, String value, Color vc,
      {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(
                  fontSize: 9, color: Color(0xFF64748B)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(value,
                style: TextStyle(fontSize: 9,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: vc)),
          ],
        ),
      );

  static Widget _fmlaRow(
      String label, String desc, double val, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 3, height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                  Text(desc, style: const TextStyle(
                      fontSize: 8, color: Color(0xFF475569))),
                ],
              ),
            ),
            Text('R\$ ${val.toStringAsFixed(2).replaceAll('.',',')}',
                style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );

  static Widget _jsonLine(String line) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 0.5),
    child: Text(line,
        style: const TextStyle(
            fontSize: 8,
            fontFamily: 'monospace',
            color: Color(0xFF475569),
            height: 1.5)),
  );

  // ── Linha de fonte de API (Bloco 06) ─────────────────────────────────
  static Widget _apiSourceRow({
    required String fonte,
    required String source,
    required String label,
    required String factor,
    required bool isLive,
  }) {
    final liveColor  = isLive ? const Color(0xFF22C55E) : const Color(0xFF475569);
    final liveLabel  = isLive ? 'LIVE' : 'HEUR';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          // Badge fonte
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(fonte,
                style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B), letterSpacing: 0.04)),
          ),
          const SizedBox(width: 4),
          // Badge LIVE/HEUR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: liveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(liveLabel,
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800,
                    color: liveColor, letterSpacing: 0.04)),
          ),
          const SizedBox(width: 6),
          // Label da API
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Fator multiplicador
          Text(factor,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: Color(0xFF38BDF8))),
        ],
      ),
    );
  }

  static Color _colorScore(double s) {
    if (s <= 20) return const Color(0xFF4ADE80);
    if (s <= 40) return const Color(0xFFA3E635);
    if (s <= 60) return const Color(0xFFFBBF24);
    if (s <= 80) return const Color(0xFFFB923C);
    return const Color(0xFFF87171);
  }

  static String _fmtDt(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')}/'
      '${dt.month.toString().padLeft(2,'0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2,'0')}:'
      '${dt.minute.toString().padLeft(2,'0')}:'
      '${dt.second.toString().padLeft(2,'0')}';
}

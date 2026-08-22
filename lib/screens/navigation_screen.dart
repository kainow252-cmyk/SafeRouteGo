// ═══════════════════════════════════════════════════════════════
// SAFEROUTE — NAVEGAÇÃO GPS REAL (Waze/Google Maps style)
// Leaflet.js 1.9.4 + OSRM + Geolocation API real
// Blob URL iframe (permite fetch externo, sem sandbox implícito)
// ═══════════════════════════════════════════════════════════════

// ignore_for_file: prefer_single_quotes
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';
import '../services/route_actuarial_service.dart';

import 'navigation_map_stub.dart'
    if (dart.library.html) 'navigation_map_web.dart';

class NavigationScreen extends StatefulWidget {
  final RouteActuarialResult selectedRoute;
  final String origin;
  final String destination;
  final double? originLat;
  final double? originLon;
  final double? destLat;
  final double? destLon;
  final VoidCallback onBack;
  final VoidCallback onEnd;

  const NavigationScreen({
    super.key,
    required this.selectedRoute,
    required this.origin,
    required this.destination,
    this.originLat,
    this.originLon,
    this.destLat,
    this.destLon,
    required this.onBack,
    required this.onEnd,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {

  // ── Estado da navegação ──────────────────────────────────────
  // ignore: unused_field
  final bool _tripStarted = true;  // auto-start: sempre true
  double _speedKmh       = 0;
  double _progressKm     = 0;
  double _remainKm       = 0;
  int    _etaMinutes     = 0;
  int    _elapsedSec     = 0;
  double _totalCost      = 0;
  bool   _arrived        = false;
  String _currentStreet  = 'Carregando rota...';
  String _nextInstruction= 'Aguardando GPS...';
  String _nextStreet     = '';
  int    _nextDistM      = 0;
  String _speedLimit     = '40';
  bool   _overSpeed      = false;
  String _riskZoneLabel  = 'Verde';
  Color  _riskZoneColor  = const Color(0xFF22C55E);
  String _arrivalTime    = '--:--';
  // ignore: unused_field
  bool   _mapReady       = false;

  // Steps reais recebidos do JS via postMessage
  final List<Map<String, dynamic>> _osrmSteps = [];

  Timer? _navTimer;

  // ── Animações ─────────────────────────────────────────────────
  late AnimationController _arrowBounce;
  late AnimationController _speedPulse;
  late AnimationController _dotPulse;
  late Animation<double>   _arrowAnim;
  late Animation<double>   _speedAnim;
  late Animation<double>   _dotAnim;

  // ── Mapa ──────────────────────────────────────────────────────
  final String _mapViewId = 'nav-map-${DateTime.now().millisecondsSinceEpoch}';
  bool _mapRegistered = false;

  @override
  void initState() {
    super.initState();

    _remainKm   = widget.selectedRoute.distanceKm;
    _etaMinutes = widget.selectedRoute.estimatedMinutes;
    _updateArrivalTime();

    _arrowBounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _speedPulse  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _dotPulse    = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _arrowAnim = Tween<double>(begin: 0, end: 7).animate(
        CurvedAnimation(parent: _arrowBounce, curve: Curves.easeInOut));
    _speedAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(parent: _speedPulse, curve: Curves.easeInOut));
    _dotAnim   = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _dotPulse, curve: Curves.easeInOut));

    // ← Auto-start: inicia navegação imediatamente ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMap();
      _startNavigation(); // inicia timer de progresso automaticamente
    });
  }

  void _initMap() {
    if (!kIsWeb || _mapRegistered) return;
    _mapRegistered = true;
    registerMapView(_mapViewId, _buildLeafletHtml(autoStart: true)); // ← sempre auto-start
    if (mounted) setState(() {});
  }

  void _updateArrivalTime() {
    final now = DateTime.now();
    final arr = now.add(Duration(minutes: _etaMinutes));
    _arrivalTime = '${arr.hour.toString().padLeft(2, '0')}:${arr.minute.toString().padLeft(2, '0')}';
  }

  void _startNavigation() {
    _navTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _arrived) return;

      final rng = math.Random();
      setState(() {
        _elapsedSec++;

        // Velocidade realista urbana (suavizada)
        final limit = double.tryParse(_speedLimit) ?? 40;
        final targetSpeed = (limit * 0.55) + rng.nextDouble() * (limit * 0.55);
        _speedKmh = (_speedKmh * 0.80 + targetSpeed * 0.20).clamp(0, 95);
        _overSpeed = _speedKmh > limit + 5;

        // Progresso baseado na velocidade real
        final kmPerSec = _speedKmh / 3600;
        _progressKm += kmPerSec;
        _remainKm = (widget.selectedRoute.distanceKm - _progressKm).clamp(0, double.infinity);

        // ETA dinâmico
        if (_speedKmh > 1) {
          _etaMinutes = (_remainKm / (_speedKmh / 60)).round().clamp(0, 999);
        }
        _updateArrivalTime();

        // Custo UBI acumulado — somente após iniciar
        _totalCost = widget.selectedRoute.finalKmPrice * _progressKm;

        // Atualiza instrução e rua baseado no progresso
        _updateInstruction();

        // Chegada
        if (_remainKm <= 0.05) {
          _arrived = true;
          _speedKmh = 0;
          t.cancel();
        }
      });
    });
  }

  // ── Chamado via postMessage do JS com step real do OSRM ────────
  void _onOsrmStep(Map<String, dynamic> step) {
    if (!mounted) return;
    setState(() {
      _currentStreet   = step['name'] as String? ?? _currentStreet;
      _nextInstruction = step['instruction'] as String? ?? _nextInstruction;
      _nextStreet      = step['nextName'] as String? ?? '';
      _nextDistM       = (step['distance'] as num?)?.toInt() ?? 0;
      // Infere limite a partir do tipo de manobra / nome da via
      final n = (_currentStreet).toLowerCase();
      if (n.contains('br-') || n.contains('es-') || n.contains('rodovia')) {
        _speedLimit = '80';
        _setZone('Laranja', const Color(0xFF9A3412));
      } else if (n.contains('av.') || n.contains('avenida')) {
        _speedLimit = '60';
        _setZone('Amarela', const Color(0xFF92400E));
      } else {
        _speedLimit = '40';
        _setZone('Verde', const Color(0xFF22C55E));
      }
    });
  }

  // ── Fallback de instrução (somente enquanto OSRM não responder) ──
  void _updateInstruction() {
    // Só usa fallback se ainda não recebeu steps reais do OSRM
    if (_osrmSteps.isNotEmpty) return;
    final pct = (_progressKm / math.max(0.001, widget.selectedRoute.distanceKm)).clamp(0.0, 1.0);
    if (pct >= 0.95) {
      _currentStreet   = widget.destination;
      _nextInstruction = 'Você chegou ao destino!';
      _nextStreet      = '';
      _nextDistM       = 0;
      _speedLimit      = '30';
      _setZone('Verde', const Color(0xFF22C55E));
    }
  }

  void _setZone(String label, Color color) {
    _riskZoneLabel = label;
    _riskZoneColor = color;
  }

  // ══════════════════════════════════════════════════════════════
  // HTML DO MAPA — Leaflet.js 1.9.4 + OSRM REAL + Geolocation
  // Blob URL garante que fetch() para OSRM e OSM funcione
  // ══════════════════════════════════════════════════════════════
  String _buildLeafletHtml({bool autoStart = false}) {
    final wp = widget.selectedRoute.waypoints;
    final startLat = widget.originLat ?? (wp.isNotEmpty ? wp.first['lat']! : -20.1281);
    final startLon = widget.originLon ?? (wp.isNotEmpty ? wp.first['lon']! : -40.3086);
    final endLat   = widget.destLat   ?? (wp.isNotEmpty ? wp.last['lat']!  : -20.3155);
    final endLon   = widget.destLon   ?? (wp.isNotEmpty ? wp.last['lon']!  : -40.3128);

    final routeColor = widget.selectedRoute.type == RouteType.segura    ? '#22C55E'
                     : widget.selectedRoute.type == RouteType.rapida    ? '#F97316'
                     : '#3B82F6';

    final routeColorLight = widget.selectedRoute.type == RouteType.segura    ? '#22C55E30'
                          : widget.selectedRoute.type == RouteType.rapida    ? '#F9731630'
                          : '#3B82F630';

    final origin      = widget.origin.replaceAll("'", "\\'");
    final destination = widget.destination.replaceAll("'", "\\'");

    return '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"/>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin=""/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:100%; height:100%; overflow:hidden; }
#map { width:100%; height:100%; background:#e8e0d0; }

/* Estilo do mapa estilo Waze/Google */
.leaflet-tile-pane { filter: saturate(1.1) brightness(1.02); }
.leaflet-control-zoom {
  border:none!important; border-radius:10px!important;
  box-shadow:0 2px 12px rgba(0,0,0,.18)!important;
  margin-right:10px!important; margin-bottom:10px!important;
}
.leaflet-control-zoom a {
  width:34px!important; height:34px!important; line-height:34px!important;
  border:none!important; border-radius:8px!important;
  color:#1A56DB!important; font-size:17px!important;
  font-weight:700!important; background:white!important;
}
.leaflet-control-zoom a:hover { background:#f0f4ff!important; }
.leaflet-control-attribution { display:none; }

/* Marcador de posição pulsante */
.pos-dot {
  width:20px; height:20px; border-radius:50%;
  background:$routeColor;
  border:3px solid white;
  box-shadow:0 0 0 0 ${routeColor}50;
  animation:posGlow 2s ease-in-out infinite;
  position:relative;
}
.pos-dot::after {
  content:'';
  position:absolute; top:-8px; left:-8px;
  width:36px; height:36px; border-radius:50%;
  background:${routeColor}25;
  animation:posRing 2s ease-in-out infinite;
}
@keyframes posGlow {
  0%,100% { box-shadow:0 0 0 4px ${routeColor}30, 0 2px 8px rgba(0,0,0,.35); }
  50%      { box-shadow:0 0 0 10px ${routeColor}08, 0 2px 8px rgba(0,0,0,.35); }
}
@keyframes posRing {
  0%,100% { transform:scale(1); opacity:0.5; }
  50%      { transform:scale(1.3); opacity:0.1; }
}

/* Marcador de destino */
.dest-pin {
  width:0; height:0;
  border-left:10px solid transparent;
  border-right:10px solid transparent;
  border-top:20px solid #EF4444;
  position:relative;
  filter:drop-shadow(0 2px 4px rgba(0,0,0,.4));
}
.dest-pin::after {
  content:'🏁';
  position:absolute;
  top:-22px; left:-8px;
  font-size:16px;
}

/* Badge loading */
#loadingBadge {
  position:absolute; top:50%; left:50%;
  transform:translate(-50%,-50%);
  background:rgba(10,20,60,.88);
  color:white; padding:14px 22px;
  border-radius:14px; text-align:center;
  font-family:'Segoe UI',sans-serif; font-size:13px;
  z-index:9999; backdrop-filter:blur(4px);
  border:1px solid rgba(255,255,255,.15);
}
#loadingBadge b { font-size:15px; display:block; margin-bottom:6px; color:#60A5FA; }
#loadingBar {
  width:180px; height:4px; background:rgba(255,255,255,.2);
  border-radius:2px; margin:10px auto 0;
  overflow:hidden;
}
#loadingBarFill {
  height:4px; background:$routeColor;
  border-radius:2px; width:0%;
  transition:width .4s ease;
}

/* Tooltip de instrução flutuante sobre o mapa */
#instrBox {
  position:absolute; bottom:12px; left:50%;
  transform:translateX(-50%);
  background:rgba(13,27,75,.92); color:white;
  padding:8px 14px; border-radius:10px;
  font-family:'Segoe UI',sans-serif; font-size:12px;
  z-index:800; pointer-events:none; white-space:nowrap;
  max-width:90%; overflow:hidden; text-overflow:ellipsis;
  backdrop-filter:blur(4px);
  box-shadow:0 4px 16px rgba(0,0,0,.35);
  border:1px solid rgba(255,255,255,.12);
  display:none;
}
</style>
</head>
<body>

<div id="map"></div>

<!-- Overlay aguardando iniciar -->
<div id="waitingOverlay" style="display:none; position:absolute; top:0; left:0; right:0; bottom:0;
  background:rgba(10,20,60,0.72); z-index:9000; align-items:center; justify-content:center;
  flex-direction:column; gap:14px; backdrop-filter:blur(2px);">
  <div style="background:white; border-radius:18px; padding:22px 28px; text-align:center;
    box-shadow:0 8px 32px rgba(0,0,0,0.35); max-width:240px;">
    <div style="font-size:32px; margin-bottom:8px;">🚗</div>
    <div style="font-size:15px; font-weight:800; color:#0D1B4B; margin-bottom:4px;">Rota pronta!</div>
    <div style="font-size:12px; color:#6B7280; margin-bottom:0;">Toque <b style="color:#22C55E">INICIAR VIAGEM</b> para começar a navegação</div>
  </div>
</div>

<div id="loadingBadge">
  <b>📡 Carregando rota real</b>
  Conectando ao servidor OSRM...
  <div id="loadingBar"><div id="loadingBarFill"></div></div>
</div>
<div id="instrBox"></div>

<script>
// ─────────────────────────────────────────────────────────────
// CONFIGURAÇÃO
// ─────────────────────────────────────────────────────────────
var CFG = {
  startLat: $startLat,
  startLon: $startLon,
  endLat:   $endLat,
  endLon:   $endLon,
  routeColor: '$routeColor',
  routeColorLight: '$routeColorLight',
  origin: '$origin',
  dest:   '$destination',
  zoom:   15
};
var AUTO_START = ${autoStart ? 'true' : 'false'};

// Barra de loading
var pct = 0;
function setLoad(p, msg) {
  pct = p;
  document.getElementById('loadingBarFill').style.width = p + '%';
  var badge = document.getElementById('loadingBadge');
  if (badge && msg) badge.childNodes[2].textContent = msg;
}

// ─────────────────────────────────────────────────────────────
// MAPA
// ─────────────────────────────────────────────────────────────
setLoad(10, 'Inicializando mapa...');

var map = L.map('map', {
  zoomControl: false,
  attributionControl: false,
  preferCanvas: true,
  fadeAnimation: true,
  zoomAnimation: true
});

// Tiles OpenStreetMap (gratuito, sem token)
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 19,
  subdomains: 'abc',
  attribution: '© OpenStreetMap'
}).addTo(map);

// Zoom no canto inferior direito
L.control.zoom({ position: 'bottomright' }).addTo(map);

// Inicializa centrando na origem
map.setView([CFG.startLat, CFG.startLon], CFG.zoom);
setLoad(25, 'Buscando rota via OSRM...');

// ─────────────────────────────────────────────────────────────
// MARCADORES
// ─────────────────────────────────────────────────────────────
var posIcon = L.divIcon({
  html: '<div class="pos-dot"></div>',
  className: '', iconSize: [20,20], iconAnchor: [10,10]
});
var posMarker = L.marker([CFG.startLat, CFG.startLon], {
  icon: posIcon, zIndexOffset: 1000
}).addTo(map);

var destIcon = L.divIcon({
  html: '<div class="dest-pin"></div>',
  className: '', iconSize: [20,20], iconAnchor: [10,20]
});
var destMarker = L.marker([CFG.endLat, CFG.endLon], { icon: destIcon }).addTo(map);
destMarker.bindPopup('<b>🏁 ' + CFG.dest + '</b>');

// ─────────────────────────────────────────────────────────────
// OSRM — ROTA REAL
// ─────────────────────────────────────────────────────────────
var routeLayer       = null;
var shadowLayer      = null;
var routeCoords      = [];    // [[lat,lon], ...]
var steps            = [];    // instrucoes OSRM
var currentStepIdx   = 0;
var animIdx          = 0;
var animTimer        = null;
var totalRouteDist   = 0;     // metros
var totalRouteDur    = 0;     // segundos

function fetchOsrmRoute() {
  // OSRM público — não precisa de token, funciona direto
  var url = 'https://router.project-osrm.org/route/v1/driving/' +
    CFG.startLon + ',' + CFG.startLat + ';' +
    CFG.endLon   + ',' + CFG.endLat +
    '?overview=full&geometries=geojson&steps=true&annotations=false';

  fetch(url, { mode: 'cors', cache: 'no-cache' })
    .then(function(r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    })
    .then(function(data) {
      if (!data.routes || !data.routes[0]) {
        throw new Error('Sem rota na resposta');
      }
      setLoad(60, 'Desenhando rota...');

      var route = data.routes[0];
      totalRouteDist = route.distance;
      totalRouteDur  = route.duration;

      // Converte [lon,lat] → [lat,lon]
      var rawCoords = route.geometry.coordinates;
      routeCoords = rawCoords.map(function(c) { return [c[1], c[0]]; });

      // Extrai steps de navegação
      if (route.legs && route.legs[0] && route.legs[0].steps) {
        steps = route.legs[0].steps
          .filter(function(s) { return s.name || (s.maneuver && s.maneuver.type); })
          .map(function(s) {
            var t = s.maneuver ? s.maneuver.type : 'depart';
            var mod = s.maneuver ? (s.maneuver.modifier || '') : '';
            return {
              name:     s.name || 'Continuar',
              distance: Math.round(s.distance),
              duration: Math.round(s.duration),
              type:     t,
              modifier: mod,
              instruction: buildInstruction(t, mod, s.name)
            };
          });
      }

      drawRoute();
      setLoad(90, 'Iniciando navegação...');

      // Ajusta o mapa para ver a rota toda com padding
      if (routeLayer) {
        map.fitBounds(routeLayer.getBounds(), { padding: [55, 55], animate: true, duration: 1.2 });
      }

      // Rota carregada: auto-inicia se tripStarted, caso contrário mostra overlay
      setTimeout(function() {
        hideBadge();
        if (AUTO_START) {
          startMarkerAnimation();
        } else {
          showWaitingOverlay();
        }
      }, 1500);

      notifyFlutter('route_loaded', {
        distM: totalRouteDist,
        durS:  totalRouteDur,
        steps: steps.length,
        coords: routeCoords.length
      });
    })
    .catch(function(err) {
      console.warn('[OSRM] Erro, usando fallback direto:', err);
      useFallbackRoute();
    });
}

// Monta instrução legível a partir do tipo OSRM
function buildInstruction(type, modifier, name) {
  var n = name || '';
  if (type === 'depart')         return 'Siga pela ' + n;
  if (type === 'arrive')         return 'Você chegou ao destino';
  if (type === 'turn') {
    if (modifier === 'right')    return 'Vire à direita em ' + n;
    if (modifier === 'left')     return 'Vire à esquerda em ' + n;
    if (modifier === 'slight right') return 'Vire ligeiramente à direita em ' + n;
    if (modifier === 'slight left')  return 'Vire ligeiramente à esquerda em ' + n;
    if (modifier === 'sharp right')  return 'Vire à direita acentuadamente em ' + n;
    if (modifier === 'sharp left')   return 'Vire à esquerda acentuadamente em ' + n;
    if (modifier === 'uturn')    return 'Faça retorno em ' + n;
    return 'Vire em ' + n;
  }
  if (type === 'roundabout')     return 'Entrada na rotatória, siga para ' + n;
  if (type === 'merge')          return 'Entre na via ' + n;
  if (type === 'continue')       return 'Continue por ' + n;
  if (type === 'fork') {
    if (modifier === 'right')    return 'Mantenha-se à direita em ' + n;
    if (modifier === 'left')     return 'Mantenha-se à esquerda em ' + n;
    return 'Mantenha-se na via ' + n;
  }
  return 'Continue por ' + n;
}

// Desenha a rota colorida no mapa
function drawRoute() {
  if (!routeCoords.length) return;

  // Remove rotas anteriores
  if (shadowLayer) map.removeLayer(shadowLayer);
  if (routeLayer)  map.removeLayer(routeLayer);

  // Sombra (casing)
  shadowLayer = L.polyline(routeCoords, {
    color:    'rgba(0,0,0,0.15)',
    weight:   12,
    lineJoin: 'round',
    lineCap:  'round'
  }).addTo(map);

  // Rota principal colorida
  routeLayer = L.polyline(routeCoords, {
    color:    CFG.routeColor,
    weight:   7,
    opacity:  0.95,
    lineJoin: 'round',
    lineCap:  'round'
  }).addTo(map);

  // Desenha zonas de risco ao longo da rota
  setTimeout(drawRiskZones, 800);
}

// Zonas de risco com círculos pulsantes
function drawRiskZones() {
  if (routeCoords.length < 5) return;
  var zones = [
    { pct: 0.20, color: '#22C55E25', r: 90 },
    { pct: 0.38, color: '#F5900025', r: 110 },
    { pct: 0.55, color: '#F9731620', r: 130 },
    { pct: 0.72, color: '#22C55E25', r: 95  },
  ];
  zones.forEach(function(z) {
    var idx = Math.floor(z.pct * routeCoords.length);
    if (idx < routeCoords.length) {
      L.circle(routeCoords[idx], {
        radius:      z.r,
        color:       'transparent',
        fillColor:   z.color,
        fillOpacity: 0.8,
        interactive: false
      }).addTo(map);
    }
  });
}

// ─────────────────────────────────────────────────────────────
// FALLBACK — rota direta se OSRM falhar
// ─────────────────────────────────────────────────────────────
function useFallbackRoute() {
  // Gera rota poligonal simples entre origem e destino
  var latDiff = CFG.endLat - CFG.startLat;
  var lonDiff = CFG.endLon - CFG.startLon;

  // Cria 20 pontos interpolados com pequena variação
  routeCoords = [];
  for (var i = 0; i <= 20; i++) {
    var t = i / 20;
    var jitter = (Math.random() - 0.5) * 0.001;
    routeCoords.push([
      CFG.startLat + latDiff * t + (i > 0 && i < 20 ? jitter : 0),
      CFG.startLon + lonDiff * t + (i > 0 && i < 20 ? jitter : 0)
    ]);
  }

  // Steps básicos de fallback
  steps = [
    { name: 'Av. Principal', distance: 2000, instruction: 'Siga pela Av. Principal', type: 'depart' },
    { name: 'Rua Central',   distance: 1500, instruction: 'Vire à direita em Rua Central', type: 'turn' },
    { name: 'Destino',       distance: 0,    instruction: 'Você chegou ao destino', type: 'arrive' }
  ];

  drawRoute();

  if (routeLayer) {
    map.fitBounds(routeLayer.getBounds(), { padding: [55, 55] });
  }

  setTimeout(function() {
    hideBadge();
    if (AUTO_START) {
      startMarkerAnimation();
    } else {
      showWaitingOverlay();
    }
  }, 1000);
}

// ─────────────────────────────────────────────────────────────
// NAVEGAÇÃO REAL: GPS real + fallback animado
// ─────────────────────────────────────────────────────────────
var followMode   = true;
var gpsWatchId   = null;
var gpsAvailable = false;
var lastStepSent = -1;

// Encontra índice do ponto mais próximo na rota
function closestRouteIdx(lat, lon) {
  var best = 0, bestD = Infinity;
  for (var i = 0; i < routeCoords.length; i++) {
    var dlat = routeCoords[i][0] - lat;
    var dlon = routeCoords[i][1] - lon;
    var d = dlat*dlat + dlon*dlon;
    if (d < bestD) { bestD = d; best = i; }
  }
  return best;
}

// Envia step OSRM real para o Flutter
function sendStep(idx) {
  if (idx === lastStepSent || idx >= steps.length) return;
  lastStepSent = idx;
  var s  = steps[idx];
  var nx = (idx + 1 < steps.length) ? steps[idx + 1] : null;
  showInstruction(idx);
  notifyFlutter('step', {
    name:        s.name || '',
    instruction: s.instruction || '',
    distance:    s.distance || 0,
    type:        s.type || '',
    nextName:    nx ? (nx.name || '') : ''
  });
}

// Move marcador e atualiza câmera + step
function moveMarker(lat, lon, idx) {
  animIdx = idx;
  posMarker.setLatLng([lat, lon]);
  if (followMode) {
    map.setView([lat, lon], 16, { animate: true, duration: 0.8, easeLinearity: 0.5 });
  }
  var progress = idx / Math.max(1, routeCoords.length - 1);
  var targetStep = Math.min(Math.floor(progress * steps.length), steps.length - 1);
  if (targetStep !== currentStepIdx) {
    currentStepIdx = targetStep;
    sendStep(targetStep);
  }
  if (idx >= routeCoords.length - 2) {
    stopNav();
    showInstruction(-1);
    notifyFlutter('arrived', {});
  }
}

function stopNav() {
  if (animTimer) { clearInterval(animTimer); animTimer = null; }
  if (gpsWatchId !== null) { navigator.geolocation.clearWatch(gpsWatchId); gpsWatchId = null; }
}

// GPS real via watchPosition
function startGpsTracking() {
  if (!navigator.geolocation) { startFallbackAnimation(); return; }
  gpsWatchId = navigator.geolocation.watchPosition(
    function(pos) {
      gpsAvailable = true;
      var lat = pos.coords.latitude;
      var lon = pos.coords.longitude;
      if (!routeCoords.length) return;
      moveMarker(lat, lon, closestRouteIdx(lat, lon));
    },
    function(err) {
      if (!gpsAvailable) startFallbackAnimation();
    },
    { enableHighAccuracy: true, maximumAge: 2000, timeout: 5000 }
  );
  // Se GPS não responder em 5s → fallback
  setTimeout(function() {
    if (!gpsAvailable && !animTimer) startFallbackAnimation();
  }, 5000);
}

// Fallback: simula percurso pela rota quando GPS indisponível
function startFallbackAnimation() {
  if (animTimer) return;
  if (!routeCoords.length) return;
  animIdx = 0;
  sendStep(0);
  // ~40 km/h → ~11 m/s; pontos OSRM espaçados ~8-15m → ~1-2 pts/s
  animTimer = setInterval(function() {
    if (animIdx >= routeCoords.length - 1) {
      stopNav(); showInstruction(-1); notifyFlutter('arrived', {}); return;
    }
    animIdx = Math.min(animIdx + 2, routeCoords.length - 1);
    var pos = routeCoords[animIdx];
    moveMarker(pos[0], pos[1], animIdx);
  }, 1000);
}

// Ponto de entrada (auto-start)
function startNavigation() {
  if (!routeCoords.length) return;
  sendStep(0);
  startGpsTracking();
}

// Alias de compatibilidade
function startMarkerAnimation() { startNavigation(); }

// Mostra instrução flutuante no mapa
function showInstruction(idx) {
  var box = document.getElementById('instrBox');
  if (!box) return;
  if (idx < 0) {
    box.textContent = '🏁 Você chegou ao destino!';
    box.style.display = 'block';
    return;
  }
  if (!steps.length) return;
  var s = steps[Math.min(idx, steps.length - 1)];
  if (!s) return;
  var dist = s.distance >= 1000
    ? (s.distance / 1000).toFixed(1) + ' km'
    : s.distance + ' m';
  box.textContent = '↗ ' + s.instruction + (s.distance > 0 ? ' (' + dist + ')' : '');
  box.style.display = 'block';
}

// Toque no mapa alterna follow mode
map.on('dragstart', function() { followMode = false; });
map.on('dblclick',  function() { followMode = true;  });

// ─────────────────────────────────────────────────────────────
// ESCUTA MENSAGENS DO FLUTTER (para-parada, futuro)
// ─────────────────────────────────────────────────────────────
window.addEventListener('message', function(e) {
  try {
    var msg = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
    if (!msg) return;
    if (msg.action === 'stop_nav') { stopNav(); }
  } catch(err) {}
});

// ─────────────────────────────────────────────────────────────
// LOADING BADGE
// ─────────────────────────────────────────────────────────────
function hideBadge() {
  var b = document.getElementById('loadingBadge');
  if (!b) return;
  b.style.transition = 'opacity .5s';
  b.style.opacity = '0';
  setTimeout(function() { b.style.display = 'none'; setLoad(100, ''); }, 500);
}

// ─────────────────────────────────────────────────────────────
// COMUNICAÇÃO COM FLUTTER (postMessage)
// ─────────────────────────────────────────────────────────────
function notifyFlutter(event, data) {
  try {
    window.parent.postMessage(JSON.stringify({ event: event, data: data }), '*');
  } catch(e) {}
}

// ─────────────────────────────────────────────────────────────
// INICIALIZA
// ─────────────────────────────────────────────────────────────
setTimeout(function() {
  fetchOsrmRoute();
}, 400);

// Notifica Flutter que o mapa carregou
setTimeout(function() { notifyFlutter('map_ready', {}); }, 800);

</script>
</body>
</html>''';
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _arrowBounce.dispose();
    _speedPulse.dispose();
    _dotPulse.dispose();
    super.dispose();
  }

  double get _progressPct =>
      (_progressKm / math.max(0.001, widget.selectedRoute.distanceKm)).clamp(0.0, 1.0);

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          // ① MAPA — 56% superior
          Positioned(
            top: 0, left: 0, right: 0,
            height: h * 0.56,
            child: _buildMap(),
          ),

          // ② Badge PROTEÇÃO ATIVA
          Positioned(
            top: top + 8, left: 0, right: 0,
            child: Center(child: _buildProtectionBadge()),
          ),

          // ③ Painel instrução (topo esquerdo)
          Positioned(
            top: top + 50, left: 12, right: 88,
            child: _buildInstructionPanel(),
          ),

          // ④ Caixa de velocidade (topo direito)
          Positioned(
            top: top + 50, right: 12,
            child: _buildSpeedBox(),
          ),

          // ⑤ Banner da rua atual (base do mapa)
          Positioned(
            top: h * 0.56 - 48,
            left: 0, right: 0,
            child: _buildStreetBanner(),
          ),

          // ⑥ Painel inferior estilo Waze
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomPanel(),
          ),

          // ⑦ Overlay de chegada
          if (_arrived) _buildArrivalOverlay(),
        ],
      ),
    );
  }

  // ── MAPA ──────────────────────────────────────────────────────
  Widget _buildMap() {
    if (kIsWeb && _mapRegistered) {
      return HtmlElementView(viewType: _mapViewId);
    }
    return _buildFallbackMap();
  }

  Widget _buildFallbackMap() {
    return Container(
      color: const Color(0xFFE8E0D0),
      child: Stack(children: [
        CustomPaint(
          size: Size.infinite,
          painter: _StreetGridPainter(
            progress: _progressPct,
            routeColor: widget.selectedRoute.type.color,
          ),
        ),
        Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _speedAnim,
              builder: (_, __) => Transform.scale(
                scale: _speedAnim.value,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: widget.selectedRoute.type.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(
                      color: widget.selectedRoute.type.color.withValues(alpha: 0.4),
                      blurRadius: 18, spreadRadius: 4,
                    )],
                  ),
                  child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('● Protegido',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        )),
      ]),
    );
  }

  // ── BADGE PROTEÇÃO ────────────────────────────────────────────
  Widget _buildProtectionBadge() {
    return AnimatedBuilder(
      animation: _dotAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: _dotAnim.value),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text('Proteção Ativa',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B6E35))),
          ],
        ),
      ),
    );
  }

  // ── PAINEL DE INSTRUÇÃO ───────────────────────────────────────
  Widget _buildInstructionPanel() {
    final instrText = _nextInstruction;
    final icon = _directionIcon(_nextInstruction);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B4B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        // Ícone de direção animado
        AnimatedBuilder(
          animation: _arrowAnim,
          builder: (_, __) => Transform.translate(
            offset: _nextInstruction.contains('direita')
                ? Offset(_arrowAnim.value, 0)
                : _nextInstruction.contains('esquerda')
                    ? Offset(-_arrowAnim.value, 0)
                    : Offset(0, -_arrowAnim.value * 0.5),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_nextDistM > 0) Text(
              _nextDistM >= 1000
                  ? '${(_nextDistM / 1000).toStringAsFixed(1)} km'
                  : '$_nextDistM m',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            Text(
              instrText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            if (_nextStreet.isNotEmpty) Text(
              _nextStreet,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        )),
      ]),
    );
  }

  IconData _directionIcon(String instr) {
    final l = instr.toLowerCase();
    if (l.contains('direita') && l.contains('acentuada'))  return Icons.turn_sharp_right_rounded;
    if (l.contains('esquerda') && l.contains('acentuada')) return Icons.turn_sharp_left_rounded;
    if (l.contains('direita'))    return Icons.turn_right_rounded;
    if (l.contains('esquerda'))   return Icons.turn_left_rounded;
    if (l.contains('rotatória'))  return Icons.roundabout_right_rounded;
    if (l.contains('retorno'))    return Icons.u_turn_right_rounded;
    if (l.contains('chegou'))     return Icons.flag_rounded;
    if (l.contains('mantenha'))   return Icons.straight_rounded;
    return Icons.straight_rounded;
  }

  // ── CAIXA DE VELOCIDADE ───────────────────────────────────────
  Widget _buildSpeedBox() {
    final over    = _overSpeed;
    final limitN  = int.tryParse(_speedLimit) ?? 40;
    final speedN  = _speedKmh.toStringAsFixed(0);

    return AnimatedBuilder(
      animation: _speedAnim,
      builder: (_, __) => Transform.scale(
        scale: over ? _speedAnim.value : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12)],
              ),
              child: Column(children: [
                Text(speedN,
                    style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, height: 1.1,
                      color: over ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                    )),
                const Text('km/h', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
              ]),
            ),
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: over ? const Color(0xFFEF4444) : Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
              ),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.speed_rounded, size: 10,
                        color: over ? Colors.white : Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text('$limitN',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: over ? Colors.white : Colors.grey.shade600,
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: over ? Colors.white : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── BANNER RUA ATUAL ──────────────────────────────────────────
  Widget _buildStreetBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_currentStreet  •  Limite $_speedLimit km/h',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  // ── PAINEL INFERIOR ESTILO WAZE ───────────────────────────────
  Widget _buildBottomPanel() {
    final pct             = _progressPct;
    final progressKmFmt   = _progressKm.toStringAsFixed(1);
    final totalKmFmt      = widget.selectedRoute.distanceKm.toStringAsFixed(1);
    final elapsedFmt      = _formatElapsed(_elapsedSec);
    final speedN          = _speedKmh.toStringAsFixed(0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // ── Linha 1: Velocidade + Rua + Zona ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Velocidade grande
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(speedN, style: TextStyle(
                        fontSize: 38, fontWeight: FontWeight.w900, height: 1.0,
                        color: _overSpeed ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                      )),
                      const Text('km/h', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentStreet,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.speed_rounded, size: 10, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text('Lim. $_speedLimit km/h',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        AnimatedBuilder(
                          animation: _dotAnim,
                          builder: (_, __) => Container(
                            width: 9, height: 9,
                            decoration: BoxDecoration(
                              color: _riskZoneColor.withValues(alpha: _dotAnim.value),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(_riskZoneLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _riskZoneColor)),
                      ]),
                    ],
                  )),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Linha 2: Chegada + Restam + Custo UBI ────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                // Chegada
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Chegada',
                        style: TextStyle(fontSize: 9, color: Color(0xFF1A56DB), fontWeight: FontWeight.w600)),
                    Text(_arrivalTime,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF1A56DB))),
                    Text('${_etaMinutes}min',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF1A56DB))),
                  ]),
                )),
                const SizedBox(width: 8),
                // Km restantes
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6F0DF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Restam',
                        style: TextStyle(fontSize: 9, color: Color(0xFF1B6E35), fontWeight: FontWeight.w600)),
                    Text('${_remainKm.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1B6E35))),
                  ]),
                )),
                const SizedBox(width: 8),
                // Custo UBI acumulado em tempo real
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(
                      'Custo UBI',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF1B6E35),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'R\$ ${_totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B6E35),
                      ),
                    ),
                    Text(
                      '${widget.selectedRoute.finalKmPrice.toStringAsFixed(2)}/km',
                      style: const TextStyle(fontSize: 8, color: Color(0xFF1B6E35)),
                    ),
                  ]),
                )),
              ]),
            ),

            const SizedBox(height: 10),

            // ── Barra de progresso ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(widget.selectedRoute.type.color),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$progressKmFmt de $totalKmFmt km',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(pct * 100).toInt()}% concluído',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: widget.selectedRoute.type.color)),
                    Text(elapsedFmt, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 10),

            // ── Botões: Assistência + Encerrar (sempre visíveis — auto-start) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                // Assistência (laranja → vermelho)
                Expanded(child: GestureDetector(
                  onTap: _showEmergencyDialog,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFE53E3E)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                        blurRadius: 14, offset: const Offset(0, 4),
                      )],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 7),
                        Text('Assistência',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                )),
                const SizedBox(width: 10),
                // Encerrar (branco + borda vermelha)
                Expanded(child: GestureDetector(
                  onTap: _showExitDialog,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1.8),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 8,
                      )],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stop_circle_rounded, color: Color(0xFFEF4444), size: 20),
                        SizedBox(width: 7),
                        Text('Encerrar',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(height: 3),
      Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
          textAlign: TextAlign.center),
    ],
  );

  // ── OVERLAY DE CHEGADA ────────────────────────────────────────
  Widget _buildArrivalOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(28),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                blurRadius: 40,
              )],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_rounded, size: 38, color: Color(0xFF22C55E)),
                ),
                const SizedBox(height: 16),
                const Text('Você chegou! 🎉',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Text(widget.destination,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center, maxLines: 2),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _arrStat('${_progressKm.toStringAsFixed(1)} km', 'Percorrido'),
                      Container(width: 1, height: 36, color: Colors.grey.shade200),
                      _arrStat(_formatElapsed(_elapsedSec), 'Duração'),
                      Container(width: 1, height: 36, color: Colors.grey.shade200),
                      _arrStat('R\$ ${_totalCost.toStringAsFixed(2)}', 'Custo UBI',
                          color: const Color(0xFF22C55E)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: widget.onEnd,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Ver resumo da viagem',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _arrStat(String v, String l, {Color? color}) => Column(children: [
    Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
        color: color ?? const Color(0xFF0F172A))),
    Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);

  String _formatElapsed(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── DIÁLOGOS ──────────────────────────────────────────────────
  void _showExitDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Encerrar navegação?',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text(
        'Percorrido: ${_progressKm.toStringAsFixed(1)} km\nCusto UBI até agora: R\$ ${_totalCost.toStringAsFixed(2)}',
        style: const TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar')),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _navTimer?.cancel(); widget.onEnd(); },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
          ),
          child: const Text('Encerrar'),
        ),
      ],
    ));
  }

  void _showEmergencyDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B35)),
        SizedBox(width: 8),
        Text('Central de Assistência',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _emergencyOption(Icons.car_crash_rounded,      'Reportar sinistro',    'Acidente ou colisão'),
        _emergencyOption(Icons.local_police_rounded,   'Acionar polícia',      'Roubo ou tentativa'),
        _emergencyOption(Icons.medical_services_rounded,'SAMU / Resgate',      'Emergência médica'),
        _emergencyOption(Icons.phone_rounded,          'Falar com atendente',  '0800 300 4500'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    ));
  }

  Widget _emergencyOption(IconData icon, String title, String subtitle) => ListTile(
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFFFF6B35), size: 20),
    ),
    title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    onTap: () => Navigator.pop(context),
    dense: true,
  );
}

// ── PAINTER FALLBACK MOBILE ───────────────────────────────────
class _StreetGridPainter extends CustomPainter {
  final double progress;
  final Color routeColor;
  const _StreetGridPainter({required this.progress, required this.routeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8E0D0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final street = Paint()..color = Colors.white..strokeWidth = 9..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 7; i++) {
      canvas.drawLine(Offset(0, size.height * i / 8), Offset(size.width, size.height * i / 8), street);
    }
    for (int i = 1; i <= 5; i++) {
      canvas.drawLine(Offset(size.width * i / 6, 0), Offset(size.width * i / 6, size.height), street);
    }

    // Rota sobre o grid
    final route = Paint()..color = routeColor..strokeWidth = 5..strokeCap = StrokeCap.round;
    final List<Offset> pts = [
      Offset(size.width * 0.5, size.height),
      Offset(size.width * 0.5, size.height * 0.75),
      Offset(size.width * 0.33, size.height * 0.75),
      Offset(size.width * 0.33, size.height * 0.5),
      Offset(size.width * 0.67, size.height * 0.5),
      Offset(size.width * 0.67, size.height * 0.25),
      Offset(size.width * 0.5, size.height * 0.25),
      Offset(size.width * 0.5, 0),
    ];
    for (int i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], route);
    }

    // Posição atual
    final idx = (progress * pts.length).clamp(0, pts.length - 1).toInt();
    final posP = Paint()..color = routeColor;
    canvas.drawCircle(pts[idx], 9, posP);
    canvas.drawCircle(pts[idx], 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_StreetGridPainter old) =>
      old.progress != progress || old.routeColor != routeColor;
}

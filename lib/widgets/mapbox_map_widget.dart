import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/risk_engine.dart';
import '../services/atuario_virtual_engine.dart';

// ─────────────────────────────────────────────
// Token & constantes Mapbox
// ─────────────────────────────────────────────
const String _mapboxToken =
    'pk.PLACEHOLDER_MAPBOX_TOKEN_SAFEROUTE';

const String _mapboxStyleStreets = 'mapbox/streets-v12';
const String _mapboxStyleDark    = 'mapbox/dark-v11';
const String _mapboxStyleLight   = 'mapbox/light-v11';

String _tileUrl(String style) =>
    'https://api.mapbox.com/styles/v1/$style/tiles/256/{z}/{x}/{y}@2x'
    '?access_token=$_mapboxToken';

// Coordenadas padrão — Serra / Vitória / ES
const LatLng _defaultCenter = LatLng(-20.1219, -40.3079);
const LatLng _serraCentro   = LatLng(-20.1286, -40.3073);
const LatLng _vitoriaCentro = LatLng(-20.3155, -40.3128);

// ═══════════════════════════════════════════════════════════════
// MODELO DE ROTA ALTERNATIVA
// ═══════════════════════════════════════════════════════════════

enum RouteType {
  rapida,
  segura,
  equilibrada;

  String get label {
    switch (this) {
      case rapida:      return 'Mais Rápida';
      case segura:      return 'Mais Segura';
      case equilibrada: return 'Equilibrada';
    }
  }

  String get subtitle {
    switch (this) {
      case rapida:      return 'Menor tempo • BR-101';
      case segura:      return 'Menor risco • ES-010 / Orla';
      case equilibrada: return 'Balanceada • Terceira Ponte';
    }
  }

  IconData get icon {
    switch (this) {
      case rapida:      return Icons.speed_rounded;
      case segura:      return Icons.shield_rounded;
      case equilibrada: return Icons.balance_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case rapida:      return const Color(0xFF3B82F6); // azul
      case segura:      return const Color(0xFF22C55E); // verde
      case equilibrada: return const Color(0xFFF59E0B); // âmbar
    }
  }
}

class RouteSegment {
  final List<LatLng> points;
  final RiskZone zone;
  final String locationName;

  const RouteSegment({
    required this.points,
    required this.zone,
    required this.locationName,
  });
}

class RouteAlternative {
  final RouteType type;
  final List<RouteSegment> segments;
  final double km;
  final int minutes;
  final double riskScore;      // 0.0 → 5.0
  final RiskZone dominantZone;
  final double price;
  final String via;            // descrição da rota

  const RouteAlternative({
    required this.type,
    required this.segments,
    required this.km,
    required this.minutes,
    required this.riskScore,
    required this.dominantZone,
    required this.price,
    required this.via,
  });

  // Todos os pontos da rota (para polyline)
  List<LatLng> get allPoints =>
      segments.expand((s) => s.points).toList();

  Color get routeColor => type.accentColor;

  String get kmFormatado => '${km.toStringAsFixed(1)} km';
  String get timeFormatado {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}min' : '${h}h';
    }
    return '${minutes}min';
  }
  String get priceFormatado => 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  String get riskLabel {
    if (riskScore <= 1.3) return 'Baixo';
    if (riskScore <= 2.0) return 'Médio';
    if (riskScore <= 3.0) return 'Alto';
    return 'Crítico';
  }
  Color get riskColor => dominantZone.color;
}

// ═══════════════════════════════════════════════════════════════
// GERADOR DE ROTAS REALISTAS DO ES
// ═══════════════════════════════════════════════════════════════

class ESRouteGenerator {

  // ─── ROTA 1: MAIS RÁPIDA — BR-101 Sul → Contorno → Centro Vitória ───────────
  static List<RouteSegment> buildRouteBR101() {
    return [
      // Segmento 1: Serra Centro → entrada BR-101 (zona Amarela)
      RouteSegment(
        locationName: 'Serra Centro / Carapina',
        zone: RiskZone.amarela,
        points: const [
          LatLng(-20.1286, -40.3073), // Serra Centro
          LatLng(-20.1380, -40.3010), // Av. Norte-Sul, Serra
          LatLng(-20.1510, -40.3050), // Carapina Grande
          LatLng(-20.1620, -40.3090), // BR-101 acesso
          LatLng(-20.1730, -40.3120), // BR-101 km 270
        ],
      ),
      // Segmento 2: BR-101 passando por trecho industrial (zona Laranja)
      RouteSegment(
        locationName: 'BR-101 / André Carloni',
        zone: RiskZone.laranja,
        points: const [
          LatLng(-20.1730, -40.3120),
          LatLng(-20.1880, -40.3070), // Av. Central da Serra
          LatLng(-20.2010, -40.3090), // Próx. André Carloni
          LatLng(-20.2150, -40.3100), // BR-101 km 265
          LatLng(-20.2290, -40.3130), // Entroncamento Cariacica
        ],
      ),
      // Segmento 3: Túnel do Contorno → acesso Vitória (zona Vermelha — Bento Ferreira)
      RouteSegment(
        locationName: 'Contorno / Bento Ferreira',
        zone: RiskZone.vermelha,
        points: const [
          LatLng(-20.2290, -40.3130),
          LatLng(-20.2530, -40.3090), // Av. Marechal Mascarenhas
          LatLng(-20.2680, -40.3110), // Bento Ferreira
          LatLng(-20.2820, -40.3120), // Lourdes / Enseada
          LatLng(-20.2940, -40.3130), // Praia do Suá
        ],
      ),
      // Segmento 4: Centro de Vitória (zona Laranja)
      RouteSegment(
        locationName: 'Centro de Vitória',
        zone: RiskZone.laranja,
        points: const [
          LatLng(-20.2940, -40.3130),
          LatLng(-20.3000, -40.3128), // Av. Jerônimo Monteiro
          LatLng(-20.3080, -40.3125),
          LatLng(-20.3155, -40.3128), // Destino Vitória
        ],
      ),
    ];
  }

  // ─── ROTA 2: MAIS SEGURA — ES-010 pela Orla / Jardim Camburi ─────────────
  static List<RouteSegment> buildRouteOrla() {
    return [
      // Segmento 1: Serra → Laranjeiras (zona Verde)
      RouteSegment(
        locationName: 'Laranjeiras / Serra',
        zone: RiskZone.verde,
        points: const [
          LatLng(-20.1286, -40.3073), // Serra Centro
          LatLng(-20.1350, -40.2940), // Laranjeiras
          LatLng(-20.1420, -40.2830), // Av. Central Laranjeiras
          LatLng(-20.1520, -40.2710), // ES-010 acesso praia
          LatLng(-20.1660, -40.2620), // Litoral Norte - Serra
        ],
      ),
      // Segmento 2: ES-010 orla pela praia (zona Verde)
      RouteSegment(
        locationName: 'ES-010 / Nova Almeida / Orla',
        zone: RiskZone.verde,
        points: const [
          LatLng(-20.1660, -40.2620),
          LatLng(-20.1820, -40.2580), // Bicanga
          LatLng(-20.2010, -40.2620), // Manguinhos
          LatLng(-20.2180, -40.2700), // Jacaraípe
          LatLng(-20.2350, -40.2760), // Carapebus
          LatLng(-20.2480, -40.2820), // ES-010 sul
        ],
      ),
      // Segmento 3: Jardim Camburi (zona Verde)
      RouteSegment(
        locationName: 'Jardim Camburi',
        zone: RiskZone.verde,
        points: const [
          LatLng(-20.2480, -40.2820),
          LatLng(-20.2590, -40.2890), // Av. Adalberto Simão Nader
          LatLng(-20.2670, -40.2960), // Jardim Camburi Norte
          LatLng(-20.2760, -40.3010), // Camburi Centro
          LatLng(-20.2880, -40.3050), // Camburi Sul
        ],
      ),
      // Segmento 4: Enseada do Suá → Vitória (zona Amarela)
      RouteSegment(
        locationName: 'Enseada do Suá / Centro',
        zone: RiskZone.amarela,
        points: const [
          LatLng(-20.2880, -40.3050),
          LatLng(-20.2960, -40.3090), // Praia do Canto
          LatLng(-20.3020, -40.3110), // Enseada do Suá
          LatLng(-20.3080, -40.3120),
          LatLng(-20.3155, -40.3128), // Destino Vitória
        ],
      ),
    ];
  }

  // ─── ROTA 3: EQUILIBRADA — BR-101 parcial + Terceira Ponte ──────────────
  static List<RouteSegment> buildRouteTerceiraPonte() {
    return [
      // Segmento 1: Serra → Campo Grande (zona Amarela)
      RouteSegment(
        locationName: 'Serra / Campo Grande',
        zone: RiskZone.amarela,
        points: const [
          LatLng(-20.1286, -40.3073), // Serra Centro
          LatLng(-20.1420, -40.3080), // Av. Minas Gerais
          LatLng(-20.1580, -40.3130), // Campo Grande Norte
          LatLng(-20.1720, -40.3170), // Campo Grande
          LatLng(-20.1860, -40.3200), // Cariacica Norte
        ],
      ),
      // Segmento 2: BR-101 Cariacica → Vila Velha (zona Laranja)
      RouteSegment(
        locationName: 'Cariacica / Vila Velha',
        zone: RiskZone.laranja,
        points: const [
          LatLng(-20.1860, -40.3200),
          LatLng(-20.2020, -40.3260), // Cariacica Centro
          LatLng(-20.2170, -40.3310), // Alto Laje
          LatLng(-20.2340, -40.3380), // BR-101 VV
          LatLng(-20.2490, -40.3520), // Vila Velha Norte
        ],
      ),
      // Segmento 3: Vila Velha → Terceira Ponte (zona Amarela)
      RouteSegment(
        locationName: 'Vila Velha / Terceira Ponte',
        zone: RiskZone.amarela,
        points: const [
          LatLng(-20.2490, -40.3520),
          LatLng(-20.2630, -40.3490), // Coqueiral
          LatLng(-20.2770, -40.3410), // Av. Antônio Gil Veloso
          LatLng(-20.2940, -40.3290), // Acesso Terceira Ponte
          LatLng(-20.3050, -40.3220), // Terceira Ponte VV
        ],
      ),
      // Segmento 4: Terceira Ponte → Vitória (zona Amarela)
      RouteSegment(
        locationName: 'Terceira Ponte / Vitória',
        zone: RiskZone.amarela,
        points: const [
          LatLng(-20.3050, -40.3220),
          LatLng(-20.3100, -40.3185), // Centro Terceira Ponte
          LatLng(-20.3130, -40.3160), // Chegando Vitória
          LatLng(-20.3155, -40.3128), // Destino Vitória
        ],
      ),
    ];
  }

  // ── Calcula score de risco médio de uma rota ──────────────────────────────
  static double calcRouteRiskScore(List<RouteSegment> segments) {
    if (segments.isEmpty) return 1.0;
    double total = 0;
    for (final s in segments) {
      total += s.zone.multiplier;
    }
    return total / segments.length;
  }

  // ── Zona dominante ────────────────────────────────────────────────────────
  static RiskZone calcDominantZone(List<RouteSegment> segments) {
    if (segments.isEmpty) return RiskZone.amarela;
    final zoneCounts = <RiskZone, int>{};
    for (final s in segments) {
      zoneCounts[s.zone] = (zoneCounts[s.zone] ?? 0) + 1;
    }
    return zoneCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // ── Gera as 3 alternativas com preço calculado pelo Motor V3 (AtuárioVirtual) ──
  static List<RouteAlternative> generateAlternatives({
    WeatherCondition weather = WeatherCondition.sol,
    TrafficLevel traffic = TrafficLevel.moderado,
    int driverScore = 820,
    double fipeValue = 80000.0,
    String planType = 'smart',
    // Distância real entre origem e destino (Haversine).
    // Se fornecida, os cards mostrarão km e preço proporcionais à viagem real.
    // Se null, usa as distâncias fixas Serra→Vitória (fallback ES local).
    double? kmReal,
    String destination = 'Vitória/ES',
    // Dados extras para o Motor V3 (precisão atuarial)
    String cidadeDestino = 'Vitória',
    int idadeCondutor = 28,
    int cnhAnos = 7,
    int sinistros3Anos = 0,
    int multas12Meses = 0,
    int acidentes3Anos = 0,
    double kmMes = 1200.0,
    double theftIndex = 0.35,
    int anoModelo = 2021,
  }) {
    final segsBR101  = buildRouteBR101();
    final segsOrla   = buildRouteOrla();
    final segsPonte  = buildRouteTerceiraPonte();

    // Distâncias base Serra→Vitória (usadas como proporção relativa entre rotas)
    const kmBase     = 27.5; // rota rápida base
    const kmOrlaBase = 38.2;
    const kmPonteBase = 32.8;

    // Se temos distância real, escalar proporcionalmente.
    // A rota rápida = distância real; segura e equilibrada = proporção igual à local.
    final kmBR101 = kmReal ?? kmBase;
    final fatorEscala = kmBR101 / kmBase;
    final kmOrla  = kmReal != null ? kmOrlaBase  * fatorEscala : kmOrlaBase;
    final kmPonte = kmReal != null ? kmPonteBase * fatorEscala : kmPonteBase;

    // Tempo proporcional à distância (velocidade média ~50km/h)
    final minBR101 = kmReal != null ? (kmBR101 / 70.0 * 60).round() : 35;
    final minOrla  = kmReal != null ? (kmOrla  / 60.0 * 60).round() : 52;
    final minPonte = kmReal != null ? (kmPonte / 65.0 * 60).round() : 43;

    final hour = DateTime.now().hour;
    final deptTime = DateTime.now().copyWith(hour: hour > 0 ? hour : 20);

    // ── Motor V3 (AtuárioVirtual) — preço atuarial real ──────────────────
    // Usa a fórmula SUSEP: P(sinistro) × FIPE × fGeo × multComposto
    // Muito mais preciso que V1: considera FIPE real, cidade destino, fGeo
    double _calcPriceV3(List<RouteSegment> segs, double km) {
      final dominantZone = calcDominantZone(segs);
      // Cep risk score sintético baseado na zona da rota
      final cepScore = switch (dominantZone) {
        RiskZone.verde    => 150,
        RiskZone.amarela  => 320,
        RiskZone.laranja  => 520,
        RiskZone.vermelha => 750,
        RiskZone.critica  => 900,
      };
      final input = AtuarioVirtualEngine.buildInputFromContext(
        fipeValor:      fipeValue,
        anoModelo:      anoModelo,
        vehicleModel:   '',
        theftIndex:     theftIndex,
        distanciaKm:    km,
        kmMes:          kmMes,
        zonaRota:       dominantZone,
        clima:          weather,
        transito:       traffic,
        cepRiskScore:   cepScore,
        cidadeOrigem:   'Serra',
        cidadeDestino:  cidadeDestino,
        idadeCondutor:  idadeCondutor,
        cnhAnos:        cnhAnos,
        sinistros3Anos: sinistros3Anos,
        multas12Meses:  multas12Meses,
        acidentes3Anos: acidentes3Anos,
        temGaragem:     false,
        temRastreador:  false,
      );
      final result = AtuarioVirtualEngine.calculate(input);
      return result.premioViagem;
    }

    // Fallback V1 (RiskEngine) caso V3 falhe — mantém compatibilidade
    double _calcPriceV1(List<RouteSegment> segs, double km) {
      final dominantZone = calcDominantZone(segs);
      final input = RiskInput(
        distanceKm: km,
        zone: dominantZone,
        departureTime: deptTime,
        weather: weather,
        driverScore: driverScore,
        traffic: traffic,
        vehicleFipeValue: fipeValue,
        vehicleModel: '',
        planType: planType,
        origin: 'Serra/ES',
        destination: destination,
      );
      return RiskEngine.calculate(input).precoFinal;
    }

    double _calcPrice(List<RouteSegment> segs, double km) {
      try {
        return _calcPriceV3(segs, km);
      } catch (_) {
        return _calcPriceV1(segs, km);
      }
    }

    return [
      RouteAlternative(
        type: RouteType.rapida,
        segments: segsBR101,
        km: kmBR101,
        minutes: minBR101,
        riskScore: calcRouteRiskScore(segsBR101),
        dominantZone: calcDominantZone(segsBR101),
        price: _calcPrice(segsBR101, kmBR101),
        via: kmReal != null ? 'Rota mais rápida' : 'BR-101 → Contorno → Centro',
      ),
      RouteAlternative(
        type: RouteType.segura,
        segments: segsOrla,
        km: kmOrla,
        minutes: minOrla,
        riskScore: calcRouteRiskScore(segsOrla),
        dominantZone: calcDominantZone(segsOrla),
        price: _calcPrice(segsOrla, kmOrla),
        via: kmReal != null ? 'Rota mais segura' : 'ES-010 → Orla → Camburi',
      ),
      RouteAlternative(
        type: RouteType.equilibrada,
        segments: segsPonte,
        km: kmPonte,
        minutes: minPonte,
        riskScore: calcRouteRiskScore(segsPonte),
        dominantZone: calcDominantZone(segsPonte),
        price: _calcPrice(segsPonte, kmPonte),
        via: kmReal != null ? 'Rota equilibrada' : 'BR-101 → Vila Velha → 3ª Ponte',
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL — MapboxRouteMap com seleção de rotas
// ═══════════════════════════════════════════════════════════════
class MapboxRouteMap extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String? originLabel;
  final String? destinationLabel;
  final bool darkMode;
  final double height;
  final bool showTraffic;
  final WeatherCondition weather;
  final TrafficLevel traffic;
  final int driverScore;
  final ValueChanged<RouteAlternative>? onRouteSelected;
  // Distância real da viagem (Haversine) para escalar preços dos cards
  final double? kmReal;
  final String destinationName;
  // Dados para Motor V3 (AtuárioVirtual) — preço atuarial preciso
  final double fipeValue;
  final int anoModelo;
  final double theftIndex;
  final String cidadeDestino;
  final int idadeCondutor;
  final int cnhAnos;
  final int sinistros3Anos;
  final int multas12Meses;
  final int acidentes3Anos;
  final double kmMes;

  const MapboxRouteMap({
    super.key,
    this.origin = _serraCentro,
    this.destination = _vitoriaCentro,
    this.originLabel,
    this.destinationLabel,
    this.darkMode = false,
    this.height = 320,
    this.showTraffic = false,
    this.weather = WeatherCondition.sol,
    this.traffic = TrafficLevel.moderado,
    this.driverScore = 820,
    this.onRouteSelected,
    this.kmReal,
    this.destinationName = 'Vitória/ES',
    this.fipeValue = 80000.0,
    this.anoModelo = 2021,
    this.theftIndex = 0.35,
    this.cidadeDestino = 'Vitória',
    this.idadeCondutor = 28,
    this.cnhAnos = 7,
    this.sinistros3Anos = 0,
    this.multas12Meses = 0,
    this.acidentes3Anos = 0,
    this.kmMes = 1200.0,
  });

  @override
  State<MapboxRouteMap> createState() => _MapboxRouteMapState();
}

class _MapboxRouteMapState extends State<MapboxRouteMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  late List<RouteAlternative> _routes;
  int _selectedIndex = 0;
  bool _showPanel = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _buildRoutes();
  }

  void _buildRoutes() {
    _routes = ESRouteGenerator.generateAlternatives(
      weather: widget.weather,
      traffic: widget.traffic,
      driverScore: widget.driverScore,
      fipeValue: widget.fipeValue,
      kmReal: widget.kmReal,
      destination: widget.destinationName,
      // Dados para Motor V3 — preço atuarial preciso por FIPE e destino
      cidadeDestino:  widget.cidadeDestino,
      idadeCondutor:  widget.idadeCondutor,
      cnhAnos:        widget.cnhAnos,
      sinistros3Anos: widget.sinistros3Anos,
      multas12Meses:  widget.multas12Meses,
      acidentes3Anos: widget.acidentes3Anos,
      kmMes:          widget.kmMes,
      theftIndex:     widget.theftIndex,
      anoModelo:      widget.anoModelo,
    );
  }

  @override
  void didUpdateWidget(MapboxRouteMap old) {
    super.didUpdateWidget(old);
    if (old.weather != widget.weather ||
        old.traffic != widget.traffic ||
        old.driverScore != widget.driverScore) {
      setState(_buildRoutes);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  RouteAlternative get _selected => _routes[_selectedIndex];

  // True quando o destino é fora do ES (viagem longa)
  bool get _isLongDistance => widget.kmReal != null;

  // Linha direta origem GPS → destino GPS
  List<LatLng> get _directLine => [widget.origin, widget.destination];

  // Calcula bounds para encaixar a rota / viagem
  LatLngBounds _calcBounds() {
    if (_isLongDistance) {
      // Bounds entre origem e destino reais
      final minLat = math.min(widget.origin.latitude,  widget.destination.latitude);
      final maxLat = math.max(widget.origin.latitude,  widget.destination.latitude);
      final minLon = math.min(widget.origin.longitude, widget.destination.longitude);
      final maxLon = math.max(widget.origin.longitude, widget.destination.longitude);
      final pad = math.max((maxLat - minLat) * 0.15, 0.8);
      return LatLngBounds(
        LatLng(minLat - pad, minLon - pad),
        LatLng(maxLat + pad, maxLon + pad),
      );
    }
    final pts = _selected.allPoints;
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    return LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b) - 0.025,
             lngs.reduce((a, b) => a < b ? a : b) - 0.025),
      LatLng(lats.reduce((a, b) => a > b ? a : b) + 0.025,
             lngs.reduce((a, b) => a > b ? a : b) + 0.025),
    );
  }

  void _selectRoute(int index) {
    setState(() => _selectedIndex = index);
    widget.onRouteSelected?.call(_routes[index]);
    // Refit camera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: _calcBounds(), padding: const EdgeInsets.all(56)),
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.darkMode ? _mapboxStyleDark : _mapboxStyleStreets;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // ── Mapa base ──────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: _calcBounds(),
                  padding: const EdgeInsets.all(56),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
                onTap: (_, __) => setState(() => _showPanel = !_showPanel),
              ),
              children: [
                // Tiles Mapbox
                TileLayer(
                  urlTemplate: _tileUrl(style),
                  additionalOptions: const {'accessToken': _mapboxToken},
                  tileProvider: NetworkTileProvider(),
                  maxZoom: 18,
                  userAgentPackageName: 'com.saferoute.insurance',
                ),

                // ── Linha de rota ─────────────────────────────────────────
                // Longa distância: linha pontilhada direta origem→destino GPS
                // ES local: polylines coloridas por zona de risco
                if (_isLongDistance) PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _directLine,
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      strokeWidth: 10,
                    ),
                    Polyline(
                      points: _directLine,
                      color: AppTheme.primary,
                      strokeWidth: 4,
                      borderColor: Colors.white.withValues(alpha: 0.6),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
                if (!_isLongDistance) ...[
                  PolylineLayer(
                    polylines: [
                      for (int i = 0; i < _routes.length; i++)
                        if (i != _selectedIndex)
                          Polyline(
                            points: _routes[i].allPoints,
                            color: _routes[i].routeColor.withValues(alpha: 0.25),
                            strokeWidth: 4,
                          ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _selected.allPoints,
                        color: _selected.routeColor.withValues(alpha: 0.3),
                        strokeWidth: 10,
                      ),
                      for (final seg in _selected.segments)
                        Polyline(
                          points: seg.points,
                          color: seg.zone.color,
                          strokeWidth: 5.5,
                          borderColor: Colors.white.withValues(alpha: 0.5),
                          borderStrokeWidth: 1,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final seg in _selected.segments)
                        if (seg.zone.index >= RiskZone.laranja.index)
                          Marker(
                            point: seg.points[seg.points.length ~/ 2],
                            width: 24,
                            height: 24,
                            child: _RiskDot(zone: seg.zone),
                          ),
                    ],
                  ),
                ],

                // ── Marcadores de origem e destino ────────────────────────
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.origin,
                      width: 56,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: _OriginMarker(
                          label: widget.originLabel ?? 'Serra'),
                    ),
                    Marker(
                      point: widget.destination,
                      width: 56,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: _DestinationMarker(
                        label: widget.destinationLabel ?? 'Vitória',
                        pulseAnim: _pulseAnim,
                      ),
                    ),
                  ],
                ),

                // Atribuição obrigatória
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('Mapbox',
                        textStyle: TextStyle(fontSize: 9, color: Colors.grey)),
                    TextSourceAttribution('OpenStreetMap',
                        textStyle: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                  alignment: AttributionAlignment.bottomRight,
                ),
              ],
            ),

            // ── Badge rota selecionada (topo) ─────────────────────────────
            Positioned(
              top: 10,
              left: 10,
              child: _RouteTypeBadge(route: _selected),
            ),

            // ── Botão toggle panel ─────────────────────────────────────────
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() => _showPanel = !_showPanel),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: Icon(
                    _showPanel ? Icons.keyboard_arrow_down : Icons.route_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),

            // ── Painel de seleção de rotas (embaixo) ─────────────────────
            if (_showPanel)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _RouteSelectionPanel(
                  routes: _routes,
                  selectedIndex: _selectedIndex,
                  onSelect: _selectRoute,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAINEL DE SELEÇÃO DE ROTAS (estilo Uber)
// ═══════════════════════════════════════════════════════════════
class _RouteSelectionPanel extends StatelessWidget {
  final List<RouteAlternative> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _RouteSelectionPanel({
    required this.routes,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.alt_route_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Escolha a rota',
                  style: const TextStyle(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                // Legenda de cores
                _RiskLegend(),
              ],
            ),
          ),
          // Cartões das rotas
          SizedBox(
            height: 94,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: routes.length,
              itemBuilder: (ctx, i) => _RouteCard(
                route: routes[i],
                isSelected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _RiskLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final zone in [RiskZone.verde, RiskZone.amarela, RiskZone.laranja, RiskZone.vermelha])
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: zone.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 4),
        Text('risco', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RouteAlternative route;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteCard({
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 148,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? route.routeColor.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? route.routeColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppTheme.shadowSm : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título + ícone
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? route.routeColor
                        : route.routeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(route.type.icon,
                      size: 12,
                      color: isSelected ? Colors.white : route.routeColor),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    route.type.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? route.routeColor : AppTheme.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Métricas
            Row(
              children: [
                _Metric(icon: Icons.access_time_rounded, value: route.timeFormatado),
                const SizedBox(width: 6),
                _Metric(icon: Icons.straighten_rounded, value: route.kmFormatado),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: route.riskColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Risco ${route.riskLabel}',
                  style: TextStyle(
                    fontSize: 9,
                    color: route.riskColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  route.priceFormatado,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? route.routeColor : AppTheme.primary,
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

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;

  const _Metric({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: Colors.grey.shade500),
        const SizedBox(width: 2),
        Text(value,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BADGE — Tipo de rota selecionada
// ═══════════════════════════════════════════════════════════════
class _RouteTypeBadge extends StatelessWidget {
  final RouteAlternative route;
  const _RouteTypeBadge({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowSm,
        border: Border.all(color: route.routeColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(route.type.icon, size: 13, color: route.routeColor),
          const SizedBox(width: 5),
          Text(
            route.type.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: route.routeColor,
            ),
          ),
          const SizedBox(width: 5),
          Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
          const SizedBox(width: 5),
          Text(
            route.via,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DOT de risco nos segmentos críticos
// ═══════════════════════════════════════════════════════════════
class _RiskDot extends StatelessWidget {
  final RiskZone zone;
  const _RiskDot({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: zone.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: zone.color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.warning_amber_rounded,
          color: Colors.white, size: 11),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGET — Mapa de viagem ativa (com carro animado)
// ═══════════════════════════════════════════════════════════════
class MapboxActiveTripMap extends StatefulWidget {
  final bool darkMode;
  final double height;

  const MapboxActiveTripMap({
    super.key,
    this.darkMode = false,
    this.height = 260,
  });

  @override
  State<MapboxActiveTripMap> createState() => _MapboxActiveTripMapState();
}

class _MapboxActiveTripMapState extends State<MapboxActiveTripMap>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _carController;
  late AnimationController _pulseController;

  // Usa a rota equilibrada (Terceira Ponte) para viagem ativa
  late final List<LatLng> _route;

  int _currentSegment = 0;
  LatLng _carPosition = _serraCentro;
  double _carBearing = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Rota ativa — pontos da rota BR-101 (Rápida)
    _route = ESRouteGenerator.buildRouteBR101()
        .expand((s) => s.points)
        .toList();

    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )
      ..addListener(_updateCarPosition)
      ..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _updateCarPosition() {
    if (!mounted) return;
    final seg = _currentSegment % (_route.length - 1);
    final next = seg + 1;
    final t = _carController.value;

    final from = _route[seg];
    final to = _route[next];
    final newLat = from.latitude + (to.latitude - from.latitude) * t;
    final newLng = from.longitude + (to.longitude - from.longitude) * t;

    final dlng = to.longitude - from.longitude;
    final dlat = to.latitude - from.latitude;
    final bearing = (180 / 3.14159) * (3.14159 / 2 - _atan2(dlat, dlng));

    if (mounted) {
      setState(() {
        _carPosition = LatLng(newLat, newLng);
        _carBearing = bearing;
      });
    }

    if (_carController.value >= 1.0) {
      _currentSegment = (_currentSegment + 1) % (_route.length - 1);
      _carController.reset();
      _carController.forward();
    }
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159;
    if (x == 0 && y > 0) return 3.14159 / 2;
    if (x == 0 && y < 0) return -3.14159 / 2;
    return 0;
  }

  double _atan(double x) {
    return x - x * x * x / 3 + x * x * x * x * x / 5;
  }

  @override
  void dispose() {
    _carController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.darkMode ? _mapboxStyleDark : _mapboxStyleStreets;
    // Segmentos coloridos da rota ativa
    final segments = ESRouteGenerator.buildRouteBR101();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _serraCentro,
            initialZoom: 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl(style),
              additionalOptions: const {'accessToken': _mapboxToken},
              tileProvider: NetworkTileProvider(),
              maxZoom: 18,
              userAgentPackageName: 'com.saferoute.insurance',
            ),

            // Rota completa por segmentos de risco
            PolylineLayer(
              polylines: [
                for (final seg in segments)
                  Polyline(
                    points: seg.points,
                    color: seg.zone.color.withValues(alpha: 0.5),
                    strokeWidth: 5,
                  ),
              ],
            ),

            // Trecho percorrido (azul mais espesso)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    ..._route.take(_currentSegment + 1),
                    _carPosition,
                  ],
                  gradientColors: const [AppTheme.primary, AppTheme.accent],
                  colorsStop: const [0.0, 1.0],
                  color: AppTheme.primary,
                  strokeWidth: 5.5,
                ),
              ],
            ),

            // Marcadores
            MarkerLayer(
              markers: [
                // Origem
                Marker(
                  point: _route.first,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.green.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.trip_origin, color: Colors.white, size: 16),
                  ),
                ),
                // Destino
                Marker(
                  point: _route.last,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.red.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 16),
                  ),
                ),
                // Carro animado
                Marker(
                  point: _carPosition,
                  width: 48,
                  height: 48,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Transform.rotate(
                      angle: _carBearing * 3.14159 / 180,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(
                                  alpha: 0.5 * _pulseController.value + 0.2),
                              blurRadius: 12 * _pulseController.value + 4,
                              spreadRadius: 3 * _pulseController.value,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Shield badge
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                      _carPosition.latitude + 0.018,
                      _carPosition.longitude),
                  width: 95,
                  height: 30,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Protegido',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('Mapbox',
                    textStyle: TextStyle(fontSize: 9, color: Colors.grey)),
              ],
              alignment: AttributionAlignment.bottomRight,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Marcadores customizados
// ═══════════════════════════════════════════════════════════════
class _OriginMarker extends StatelessWidget {
  final String label;
  const _OriginMarker({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.green,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 2),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.green.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1)
            ],
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 10),
        ),
      ],
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  final String label;
  final Animation<double> pulseAnim;
  const _DestinationMarker(
      {required this.label, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 2),
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color:
                      AppTheme.primary.withValues(alpha: 0.5 * pulseAnim.value),
                  blurRadius: 10 * pulseAnim.value,
                  spreadRadius: 3 * pulseAnim.value,
                ),
              ],
            ),
            child:
                const Icon(Icons.location_on, color: Colors.white, size: 12),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Mini-mapa (Dashboard / Cards)
// ═══════════════════════════════════════════════════════════════
class MapboxMiniMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final double height;
  final bool darkMode;

  const MapboxMiniMap({
    super.key,
    this.center = _defaultCenter,
    this.zoom = 13,
    this.height = 140,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = darkMode ? _mapboxStyleDark : _mapboxStyleLight;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl(style),
              additionalOptions: const {'accessToken': _mapboxToken},
              tileProvider: NetworkTileProvider(),
              userAgentPackageName: 'com.saferoute.insurance',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: AppTheme.shadowMd,
                    ),
                    child: const Icon(Icons.my_location,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('Mapbox',
                    textStyle: TextStyle(fontSize: 8))
              ],
              alignment: AttributionAlignment.bottomRight,
            ),
          ],
        ),
      ),
    );
  }
}

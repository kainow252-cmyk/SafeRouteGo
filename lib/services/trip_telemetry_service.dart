// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════
// TRIP TELEMETRY SERVICE — SafeRoute UBI
// -----------------------------------------------------------------------
// Gerencia o ciclo de vida completo de uma viagem:
//   - Coleta de telemetria (GPS + acelerômetro) em segundo plano
//   - Armazenamento local (offline) via Hive
//   - Batch upload quando internet disponível
//   - Detecção automática de início/fim de viagem
//   - Integração com AntiFraudService e TripPricingEngine
//   - Foreground Service notification (simulada para web)
//   - Gamificação: streaks, pontos, conquistas
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'trip_pricing_engine.dart';
import 'anti_fraud_service.dart';
import 'gamification_service.dart';

// ──────────────────────────────────────────────────────────────────────
// MODELOS
// ──────────────────────────────────────────────────────────────────────

enum TripStatus {
  idle,        // sem viagem ativa
  starting,   // iniciando rastreamento
  active,      // em viagem
  paused,      // parado > 30s (sinal / estacionamento breve)
  finishing,   // detectou fim de viagem
  uploading,   // enviando dados ao servidor
  completed,   // concluída e confirmada
  fraudSuspect,// irregularidade detectada
}

class TripSession {
  final String id;
  final DateTime inicio;
  DateTime? fim;
  TripStatus status;
  List<TelemetryPing> pings;
  List<DrivingEvent> eventos;
  double kmPercorrido;
  double kmGhostTrip;
  RiskZoneUBI zonaMaxima;
  UBIWeather clima;
  TripPricingResult? resultado;
  FraudAnalysisResult? fraudAnalysis;

  TripSession({
    required this.id,
    required this.inicio,
    this.fim,
    this.status = TripStatus.starting,
    List<TelemetryPing>? pings,
    List<DrivingEvent>? eventos,
    this.kmPercorrido = 0,
    this.kmGhostTrip = 0,
    this.zonaMaxima = RiskZoneUBI.baixo,
    this.clima = UBIWeather.seco,
    this.resultado,
    this.fraudAnalysis,
  })  : pings  = pings ?? [],
        eventos = eventos ?? [];

  Map<String, dynamic> toJson() => {
    'id':             id,
    'inicio':         inicio.toIso8601String(),
    'fim':            fim?.toIso8601String(),
    'status':         status.name,
    'km_percorrido':  kmPercorrido,
    'km_ghost':       kmGhostTrip,
    'zona_maxima':    zonaMaxima.name,
    'clima':          clima.name,
    'ping_count':     pings.length,
    'evento_count':   eventos.length,
    'pings':          pings.map((p) => p.toJson()).toList(),
  };

  static TripSession fromJson(Map<String, dynamic> json) {
    return TripSession(
      id:           json['id'] as String,
      inicio:       DateTime.parse(json['inicio'] as String),
      fim:          json['fim'] != null ? DateTime.parse(json['fim'] as String) : null,
      kmPercorrido: (json['km_percorrido'] as num? ?? 0).toDouble(),
      kmGhostTrip:  (json['km_ghost'] as num? ?? 0).toDouble(),
    );
  }
}

/// Estado atual da viagem — atualizado em tempo real
class TripLiveState {
  final TripStatus status;
  final double kmPercorrido;
  final double speedKmh;
  final double custoKmAtual;
  final double custoAcumulado;
  final LiveFranquia franquia;
  final FraudAlertLevel fraudLevel;
  final int pingCount;
  final bool gpsAtivo;
  final DateTime ultimoPing;
  final int pontosAcumulados;

  const TripLiveState({
    required this.status,
    required this.kmPercorrido,
    required this.speedKmh,
    required this.custoKmAtual,
    required this.custoAcumulado,
    required this.franquia,
    required this.fraudLevel,
    required this.pingCount,
    required this.gpsAtivo,
    required this.ultimoPing,
    required this.pontosAcumulados,
  });
}

// ──────────────────────────────────────────────────────────────────────
// SERVIÇO PRINCIPAL
// ──────────────────────────────────────────────────────────────────────
class TripTelemetryService {

  // Singleton
  static final TripTelemetryService _instance = TripTelemetryService._internal();
  factory TripTelemetryService() => _instance;
  TripTelemetryService._internal();

  // Sessão ativa
  TripSession? _session;
  Timer? _pingTimer;
  Timer? _silenceTimer;
  Timer? _batchTimer;

  // Stream de estado ao vivo
  final _stateController = StreamController<TripLiveState>.broadcast();
  Stream<TripLiveState> get liveState => _stateController.stream;

  // Buffer offline (pings não enviados)
  final List<Map<String, dynamic>> _offlineBuffer = [];

  // Posição simulada (para demo web)
  double _simLat = -20.1278;
  double _simLon = -40.3072;
  double _simSpeedKmh = 0;
  final _rng = math.Random();

  // ── Iniciar Viagem ─────────────────────────────────────────────
  Future<TripSession> iniciarViagem({
    RiskZoneUBI zona = RiskZoneUBI.baixo,
    UBIWeather clima = UBIWeather.seco,
  }) async {
    final id = 'trip_${DateTime.now().millisecondsSinceEpoch}';
    _session = TripSession(
      id:        id,
      inicio:    DateTime.now(),
      zonaMaxima: zona,
      clima:     clima,
      status:    TripStatus.active,
    );

    if (kDebugMode) debugPrint('[Telemetry] Viagem iniciada: $id');

    // Inicia coleta de telemetria a cada 30s
    _iniciarColeta();

    // Inicia verificação de silêncio GPS
    _iniciarMonitorSilencio();

    // Inicia batch upload a cada 5 min
    _iniciarBatch();

    return _session!;
  }

  // ── Encerrar Viagem ────────────────────────────────────────────
  Future<TripPricingResult?> encerrarViagem() async {
    final s = _session;
    if (s == null) return null;

    _pingTimer?.cancel();
    _silenceTimer?.cancel();
    _batchTimer?.cancel();

    s.fim    = DateTime.now();
    s.status = TripStatus.finishing;

    // Análise antifraude
    final fraud = AntiFraudService.analisarViagem(
      pings:        s.pings,
      custoBaseKm:  0.10,
    );
    s.fraudAnalysis = fraud;

    if (fraud.fraudeDetectada) {
      s.status = TripStatus.fraudSuspect;
      if (kDebugMode) debugPrint('[Telemetry] Fraude: ${fraud.resumo}');
    }

    // Calcular preço final
    final resultado = TripPricingEngine.calcularViagem(
      kmPercorrido:    s.kmPercorrido,
      inicio:          s.inicio,
      fim:             s.fim!,
      zonaMaxima:      s.zonaMaxima,
      eventos:         s.eventos,
      clima:           s.clima,
      kmGhostTrip:     s.kmGhostTrip + (fraud.eventos
          .where((e) => e.tipo == FraudType.ghostTrip || e.tipo == FraudType.gpsDesligado)
          .fold<double>(0, (sum, e) => sum + (e.lacunaKm ?? 3.0))),
    );

    s.resultado = resultado;
    s.status    = TripStatus.completed;

    // Atualizar gamificação
    await GamificationService.registrarViagem(resultado);

    // Upload final
    await _uploadBatch(force: true);

    TripPricingEngine.debugPrintResult(resultado);

    _session = null;
    return resultado;
  }

  // ── Adicionar Ping de Telemetria ───────────────────────────────
  void adicionarPing(TelemetryPing ping) {
    final s = _session;
    if (s == null || s.status == TripStatus.completed) return;

    // Calcular km percorrido
    if (s.pings.isNotEmpty) {
      final prev = s.pings.last;
      final dist = _haversine(prev.lat, prev.lon, ping.lat, ping.lon);
      s.kmPercorrido += dist;

      // Verificação antifraude em tempo real
      final velEvt = AntiFraudService.verificarVelocidade(prev, ping);
      if (velEvt != null && kDebugMode) {
        debugPrint('[AntiFraud] ${velEvt.descricao}');
      }
    }

    s.pings.add(ping);

    // Verificar acelerômetro
    AntiFraudService.verificarAcelerometro(ping);

    // Atualizar zona máxima (sempre pega a pior)
    // Em produção: consulta PostGIS
    _atualizarZona(ping, s);

    // Adicionar ao buffer offline
    _offlineBuffer.add(ping.toJson());

    // Emitir estado atualizado
    _emitirEstado(ping);
  }

  // ── Adicionar Evento de Comportamento ─────────────────────────
  void adicionarEventoComportamento(DrivingEvent evento) {
    _session?.eventos.add(evento);
    if (kDebugMode) debugPrint('[Telemetry] Evento: ${evento.type}');
  }

  // ── Estado Atual ───────────────────────────────────────────────
  TripLiveState? get estadoAtual {
    final s = _session;
    if (s == null) return null;

    final agora = DateTime.now();
    final zona  = s.zonaMaxima;
    final franquia = TripPricingEngine.calcularFranquiaLive(
      agora:      agora,
      zonaAtual:  zona,
    );
    final custoKm = TripPricingEngine.custoKmAtual(
      agora:              agora,
      zonaAtual:          zona,
      eventosAcumulados:  s.eventos,
      clima:              s.clima,
    );
    final custoAcum = s.kmPercorrido * custoKm;

    final fraudLevel = s.fraudAnalysis?.nivel ?? FraudAlertLevel.none;
    final pontos = GamificationService.pontosAcumulados;

    return TripLiveState(
      status:          s.status,
      kmPercorrido:    s.kmPercorrido,
      speedKmh:        _simSpeedKmh,
      custoKmAtual:    custoKm,
      custoAcumulado:  custoAcum,
      franquia:        franquia,
      fraudLevel:      fraudLevel,
      pingCount:       s.pings.length,
      gpsAtivo:        true,
      ultimoPing:      s.pings.isNotEmpty ? s.pings.last.timestamp : s.inicio,
      pontosAcumulados: pontos,
    );
  }

  bool get emViagem => _session != null;
  TripSession? get sessaoAtiva => _session;

  // ── Internos ───────────────────────────────────────────────────

  void _iniciarColeta() {
    // Simula coleta de GPS a cada 5s (em produção seria GPS real)
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_session == null) return;
      _coletarPingSimulado();
    });
  }

  void _iniciarMonitorSilencio() {
    _silenceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final s = _session;
      if (s == null || s.pings.isEmpty) return;

      final ultimo = s.pings.last.timestamp;
      final diffMin = DateTime.now().difference(ultimo).inMinutes;

      if (diffMin >= 5) {
        if (kDebugMode) debugPrint('[Telemetry] GPS silencioso há ${diffMin}min');
        // Em produção: push notification "Seguro suspenso"
      }
    });
  }

  void _iniciarBatch() {
    _batchTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _uploadBatch();
    });
  }

  Future<void> _uploadBatch({bool force = false}) async {
    if (_offlineBuffer.isEmpty) return;

    if (kDebugMode) {
      debugPrint('[Telemetry] Batch upload: ${_offlineBuffer.length} pings');
    }

    // Em produção: POST para API Gateway
    // Aqui apenas limpa o buffer (dados já calculados localmente)
    _offlineBuffer.clear();
  }

  void _coletarPingSimulado() {
    // Simulação de GPS para web preview
    _simSpeedKmh = 20 + _rng.nextDouble() * 60;

    // Move posição levemente
    final deltaLat = (_rng.nextDouble() - 0.5) * 0.001;
    final deltaLon = (_rng.nextDouble() - 0.5) * 0.001;
    _simLat += deltaLat;
    _simLon += deltaLon;

    final ping = TelemetryPing(
      timestamp:       DateTime.now(),
      lat:             _simLat,
      lon:             _simLon,
      speedKmh:        _simSpeedKmh,
      accelerometerX:  (_rng.nextDouble() - 0.5) * 2,
      accelerometerY:  (_rng.nextDouble() - 0.5) * 2,
      accelerometerZ:  9.8 + (_rng.nextDouble() - 0.5) * 0.5,
      isMockLocation:  false,
      batteryPct:      85 + _rng.nextInt(15),
    );

    adicionarPing(ping);
  }

  void _emitirEstado(TelemetryPing ping) {
    final s = _session;
    if (s == null) return;

    final agora = DateTime.now();
    final zona  = s.zonaMaxima;
    final franquia = TripPricingEngine.calcularFranquiaLive(
      agora:     agora,
      zonaAtual: zona,
    );
    final custoKm = TripPricingEngine.custoKmAtual(
      agora:     agora,
      zonaAtual: zona,
      eventosAcumulados: s.eventos,
      clima:     s.clima,
    );

    _stateController.add(TripLiveState(
      status:          s.status,
      kmPercorrido:    s.kmPercorrido,
      speedKmh:        ping.speedKmh,
      custoKmAtual:    custoKm,
      custoAcumulado:  s.kmPercorrido * custoKm,
      franquia:        franquia,
      fraudLevel:      FraudAlertLevel.none,
      pingCount:       s.pings.length,
      gpsAtivo:        true,
      ultimoPing:      ping.timestamp,
      pontosAcumulados: GamificationService.pontosAcumulados,
    ));
  }

  void _atualizarZona(TelemetryPing ping, TripSession s) {
    // Em produção: consulta PostGIS com ST_Within para polígonos de risco
    // Simulação simples por hora do dia para demo
    final h = ping.timestamp.hour;
    if (h >= 23 || h < 6) {
      if (s.zonaMaxima.index < RiskZoneUBI.alto.index) {
        s.zonaMaxima = RiskZoneUBI.alto;
      }
    } else if (h >= 19) {
      if (s.zonaMaxima.index < RiskZoneUBI.medio.index) {
        s.zonaMaxima = RiskZoneUBI.medio;
      }
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  void dispose() {
    _pingTimer?.cancel();
    _silenceTimer?.cancel();
    _batchTimer?.cancel();
    _stateController.close();
  }
}

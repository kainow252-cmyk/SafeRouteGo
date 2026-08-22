// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════
// ANTI FRAUD SERVICE — SafeRoute UBI
// -----------------------------------------------------------------------
// Sistema antifraude baseado na especificação do fundador:
//   1. Mock GPS Detection  — isMockProvider() + dev options check
//   2. Velocidade Impossível — Haversine entre pings
//   3. Cruzamento Acelerômetro — GPS × sensor físico
//   4. Ghost Trip Detection — lacuna > 500m entre viagens
//   5. Cobrança por Estimativa — rota MapBox entre gaps
//   6. Controle de KM por Odômetro (validação mensal)
// ═══════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'trip_pricing_engine.dart';

// ──────────────────────────────────────────────────────────────────────
// ENUMS E MODELOS DE FRAUDE
// ──────────────────────────────────────────────────────────────────────

enum FraudType {
  nenhuma,
  mockGps,               // app de localização falsa detectado
  velocidadeImplausivel, // > 220 km/h calculado
  acelerometroIncompativel, // GPS move, accel = zero
  ghostTrip,             // lacuna > 500m entre viagens
  gpsDesligado,          // ping ausente > 5 min em viagem ativa
}

class FraudEvent {
  final DateTime timestamp;
  final FraudType tipo;
  final String descricao;
  final double? velocidadeCalculada;
  final double? lacunaKm;
  final double penalidade; // valor adicional cobrado

  const FraudEvent({
    required this.timestamp,
    required this.tipo,
    required this.descricao,
    this.velocidadeCalculada,
    this.lacunaKm,
    this.penalidade = 0,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'tipo': tipo.name,
    'descricao': descricao,
    'velocidade_calculada': velocidadeCalculada,
    'lacuna_km': lacunaKm,
    'penalidade': penalidade,
  };
}

class FraudAnalysisResult {
  final bool fraudeDetectada;
  final List<FraudEvent> eventos;
  final double penalidadeTotal;
  final String resumo;
  final FraudAlertLevel nivel;

  const FraudAnalysisResult({
    required this.fraudeDetectada,
    required this.eventos,
    required this.penalidadeTotal,
    required this.resumo,
    required this.nivel,
  });
}

// ──────────────────────────────────────────────────────────────────────
// SERVIÇO ANTIFRAUDE
// ──────────────────────────────────────────────────────────────────────
class AntiFraudService {

  // Constantes de validação
  static const double _maxVelocidadeKmh     = 220.0;  // acima = impossível
  static const double _suspiciousVelocidade = 160.0;  // acima = suspeito
  static const double _maxPingSilenceMin    = 5.0;    // minutos sem ping
  static const double _ghostTripTolerancia  = 0.5;    // km — tolerância lacuna
  static const double _ghostMultiplier      = 3.0;    // penalidade ghost km
  static const double _accelZeroThreshold   = 0.5;    // m/s² — "parado" no accel
  static const double _minGpsSpeedForAccel  = 20.0;   // km/h mínimo para cruzar acc

  // ── 1. Verificar Mock GPS ──────────────────────────────────────
  /// No Flutter web/mobile, simula a verificação (na app nativa Android
  /// isto chama LocationManager.isProviderEnabled + isMockProvider())
  static FraudEvent? verificarMockGps(TelemetryPing ping) {
    if (!ping.isMockLocation) return null;

    return FraudEvent(
      timestamp:  ping.timestamp,
      tipo:       FraudType.mockGps,
      descricao:  'Localização simulada detectada (app Mock GPS ativo)',
      penalidade: 50.0, // penalidade fixa por tentativa de fraude
    );
  }

  // ── 2. Verificar Velocidade Impossível ─────────────────────────
  /// Calcula velocidade real entre dois pings GPS consecutivos
  static FraudEvent? verificarVelocidade(TelemetryPing a, TelemetryPing b) {
    final distKm = _haversine(a.lat, a.lon, b.lat, b.lon);
    final diffSec = b.timestamp.difference(a.timestamp).inSeconds.abs();

    if (diffSec == 0) return null;

    final velocidade = (distKm / diffSec) * 3600;

    if (velocidade > _maxVelocidadeKmh) {
      return FraudEvent(
        timestamp:             b.timestamp,
        tipo:                  FraudType.velocidadeImplausivel,
        descricao:             'Velocidade calculada impossível: ${velocidade.toStringAsFixed(0)} km/h',
        velocidadeCalculada:   velocidade,
        penalidade:            distKm * 0.30 * _ghostMultiplier, // cobra km ×3
      );
    }

    if (velocidade > _suspiciousVelocidade) {
      // Suspeito mas não impossível (pode ser estrada)
      if (kDebugMode) {
        debugPrint('[AntiFraud] Velocidade suspeita: ${velocidade.toStringAsFixed(0)} km/h');
      }
    }

    return null;
  }

  // ── 3. Cruzamento Acelerômetro × GPS ──────────────────────────
  /// Se GPS indica movimento > 20km/h mas accel é praticamente zero → fraude
  static FraudEvent? verificarAcelerometro(TelemetryPing ping) {
    final speedGps = ping.speedKmh;
    if (speedGps < _minGpsSpeedForAccel) return null;

    // Magnitude do acelerômetro (sem gravidade)
    // Accel total ≈ sqrt(x²+y²+z²) - quando parado ≈ 9.8 (gravidade pura)
    final accelTotal = math.sqrt(
      ping.accelerometerX * ping.accelerometerX +
      ping.accelerometerY * ping.accelerometerY +
      ping.accelerometerZ * ping.accelerometerZ,
    );

    // Se apenas gravidade presente (9.8 ±0.5), o aparelho está completamente parado
    final accelSemGravidade = (accelTotal - 9.81).abs();

    if (accelSemGravidade < _accelZeroThreshold && speedGps > _minGpsSpeedForAccel) {
      return FraudEvent(
        timestamp: ping.timestamp,
        tipo: FraudType.acelerometroIncompativel,
        descricao:
            'GPS indica ${speedGps.toStringAsFixed(0)} km/h, '
            'mas acelerômetro indica aparelho parado (Δacc=${accelSemGravidade.toStringAsFixed(2)})',
        penalidade: 20.0,
      );
    }

    return null;
  }

  // ── 4. Ghost Trip Detection ───────────────────────────────────
  /// Detecta se o veículo se moveu com GPS desligado entre viagens
  /// Tolerância: 500m (movimento natural — estacionamento, etc.)
  static FraudEvent? detectarGhostTrip({
    required TelemetryPing fimViagemAnterior,
    required TelemetryPing inicioNovaViagem,
    required double custoBaseKm,
  }) {
    final lacunaKm = _haversine(
      fimViagemAnterior.lat, fimViagemAnterior.lon,
      inicioNovaViagem.lat, inicioNovaViagem.lon,
    );

    if (lacunaKm <= _ghostTripTolerancia) return null;

    // km ghost cobrados com multiplicador ×3
    final kmCobrado  = lacunaKm * _ghostMultiplier;
    final penalidade = kmCobrado * custoBaseKm * 1.6; // fator alto risco

    return FraudEvent(
      timestamp: inicioNovaViagem.timestamp,
      tipo:      FraudType.ghostTrip,
      descricao: 'Lacuna GPS de ${lacunaKm.toStringAsFixed(2)} km. '
          '${lacunaKm.toStringAsFixed(1)} km × 3 cobrado automaticamente.',
      lacunaKm:  lacunaKm,
      penalidade: penalidade,
    );
  }

  // ── 5. Verificar Silêncio do GPS ──────────────────────────────
  /// Detecta ausência de ping por mais de 5 minutos durante viagem ativa
  static FraudEvent? verificarSilencioGps({
    required DateTime ultimoPing,
    required DateTime agora,
    required double custoBaseKm,
    double kmEstimado = 5.0, // estimativa conservadora quando não sabe
  }) {
    final diffMin = agora.difference(ultimoPing).inMinutes.toDouble();
    if (diffMin < _maxPingSilenceMin) return null;

    final kmGhost = kmEstimado * _ghostMultiplier;
    final penalidade = kmGhost * custoBaseKm * 1.6;

    return FraudEvent(
      timestamp: agora,
      tipo:      FraudType.gpsDesligado,
      descricao: 'GPS desligado por ${diffMin.toStringAsFixed(0)} min. '
          '${kmEstimado.toStringAsFixed(1)} km estimado cobrado × 3.',
      penalidade: penalidade,
    );
  }

  // ── Análise completa de uma sequência de pings ────────────────
  /// Analisa toda a telemetria da viagem em busca de fraudes
  static FraudAnalysisResult analisarViagem({
    required List<TelemetryPing> pings,
    required double custoBaseKm,
  }) {
    final eventos = <FraudEvent>[];

    for (int i = 0; i < pings.length; i++) {
      final ping = pings[i];

      // Mock GPS
      final mockEvt = verificarMockGps(ping);
      if (mockEvt != null) eventos.add(mockEvt);

      // Velocidade impossível (entre pings consecutivos)
      if (i > 0) {
        final velEvt = verificarVelocidade(pings[i - 1], ping);
        if (velEvt != null) eventos.add(velEvt);

        // Silêncio GPS (gap grande entre pings)
        final gapMin = ping.timestamp.difference(pings[i - 1].timestamp).inMinutes;
        if (gapMin >= _maxPingSilenceMin.round()) {
          final silEvt = verificarSilencioGps(
            ultimoPing:   pings[i - 1].timestamp,
            agora:        ping.timestamp,
            custoBaseKm:  custoBaseKm,
            kmEstimado:   _haversine(
              pings[i - 1].lat, pings[i - 1].lon,
              ping.lat, ping.lon,
            ),
          );
          if (silEvt != null) eventos.add(silEvt);
        }
      }

      // Acelerômetro × GPS
      final accEvt = verificarAcelerometro(ping);
      if (accEvt != null) eventos.add(accEvt);
    }

    final penalidadeTotal = eventos.fold<double>(0, (s, e) => s + e.penalidade);
    final fraudeDetectada = eventos.isNotEmpty;

    FraudAlertLevel nivel;
    if (!fraudeDetectada) {
      nivel = FraudAlertLevel.none;
    } else if (eventos.any((e) =>
        e.tipo == FraudType.mockGps || e.tipo == FraudType.velocidadeImplausivel)) {
      nivel = FraudAlertLevel.confirmed;
    } else {
      nivel = FraudAlertLevel.suspicious;
    }

    final resumo = fraudeDetectada
        ? '${eventos.length} ocorrência(s) antifraude — penalidade: R\$ ${penalidadeTotal.toStringAsFixed(2)}'
        : 'Viagem válida — nenhuma irregularidade detectada';

    return FraudAnalysisResult(
      fraudeDetectada: fraudeDetectada,
      eventos:         eventos,
      penalidadeTotal: penalidadeTotal,
      resumo:          resumo,
      nivel:           nivel,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
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

  /// Retorna mensagem amigável para o usuário sobre o status
  static String mensagemStatus(FraudAlertLevel nivel) {
    switch (nivel) {
      case FraudAlertLevel.none:
        return '✅ Rastreamento normal — sem anomalias';
      case FraudAlertLevel.suspicious:
        return '⚠️ Comportamento incomum detectado — verificando...';
      case FraudAlertLevel.confirmed:
        return '🚫 Irregularidade confirmada — cobertura suspensa';
    }
  }
}

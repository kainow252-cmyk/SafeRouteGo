// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════
// MOTOR UBI — SafeRoute Pay-Per-Mile Engine v1.0
// -----------------------------------------------------------------------
// Fórmula base (spec do fundador):
//   Prêmio Total = Taxa Fixa + Σ( KM × CustoBase × FatorRisco )
//
// FatorRisco = FatorHorario × FatorLocalizacao × FatorComportamento × FatorClima
//
// FatorHorario:
//   06–19h  Comercial   → 1.0
//   19–23h  Noite       → 1.2
//   23–06h  Madrugada   → 1.5  (até 1.8 com zona vermelha)
//
// FatorLocalizacao (geofencing):
//   Baixo risco         → 1.0
//   Médio risco         → 1.25
//   Alto risco          → 1.6
//
// FatorComportamento (telemetria):
//   Sem eventos         → 1.0
//   Frenagem brusca     → +0.05 por evento
//   Excesso velocidade  → +0.10 por evento
//
// FatorClima:
//   Seco                → 1.0
//   Chuva moderada      → +0.1
//   Tempestade          → +0.2
//
// Franquia dinâmica:
//   Franquia = FranquiaBase × FatorHorario × FatorLocalizacao
//
// Ghost Trip (lacuna GPS > 500m):
//   KM estimado cobrado × 3  (multiplicador de fraude)
// ═══════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

// ──────────────────────────────────────────────────────────────────────
// ENUMS
// ──────────────────────────────────────────────────────────────────────

enum RiskZoneUBI {
  baixo,   // bairro residencial policiado
  medio,   // centro urbano comercial
  alto,    // área com altos índices de roubo/furto
}

enum UBIWeather {
  seco,
  chuvaLeve,
  chuvaForte,   // +0.2
}

enum FraudAlertLevel {
  none,
  suspicious,   // velocidade impossível
  confirmed,    // mock GPS detectado
}

// ──────────────────────────────────────────────────────────────────────
// MODELOS
// ──────────────────────────────────────────────────────────────────────

/// Ponto de telemetria — enviado a cada ~30s
class TelemetryPing {
  final DateTime timestamp;
  final double lat;
  final double lon;
  final double speedKmh;
  final double accelerometerX;
  final double accelerometerY;
  final double accelerometerZ;
  final bool isMockLocation;
  final int batteryPct;

  const TelemetryPing({
    required this.timestamp,
    required this.lat,
    required this.lon,
    required this.speedKmh,
    this.accelerometerX = 0,
    this.accelerometerY = 0,
    this.accelerometerZ = 9.8,
    this.isMockLocation = false,
    this.batteryPct = 100,
  });

  Map<String, dynamic> toJson() => {
    'ts': timestamp.toIso8601String(),
    'lat': lat,
    'lon': lon,
    'speed_kmh': speedKmh,
    'acc_x': accelerometerX,
    'acc_y': accelerometerY,
    'acc_z': accelerometerZ,
    'mock': isMockLocation,
    'battery': batteryPct,
  };
}

/// Evento de comportamento do motorista
class DrivingEvent {
  final DateTime timestamp;
  final String type;    // 'frenagem_brusca' | 'curva_acentuada' | 'excesso_velocidade'
  final double severity; // 0.0–1.0

  const DrivingEvent({
    required this.timestamp,
    required this.type,
    required this.severity,
  });
}

/// Resultado de preço por segmento de km
class KmSegmentPrice {
  final double km;
  final double custoBase;
  final double fatorHorario;
  final double fatorLocalizacao;
  final double fatorComportamento;
  final double fatorClima;
  final double fatorFinal;
  final double custo;
  final bool isGhostTrip;

  const KmSegmentPrice({
    required this.km,
    required this.custoBase,
    required this.fatorHorario,
    required this.fatorLocalizacao,
    required this.fatorComportamento,
    required this.fatorClima,
    required this.fatorFinal,
    required this.custo,
    this.isGhostTrip = false,
  });

  double get custoKm => custoBase * fatorFinal;
}

/// Resultado completo de uma viagem
class TripPricingResult {
  final double taxaFixa;
  final double totalKmCobrado;
  final double custoVariavel;
  final double premioTotal;
  final double franquiaAplicada;
  final double franquiaBase;
  final List<KmSegmentPrice> segmentos;
  final double fatorHorarioMedio;
  final double fatorLocalizacaoMax;   // pior zona da rota
  final double fatorComportamento;
  final double fatorClima;
  final bool ghostTripDetected;
  final double ghostKmCobrado;
  final String resumo;
  final List<String> alertas;
  final DriverScore scoreViagem;

  const TripPricingResult({
    required this.taxaFixa,
    required this.totalKmCobrado,
    required this.custoVariavel,
    required this.premioTotal,
    required this.franquiaAplicada,
    required this.franquiaBase,
    required this.segmentos,
    required this.fatorHorarioMedio,
    required this.fatorLocalizacaoMax,
    required this.fatorComportamento,
    required this.fatorClima,
    required this.ghostTripDetected,
    required this.ghostKmCobrado,
    required this.resumo,
    required this.alertas,
    required this.scoreViagem,
  });
}

/// Score do motorista (gamificação)
class DriverScore {
  final int pontosGanhos;
  final int nivel;          // 1–5 estrelas
  final String classificacao; // 'Excelente' | 'Bom' | 'Regular' | 'Ruim'
  final double descontoMensalidade; // 0–10%
  final List<String> conquistas;

  const DriverScore({
    required this.pontosGanhos,
    required this.nivel,
    required this.classificacao,
    required this.descontoMensalidade,
    required this.conquistas,
  });
}

/// Franquia em tempo real (exibida durante a viagem)
class LiveFranquia {
  final double valor;
  final double franquiaBase;
  final double fatorHorario;
  final double fatorLocalizacao;
  final RiskZoneUBI zonaAtual;
  final String corSemaforo; // 'verde' | 'amarelo' | 'vermelho'
  final String mensagem;
  final String? dica;

  const LiveFranquia({
    required this.valor,
    required this.franquiaBase,
    required this.fatorHorario,
    required this.fatorLocalizacao,
    required this.zonaAtual,
    required this.corSemaforo,
    required this.mensagem,
    this.dica,
  });
}

// ──────────────────────────────────────────────────────────────────────
// MOTOR PRINCIPAL
// ──────────────────────────────────────────────────────────────────────
class TripPricingEngine {

  // ── Constantes padrão ──────────────────────────────────────────
  static const double _taxaFixaMensal    = 60.00;  // R$ taxa fixa mensal
  static const double _custoBaseKm       = 0.10;   // R$ por km base
  static const double _franquiaBase      = 3000.00; // R$ franquia base
  static const double _ghostMultiplier   = 3.0;    // penalidade ghost trip
  static const double _maxVelocidadeKmh  = 220.0;  // acima = fraude

  // ── Fatores Horário ────────────────────────────────────────────
  static double fatorHorario(DateTime dt) {
    final h = dt.hour;
    if (h >= 6 && h < 19)  return 1.0;  // Comercial
    if (h >= 19 && h < 23) return 1.2;  // Noite
    return 1.5;                          // Madrugada (23–06)
  }

  static String labelHorario(DateTime dt) {
    final h = dt.hour;
    if (h >= 6 && h < 19)  return 'Comercial';
    if (h >= 19 && h < 23) return 'Noite';
    return 'Madrugada';
  }

  // ── Fatores Localização ────────────────────────────────────────
  static double fatorLocalizacao(RiskZoneUBI zona) {
    switch (zona) {
      case RiskZoneUBI.baixo: return 1.0;
      case RiskZoneUBI.medio: return 1.25;
      case RiskZoneUBI.alto:  return 1.6;
    }
  }

  static String labelZona(RiskZoneUBI zona) {
    switch (zona) {
      case RiskZoneUBI.baixo: return 'Baixo Risco';
      case RiskZoneUBI.medio: return 'Médio Risco';
      case RiskZoneUBI.alto:  return 'Alto Risco';
    }
  }

  // ── Fator Clima ────────────────────────────────────────────────
  static double fatorClima(UBIWeather clima) {
    switch (clima) {
      case UBIWeather.seco:        return 1.0;
      case UBIWeather.chuvaLeve:   return 1.1;
      case UBIWeather.chuvaForte:  return 1.2;
    }
  }

  static String labelClima(UBIWeather clima) {
    switch (clima) {
      case UBIWeather.seco:        return 'Tempo seco';
      case UBIWeather.chuvaLeve:   return 'Chuva leve';
      case UBIWeather.chuvaForte:  return 'Tempestade';
    }
  }

  // ── Fator Comportamento ────────────────────────────────────────
  /// Calcula fator de comportamento baseado em eventos de telemetria
  static double fatorComportamento(List<DrivingEvent> eventos) {
    if (eventos.isEmpty) return 1.0;
    double adicional = 0.0;
    for (final e in eventos) {
      switch (e.type) {
        case 'frenagem_brusca':    adicional += 0.05 * e.severity; break;
        case 'curva_acentuada':    adicional += 0.03 * e.severity; break;
        case 'excesso_velocidade': adicional += 0.10 * e.severity; break;
      }
    }
    // Cap: máximo +0.5 (muito perigoso)
    return (1.0 + adicional).clamp(1.0, 1.5);
  }

  // ── Franquia em Tempo Real ─────────────────────────────────────
  /// Calcula e retorna franquia atual da viagem para exibição na tela
  static LiveFranquia calcularFranquiaLive({
    required DateTime agora,
    required RiskZoneUBI zonaAtual,
    double franquiaBaseCustom = _franquiaBase,
  }) {
    final fH = fatorHorario(agora);
    final fL = fatorLocalizacao(zonaAtual);
    final valor = franquiaBaseCustom * fH * fL;

    // Semáforo: verde ≤ 3500, amarelo ≤ 5000, vermelho > 5000
    final String cor;
    final String msg;
    String? dica;

    if (valor <= _franquiaBase * 1.1) {
      cor = 'verde';
      msg = 'Franquia mínima garantida';
    } else if (valor <= _franquiaBase * 1.5) {
      cor = 'amarelo';
      msg = 'Franquia moderada — atenção';
      // Sugere esperar se for madrugada
      final h = agora.hour;
      if (h >= 23 || h < 6) {
        dica = 'Se você esperar até as 06h, sua franquia cai para R\$ ${_fmt(_franquiaBase * 1.0 * fL)}';
      }
    } else {
      cor = 'vermelho';
      msg = 'Franquia elevada — zona de risco';
      if (fL > 1.0) {
        dica = 'Evite esta região para reduzir sua franquia';
      }
    }

    return LiveFranquia(
      valor:             valor,
      franquiaBase:      franquiaBaseCustom,
      fatorHorario:      fH,
      fatorLocalizacao:  fL,
      zonaAtual:         zonaAtual,
      corSemaforo:       cor,
      mensagem:          msg,
      dica:              dica,
    );
  }

  // ── Cálculo completo da viagem ─────────────────────────────────
  /// Calcula preço final da viagem com todos os fatores
  static TripPricingResult calcularViagem({
    required double kmPercorrido,
    required DateTime inicio,
    required DateTime fim,
    required RiskZoneUBI zonaMaxima,   // pior zona da rota
    List<DrivingEvent> eventos = const [],
    UBIWeather clima = UBIWeather.seco,
    double kmGhostTrip = 0,           // km com GPS desligado
    double taxaFixaCustom = _taxaFixaMensal,
    double custoBaseCustom = _custoBaseKm,
    double franquiaBaseCustom = _franquiaBase,
  }) {
    final alertas = <String>[];

    // Fator horário: usa o horário de início
    final fH = fatorHorario(inicio);
    final fL = fatorLocalizacao(zonaMaxima);
    final fC = fatorComportamento(eventos);
    final fCl = fatorClima(clima);

    // Ghost trip detection
    bool ghostDetected = kmGhostTrip > 0.5;
    double kmGhostCobrado = 0;
    if (ghostDetected) {
      kmGhostCobrado = kmGhostTrip * _ghostMultiplier;
      alertas.add('⚠️ Lacuna GPS detectada: ${kmGhostTrip.toStringAsFixed(1)} km cobrados com multa ×3');
    }

    // Fator final combinado
    final fFinal = fH * fL * fC * fCl;

    // Custo variável normal
    final custoNormal = kmPercorrido * custoBaseCustom * fFinal;

    // Custo ghost trip (penalidade)
    final custoGhost = ghostDetected
        ? kmGhostCobrado * custoBaseCustom * fFinal
        : 0.0;

    final custoVariavel = custoNormal + custoGhost;
    final premioTotal = taxaFixaCustom / 30 + custoVariavel; // taxa fixa proporcional ao dia

    // Franquia calculada para esta viagem
    final franquia = franquiaBaseCustom * fH * fL;

    // Alertas por comportamento
    if (eventos.isNotEmpty) {
      final frenagens = eventos.where((e) => e.type == 'frenagem_brusca').length;
      final excessos  = eventos.where((e) => e.type == 'excesso_velocidade').length;
      if (frenagens > 0) alertas.add('$frenagens frenagem(ns) brusca(s) registrada(s)');
      if (excessos > 0)  alertas.add('$excessos excesso(s) de velocidade registrado(s)');
    }

    if (clima == UBIWeather.chuvaForte) {
      alertas.add('🌧️ Tarifa de chuva aplicada (+20%)');
    }

    final labelH  = labelHorario(inicio);
    final labelZ  = labelZona(zonaMaxima);
    final labelCl = labelClima(clima);

    // Segmentos (simplificado: 1 segmento por viagem no MVP)
    final segmentos = [
      KmSegmentPrice(
        km:               kmPercorrido,
        custoBase:        custoBaseCustom,
        fatorHorario:     fH,
        fatorLocalizacao: fL,
        fatorComportamento: fC,
        fatorClima:       fCl,
        fatorFinal:       fFinal,
        custo:            custoNormal,
      ),
      if (ghostDetected) KmSegmentPrice(
        km:               kmGhostCobrado,
        custoBase:        custoBaseCustom,
        fatorHorario:     fH,
        fatorLocalizacao: fL,
        fatorComportamento: fC,
        fatorClima:       fCl,
        fatorFinal:       fFinal,
        custo:            custoGhost.toDouble(),
        isGhostTrip:      true,
      ),
    ];

    // Score do motorista
    final score = _calcularScore(
      kmPercorrido: kmPercorrido,
      eventos:      eventos,
      zonaMaxima:   zonaMaxima,
      ghostTrip:    ghostDetected,
    );

    final resumo = '$labelH · $labelZ · $labelCl\n'
        'R\$ ${_fmt(custoBaseCustom)} × fator ${fFinal.toStringAsFixed(2)} = R\$ ${_fmt(custoNormal)}/viagem\n'
        'Franquia desta viagem: R\$ ${_fmt(franquia)}';

    return TripPricingResult(
      taxaFixa:             taxaFixaCustom / 30,
      totalKmCobrado:       kmPercorrido + kmGhostCobrado,
      custoVariavel:        custoVariavel,
      premioTotal:          premioTotal,
      franquiaAplicada:     franquia,
      franquiaBase:         franquiaBaseCustom,
      segmentos:            segmentos,
      fatorHorarioMedio:    fH,
      fatorLocalizacaoMax:  fL,
      fatorComportamento:   fC,
      fatorClima:           fCl,
      ghostTripDetected:    ghostDetected,
      ghostKmCobrado:       kmGhostCobrado,
      resumo:               resumo,
      alertas:              alertas,
      scoreViagem:          score,
    );
  }

  // ── Score / Gamificação ────────────────────────────────────────
  static DriverScore _calcularScore({
    required double kmPercorrido,
    required List<DrivingEvent> eventos,
    required RiskZoneUBI zonaMaxima,
    required bool ghostTrip,
  }) {
    // Pontos base: 1 ponto por km
    int pontos = kmPercorrido.round();

    // Penalidades
    final frenagens = eventos.where((e) => e.type == 'frenagem_brusca').length;
    final excessos  = eventos.where((e) => e.type == 'excesso_velocidade').length;
    pontos -= frenagens * 5;
    pontos -= excessos * 10;
    if (ghostTrip) pontos -= 50;   // penalidade ghost trip

    // Bônus: sem eventos = direção perfeita
    if (eventos.isEmpty && !ghostTrip) pontos += (kmPercorrido * 0.5).round();

    pontos = pontos.clamp(0, 9999);

    // Classificação
    final int nivel;
    final String classif;
    if (eventos.isEmpty && !ghostTrip) {
      nivel = 5; classif = 'Excelente';
    } else if (frenagens <= 1 && excessos == 0 && !ghostTrip) {
      nivel = 4; classif = 'Bom';
    } else if (frenagens <= 3 && excessos <= 1 && !ghostTrip) {
      nivel = 3; classif = 'Regular';
    } else if (ghostTrip) {
      nivel = 1; classif = 'Irregular';
    } else {
      nivel = 2; classif = 'Ruim';
    }

    // Desconto na mensalidade (apenas para motoristas nível 5 com GPS 100%)
    final desconto = nivel == 5 ? 10.0 : nivel == 4 ? 5.0 : 0.0;

    // Conquistas
    final conquistas = <String>[];
    if (eventos.isEmpty && !ghostTrip) conquistas.add('🏆 Viagem Perfeita');
    if (kmPercorrido >= 50)            conquistas.add('🚀 Longa Distância');
    if (zonaMaxima == RiskZoneUBI.alto && !ghostTrip) conquistas.add('🛡️ Zona de Risco Superada');

    return DriverScore(
      pontosGanhos:        pontos,
      nivel:               nivel,
      classificacao:       classif,
      descontoMensalidade: desconto,
      conquistas:          conquistas,
    );
  }

  // ── Detecção de Fraude por Velocidade ─────────────────────────
  /// Retorna true se a velocidade calculada entre dois pings é fisicamente impossível
  static FraudAlertLevel verificarVelocidade({
    required TelemetryPing a,
    required TelemetryPing b,
  }) {
    // Se mock GPS já detectado
    if (b.isMockLocation) return FraudAlertLevel.confirmed;

    final distKm = _haversineKm(a.lat, a.lon, b.lat, b.lon);
    final diffSec = b.timestamp.difference(a.timestamp).inSeconds.abs();
    if (diffSec == 0) return FraudAlertLevel.none;

    final velocidadeCalculada = (distKm / diffSec) * 3600;

    if (velocidadeCalculada > _maxVelocidadeKmh) {
      return FraudAlertLevel.confirmed;
    }
    if (velocidadeCalculada > 180) {
      return FraudAlertLevel.suspicious;
    }
    return FraudAlertLevel.none;
  }

  /// Detecta ghost trip: distância entre fim da viagem A e início da viagem B
  static double calcularLacunaKm({
    required TelemetryPing fimViagemA,
    required TelemetryPing inicioViagemB,
  }) {
    return _haversineKm(
      fimViagemA.lat, fimViagemA.lon,
      inicioViagemB.lat, inicioViagemB.lon,
    );
  }

  // ── Custo estimado por KM atual (para exibição live) ──────────
  static double custoKmAtual({
    required DateTime agora,
    required RiskZoneUBI zonaAtual,
    List<DrivingEvent> eventosAcumulados = const [],
    UBIWeather clima = UBIWeather.seco,
    double custoBaseCustom = _custoBaseKm,
  }) {
    final fH  = fatorHorario(agora);
    final fL  = fatorLocalizacao(zonaAtual);
    final fC  = fatorComportamento(eventosAcumulados);
    final fCl = fatorClima(clima);
    return custoBaseCustom * fH * fL * fC * fCl;
  }

  // ── Previsão de custo da rota ──────────────────────────────────
  static double previsaoCustoRota({
    required double kmEstimado,
    required DateTime saidaPrevista,
    required RiskZoneUBI zonaEstimada,
    UBIWeather clima = UBIWeather.seco,
    double taxaFixaCustom = _taxaFixaMensal,
    double custoBaseCustom = _custoBaseKm,
  }) {
    final fH  = fatorHorario(saidaPrevista);
    final fL  = fatorLocalizacao(zonaEstimada);
    final fCl = fatorClima(clima);
    return (taxaFixaCustom / 30) + kmEstimado * custoBaseCustom * fH * fL * fCl;
  }

  // ── Helpers ────────────────────────────────────────────────────
  static String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  /// Distância Haversine em km entre dois pontos GPS
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // raio da Terra em km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  /// Debug: imprime resumo do cálculo
  static void debugPrintResult(TripPricingResult r) {
    if (!kDebugMode) return;
    debugPrint('══════ UBI Pricing Result ══════');
    debugPrint('Total KM cobrado: ${r.totalKmCobrado.toStringAsFixed(2)} km');
    debugPrint('Taxa fixa (dia): R\$ ${_fmt(r.taxaFixa)}');
    debugPrint('Custo variável:  R\$ ${_fmt(r.custoVariavel)}');
    debugPrint('Prêmio total:    R\$ ${_fmt(r.premioTotal)}');
    debugPrint('Franquia:        R\$ ${_fmt(r.franquiaAplicada)}');
    debugPrint('Score:           ${r.scoreViagem.nivel}⭐ ${r.scoreViagem.classificacao}');
    debugPrint('Alertas: ${r.alertas.join(' | ')}');
    debugPrint('════════════════════════════════');
  }
}

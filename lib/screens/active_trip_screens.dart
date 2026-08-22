import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/risk_engine.dart';
import '../widgets/mapbox_map_widget.dart';
import '../services/trip_pricing_engine.dart';
import '../services/trip_telemetry_service.dart';
import '../widgets/franquia_card_widget.dart';
import '../services/location_service.dart';
import '../services/overpass_api_service.dart';
import '../services/osrm_route_service.dart';

// ══════════════════════════════════════════════════════════════
// ESTADO DA VIAGEM
// ══════════════════════════════════════════════════════════════
enum TripPhase {
  aguardando,  // carro parado, proteção ativa mas não contando
  emViagem,    // carro em movimento — conta km, tempo, velocidade
  pausado,     // parou em sinal (velocidade caiu a zero)
  concluida,   // chegou ao destino
}

// Tipos de manobra GPS
enum _Manobra { reto, direitaLeve, direitaForte, esquerdaLeve, esquerdaForte, retorno, destino }

extension _ManobraExt on _Manobra {
  IconData get icon {
    switch (this) {
      case _Manobra.reto:          return Icons.straight_rounded;
      case _Manobra.direitaLeve:   return Icons.turn_slight_right_rounded;
      case _Manobra.direitaForte:  return Icons.turn_right_rounded;
      case _Manobra.esquerdaLeve:  return Icons.turn_slight_left_rounded;
      case _Manobra.esquerdaForte: return Icons.turn_left_rounded;
      case _Manobra.retorno:       return Icons.u_turn_left_rounded;
      case _Manobra.destino:       return Icons.location_on_rounded;
    }
  }
  String get label {
    switch (this) {
      case _Manobra.reto:          return 'Siga em frente';
      case _Manobra.direitaLeve:   return 'Vire levemente à direita';
      case _Manobra.direitaForte:  return 'Vire à direita';
      case _Manobra.esquerdaLeve:  return 'Vire levemente à esquerda';
      case _Manobra.esquerdaForte: return 'Vire à esquerda';
      case _Manobra.retorno:       return 'Faça o retorno';
      case _Manobra.destino:       return 'Chegando ao destino';
    }
  }
}

// Segmentos com velocidade máxima, manobra e distância
class _RoadSegment {
  final String name;           // nome da via
  final int speedLimitKmh;     // limite da via
  final int avgSpeedKmh;       // velocidade média real
  final RiskZone zone;
  final _Manobra proximaManobra;   // o que fazer AO SAIR deste segmento
  final double distProxManobra;    // em km até a próxima manobra

  const _RoadSegment(this.name, this.speedLimitKmh, this.avgSpeedKmh,
      this.zone, this.proximaManobra, this.distProxManobra);
}

const List<_RoadSegment> _roadSegments = [
  _RoadSegment('Rua Coronel Borges',    40,  25, RiskZone.amarela,  _Manobra.direitaForte,  0.6),
  _RoadSegment('Av. Norte-Sul',         60,  45, RiskZone.amarela,  _Manobra.reto,          2.1),
  _RoadSegment('Acesso BR-101',         60,  50, RiskZone.amarela,  _Manobra.direitaLeve,   0.8),
  _RoadSegment('BR-101 Norte km 270',   80,  72, RiskZone.amarela,  _Manobra.reto,          4.5),
  _RoadSegment('BR-101 km 265',        100,  87, RiskZone.laranja,  _Manobra.reto,          5.2),
  _RoadSegment('BR-101 André Carloni', 100,  68, RiskZone.laranja,  _Manobra.esquerdaForte, 3.1),
  _RoadSegment('Contorno de Vitória',   60,  41, RiskZone.vermelha, _Manobra.esquerdaLeve,  2.4),
  _RoadSegment('Av. Marechal Mascarenhas', 60, 38, RiskZone.laranja, _Manobra.direitaForte, 1.8),
  _RoadSegment('Av. Jerônimo Monteiro', 40,  22, RiskZone.laranja,  _Manobra.destino,       1.0),
];

// ══════════════════════════════════════════════════════════════
// VIAGEM ATIVA
// ══════════════════════════════════════════════════════════════
class ActiveTripScreen extends StatefulWidget {
  final VoidCallback onEmergency;
  final VoidCallback onEnd;
  final VoidCallback onAI;

  const ActiveTripScreen({super.key, required this.onEmergency, required this.onEnd, required this.onAI});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with TickerProviderStateMixin {
  // ── Estado principal ─────────────────────────────────────────
  TripPhase _phase = TripPhase.aguardando;
  Timer? _mainTimer;
  Timer? _countdownTimer;

  // Contadores
  int _tripSeconds = 0;       // tempo em viagem
  int _waitSeconds = 0;       // tempo aguardando (uso interno)
  double _kmPercorrido = 0.0; // km percorrido real
  double _kmTotal = 27.5;     // km total da rota escolhida

  // Velocidade simulada
  int _speedKmh = 0;
  int _speedLimitKmh = 40;    // limite da via atual
  _RoadSegment _currentSegment = _roadSegments[0];
  int _segmentIndex = 0;

  // Countdown para sair
  int _countdown = 5;
  bool _showCountdown = true;

  // Variações de velocidade
  final _rng = math.Random();
  int _speedVariation = 0;

  // Animações
  late AnimationController _pulseCtrl;
  late AnimationController _speedCtrl;

  // ── UBI / Franquia em tempo real ─────────────────────────────
  bool _franquiaExpanded = false;
  RiskZoneUBI _zonaAtual = RiskZoneUBI.baixo;
  UBIWeather _climaAtual = UBIWeather.seco;

  LiveFranquia get _franquiaLive => TripPricingEngine.calcularFranquiaLive(
    agora:     DateTime.now(),
    zonaAtual: _zonaAtual,
  );

  double get _custoKmAtual => TripPricingEngine.custoKmAtual(
    agora:     DateTime.now(),
    zonaAtual: _zonaAtual,
    clima:     _climaAtual,
  );

  // Valor acumulado UBI (substitui o cálculo fixo anterior)
  double get _tripValue {
    if (_kmPercorrido < 0.1) return 0;
    return _kmPercorrido * _custoKmAtual + 60.0 / 30; // km×custo + taxa fixa diária
  }
  double get _progress => (_kmPercorrido / _kmTotal).clamp(0.0, 1.0);

  // Velocidade com variação natural
  int get _displaySpeed => (_speedKmh + _speedVariation).clamp(0, _speedLimitKmh + 15);

  // ── GPS: ETA e km restante ───────────────────────────────────
  double get _kmRestante => (_kmTotal - _kmPercorrido).clamp(0.0, _kmTotal);

  /// Tempo estimado de chegada (ETA) baseado na velocidade média atual
  String get _eta {
    final speedAtual = _displaySpeed > 5 ? _displaySpeed : _currentSegment.avgSpeedKmh;
    if (speedAtual < 1) return '--:--';
    final horasRestantes = _kmRestante / speedAtual;
    final minutosRestantes = (horasRestantes * 60).round();
    final agora = DateTime.now();
    final chegada = agora.add(Duration(minutes: minutosRestantes));
    final h = chegada.hour.toString().padLeft(2, '0');
    final m = chegada.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Tempo restante legível (ex: "18 min", "1h 12min")
  String get _tempoRestante {
    final speedAtual = _displaySpeed > 5 ? _displaySpeed : _currentSegment.avgSpeedKmh;
    if (speedAtual < 1) return '--';
    final mins = (_kmRestante / speedAtual * 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}min';
  }

  /// Distância até a próxima manobra, descontando o já percorrido no segmento
  String get _distProxManobra {
    final kmNoSeg = _kmPercorrido - (_segmentIndex / _roadSegments.length * _kmTotal);
    final restante = (_currentSegment.distProxManobra - kmNoSeg.abs()).clamp(0.0, _currentSegment.distProxManobra);
    if (restante < 0.1) return 'Agora';
    if (restante < 1.0) return '${(restante * 1000).round()} m';
    return '${restante.toStringAsFixed(1)} km';
  }

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _speedCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  // _speedAnim declarada mas não usada diretamente — mantida para extensão futura

    // Inicia countdown de 5s e timer de espera
    _startWaitingPhase();
  }

  void _startWaitingPhase() {
    _phase = TripPhase.aguardando;
    _countdown = 5;

    // Timer do contador regressivo
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _waitSeconds++;
        _countdown--;
        if (_countdown <= 0) {
          t.cancel();
          _startTripPhase();
        }
      });
    });
  }

  void _startTripPhase() {
    _phase = TripPhase.emViagem;
    _showCountdown = false;
    _segmentIndex = 0;
    _currentSegment = _roadSegments[0];
    _speedKmh = 0;

    // Acelera gradualmente ao sair
    _animateSpeedTo(_currentSegment.avgSpeedKmh);

    _mainTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _tripSeconds++;

        // Variação natural da velocidade (±5 km/h)
        if (_tripSeconds % 3 == 0) {
          _speedVariation = _rng.nextInt(11) - 5;
        }

        // Avança km (baseado na velocidade real / 3600 * 0.4s)
        final effectiveSpeed = _displaySpeed.toDouble();
        _kmPercorrido += (effectiveSpeed / 3600) * 0.4;
        if (_kmPercorrido > _kmTotal) {
          _kmPercorrido = _kmTotal;
          t.cancel();
          setState(() => _phase = TripPhase.concluida);
          return;
        }

        // Avança segmento da via baseado no progresso
        final segProgress = _kmPercorrido / _kmTotal;
        final newSegIdx = (segProgress * _roadSegments.length).floor()
            .clamp(0, _roadSegments.length - 1);
        if (newSegIdx != _segmentIndex) {
          _segmentIndex = newSegIdx;
          _currentSegment = _roadSegments[_segmentIndex];
          _speedLimitKmh = _currentSegment.speedLimitKmh;
          _animateSpeedTo(_currentSegment.avgSpeedKmh);

          // Atualiza zona UBI conforme zona de risco da via
          _zonaAtual = _riskZoneToUBI(_currentSegment.zone);
        }

        // Simula parada em sinal (5% chance a cada tick)
        if (_rng.nextInt(100) < 5 && _phase == TripPhase.emViagem) {
          _simulateRedLight();
        }
      });
    });
  }

  void _animateSpeedTo(int target) {
    _speedKmh = target;
    _speedCtrl.forward(from: 0);
  }

  // Converte RiskZone (motor de risco) → RiskZoneUBI (motor UBI)
  RiskZoneUBI _riskZoneToUBI(RiskZone zone) {
    switch (zone) {
      case RiskZone.verde:
      case RiskZone.amarela:
        return RiskZoneUBI.baixo;
      case RiskZone.laranja:
        return RiskZoneUBI.medio;
      case RiskZone.vermelha:
      case RiskZone.critica:
        return RiskZoneUBI.alto;
    }
  }

  // Simula parada no semáforo por 3-6s
  void _simulateRedLight() {
    _phase = TripPhase.pausado;
    final prevSpeed = _speedKmh;
    setState(() { _speedKmh = 0; _speedVariation = 0; });

    final pauseDuration = 3 + _rng.nextInt(4);
    Future.delayed(Duration(seconds: pauseDuration), () {
      if (!mounted) return;
      setState(() {
        _phase = TripPhase.emViagem;
        _speedKmh = prevSpeed;
        _animateSpeedTo(prevSpeed);
      });
    });
  }

  @override
  void dispose() {
    _mainTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _speedCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Color get _phaseColor {
    switch (_phase) {
      case TripPhase.aguardando: return AppTheme.yellow;
      case TripPhase.emViagem:   return AppTheme.green;
      case TripPhase.pausado:    return AppTheme.yellow;
      case TripPhase.concluida:  return AppTheme.primary;
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case TripPhase.aguardando: return 'Aguardando saída...';
      case TripPhase.emViagem:   return 'Proteção Ativa';
      case TripPhase.pausado:    return 'Veículo parado';
      case TripPhase.concluida:  return 'Viagem concluída!';
    }
  }

  bool get _isSpeedOverLimit => _displaySpeed > _speedLimitKmh + 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // ── Mapa ───────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                MapboxActiveTripMap(height: double.infinity),

                // Status badge (topo)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 0, right: 0,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: AppTheme.shadowMd,
                        border: Border.all(color: _phaseColor.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PhaseDot(color: _phaseColor, pulse: _phase == TripPhase.emViagem),
                          const SizedBox(width: 8),
                          Text(_phaseLabel, style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _phaseColor)),
                        ],
                      ),
                    ),
                  ),
                ),

                // Countdown ao sair (aguardando)
                if (_phase == TripPhase.aguardando && _showCountdown)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 64,
                    left: 0, right: 0,
                    child: Center(
                      child: _CountdownBadge(seconds: _countdown),
                    ),
                  ),

                // ── Banner de manobra GPS (topo) estilo Waze ──────────
                if (_phase == TripPhase.emViagem || _phase == TripPhase.pausado)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 58,
                    left: 12, right: 90,
                    child: _ManobraBanner(
                      manobra: _currentSegment.proximaManobra,
                      distancia: _distProxManobra,
                      proximaVia: _segmentIndex + 1 < _roadSegments.length
                          ? _roadSegments[_segmentIndex + 1].name
                          : 'Destino',
                      isStopped: _phase == TripPhase.pausado,
                    ),
                  ),

                // Speedometer badge (direita, pequeno)
                if (_phase == TripPhase.emViagem || _phase == TripPhase.pausado)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 64,
                    right: 14,
                    child: _SpeedometerBadge(
                      speedKmh: _phase == TripPhase.pausado ? 0 : _displaySpeed,
                      limitKmh: _speedLimitKmh,
                      roadName: _currentSegment.name,
                      zone: _currentSegment.zone,
                      isStopped: _phase == TripPhase.pausado,
                    ),
                  ),

                // ── AI Bubble flutuante no mapa (fase ativa) ────────
                if (_phase == TripPhase.emViagem || _phase == TripPhase.pausado)
                  Positioned(
                    bottom: 12, left: 12, right: 12,
                    child: GestureDetector(
                      onTap: widget.onAI,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          boxShadow: AppTheme.shadowMd,
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_aiMessage,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.text)),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Fase aguardando — AI Bubble
                if (_phase == TripPhase.aguardando)
                  Positioned(
                    bottom: 12, left: 12, right: 12,
                    child: GestureDetector(
                      onTap: widget.onAI,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          boxShadow: AppTheme.shadowMd,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_aiMessage,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.text)),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Painel inferior ────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusXl),
                topRight: Radius.circular(AppTheme.radiusXl),
              ),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 24, offset: const Offset(0, -4))],
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                // Handle
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 12),

                // Fase aguardando
                if (_phase == TripPhase.aguardando)
                  _WaitingBanner(countdown: _countdown)
                else ...[

                  // ── PAINEL GPS ESTILO UBER ──────────────────────────

                  // Linha 1: Via atual + velocidade grande
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Velocidade grande (destaque principal)
                      Column(
                        children: [
                          Text(
                            _phase == TripPhase.pausado ? '0' : '${_displaySpeed}',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: _isSpeedOverLimit ? AppTheme.red : AppTheme.text,
                              height: 1.0,
                            ),
                          ),
                          Text('km/h',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            )),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Divisória vertical
                      Container(width: 1, height: 48, color: AppTheme.border),
                      const SizedBox(width: 12),
                      // Via atual + limite
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _phase == TripPhase.pausado ? 'Veículo parado' : _currentSegment.name,
                              style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isSpeedOverLimit
                                        ? AppTheme.red.withValues(alpha: 0.12)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: _isSpeedOverLimit ? AppTheme.red : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.speed_rounded, size: 10,
                                          color: _isSpeedOverLimit ? AppTheme.red : Colors.grey.shade600),
                                      const SizedBox(width: 3),
                                      Text('Lim. $_speedLimitKmh km/h',
                                        style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w700,
                                          color: _isSpeedOverLimit ? AppTheme.red : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(width: 7, height: 7,
                                    decoration: BoxDecoration(
                                        color: _currentSegment.zone.color, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(_currentSegment.zone.label,
                                    style: TextStyle(fontSize: 10, color: _currentSegment.zone.color)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Linha 2: ETA + km restante + tempo decorrido + valor
                  Row(
                    children: [
                      // ETA — destaque
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chegada', style: TextStyle(
                                  fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                              Text(_eta, style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primary, height: 1.1)),
                              Text(_tempoRestante, style: const TextStyle(
                                  fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // km restante
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Restam', style: TextStyle(
                                  fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                              Text(
                                _kmRestante < 1
                                    ? '${(_kmRestante * 1000).round()} m'
                                    : '${_kmRestante.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.green, height: 1.2)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Valor acumulado
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Custo UBI', style: TextStyle(
                                  fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                              Text(
                                'R\$ ${_tripValue.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.accent, height: 1.2)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Linha 3: Barra de progresso da rota
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_kmPercorrido.toStringAsFixed(1)} de ${_kmTotal.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                Text(
                                  '${(_progress * 100).round()}% concluído',
                                  style: TextStyle(fontSize: 10, color: AppTheme.green, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progress,
                                backgroundColor: AppTheme.border,
                                valueColor: AlwaysStoppedAnimation(_phaseColor),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tempo decorrido
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatTime(_tripSeconds),
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                          const Text('decorrido', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Botões ação
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onEmergency,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Assistência', style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onEnd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.red, width: 2),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.stop_rounded, color: AppTheme.red, size: 18),
                              SizedBox(width: 8),
                              Text('Encerrar', style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mensagem dinâmica da IA
  String get _aiMessage {
    if (_phase == TripPhase.aguardando) return 'Sistema ativo — aguardando você sair...';
    if (_phase == TripPhase.pausado) return 'Veículo parado — proteção mantida';
    if (_isSpeedOverLimit) return '⚠️ Atenção: acima do limite da via ($_speedLimitKmh km/h)';
    if (_currentSegment.zone == RiskZone.vermelha || _currentSegment.zone == RiskZone.critica) {
      return '🔴 Zona de risco — mantenha portas travadas';
    }
    if (_currentSegment.zone == RiskZone.laranja) {
      return '🟠 Trecho com atenção — ${_currentSegment.name}';
    }
    if (_kmPercorrido > _kmTotal * 0.8) return '✅ Quase chegando! Proteção ativa';
    return '${_currentSegment.name} · Limite ${_speedLimitKmh} km/h';
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES DA VIAGEM
// ═══════════════════════════════════════════════════════════════

// ── Banner de manobra GPS estilo Waze/Google Maps ───────────────
class _ManobraBanner extends StatelessWidget {
  final _Manobra manobra;
  final String distancia;
  final String proximaVia;
  final bool isStopped;

  const _ManobraBanner({
    required this.manobra,
    required this.distancia,
    required this.proximaVia,
    required this.isStopped,
  });

  @override
  Widget build(BuildContext context) {
    final isDestino = manobra == _Manobra.destino;
    final bgColor   = isDestino ? AppTheme.primary : const Color(0xFF1E293B);
    final iconColor = isDestino ? Colors.white : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Ícone grande da manobra
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(manobra.icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 10),
          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Distância até a manobra
                Text(
                  isStopped ? 'Parado' : distancia,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                // Nome da próxima via
                Text(
                  isDestino ? 'Chegando ao destino' : proximaVia,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Label da manobra
                Text(
                  manobra.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
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

// Banner de aguardando saída
class _WaitingBanner extends StatelessWidget {
  final int countdown;
  const _WaitingBanner({required this.countdown});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.yellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.yellow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppTheme.yellow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: countdown > 0
                  ? Text('$countdown',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))
                  : const Icon(Icons.directions_car_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aguardando você sair',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
                Text(
                  countdown > 0
                      ? 'Proteção ativa quando o veículo se mover ($countdown s)'
                      : 'Movimentação detectada — iniciando...',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Countdown badge no mapa
class _CountdownBadge extends StatelessWidget {
  final int seconds;
  const _CountdownBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(99),
        boxShadow: AppTheme.shadowMd,
        border: Border.all(color: AppTheme.yellow.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFF92400E)),
          const SizedBox(width: 7),
          Text(
            'Iniciando em ${seconds}s...',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}

// Velocímetro badge flutuante no mapa
class _SpeedometerBadge extends StatelessWidget {
  final int speedKmh;
  final int limitKmh;
  final String roadName;
  final RiskZone zone;
  final bool isStopped;

  const _SpeedometerBadge({
    required this.speedKmh,
    required this.limitKmh,
    required this.roadName,
    required this.zone,
    required this.isStopped,
  });

  bool get _overLimit => speedKmh > limitKmh + 5;

  @override
  Widget build(BuildContext context) {
    final speedColor = isStopped
        ? Colors.grey.shade500
        : _overLimit
            ? AppTheme.red
            : AppTheme.green;

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.shadowMd,
        border: Border.all(color: speedColor.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Velocidade atual
          Text(
            isStopped ? '0' : '$speedKmh',
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: speedColor,
              height: 1,
            ),
          ),
          Text('km/h', style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          // Divisória
          Container(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 4),
          // Limite da via
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _overLimit ? AppTheme.red.withValues(alpha: 0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _overLimit ? AppTheme.red : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed_rounded, size: 9,
                    color: _overLimit ? AppTheme.red : Colors.grey.shade500),
                const SizedBox(width: 2),
                Text('$limitKmh', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _overLimit ? AppTheme.red : Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Zona de risco
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: zone.color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

// Barra de velocidade inline no painel
class _SpeedBar extends StatelessWidget {
  final int speed;
  final int limit;
  final _RoadSegment segment;
  final bool isStopped;

  const _SpeedBar({
    required this.speed,
    required this.limit,
    required this.segment,
    required this.isStopped,
  });

  bool get _over => speed > limit + 5;
  Color get _barColor => isStopped
      ? Colors.grey.shade400
      : _over ? AppTheme.red : AppTheme.green;

  @override
  Widget build(BuildContext context) {
    final pct = isStopped ? 0.0 : (speed / (limit * 1.5)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _barColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: _barColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 15, color: _barColor),
              const SizedBox(width: 8),
              // Nome da via
              Expanded(
                child: Text(
                  isStopped ? 'Veículo parado' : segment.name,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Velocidade
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: isStopped ? '0' : '$speed',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, color: _barColor,
                      ),
                    ),
                    TextSpan(
                      text: ' km/h',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Badge limite
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _over ? AppTheme.red.withValues(alpha: 0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _over ? AppTheme.red : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Lim. $limit',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _over ? AppTheme.red : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Barra de progresso da velocidade
          Stack(
            children: [
              // Fundo
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Progresso
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: _barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Marcador de limite
              FractionallySizedBox(
                widthFactor: (1 / 1.5).clamp(0.0, 1.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 2, height: 8,
                    margin: const EdgeInsets.only(top: -1.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Zona de risco da via
          Row(
            children: [
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: segment.zone.color, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('Zona ${segment.zone.label} — ${segment.zone.description}',
                  style: TextStyle(fontSize: 9, color: segment.zone.color)),
            ],
          ),
        ],
      ),
    );
  }
}

// Ponto pulsante de fase
class _PhaseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PhaseDot({required this.color, required this.pulse});

  @override
  State<_PhaseDot> createState() => _PhaseDotState();
}

class _PhaseDotState extends State<_PhaseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.4).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: widget.color.withValues(alpha: 0.6 * _anim.value),
              blurRadius: 8)],
        ),
      ),
    );
  }
}

class _GreenPulseDot extends StatefulWidget {
  @override
  State<_GreenPulseDot> createState() => _GreenPulseDotState();
}

class _GreenPulseDotState extends State<_GreenPulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.4).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: AppTheme.green,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppTheme.green.withValues(alpha: 0.6 * _anim.value), blurRadius: 8)],
        ),
      ),
    );
  }
}

class _TripMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _TripMetric({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                overflow: TextOverflow.ellipsis),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
// ══════════════════════════════════════════
class EmergencyScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onClaim;

  const EmergencyScreen({super.key, required this.onBack, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 14, bottom: 14, left: 16, right: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)]),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Assistência',
                    style: TextStyle(fontSize:16, fontWeight:FontWeight.w600, color:Colors.white))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text('ATIVA', style: TextStyle(fontSize:11, fontWeight:FontWeight.w700, color:Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecione o tipo de ocorrência:',
                      style: TextStyle(fontSize:14, fontWeight:FontWeight.w500, color:AppTheme.textMuted)),
                  const SizedBox(height: 14),
                  // Grid de emergências
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.2,
                    children: [
                      _EmergencyBtn(icon: Icons.car_crash_rounded, iconBg: AppTheme.red.withValues(alpha: 0.1),
                          iconColor: AppTheme.red, label: 'Acidente', onTap: onClaim),
                      _EmergencyBtn(icon: Icons.masks_rounded, iconBg: AppTheme.yellow.withValues(alpha: 0.1),
                          iconColor: AppTheme.yellow, label: 'Roubo', onTap: onClaim),
                      _EmergencyBtn(icon: Icons.build_rounded, iconBg: AppTheme.blueLight.withValues(alpha: 0.1),
                          iconColor: AppTheme.blueLight, label: 'Pane', onTap: () {}),
                      _EmergencyBtn(icon: Icons.medical_services_rounded, iconBg: AppTheme.green.withValues(alpha: 0.1),
                          iconColor: AppTheme.green, label: 'Emergência Médica', onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Precisa de ajuda imediata?',
                      style: TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:AppTheme.textMuted)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.green, AppTheme.greenDark]),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Falar com Atendente', style: TextStyle(fontSize:15, fontWeight:FontWeight.w600, color:Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _emergNumber(Icons.local_fire_department_rounded, 'Bombeiros: 193'),
                      _emergNumber(Icons.local_hospital_rounded, 'SAMU: 192'),
                      _emergNumber(Icons.shield_rounded, 'Polícia: 190'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emergNumber(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize:12, fontWeight:FontWeight.w600, color:AppTheme.text)),
        ],
      ),
    );
  }
}

class _EmergencyBtn extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _EmergencyBtn({required this.icon, required this.iconBg, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:AppTheme.text),
                textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// SINISTRO — funcional com GPS + Overpass
// ══════════════════════════════════════════
class ClaimScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSend;

  const ClaimScreen({super.key, required this.onBack, required this.onSend});

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  // ── Estado do formulário ─────────────────────────────────────────
  String _tipoSinistro = 'Colisão';
  final _descController = TextEditingController();
  final List<String> _fotosMock = []; // simulação (sem image_picker no web)

  // ── GPS e localização ────────────────────────────────────────────
  double? _lat;
  double? _lon;
  String _locLabel = 'Obtendo localização…';
  bool _loadingGps = true;

  // ── Serviços de emergência próximos (Overpass) ───────────────────
  List<OverpassPoi> _hospitais = [];
  List<OverpassPoi> _delegacias = [];
  bool _loadingEmerg = false;

  // ── Rota até hospital mais próximo (OSRM) ───────────────────────
  OsrmRoute? _rotaHospital;

  // Data/hora automáticos
  late final String _dataHora;
  // Protocolo gerado ao enviar
  String? _protocolo;

  static const _tipos = [
    'Colisão', 'Roubo / Furto', 'Dano a terceiros',
    'Pane mecânica', 'Incêndio', 'Alagamento', 'Vidro quebrado',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataHora = '${now.day.toString().padLeft(2,'0')}/'
        '${now.month.toString().padLeft(2,'0')}/'
        '${now.year}  '
        '${now.hour.toString().padLeft(2,'0')}:'
        '${now.minute.toString().padLeft(2,'0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGps());
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // ── Obtém GPS → endereço + serviços de emergência ────────────────
  Future<void> _initGps() async {
    setState(() { _loadingGps = true; });
    try {
      final locState = LocationService.instance.state;
      if (locState.hasPosition) {
        _lat = locState.lat!;
        _lon = locState.lon!;
      } else {
        final fresh = await LocationService.instance.getCurrentPosition();
        if (fresh.hasPosition) {
          _lat = fresh.lat!;
          _lon = fresh.lon!;
        }
      }
      if (_lat != null) {
        _locLabel = '${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)}';
        if (LocationService.instance.state.geo != null) {
          final geo = LocationService.instance.state.geo!;
          _locLabel = geo.uf != null ? 'Brasil — ${geo.ufFullName} (${geo.uf})' : 'Brasil';
        }
        _loadEmergency();
      } else {
        _locLabel = 'Localização não disponível';
      }
    } catch (_) {
      _locLabel = 'Erro ao obter localização';
    }
    if (mounted) setState(() { _loadingGps = false; });
  }

  // ── Carrega hospitais e delegacias próximos (Overpass) ───────────
  Future<void> _loadEmergency() async {
    if (_lat == null || _lon == null) return;
    setState(() => _loadingEmerg = true);
    try {
      final emerg = await OverpassApiService.searchEmergencyNearby(
        lat: _lat!, lon: _lon!, radiusKm: 15,
      );
      _hospitais  = emerg['hospital'] ?? [];
      _delegacias = emerg['police']   ?? [];

      // Se tem hospital: calcula rota via OSRM
      if (_hospitais.isNotEmpty) {
        final hosp = _hospitais.first;
        final rota = await OsrmRouteService.getRoute(
          fromLat: _lat!, fromLon: _lon!,
          toLat: hosp.lat, toLon: hosp.lon,
        );
        if (mounted) setState(() => _rotaHospital = rota);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingEmerg = false);
  }

  // ── Envio do sinistro ────────────────────────────────────────────
  void _enviarSinistro() {
    final prot = 'SR${DateTime.now().millisecondsSinceEpoch % 1000000}';
    setState(() => _protocolo = prot);
    Future.delayed(const Duration(milliseconds: 800), widget.onSend);
  }

  // ── Adiciona foto mockada ────────────────────────────────────────
  void _adicionarFoto(String label) {
    setState(() => _fotosMock.add(label));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📷 "$label" registrada (simulação web)'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          AppHeaderBar(title: 'Registrar Sinistro', onBack: widget.onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── BANNER GPS ────────────────────────────────────
                  _InfoBanner(
                    icon: _loadingGps ? Icons.gps_not_fixed_rounded : Icons.gps_fixed_rounded,
                    color: _loadingGps ? AppTheme.yellow : AppTheme.green,
                    text: _loadingGps
                        ? 'Obtendo localização GPS…'
                        : '📍 $_locLabel · $_dataHora',
                  ),
                  const SizedBox(height: 16),

                  // ── TIPO DE SINISTRO ──────────────────────────────
                  const Text('TIPO DE OCORRÊNCIA',
                      style: TextStyle(fontSize:11, fontWeight:FontWeight.w700,
                          color: AppTheme.textMuted, letterSpacing: 0.06)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _tipos.map((t) {
                      final sel = t == _tipoSinistro;
                      return GestureDetector(
                        onTap: () => setState(() => _tipoSinistro = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? AppTheme.primary : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? AppTheme.primary : AppTheme.border,
                              width: 1.5,
                            ),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : AppTheme.text,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── DESCRIÇÃO ─────────────────────────────────────
                  const Text('DESCRIÇÃO',
                      style: TextStyle(fontSize:11, fontWeight:FontWeight.w700,
                          color: AppTheme.textMuted, letterSpacing: 0.06)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border, width: 1.5),
                    ),
                    child: TextField(
                      controller: _descController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14, color: AppTheme.text),
                      decoration: const InputDecoration(
                        hintText: 'Descreva o que aconteceu, onde e como…',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        contentPadding: EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── EVIDÊNCIAS ───────────────────────────────────
                  const Text('EVIDÊNCIAS',
                      style: TextStyle(fontSize:11, fontWeight:FontWeight.w700,
                          color: AppTheme.textMuted, letterSpacing: 0.06)),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.0,
                    children: [
                      _FotoBox(
                        icon: Icons.directions_car_rounded,
                        label: 'Foto do veículo',
                        adicionado: _fotosMock.contains('Foto do veículo'),
                        onTap: () => _adicionarFoto('Foto do veículo'),
                      ),
                      _FotoBox(
                        icon: Icons.badge_rounded,
                        label: 'Documento',
                        adicionado: _fotosMock.contains('Documento'),
                        onTap: () => _adicionarFoto('Documento'),
                      ),
                      _FotoBox(
                        icon: Icons.description_rounded,
                        label: 'Boletim',
                        adicionado: _fotosMock.contains('Boletim'),
                        onTap: () => _adicionarFoto('Boletim'),
                      ),
                      _FotoBox(
                        icon: Icons.camera_alt_rounded,
                        label: 'Outras fotos',
                        adicionado: _fotosMock.contains('Outras fotos'),
                        onTap: () => _adicionarFoto('Outras fotos'),
                      ),
                    ],
                  ),
                  if (_fotosMock.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${_fotosMock.length} evidência(s) registrada(s)',
                        style: const TextStyle(fontSize: 12, color: AppTheme.green)),
                  ],
                  const SizedBox(height: 20),

                  // ── SERVIÇOS DE EMERGÊNCIA PRÓXIMOS ──────────────
                  const Text('SERVIÇOS DE EMERGÊNCIA PRÓXIMOS',
                      style: TextStyle(fontSize:11, fontWeight:FontWeight.w700,
                          color: AppTheme.textMuted, letterSpacing: 0.06)),
                  const SizedBox(height: 8),
                  if (_loadingEmerg)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Buscando via OpenStreetMap…',
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                      ]),
                    )
                  else if (_lat == null)
                    const Text('GPS necessário para buscar serviços próximos.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted))
                  else ...[
                    if (_hospitais.isNotEmpty) ...[
                      _EmergencySection(
                        icon: Icons.local_hospital_rounded,
                        color: AppTheme.red,
                        titulo: 'Hospitais / Clínicas',
                        pois: _hospitais.take(3).toList(),
                        rota: _rotaHospital,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_delegacias.isNotEmpty) ...[
                      _EmergencySection(
                        icon: Icons.local_police_rounded,
                        color: const Color(0xFF1E40AF),
                        titulo: 'Delegacias',
                        pois: _delegacias.take(2).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_hospitais.isEmpty && _delegacias.isEmpty)
                      const Text('Nenhum serviço encontrado no raio de 15 km (OSM).',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  ],
                  const SizedBox(height: 24),

                  // ── BOTÃO ENVIAR ──────────────────────────────────
                  PrimaryButton(
                    text: 'Enviar Sinistro',
                    icon: Icons.send_rounded,
                    onTap: _enviarSinistro,
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Ao enviar, um protocolo será gerado e nossa equipe\n'
                      'entrará em contato em até 2 horas úteis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner informativo ────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: TextStyle(fontSize: 13, color: color,
                fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ── Caixa de foto ─────────────────────────────────────────────────
class _FotoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool adicionado;
  final VoidCallback onTap;
  const _FotoBox({required this.icon, required this.label,
      required this.adicionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: adicionado
              ? AppTheme.green.withValues(alpha: 0.1)
              : AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: adicionado ? AppTheme.green : AppTheme.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(adicionado ? Icons.check_circle_rounded : icon,
                color: adicionado ? AppTheme.green : AppTheme.primary, size: 22),
            const SizedBox(height: 5),
            Text(adicionado ? 'Adicionada ✓' : label,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: adicionado ? AppTheme.green : AppTheme.textMuted,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Seção de emergência ───────────────────────────────────────────
class _EmergencySection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final List<OverpassPoi> pois;
  final OsrmRoute? rota;
  const _EmergencySection({
    required this.icon, required this.color, required this.titulo,
    required this.pois, this.rota,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          if (rota != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(rota!.summary,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        ...pois.map((poi) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poi.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text)),
                if (poi.subtitle.isNotEmpty)
                  Text(poi.subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                if (poi.phone != null)
                  Text('📞 ${poi.phone}', style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
              ],
            )),
          ]),
        )),
      ],
    );
  }
}



class _UploadBox extends StatelessWidget {
  final IconData icon;
  final String label;
  const _UploadBox({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 2, style: BorderStyle.none),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.border,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize:11, fontWeight:FontWeight.w500, color:AppTheme.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// SINISTRO ENVIADO
// ══════════════════════════════════════════
class ClaimSentScreen extends StatelessWidget {
  final VoidCallback onHome;

  const ClaimSentScreen({super.key, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeaderBar(title: 'Sinistro Registrado', onBack: onHome),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.green, width: 3),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text('Sinistro Registrado!',
                          style: TextStyle(fontSize:22, fontWeight:FontWeight.w800, color:AppTheme.text)),
                      const SizedBox(height: 8),
                      RichText(text: const TextSpan(
                        style: TextStyle(fontSize:14, color:AppTheme.textMuted),
                        children: [
                          TextSpan(text: 'Protocolo: '),
                          TextSpan(text: '#SR-2026-001234',
                              style: TextStyle(fontWeight:FontWeight.w700, color:AppTheme.text)),
                        ],
                      )),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface2,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Column(
                          children: [
                            _TimelineStep(icon: Icons.check_circle_rounded, label: 'Ocorrência registrada', status: 'done'),
                            _TimelineStep(icon: Icons.hourglass_top_rounded, label: 'Em análise', status: 'active'),
                            _TimelineStep(icon: Icons.circle_outlined, label: 'Regulação', status: 'pending'),
                            _TimelineStep(icon: Icons.circle_outlined, label: 'Indenização paga', status: 'pending'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(text: 'Voltar ao Início', onTap: onHome),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status; // 'done', 'active', 'pending'
  const _TimelineStep({required this.icon, required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = status == 'done' ? AppTheme.green : status == 'active' ? AppTheme.yellow : AppTheme.border;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(
              fontSize:13,
              color: status == 'pending' ? AppTheme.textMuted : AppTheme.text,
              fontWeight: status != 'pending' ? FontWeight.w500 : FontWeight.w400)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// ENCERRAMENTO
// ══════════════════════════════════════════
class TripEndScreen extends StatelessWidget {
  final VoidCallback onReceipt;
  final VoidCallback onNewTrip;

  const TripEndScreen({super.key, required this.onReceipt, required this.onNewTrip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 14, bottom: 14, left: 16, right: 16),
            decoration: const BoxDecoration(
              gradient: AppTheme.greenGradient,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onNewTrip,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Viagem Encerrada',
                    style: TextStyle(fontSize:16, fontWeight:FontWeight.w600, color:Colors.white))),
                GestureDetector(
                  onTap: onNewTrip,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryAccentGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    child: const Icon(Icons.sports_score_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Viagem encerrada!',
                      style: TextStyle(fontSize:24, fontWeight:FontWeight.w800, color:AppTheme.text)),
                  const SizedBox(height: 6),
                  const Text('Você chegou ao seu destino em segurança.',
                      style: TextStyle(fontSize:14, color:AppTheme.textMuted),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  // Stats
                  Row(
                    children: [
                      _EndStat(icon: Icons.route_rounded, value: '24 km', label: 'Distância'),
                      const SizedBox(width: 10),
                      _EndStat(icon: Icons.access_time_rounded, value: '32 min', label: 'Duração'),
                      const SizedBox(width: 10),
                      _EndStat(icon: Icons.star_rounded, value: '+12 pts', label: 'Score'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Franquia desta viagem (destaque UBI)
                  _UBITripSummary(),
                  const SizedBox(height: 12),
                  // Pagamento confirmado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.green, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 34),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PIX automático realizado',
                                style: TextStyle(fontSize:13, color:AppTheme.textMuted, fontWeight:FontWeight.w500)),
                            const Text('R\$ 5,12', style: TextStyle(fontSize:18, fontWeight:FontWeight.w800, color:AppTheme.text)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Score da viagem
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: Column(
                      children: [
                        const Text('Avaliação desta viagem',
                            style: TextStyle(fontSize:13, color:AppTheme.textMuted)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) => Icon(
                            i < 4 ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppTheme.yellow, size: 28,
                          )),
                        ),
                        const SizedBox(height: 8),
                        const Text('Boa direção! Sem freadas bruscas. 🏆',
                            style: TextStyle(fontSize:13, color:AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlineButton(text: 'Ver Recibo', icon: Icons.receipt_rounded, onTap: onReceipt),
                  const SizedBox(height: 10),
                  PrimaryButton(text: 'Nova Viagem', icon: Icons.add_rounded, onTap: onNewTrip),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _EndStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize:15, fontWeight:FontWeight.w800, color:AppTheme.text)),
            Text(label, style: const TextStyle(fontSize:10, color:AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// WIDGET UBI — Resumo Pós-Viagem
// ══════════════════════════════════════════
class _UBITripSummary extends StatelessWidget {
  const _UBITripSummary();

  @override
  Widget build(BuildContext context) {
    // Simula resultado UBI da viagem (em produção: vem do TripTelemetryService)
    final now = DateTime.now();
    final franquia = TripPricingEngine.calcularFranquiaLive(
      agora:     now,
      zonaAtual: RiskZoneUBI.baixo,
    );

    final cor = franquia.corSemaforo == 'verde'
        ? AppTheme.green
        : franquia.corSemaforo == 'amarelo'
            ? AppTheme.yellow
            : AppTheme.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: cor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: cor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'FRANQUIA DESTA VIAGEM',
                style: TextStyle(fontSize:10, fontWeight:FontWeight.w700,
                    color:AppTheme.textMuted, letterSpacing:0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'R\$ ${franquia.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(fontSize:22, fontWeight:FontWeight.w900, color:cor),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Horário ×${franquia.fatorHorario.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize:10, color:AppTheme.textMuted),
                  ),
                  Text(
                    'Local ×${franquia.fatorLocalizacao.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize:10, color:AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            franquia.corSemaforo == 'verde'
                ? '✅ Franquia mínima — ótima direção! Parabéns!'
                : '⚠️ Franquia elevada pelo horário/zona da rota.',
            style: TextStyle(fontSize:11, color:cor, fontWeight:FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

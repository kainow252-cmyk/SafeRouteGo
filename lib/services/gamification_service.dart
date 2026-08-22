// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════
// GAMIFICATION SERVICE — SafeRoute UBI
// -----------------------------------------------------------------------
// Especificação do fundador:
//   • Desconto 10% mensalidade → GPS ativo em 100% das viagens no mês
//   • Pontos por KM seguro → acúmulo e resgate
//   • Metas semanais → KM sem eventos ruins
//   • Conquistas desbloqueáveis
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'trip_pricing_engine.dart';

// ──────────────────────────────────────────────────────────────────────
// MODELOS
// ──────────────────────────────────────────────────────────────────────

class MonthlyStats {
  final int totalViagens;
  final double totalKm;
  final double totalKmSemEventos;  // km com direção perfeita
  final int gpsAtivoViagens;       // viagens com GPS 100% ativo
  final int totalEventos;
  final double descontoMensalidade; // 0–10%
  final int pontosTotais;
  final int nivel;                 // 1–5
  final List<String> conquistas;

  const MonthlyStats({
    required this.totalViagens,
    required this.totalKm,
    required this.totalKmSemEventos,
    required this.gpsAtivoViagens,
    required this.totalEventos,
    required this.descontoMensalidade,
    required this.pontosTotais,
    required this.nivel,
    required this.conquistas,
  });

  double get percentualGpsAtivo =>
      totalViagens == 0 ? 0 : gpsAtivoViagens / totalViagens * 100;

  bool get qualificaDescontoTotal => percentualGpsAtivo >= 100.0;
}

class WeeklyChallenge {
  final String id;
  final String titulo;
  final String descricao;
  final String iconEmoji;
  final double metaKm;
  final double kmAtingido;
  final int pontosRecompensa;
  final bool concluido;

  const WeeklyChallenge({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.iconEmoji,
    required this.metaKm,
    required this.kmAtingido,
    required this.pontosRecompensa,
    required this.concluido,
  });

  double get progresso => (kmAtingido / metaKm).clamp(0.0, 1.0);
}

// ──────────────────────────────────────────────────────────────────────
// SERVIÇO
// ──────────────────────────────────────────────────────────────────────
class GamificationService {

  // Estado em memória (sincronizado com SharedPreferences)
  static int _pontosAcumulados    = 0;
  static int _viagensNoMes        = 0;
  static int _gpsAtivoNoMes       = 0;
  static double _kmNoMes          = 0;
  static double _kmSemEventos     = 0;
  static int _eventosNoMes        = 0;
  static List<String> _conquistas = [];
  static bool _inicializado       = false;

  static int get pontosAcumulados    => _pontosAcumulados;
  static double get kmNoMes          => _kmNoMes;
  static int get viagensNoMes        => _viagensNoMes;

  // ── Inicializar ────────────────────────────────────────────────
  static Future<void> inicializar() async {
    if (_inicializado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _pontosAcumulados = prefs.getInt('gami_pontos') ?? 0;
      _viagensNoMes     = prefs.getInt('gami_viagens_mes') ?? 0;
      _gpsAtivoNoMes    = prefs.getInt('gami_gps_ativo_mes') ?? 0;
      _kmNoMes          = prefs.getDouble('gami_km_mes') ?? 0;
      _kmSemEventos     = prefs.getDouble('gami_km_sem_eventos') ?? 0;
      _eventosNoMes     = prefs.getInt('gami_eventos_mes') ?? 0;
      _conquistas       = prefs.getStringList('gami_conquistas') ?? [];
      _inicializado     = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Gamification] init error: $e');
    }
  }

  // ── Registrar viagem ───────────────────────────────────────────
  static Future<void> registrarViagem(TripPricingResult resultado) async {
    await inicializar();

    final score = resultado.scoreViagem;
    _pontosAcumulados += score.pontosGanhos;
    _viagensNoMes++;
    _kmNoMes += resultado.totalKmCobrado;
    _eventosNoMes += resultado.segmentos.length; // proxy para eventos

    // GPS ativo = sem ghost trip
    if (!resultado.ghostTripDetected) {
      _gpsAtivoNoMes++;
    }

    // KM sem eventos (direção perfeita)
    if (score.nivel >= 4) {
      _kmSemEventos += resultado.totalKmCobrado;
    }

    // Verificar conquistas
    _verificarConquistas(resultado);

    await _salvar();

    if (kDebugMode) {
      debugPrint('[Gamification] Pontos ganhos: ${score.pontosGanhos} (total: $_pontosAcumulados)');
    }
  }

  // ── Estatísticas do mês ────────────────────────────────────────
  static Future<MonthlyStats> obterEstatisticasMes() async {
    await inicializar();

    // Calcular desconto
    final pctGps = _viagensNoMes == 0 ? 0.0 : _gpsAtivoNoMes / _viagensNoMes * 100;
    double desconto = 0;
    if (pctGps >= 100) desconto = 10.0;
    else if (pctGps >= 80) desconto = 5.0;
    else if (pctGps >= 60) desconto = 2.0;

    // Nível global
    final int nivel;
    if (_pontosAcumulados >= 5000) nivel = 5;
    else if (_pontosAcumulados >= 2000) nivel = 4;
    else if (_pontosAcumulados >= 1000) nivel = 3;
    else if (_pontosAcumulados >= 500)  nivel = 2;
    else nivel = 1;

    return MonthlyStats(
      totalViagens:         _viagensNoMes,
      totalKm:              _kmNoMes,
      totalKmSemEventos:    _kmSemEventos,
      gpsAtivoViagens:      _gpsAtivoNoMes,
      totalEventos:         _eventosNoMes,
      descontoMensalidade:  desconto,
      pontosTotais:         _pontosAcumulados,
      nivel:                nivel,
      conquistas:           List.unmodifiable(_conquistas),
    );
  }

  // ── Desafios semanais ──────────────────────────────────────────
  static List<WeeklyChallenge> obterDesafiosSemana() {
    final kmAtual = _kmNoMes.clamp(0, 200).toDouble();

    return [
      WeeklyChallenge(
        id:              'km_safe_50',
        titulo:          'Guardião da Estrada',
        descricao:       'Rode 50 km sem nenhum evento de risco',
        iconEmoji:       '🛡️',
        metaKm:          50,
        kmAtingido:      _kmSemEventos.clamp(0, 50).toDouble(),
        pontosRecompensa: 100,
        concluido:       _kmSemEventos >= 50,
      ),
      WeeklyChallenge(
        id:              'km_week_100',
        titulo:          'Viajante Frequente',
        descricao:       'Percorra 100 km esta semana com GPS ativo',
        iconEmoji:       '🚗',
        metaKm:          100,
        kmAtingido:      kmAtual.clamp(0, 100),
        pontosRecompensa: 150,
        concluido:       kmAtual >= 100,
      ),
      WeeklyChallenge(
        id:              'night_safe',
        titulo:          'Noturno Seguro',
        descricao:       'Complete 3 viagens noturnas sem incidentes',
        iconEmoji:       '🌙',
        metaKm:          3,  // viagens como meta
        kmAtingido:      (_viagensNoMes * 0.3).clamp(0, 3).toDouble(),
        pontosRecompensa: 200,
        concluido:       _viagensNoMes >= 10,
      ),
    ];
  }

  // ── Banner de Desconto ─────────────────────────────────────────
  /// Retorna null se não há desconto disponível
  static Future<String?> bannerDesconto() async {
    await inicializar();
    final pct = _viagensNoMes == 0 ? 0.0 : _gpsAtivoNoMes / _viagensNoMes * 100;
    final faltam = _viagensNoMes == 0 ? 5 : ((_viagensNoMes - _gpsAtivoNoMes)).clamp(0, 999);

    if (pct >= 100) {
      return '🎉 Parabéns! Você ganhou 10% de desconto na mensalidade deste mês!';
    } else if (pct >= 80) {
      return '⭐ ${pct.toStringAsFixed(0)}% GPS ativo — mais ${faltam} viagens com GPS para 10% off!';
    } else if (_viagensNoMes >= 3) {
      return '💡 Ative o GPS em 100% das viagens e ganhe 10% de desconto!';
    }
    return null;
  }

  // ── Reset mensal ───────────────────────────────────────────────
  static Future<void> resetarMes() async {
    _viagensNoMes  = 0;
    _gpsAtivoNoMes = 0;
    _kmNoMes       = 0;
    _kmSemEventos  = 0;
    _eventosNoMes  = 0;
    await _salvar();
  }

  // ── Interno ────────────────────────────────────────────────────
  static void _verificarConquistas(TripPricingResult resultado) {
    final novas = <String>[];

    if (_kmNoMes >= 500 && !_conquistas.contains('km500')) {
      _conquistas.add('km500');
      novas.add('🏆 500 km Rodados!');
    }
    if (_viagensNoMes >= 20 && !_conquistas.contains('v20')) {
      _conquistas.add('v20');
      novas.add('🔥 20 Viagens no Mês!');
    }
    if (_gpsAtivoNoMes >= _viagensNoMes && _viagensNoMes >= 10
        && !_conquistas.contains('gps100')) {
      _conquistas.add('gps100');
      novas.add('📡 GPS 100% Ativo!');
    }
    if (_pontosAcumulados >= 1000 && !_conquistas.contains('p1000')) {
      _conquistas.add('p1000');
      novas.add('⭐ 1000 Pontos!');
    }

    if (novas.isNotEmpty && kDebugMode) {
      debugPrint('[Gamification] Conquistas: ${novas.join(', ')}');
    }
  }

  static Future<void> _salvar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('gami_pontos', _pontosAcumulados);
      await prefs.setInt('gami_viagens_mes', _viagensNoMes);
      await prefs.setInt('gami_gps_ativo_mes', _gpsAtivoNoMes);
      await prefs.setDouble('gami_km_mes', _kmNoMes);
      await prefs.setDouble('gami_km_sem_eventos', _kmSemEventos);
      await prefs.setInt('gami_eventos_mes', _eventosNoMes);
      await prefs.setStringList('gami_conquistas', _conquistas);
    } catch (e) {
      if (kDebugMode) debugPrint('[Gamification] save error: $e');
    }
  }
}

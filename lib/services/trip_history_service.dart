// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// TRIP HISTORY SERVICE — SafeRoute
// Persiste histórico de viagens reais em SharedPreferences (JSON)
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────
// MODELO
// ──────────────────────────────────────────────────────────────────
class TripHistoryRecord {
  final String id;
  final DateTime datetime;
  final String origin;
  final String destination;
  final double kmTotal;
  final int durationMinutes;
  final double totalCost;
  final String riskZone;   // 'verde', 'amarela', 'laranja', 'vermelha', 'critica'
  final String planType;   // 'Econômico', 'Equilibrado', 'Premium'
  final int scoreViagem;
  final int pontosGanhos;
  final bool hasSinistro;

  const TripHistoryRecord({
    required this.id,
    required this.datetime,
    required this.origin,
    required this.destination,
    required this.kmTotal,
    required this.durationMinutes,
    required this.totalCost,
    required this.riskZone,
    required this.planType,
    required this.scoreViagem,
    required this.pontosGanhos,
    this.hasSinistro = false,
  });

  // Formatações para exibição
  String get dateFormatted {
    return '${datetime.day.toString().padLeft(2,'0')}/${datetime.month.toString().padLeft(2,'0')}';
  }

  String get weekdayAbbr {
    const dias = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];
    return dias[datetime.weekday % 7];
  }

  String get timeFormatted {
    return '${datetime.hour.toString().padLeft(2,'0')}h${datetime.minute.toString().padLeft(2,'0')}';
  }

  String get kmFormatted => '${kmTotal.round()} km';
  String get durationFormatted {
    if (durationMinutes >= 60) {
      final h = durationMinutes ~/ 60;
      final m = durationMinutes % 60;
      return '${h}h ${m}min';
    }
    return '$durationMinutes min';
  }

  String get priceFormatted =>
      'R\$ ${totalCost.toStringAsFixed(2).replaceAll('.', ',')}';

  String get monthLabel {
    const meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
        'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    return meses[datetime.month - 1];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'datetime': datetime.millisecondsSinceEpoch,
    'origin': origin,
    'destination': destination,
    'kmTotal': kmTotal,
    'durationMinutes': durationMinutes,
    'totalCost': totalCost,
    'riskZone': riskZone,
    'planType': planType,
    'scoreViagem': scoreViagem,
    'pontosGanhos': pontosGanhos,
    'hasSinistro': hasSinistro,
  };

  factory TripHistoryRecord.fromJson(Map<String, dynamic> j) =>
      TripHistoryRecord(
        id: j['id'] as String,
        datetime: DateTime.fromMillisecondsSinceEpoch(j['datetime'] as int),
        origin: j['origin'] as String,
        destination: j['destination'] as String,
        kmTotal: (j['kmTotal'] as num).toDouble(),
        durationMinutes: j['durationMinutes'] as int,
        totalCost: (j['totalCost'] as num).toDouble(),
        riskZone: j['riskZone'] as String? ?? 'amarela',
        planType: j['planType'] as String? ?? 'Equilibrado',
        scoreViagem: j['scoreViagem'] as int? ?? 85,
        pontosGanhos: j['pontosGanhos'] as int? ?? 10,
        hasSinistro: j['hasSinistro'] as bool? ?? false,
      );
}

// ──────────────────────────────────────────────────────────────────
// SERVIÇO
// ──────────────────────────────────────────────────────────────────
class TripHistoryService {
  static const _kHistory = 'trip_history_v1';
  static const _maxRecords = 100;

  static List<TripHistoryRecord>? _cached;

  // ── Carregar ─────────────────────────────────────────────────────
  static Future<List<TripHistoryRecord>> loadAll() async {
    if (_cached != null) return List.unmodifiable(_cached!);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistory);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _cached = list
            .cast<Map<String, dynamic>>()
            .map(TripHistoryRecord.fromJson)
            .toList()
          ..sort((a, b) => b.datetime.compareTo(a.datetime));
        return List.unmodifiable(_cached!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TripHistory] load error: $e');
    }
    _cached = [];
    return [];
  }

  // ── Salvar viagem ─────────────────────────────────────────────────
  static Future<void> saveTrip(TripHistoryRecord trip) async {
    final list = await loadAll();
    final mutable = [trip, ...list].take(_maxRecords).toList();
    _cached = mutable;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kHistory,
        jsonEncode(mutable.map((t) => t.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TripHistory] save error: $e');
    }
  }

  // ── Buscar por mês ─────────────────────────────────────────────────
  static Future<List<TripHistoryRecord>> loadByMonth(int year, int month) async {
    final all = await loadAll();
    return all
        .where((t) => t.datetime.year == year && t.datetime.month == month)
        .toList();
  }

  // ── Estatísticas do mês ────────────────────────────────────────────
  static Future<Map<String, dynamic>> statsForMonth(int year, int month) async {
    final trips = await loadByMonth(year, month);
    final totalKm = trips.fold(0.0, (s, t) => s + t.kmTotal);
    final totalCost = trips.fold(0.0, (s, t) => s + t.totalCost);
    return {
      'count': trips.length,
      'km': totalKm,
      'cost': totalCost,
    };
  }

  // ── Estatísticas do dia de hoje ────────────────────────────────────
  static Future<Map<String, dynamic>> statsForToday() async {
    final all = await loadAll();
    final today = DateTime.now();
    final todayTrips = all.where((t) =>
      t.datetime.year == today.year &&
      t.datetime.month == today.month &&
      t.datetime.day == today.day
    ).toList();
    final km = todayTrips.fold(0.0, (s, t) => s + t.kmTotal);
    final cost = todayTrips.fold(0.0, (s, t) => s + t.totalCost);
    return {'count': todayTrips.length, 'km': km, 'cost': cost};
  }

  // ── Última viagem ─────────────────────────────────────────────────
  static Future<TripHistoryRecord?> lastTrip() async {
    final all = await loadAll();
    return all.isNotEmpty ? all.first : null;
  }

  // ── Criar registro a partir de viagem simulada ────────────────────
  static TripHistoryRecord createFromSimulation({
    required String origin,
    required String destination,
    required double km,
    required double cost,
    required int durationMin,
    String riskZone = 'amarela',
    String planType = 'Equilibrado',
  }) {
    final score = (75 + (cost < 5 ? 15 : cost < 10 ? 10 : 5)).clamp(0, 100);
    return TripHistoryRecord(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      datetime: DateTime.now(),
      origin: origin,
      destination: destination,
      kmTotal: km,
      durationMinutes: durationMin,
      totalCost: cost,
      riskZone: riskZone,
      planType: planType,
      scoreViagem: score,
      pontosGanhos: (km * 2).round(),
    );
  }

  static void invalidateCache() => _cached = null;
}

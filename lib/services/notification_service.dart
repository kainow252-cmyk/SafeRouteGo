// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION SERVICE — SafeRoute
// Notificações persistidas em SharedPreferences
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────
// MODELO
// ──────────────────────────────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'info', 'achievement', 'discount', 'alert', 'trip'
  final DateTime datetime;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.datetime,
    this.isRead = false,
  });

  IconData get icon {
    switch (type) {
      case 'achievement': return Icons.emoji_events_rounded;
      case 'discount':    return Icons.percent_rounded;
      case 'alert':       return Icons.warning_rounded;
      case 'trip':        return Icons.shield_rounded;
      default:            return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'achievement': return const Color(0xFFF59E0B);
      case 'discount':    return const Color(0xFF22C55E);
      case 'alert':       return const Color(0xFFEF4444);
      case 'trip':        return const Color(0xFF1A56DB);
      default:            return const Color(0xFF64748B);
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(datetime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${datetime.day}/${datetime.month}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'datetime': datetime.millisecondsSinceEpoch,
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    type: j['type'] as String? ?? 'info',
    datetime: DateTime.fromMillisecondsSinceEpoch(j['datetime'] as int),
    isRead: j['isRead'] as bool? ?? false,
  );
}

// ──────────────────────────────────────────────────────────────────
// SERVIÇO
// ──────────────────────────────────────────────────────────────────
class NotificationService {
  static const _kNotifs = 'app_notifications_v1';
  static const _maxNotifs = 50;

  static List<AppNotification>? _cached;

  static Future<List<AppNotification>> loadAll() async {
    if (_cached != null) return List.from(_cached!);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kNotifs);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _cached = list.cast<Map<String, dynamic>>()
            .map(AppNotification.fromJson).toList()
          ..sort((a, b) => b.datetime.compareTo(a.datetime));
        return List.from(_cached!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] load error: $e');
    }
    // Notificações iniciais de boas-vindas
    _cached = _initialNotifications();
    await _persist();
    return List.from(_cached!);
  }

  static List<AppNotification> _initialNotifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'welcome',
        title: 'Bem-vindo ao SafeRouteGo! 🎉',
        body: 'Ative sua proteção antes da primeira viagem e ganhe 50 pontos bônus.',
        type: 'info',
        datetime: now.subtract(const Duration(minutes: 5)),
      ),
      AppNotification(
        id: 'benefit_new',
        title: 'Novo benefício disponível',
        body: 'Lavagem Premium: 2ª lavagem grátis no mês. Aproveite!',
        type: 'discount',
        datetime: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'score_tip',
        title: 'Dica de pontuação ⭐',
        body: 'Evite freadas bruscas e acelere suavemente para maximizar seu score.',
        type: 'info',
        datetime: now.subtract(const Duration(hours: 6)),
        isRead: true,
      ),
    ];
  }

  static Future<void> add(AppNotification notif) async {
    await loadAll();
    _cached!.insert(0, notif);
    if (_cached!.length > _maxNotifs) _cached = _cached!.take(_maxNotifs).toList();
    await _persist();
  }

  static Future<void> addTripNotification(String destination, double km, double cost) async {
    await add(AppNotification(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Viagem concluída com sucesso!',
      body: 'Destino: $destination · ${km.round()} km · R\$ ${cost.toStringAsFixed(2).replaceAll('.', ',')}',
      type: 'trip',
      datetime: DateTime.now(),
    ));
  }

  static Future<void> addAchievementNotification(String achievement) async {
    await add(AppNotification(
      id: 'ach_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Conquista desbloqueada! 🏆',
      body: achievement,
      type: 'achievement',
      datetime: DateTime.now(),
    ));
  }

  static Future<void> markAllRead() async {
    await loadAll();
    for (final n in _cached!) { n.isRead = true; }
    await _persist();
  }

  static Future<void> markRead(String id) async {
    await loadAll();
    for (final n in _cached!) {
      if (n.id == id) { n.isRead = true; break; }
    }
    await _persist();
  }

  static Future<int> unreadCount() async {
    final list = await loadAll();
    return list.where((n) => !n.isRead).length;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kNotifs,
        jsonEncode(_cached!.map((n) => n.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] persist error: $e');
    }
  }

  static void invalidateCache() => _cached = null;
}

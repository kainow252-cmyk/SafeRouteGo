// ═══════════════════════════════════════════════════════════════
// FREQUENT ROUTES SERVICE — CRUD com SharedPreferences
// ═══════════════════════════════════════════════════════════════
// ignore_for_file: prefer_single_quotes
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Enum de tipo de rota frequente ─────────────────────────────
enum FrequentRouteType { home, work, gym, school, market, other }

extension FrequentRouteTypeExt on FrequentRouteType {
  String get label {
    switch (this) {
      case FrequentRouteType.home:   return 'Casa';
      case FrequentRouteType.work:   return 'Trabalho';
      case FrequentRouteType.gym:    return 'Academia';
      case FrequentRouteType.school: return 'Escola';
      case FrequentRouteType.market: return 'Mercado';
      case FrequentRouteType.other:  return 'Outro';
    }
  }

  IconData get icon {
    switch (this) {
      case FrequentRouteType.home:   return Icons.home_rounded;
      case FrequentRouteType.work:   return Icons.work_rounded;
      case FrequentRouteType.gym:    return Icons.fitness_center_rounded;
      case FrequentRouteType.school: return Icons.school_rounded;
      case FrequentRouteType.market: return Icons.shopping_cart_rounded;
      case FrequentRouteType.other:  return Icons.place_rounded;
    }
  }

  Color get color {
    switch (this) {
      case FrequentRouteType.home:   return const Color(0xFF22C55E);
      case FrequentRouteType.work:   return const Color(0xFF1A56DB);
      case FrequentRouteType.gym:    return const Color(0xFFEA580C);
      case FrequentRouteType.school: return const Color(0xFF7C3AED);
      case FrequentRouteType.market: return const Color(0xFF0891B2);
      case FrequentRouteType.other:  return const Color(0xFF6B7280);
    }
  }

  String get key {
    switch (this) {
      case FrequentRouteType.home:   return 'home';
      case FrequentRouteType.work:   return 'work';
      case FrequentRouteType.gym:    return 'gym';
      case FrequentRouteType.school: return 'school';
      case FrequentRouteType.market: return 'market';
      case FrequentRouteType.other:  return 'other';
    }
  }

  static FrequentRouteType fromKey(String k) {
    switch (k) {
      case 'home':   return FrequentRouteType.home;
      case 'work':   return FrequentRouteType.work;
      case 'gym':    return FrequentRouteType.gym;
      case 'school': return FrequentRouteType.school;
      case 'market': return FrequentRouteType.market;
      default:       return FrequentRouteType.other;
    }
  }
}

// ── Model ───────────────────────────────────────────────────────
class FrequentRoute {
  final String id;
  final FrequentRouteType type;
  final String label;
  final String address;
  final double lat;
  final double lon;
  final DateTime createdAt;
  final int tripCount;

  const FrequentRoute({
    required this.id,
    required this.type,
    required this.label,
    required this.address,
    required this.lat,
    required this.lon,
    required this.createdAt,
    this.tripCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.key,
    'label': label,
    'address': address,
    'lat': lat,
    'lon': lon,
    'createdAt': createdAt.toIso8601String(),
    'tripCount': tripCount,
  };

  factory FrequentRoute.fromJson(Map<String, dynamic> j) => FrequentRoute(
    id:        j['id'] as String,
    type:      FrequentRouteTypeExt.fromKey(j['type'] as String? ?? 'other'),
    label:     j['label'] as String? ?? '',
    address:   j['address'] as String? ?? '',
    lat:       (j['lat'] as num).toDouble(),
    lon:       (j['lon'] as num).toDouble(),
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    tripCount: j['tripCount'] as int? ?? 0,
  );

  FrequentRoute copyWith({
    String? label, String? address, double? lat, double? lon,
    FrequentRouteType? type, int? tripCount,
  }) => FrequentRoute(
    id: id, createdAt: createdAt,
    type:      type ?? this.type,
    label:     label ?? this.label,
    address:   address ?? this.address,
    lat:       lat ?? this.lat,
    lon:       lon ?? this.lon,
    tripCount: tripCount ?? this.tripCount,
  );
}

// ── Service ─────────────────────────────────────────────────────
class FrequentRoutesService {
  static const _key = 'frequent_routes_v1';

  static Future<List<FrequentRoute>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => FrequentRoute.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<FrequentRoute> routes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(routes.map((r) => r.toJson()).toList()));
  }

  static Future<void> add(FrequentRoute route) async {
    final routes = await load();
    routes.add(route);
    await _save(routes);
  }

  static Future<void> update(FrequentRoute route) async {
    final routes = await load();
    final idx = routes.indexWhere((r) => r.id == route.id);
    if (idx >= 0) {
      routes[idx] = route;
      await _save(routes);
    }
  }

  static Future<void> remove(String id) async {
    final routes = await load();
    routes.removeWhere((r) => r.id == id);
    await _save(routes);
  }

  static Future<void> incrementUsage(String id) async {
    final routes = await load();
    final idx = routes.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      routes[idx] = routes[idx].copyWith(tripCount: routes[idx].tripCount + 1);
      await _save(routes);
    }
  }

  static String generateId() =>
      'fr_${DateTime.now().millisecondsSinceEpoch}';
}

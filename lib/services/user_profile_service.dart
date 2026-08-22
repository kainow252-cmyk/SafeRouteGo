// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════
// USER PROFILE SERVICE — SafeRoute
// Persiste nome, CPF, e-mail, telefone, veículos em SharedPreferences
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────────────────────────
// MODELOS
// ──────────────────────────────────────────────────────────────────

class VehicleProfile {
  final String id;
  final String brand;
  final String model;
  final String year;
  final String plate;
  final bool isActive;

  const VehicleProfile({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    this.isActive = false,
  });

  String get displayName => '$brand $model · $plate';
  String get shortName => '$brand $model';

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'model': model,
    'year': year,
    'plate': plate,
    'isActive': isActive,
  };

  factory VehicleProfile.fromJson(Map<String, dynamic> j) => VehicleProfile(
    id: j['id'] as String,
    brand: j['brand'] as String,
    model: j['model'] as String,
    year: j['year'] as String,
    plate: j['plate'] as String,
    isActive: j['isActive'] as bool? ?? false,
  );

  VehicleProfile copyWith({
    String? id, String? brand, String? model,
    String? year, String? plate, bool? isActive,
  }) => VehicleProfile(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    year: year ?? this.year,
    plate: plate ?? this.plate,
    isActive: isActive ?? this.isActive,
  );
}

class UserProfile {
  final String nome;
  final String cpf;
  final String email;
  final String telefone;
  final String membroDesde;
  final List<VehicleProfile> veiculos;
  final String? photoBase64;

  const UserProfile({
    required this.nome,
    required this.cpf,
    required this.email,
    required this.telefone,
    required this.membroDesde,
    required this.veiculos,
    this.photoBase64,
  });

  /// Inicial do nome para o avatar
  String get inicial => nome.isNotEmpty ? nome[0].toUpperCase() : 'U';

  /// Veículo ativo (primeiro com isActive=true, ou o primeiro da lista)
  VehicleProfile? get veiculoAtivo {
    if (veiculos.isEmpty) return null;
    try {
      return veiculos.firstWhere((v) => v.isActive);
    } catch (_) {
      return veiculos.first;
    }
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'cpf': cpf,
    'email': email,
    'telefone': telefone,
    'membroDesde': membroDesde,
    'veiculos': veiculos.map((v) => v.toJson()).toList(),
    'photoBase64': photoBase64,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    nome: j['nome'] as String? ?? 'Usuário',
    cpf: j['cpf'] as String? ?? '',
    email: j['email'] as String? ?? '',
    telefone: j['telefone'] as String? ?? '',
    membroDesde: j['membroDesde'] as String? ?? _mesAno(),
    photoBase64: j['photoBase64'] as String?,
    veiculos: ((j['veiculos'] as List?)?.cast<Map<String, dynamic>>() ?? [])
        .map(VehicleProfile.fromJson)
        .toList(),
  );

  UserProfile copyWith({
    String? nome, String? cpf, String? email, String? telefone,
    String? membroDesde, List<VehicleProfile>? veiculos, String? photoBase64,
  }) => UserProfile(
    nome: nome ?? this.nome,
    cpf: cpf ?? this.cpf,
    email: email ?? this.email,
    telefone: telefone ?? this.telefone,
    membroDesde: membroDesde ?? this.membroDesde,
    veiculos: veiculos ?? this.veiculos,
    photoBase64: photoBase64 ?? this.photoBase64,
  );

  static String _mesAno() {
    final now = DateTime.now();
    const meses = ['janeiro','fevereiro','março','abril','maio','junho',
        'julho','agosto','setembro','outubro','novembro','dezembro'];
    return '${meses[now.month - 1]} ${now.year}';
  }
}

// ──────────────────────────────────────────────────────────────────
// SERVIÇO
// ──────────────────────────────────────────────────────────────────
class UserProfileService {
  static const _kProfile = 'user_profile_v2';

  static UserProfile? _cached;

  static UserProfile get defaultProfile => UserProfile(
    nome: 'Motorista',
    cpf: '',
    email: '',
    telefone: '',
    membroDesde: UserProfile._mesAno(),
    veiculos: [
      VehicleProfile(
        id: 'v1',
        brand: 'Selecione',
        model: 'seu veículo',
        year: '2024',
        plate: 'AAA-0000',
        isActive: true,
      ),
    ],
  );

  // ── Carregar ─────────────────────────────────────────────────────
  static Future<UserProfile> load() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProfile);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _cached = UserProfile.fromJson(j);
        return _cached!;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[UserProfile] load error: $e');
    }
    return defaultProfile;
  }

  // ── Salvar ───────────────────────────────────────────────────────
  static Future<void> save(UserProfile profile) async {
    _cached = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kProfile, jsonEncode(profile.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('[UserProfile] save error: $e');
    }
  }

  // ── Atualizar campo individual ───────────────────────────────────
  static Future<UserProfile> updateField({
    String? nome, String? cpf, String? email, String? telefone,
    String? photoBase64,
  }) async {
    final current = await load();
    final updated = current.copyWith(
      nome: nome, cpf: cpf, email: email,
      telefone: telefone, photoBase64: photoBase64,
    );
    await save(updated);
    return updated;
  }

  // ── Adicionar veículo ────────────────────────────────────────────
  static Future<UserProfile> addVehicle(VehicleProfile v) async {
    final current = await load();
    // Máximo 3 veículos
    if (current.veiculos.length >= 3) {
      final updated = current.copyWith(
        veiculos: [...current.veiculos.take(2), v],
      );
      await save(updated);
      return updated;
    }
    final updated = current.copyWith(veiculos: [...current.veiculos, v]);
    await save(updated);
    return updated;
  }

  // ── Definir veículo ativo ─────────────────────────────────────────
  static Future<UserProfile> setActiveVehicle(String vehicleId) async {
    final current = await load();
    final updated = current.copyWith(
      veiculos: current.veiculos
          .map((v) => v.copyWith(isActive: v.id == vehicleId))
          .toList(),
    );
    await save(updated);
    return updated;
  }

  // ── Remover veículo ──────────────────────────────────────────────
  static Future<UserProfile> removeVehicle(String vehicleId) async {
    final current = await load();
    final novos = current.veiculos.where((v) => v.id != vehicleId).toList();
    // Se removeu o ativo, ativa o primeiro
    if (novos.isNotEmpty && !novos.any((v) => v.isActive)) {
      novos[0] = novos[0].copyWith(isActive: true);
    }
    final updated = current.copyWith(veiculos: novos);
    await save(updated);
    return updated;
  }

  // ── Invalidar cache ──────────────────────────────────────────────
  static void invalidateCache() => _cached = null;
}

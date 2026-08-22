// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — DRIVER PROFILE SERVICE
//
// Perfil completo do condutor, persistido em SharedPreferences.
// Alimenta o ActuarialEngine com dados reais do usuário, substituindo
// os valores hardcoded (driverAge: 28, multas: 0, etc.)
//
// Campos atuarialmente relevantes:
//   • Idade do condutor           → AgeFactor multiplier
//   • Anos de CNH                 → DriverHistory tier
//   • Sinistros (últimos 3 anos)  → DriverHistory.sinistros
//   • Multas (últimos 12 meses)   → DriverHistory.multas
//   • Score interno               → DriverHistory.score
//   • km/mês estimado             → UsageDataV3.kmMes
//   • Padrão de uso               → UsageDataV3.pattern
//   • CEP residência              → CepRiskDatabase origin
//   • Veículo principal           → VehicleRiskDatabase
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE PERFIL
// ─────────────────────────────────────────────────────────────────────────────

class DriverProfile {
  // ── Dados pessoais ────────────────────────────────────────────
  final String nome;
  final int idade;              // anos
  final int cnhAnos;            // tempo de CNH em anos
  final String cnh;             // número CNH (opcional, para display)

  // ── Histórico atuarial ────────────────────────────────────────
  final int sinistros3Anos;     // ocorrências nos últimos 3 anos
  final int multas12Meses;      // multas nos últimos 12 meses
  final int acidentes3Anos;     // acidentes com dano material
  final int acioamentos12Meses; // vezes que acionou o seguro

  // ── Veículo principal ─────────────────────────────────────────
  final String vehicleModel;    // ex: "Chevrolet Onix"
  final String vehicleBrand;    // ex: "Chevrolet"
  final int vehicleYear;        // ano do modelo
  final double vehicleFipe;     // valor FIPE em R$
  final String vehiclePlate;    // placa (opcional)

  // ── Uso ───────────────────────────────────────────────────────
  final double kmMes;           // km estimado por mês
  final String usagePattern;    // 'trabalho','lazer','app','misto','baixoUso'
  final String primaryTimeSlot; // 'manha','tarde','noite','tardio','madrugada'

  // ── Localização ───────────────────────────────────────────────
  final String cepResidencia;   // CEP do endereço principal
  final String cidadeResidencia;
  final String uf;

  // ── Metadados ─────────────────────────────────────────────────
  final DateTime? updatedAt;
  final bool isComplete;        // perfil preenchido o suficiente para cotação

  const DriverProfile({
    this.nome = '',
    this.idade = 28,
    this.cnhAnos = 5,
    this.cnh = '',
    this.sinistros3Anos = 0,
    this.multas12Meses = 0,
    this.acidentes3Anos = 0,
    this.acioamentos12Meses = 0,
    this.vehicleModel = 'BYD Atto 2',
    this.vehicleBrand = 'BYD',
    this.vehicleYear = 2022,
    this.vehicleFipe = 130000,
    this.vehiclePlate = '',
    this.kmMes = 1200,
    this.usagePattern = 'trabalho',
    this.primaryTimeSlot = 'tarde',
    this.cepResidencia = '29170-000',
    this.cidadeResidencia = 'Serra',
    this.uf = 'ES',
    this.updatedAt,
    this.isComplete = false,
  });

  // ── Score atuarial calculado ──────────────────────────────────
  // Baseado na fórmula do DriverHistory do ActuarialEngine
  int get scoreCalculado {
    int s = 1000;
    s -= sinistros3Anos  * 120; // -120 por sinistro
    s -= multas12Meses   * 40;  // -40 por multa
    s -= acidentes3Anos  * 100; // -100 por acidente
    s -= acioamentos12Meses * 50; // -50 por acionamento
    // Bônus por experiência
    if (cnhAnos >= 10) s += 50;
    if (cnhAnos >= 20) s += 30;
    return s.clamp(0, 1000);
  }

  String get scoreTier {
    final s = scoreCalculado;
    if (s >= 900) return 'Elite';
    if (s >= 800) return 'Ouro';
    if (s >= 700) return 'Prata';
    if (s >= 600) return 'Bronze';
    return 'Básico';
  }

  // ── Risco total 0–10 (escala atuarial para o usuário) ─────────
  double get riscoScore {
    double r = 3.0; // base neutra
    // Faixa etária
    if (idade < 25)       r += 2.5;
    else if (idade < 35)  r += 1.2;
    else if (idade > 65)  r += 1.0;
    // Histórico
    r += sinistros3Anos  * 0.8;
    r += multas12Meses   * 0.4;
    r += acidentes3Anos  * 0.7;
    // CNH
    if (cnhAnos < 2)  r += 1.5;
    if (cnhAnos >= 10) r -= 0.5;
    // FIPE alta
    if (vehicleFipe > 200000) r += 0.5;
    if (vehicleFipe > 400000) r += 0.5;
    return r.clamp(1.0, 10.0);
  }

  String get riscoLabel {
    if (riscoScore <= 3.0) return 'Muito Baixo';
    if (riscoScore <= 5.0) return 'Baixo';
    if (riscoScore <= 6.5) return 'Moderado';
    if (riscoScore <= 8.0) return 'Alto';
    return 'Crítico';
  }

  // ── Fatores explicáveis (para o Atuário Virtual) ─────────────
  List<RiskFactor> get factorsExplained {
    final factors = <RiskFactor>[];

    // Faixa etária
    if (idade < 25) {
      factors.add(RiskFactor(
        label: 'Faixa etária ($idade anos)',
        delta: 15.0,
        descricao: 'Condutores abaixo de 25 anos têm 40% mais colisões.',
        tipo: RiskFactorType.negativo,
      ));
    } else if (idade >= 25 && idade <= 35) {
      factors.add(RiskFactor(
        label: 'Faixa etária ($idade anos)',
        delta: 5.0,
        descricao: 'Adultos jovens com risco moderado.',
        tipo: RiskFactorType.neutro,
      ));
    } else if (idade > 36 && idade <= 60) {
      factors.add(RiskFactor(
        label: 'Faixa etária ($idade anos)',
        delta: -5.0,
        descricao: 'Faixa de menor risco — ótimo perfil etário.',
        tipo: RiskFactorType.positivo,
      ));
    }

    // CNH
    if (cnhAnos < 2) {
      factors.add(RiskFactor(
        label: 'CNH recente ($cnhAnos anos)',
        delta: 20.0,
        descricao: 'Habilitação nova aumenta risco de colisão.',
        tipo: RiskFactorType.negativo,
      ));
    } else if (cnhAnos >= 10) {
      factors.add(RiskFactor(
        label: 'CNH experiente ($cnhAnos anos)',
        delta: -8.0,
        descricao: 'Longa experiência reduz chance de acidentes.',
        tipo: RiskFactorType.positivo,
      ));
    }

    // Sinistros
    if (sinistros3Anos > 0) {
      factors.add(RiskFactor(
        label: '$sinistros3Anos sinistro(s) em 3 anos',
        delta: sinistros3Anos * 12.0,
        descricao: 'Histórico de sinistros é o fator mais preditivo de risco.',
        tipo: RiskFactorType.negativo,
      ));
    } else {
      factors.add(RiskFactor(
        label: 'Sem sinistros (3 anos)',
        delta: -10.0,
        descricao: 'Histórico limpo reduz seu prêmio.',
        tipo: RiskFactorType.positivo,
      ));
    }

    // Multas
    if (multas12Meses > 0) {
      factors.add(RiskFactor(
        label: '$multas12Meses multa(s) em 12 meses',
        delta: multas12Meses * 8.0,
        descricao: 'Infrações de trânsito indicam comportamento de risco.',
        tipo: RiskFactorType.negativo,
      ));
    }

    // KM/mês
    if (kmMes > 3000) {
      factors.add(RiskFactor(
        label: 'Alto KM/mês (${kmMes.round()} km)',
        delta: 10.0,
        descricao: 'Maior exposição aumenta probabilidade de sinistro.',
        tipo: RiskFactorType.negativo,
      ));
    } else if (kmMes < 500) {
      factors.add(RiskFactor(
        label: 'Baixo KM/mês (${kmMes.round()} km)',
        delta: -8.0,
        descricao: 'Pouca exposição reduz risco estatístico.',
        tipo: RiskFactorType.positivo,
      ));
    }

    // FIPE
    if (vehicleFipe > 200000) {
      factors.add(RiskFactor(
        label: 'Veículo alto valor (FIPE ${_fmtFipe(vehicleFipe)})',
        delta: 15.0,
        descricao: 'Veículos acima de R\$200k têm custo de reparo elevado.',
        tipo: RiskFactorType.negativo,
      ));
    } else if (vehicleFipe < 60000) {
      factors.add(RiskFactor(
        label: 'Veículo popular (FIPE ${_fmtFipe(vehicleFipe)})',
        delta: -5.0,
        descricao: 'Custo de reparo menor reduz prêmio.',
        tipo: RiskFactorType.positivo,
      ));
    }

    return factors;
  }

  static String _fmtFipe(double v) {
    if (v >= 1000000) return 'R\$${(v / 1000000).toStringAsFixed(1)}M';
    return 'R\$${(v / 1000).toStringAsFixed(0)}k';
  }

  // ── Serialização ─────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'nome': nome,
    'idade': idade,
    'cnhAnos': cnhAnos,
    'cnh': cnh,
    'sinistros3Anos': sinistros3Anos,
    'multas12Meses': multas12Meses,
    'acidentes3Anos': acidentes3Anos,
    'acioamentos12Meses': acioamentos12Meses,
    'vehicleModel': vehicleModel,
    'vehicleBrand': vehicleBrand,
    'vehicleYear': vehicleYear,
    'vehicleFipe': vehicleFipe,
    'vehiclePlate': vehiclePlate,
    'kmMes': kmMes,
    'usagePattern': usagePattern,
    'primaryTimeSlot': primaryTimeSlot,
    'cepResidencia': cepResidencia,
    'cidadeResidencia': cidadeResidencia,
    'uf': uf,
    'updatedAt': updatedAt?.toIso8601String(),
    'isComplete': isComplete,
  };

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
    nome:               j['nome']               as String? ?? '',
    idade:              j['idade']              as int?    ?? 28,
    cnhAnos:            j['cnhAnos']            as int?    ?? 5,
    cnh:                j['cnh']                as String? ?? '',
    sinistros3Anos:     j['sinistros3Anos']     as int?    ?? 0,
    multas12Meses:      j['multas12Meses']      as int?    ?? 0,
    acidentes3Anos:     j['acidentes3Anos']     as int?    ?? 0,
    acioamentos12Meses: j['acioamentos12Meses'] as int?    ?? 0,
    vehicleModel:       j['vehicleModel']       as String? ?? 'BYD Atto 2',
    vehicleBrand:       j['vehicleBrand']       as String? ?? 'BYD',
    vehicleYear:        j['vehicleYear']        as int?    ?? 2022,
    vehicleFipe:        (j['vehicleFipe'] as num?)?.toDouble() ?? 130000,
    vehiclePlate:       j['vehiclePlate']       as String? ?? '',
    kmMes:              (j['kmMes'] as num?)?.toDouble() ?? 1200,
    usagePattern:       j['usagePattern']       as String? ?? 'trabalho',
    primaryTimeSlot:    j['primaryTimeSlot']    as String? ?? 'tarde',
    cepResidencia:      j['cepResidencia']      as String? ?? '29170-000',
    cidadeResidencia:   j['cidadeResidencia']   as String? ?? 'Serra',
    uf:                 j['uf']                 as String? ?? 'ES',
    updatedAt:          j['updatedAt'] != null
        ? DateTime.tryParse(j['updatedAt'] as String)
        : null,
    isComplete:         j['isComplete']         as bool?   ?? false,
  );

  DriverProfile copyWith({
    String? nome, int? idade, int? cnhAnos, String? cnh,
    int? sinistros3Anos, int? multas12Meses, int? acidentes3Anos,
    int? acioamentos12Meses,
    String? vehicleModel, String? vehicleBrand, int? vehicleYear,
    double? vehicleFipe, String? vehiclePlate,
    double? kmMes, String? usagePattern, String? primaryTimeSlot,
    String? cepResidencia, String? cidadeResidencia, String? uf,
    DateTime? updatedAt, bool? isComplete,
  }) => DriverProfile(
    nome:               nome               ?? this.nome,
    idade:              idade              ?? this.idade,
    cnhAnos:            cnhAnos            ?? this.cnhAnos,
    cnh:                cnh                ?? this.cnh,
    sinistros3Anos:     sinistros3Anos     ?? this.sinistros3Anos,
    multas12Meses:      multas12Meses      ?? this.multas12Meses,
    acidentes3Anos:     acidentes3Anos     ?? this.acidentes3Anos,
    acioamentos12Meses: acioamentos12Meses ?? this.acioamentos12Meses,
    vehicleModel:       vehicleModel       ?? this.vehicleModel,
    vehicleBrand:       vehicleBrand       ?? this.vehicleBrand,
    vehicleYear:        vehicleYear        ?? this.vehicleYear,
    vehicleFipe:        vehicleFipe        ?? this.vehicleFipe,
    vehiclePlate:       vehiclePlate       ?? this.vehiclePlate,
    kmMes:              kmMes              ?? this.kmMes,
    usagePattern:       usagePattern       ?? this.usagePattern,
    primaryTimeSlot:    primaryTimeSlot    ?? this.primaryTimeSlot,
    cepResidencia:      cepResidencia      ?? this.cepResidencia,
    cidadeResidencia:   cidadeResidencia   ?? this.cidadeResidencia,
    uf:                 uf                 ?? this.uf,
    updatedAt:          updatedAt          ?? this.updatedAt,
    isComplete:         isComplete         ?? this.isComplete,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FATOR DE RISCO EXPLICÁVEL
// ─────────────────────────────────────────────────────────────────────────────

enum RiskFactorType { positivo, neutro, negativo }

class RiskFactor {
  final String label;
  final double delta;       // variação % no prêmio (+15% = +15.0, -8% = -8.0)
  final String descricao;
  final RiskFactorType tipo;

  const RiskFactor({
    required this.label,
    required this.delta,
    required this.descricao,
    required this.tipo,
  });

  String get deltaLabel {
    if (delta > 0) return '+${delta.toStringAsFixed(0)}%';
    return '${delta.toStringAsFixed(0)}%';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVIÇO — singleton com persistência
// ─────────────────────────────────────────────────────────────────────────────

class DriverProfileService {
  DriverProfileService._();
  static final DriverProfileService instance = DriverProfileService._();

  static const _key = 'driver_profile_v1';

  DriverProfile _profile = const DriverProfile();
  DriverProfile get profile => _profile;

  bool get isLoaded => _profile.updatedAt != null || _profile.isComplete;
  bool get needsSetup => !_profile.isComplete;

  // ── Carrega do SharedPreferences ─────────────────────────────
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _profile = DriverProfile.fromJson(map);
        if (kDebugMode) {
          debugPrint('[DriverProfile] Carregado: ${_profile.nome}, '
              'score=${_profile.scoreCalculado}, risco=${_profile.riscoScore.toStringAsFixed(1)}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DriverProfile] Erro ao carregar: $e');
    }
  }

  // ── Salva no SharedPreferences ────────────────────────────────
  Future<void> save(DriverProfile profile) async {
    _profile = profile.copyWith(updatedAt: DateTime.now());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_profile.toJson()));
      if (kDebugMode) debugPrint('[DriverProfile] Salvo: score=${_profile.scoreCalculado}');
    } catch (e) {
      if (kDebugMode) debugPrint('[DriverProfile] Erro ao salvar: $e');
    }
  }

  // ── Atualiza parcialmente ──────────────────────────────────────
  Future<void> update(DriverProfile updated) => save(updated);

  // ── Reset ─────────────────────────────────────────────────────
  Future<void> clear() async {
    _profile = const DriverProfile();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

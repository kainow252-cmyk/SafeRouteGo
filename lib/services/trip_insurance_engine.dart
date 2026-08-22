// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — TRIP INSURANCE ENGINE  (MOTOR ATUARIAL DE VIAGEM)
//
// Motor interno de precificação dinâmica por trajeto.
// Consome APIs reais em paralelo e produz o prêmio final.
// O USUÁRIO VÊ APENAS: rota · distância · risco · R$ final.
// TODO O RESTO É OCULTO — igual ao algoritmo de preço do Uber.
//
// FLUXO INTERNO:
//   1. Coleta paralela: clima (OpenWeather) + trânsito (OSRM/TomTom)
//                     + crime (dados.gov.br) + acidentes (PRF) + FIPE
//   2. Cada fonte gera um multiplicador (fator atuarial)
//   3. Score = 100 × f_clima × f_transito × f_crime × f_acidente × f_veiculo × f_condutor
//   4. Normaliza: score_raw ÷ 3 → índice 0–100
//   5. Probabilidades por cobertura (colisão, roubo, furto, terceiros)
//   6. Fórmula: Prêmio = P×Sev + Operação(12%) + Reserva(10%) + Margem(8%)
//   7. Retorna TripInsuranceResult — JSON completo pronto para API interna
//
// SEGREDO COMERCIAL: esta classe não é exposta em nenhuma tela do usuário.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'risk_engine.dart';
import 'driver_profile_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAVES DE API  (sem autenticação = gratuitas por padrão)
// Substitua pelas chaves reais quando disponíveis.
// ─────────────────────────────────────────────────────────────────────────────
class _ApiKeys {
  // OpenWeatherMap — gratuito 60 calls/min
  // https://openweathermap.org/api
  static const openWeather = 'SEM_CHAVE'; // substituir: 'abc123...'

  // TomTom Traffic — gratuito 2.500 calls/dia
  // https://developer.tomtom.com/traffic-api/documentation
  static const tomTom = 'SEM_CHAVE'; // substituir: 'xyz789...'

  // Geoapify — gratuito 3.000 calls/dia
  // https://www.geoapify.com/
  static const geoapify = 'SEM_CHAVE';
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO DE CADA FONTE  (multiplicador + label para o painel interno)
// ─────────────────────────────────────────────────────────────────────────────
class ApiFactorResult {
  final String source;    // 'openweather' | 'osrm' | 'tomtom' | 'prf' | 'fipe' | 'condutor' | 'fallback'
  final double factor;    // multiplicador atuarial (ex: 1.20)
  final String label;     // ex: 'Chuva leve — 7.2 mm'
  final String detail;    // dado bruto retornado pela API
  final bool isLive;      // true = dado real de API; false = heurística interna

  const ApiFactorResult({
    required this.source,
    required this.factor,
    required this.label,
    required this.detail,
    this.isLive = false,
  });

  String get factorFmt => '×${factor.toStringAsFixed(2)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// PROBABILIDADES POR COBERTURA
// ─────────────────────────────────────────────────────────────────────────────
class TripProbabilities {
  final double colisao;    // % anual → por viagem = anual × (distKm / kmAno)
  final double roubo;
  final double furto;
  final double terceiros;
  final double perdaTotal;
  final double assistencia;
  final double pTotal;     // P(ao menos um evento nesta viagem)

  final double custoColisao;
  final double custoRoubo;
  final double custoFurto;
  final double custoTerceiros;
  final double custoEsperadoViagem; // R$ esperado para esta viagem

  const TripProbabilities({
    required this.colisao,
    required this.roubo,
    required this.furto,
    required this.terceiros,
    required this.perdaTotal,
    required this.assistencia,
    required this.pTotal,
    required this.custoColisao,
    required this.custoRoubo,
    required this.custoFurto,
    required this.custoTerceiros,
    required this.custoEsperadoViagem,
  });

  String fmt(double p) => '${(p * 100).toStringAsFixed(2)}%';
  String fmtBRL(double v) {
    if (v < 0.01) return 'R\$ 0,00';
    final s = v.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEGMENTOS DE ROTA  (cada trecho tem seu próprio índice de risco)
// Baseado na estrutura descrita pelo usuário:
//   BR-101 / Contorno / Zona Laranja / Centro / etc.
// ─────────────────────────────────────────────────────────────────────────────
class RouteSegment {
  final String nome;
  final double crimeFactor;   // multiplicador de criminalidade
  final double accidentFactor;// multiplicador de acidentes
  final double kmShare;       // % da rota neste trecho (0.0–1.0)

  const RouteSegment({
    required this.nome,
    required this.crimeFactor,
    required this.accidentFactor,
    required this.kmShare,
  });

  // Índice de risco combinado do segmento
  double get segmentRisk => crimeFactor * accidentFactor * kmShare;
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO COMPLETO  (o JSON que sairia de uma API interna)
// ─────────────────────────────────────────────────────────────────────────────
class TripInsuranceResult {
  // ── Identificação da viagem ───────────────────────────────────
  final String origem;
  final String destino;
  final double distanciaKm;
  final int    estimativaMinutos;
  final DateTime calculadoEm;

  // ── Score atuarial ────────────────────────────────────────────
  final double scoreBase;        // sempre 100
  final double scoreRaw;         // 100 × todos os multiplicadores
  final double scoreNormalizado; // scoreRaw ÷ 3 → 0–100
  final String nivelRisco;       // 'baixo' | 'moderado' | 'médio' | 'alto' | 'crítico'
  final String nivelLabel;       // label para exibição

  // ── Multiplicadores individuais (os "fatores" do Uber interno) ─
  final ApiFactorResult fatorClima;
  final ApiFactorResult fatorTransito;
  final ApiFactorResult fatorCrime;
  final ApiFactorResult fatorAcidentes;
  final ApiFactorResult fatorVeiculo;
  final ApiFactorResult fatorCondutor;

  // ── Segmentos de rota ─────────────────────────────────────────
  final List<RouteSegment> segmentos;
  final double fatorSegmentoComposito; // ponderado por kmShare

  // ── Probabilidades ────────────────────────────────────────────
  final TripProbabilities probs;

  // ── Precificação (fórmula atuarial completa) ─────────────────
  final double riscoEsperado;   // P × Severidade
  final double operacao;        // 12%
  final double reserva;         // 10%
  final double margem;          // 8%
  final double premioViagem;    // R$ para esta viagem
  final double premioAnual;     // R$ anualizado
  final double premioMensal;    // R$ mensal
  final double premioPorKm;     // R$/km
  final double franquia;        // R$ franquia calculada

  // ── Dados brutos das APIs (para o painel interno) ─────────────
  final Map<String, dynamic> rawApiData;

  TripInsuranceResult({
    required this.origem,
    required this.destino,
    required this.distanciaKm,
    required this.estimativaMinutos,
    required this.scoreBase,
    required this.scoreRaw,
    required this.scoreNormalizado,
    required this.nivelRisco,
    required this.nivelLabel,
    required this.fatorClima,
    required this.fatorTransito,
    required this.fatorCrime,
    required this.fatorAcidentes,
    required this.fatorVeiculo,
    required this.fatorCondutor,
    required this.segmentos,
    required this.fatorSegmentoComposito,
    required this.probs,
    required this.riscoEsperado,
    required this.operacao,
    required this.reserva,
    required this.margem,
    required this.premioViagem,
    required this.premioAnual,
    required this.premioMensal,
    required this.premioPorKm,
    required this.franquia,
    required this.rawApiData,
  }) : calculadoEm = DateTime.now();

  // ── Formatadores ─────────────────────────────────────────────
  String get premioViagemFmt  => 'R\$ ${premioViagem.toStringAsFixed(2).replaceAll('.', ',')}';
  String get premioAnualFmt   => 'R\$ ${premioAnual.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  String get premioMensalFmt  => 'R\$ ${premioMensal.toStringAsFixed(2).replaceAll('.', ',')}';
  String get premioPorKmFmt   => 'R\$ ${premioPorKm.toStringAsFixed(3).replaceAll('.', ',')}';
  String get franquiaFmt      => 'R\$ ${franquia.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  String get scoreLabel       => '${scoreNormalizado.toStringAsFixed(1)}/100';

  // ── JSON de saída (formato API interna — igual a uma seguradora) ─
  Map<String, dynamic> toApiJson() => {
    'rota':               '$origem → $destino',
    'distancia_km':       distanciaKm,
    'estimativa_min':     estimativaMinutos,
    'score_risco':        double.parse(scoreNormalizado.toStringAsFixed(1)),
    'nivel':              nivelRisco,
    'fatores': {
      'clima':      fatorClima.factor,
      'transito':   fatorTransito.factor,
      'crime':      fatorCrime.factor,
      'acidentes':  fatorAcidentes.factor,
      'veiculo':    fatorVeiculo.factor,
      'condutor':   fatorCondutor.factor,
    },
    'prob_colisao':       double.parse((probs.colisao * 100).toStringAsFixed(2)),
    'prob_roubo':         double.parse((probs.roubo  * 100).toStringAsFixed(2)),
    'prob_furto':         double.parse((probs.furto  * 100).toStringAsFixed(2)),
    'prob_terceiros':     double.parse((probs.terceiros * 100).toStringAsFixed(2)),
    'prob_perda_total':   double.parse((probs.perdaTotal * 100).toStringAsFixed(2)),
    'prob_total_viagem':  double.parse((probs.pTotal * 100).toStringAsFixed(4)),
    'custo_esperado_R\$': double.parse(probs.custoEsperadoViagem.toStringAsFixed(2)),
    'premio_viagem':      double.parse(premioViagem.toStringAsFixed(2)),
    'premio_anual':       double.parse(premioAnual.toStringAsFixed(2)),
    'premio_mensal':      double.parse(premioMensal.toStringAsFixed(2)),
    'premio_por_km':      double.parse(premioPorKm.toStringAsFixed(4)),
    'franquia':           double.parse(franquia.toStringAsFixed(2)),
    'calculado_em':       calculadoEm.toIso8601String(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIP INSURANCE ENGINE  — ORQUESTRADOR PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class TripInsuranceEngine {

  // ═══════════════════════════════════════════════════════════════
  // MÉTODO PRINCIPAL — chame este no _recalculate()
  // Executa todas as chamadas de API em paralelo (Future.wait)
  // ═══════════════════════════════════════════════════════════════
  static Future<TripInsuranceResult> calculate({
    // Rota
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required String origemLabel,
    required String destinoLabel,
    required double distanciaKm,

    // Veículo (FIPE já carregado no app)
    required double fipeValor,
    required int    anoModelo,
    required String vehicleModel,

    // Condutor (DriverProfileService)
    required DriverProfile condutor,
  }) async {

    // ── COLETA PARALELA — todas as APIs ao mesmo tempo ──────────
    final results = await Future.wait([
      _fetchClima(fromLat, fromLon),           // [0] OpenWeather
      _fetchTransito(fromLat, fromLon,          // [1] OSRM + TomTom
                     toLat,   toLon),
      _calcCrime(fromLat, fromLon,              // [2] heurística GPS + dados.gov
                 toLat,   toLon),
      _calcAcidentes(fromLat, fromLon,          // [3] PRF / heurística
                     toLat,   toLon),
      _calcVeiculo(fipeValor, anoModelo,        // [4] FIPE + índice roubo
                   vehicleModel),
      _calcCondutor(condutor),                  // [5] perfil condutor
    ]);

    final fClima    = results[0];
    final fTransito = results[1];
    final fCrime    = results[2];
    final fAcident  = results[3];
    final fVeiculo  = results[4];
    final fCondutor = results[5];

    // ── SEGMENTOS DE ROTA ────────────────────────────────────────
    final segmentos = _buildSegmentos(fromLat, fromLon, toLat, toLon, distanciaKm);
    final fSegmento = _calcFatorSegmento(segmentos);

    // ── SCORE ATUARIAL ───────────────────────────────────────────
    // Score Base = 100 × todos os multiplicadores (exatamente como descrito)
    const scoreBase = 100.0;
    final scoreRaw  = scoreBase
        * fClima.factor
        * fTransito.factor
        * fCrime.factor
        * fAcident.factor
        * fVeiculo.factor
        * fCondutor.factor
        * fSegmento;

    // Normaliza: scoreRaw ÷ 3 → faixa 0–100
    final scoreNorm = (scoreRaw / 3.0).clamp(0.0, 100.0);
    final (nivel, nivelLabel) = _nivelRisco(scoreNorm);

    // ── PROBABILIDADES POR COBERTURA ─────────────────────────────
    final probs = _calcProbabilidades(
      scoreNorm:   scoreNorm,
      fipeValor:   fipeValor,
      distanciaKm: distanciaKm,
      kmAno:       condutor.kmMes * 12,
      fCrime:      fCrime.factor,
      fClima:      fClima.factor,
      fTransito:   fTransito.factor,
      fCondutor:   fCondutor.factor,
      fromLat:     fromLat,
      fromLon:     fromLon,
      toLat:       toLat,
      toLon:       toLon,
    );

    // ── FÓRMULA ATUARIAL CORRETA ─────────────────────────────────────
    //
    //  Risco Esperado Anual  = Σ(P × Severidade × FIPE) — já calculado em probs
    //  Custo anual base      = soma de todos os custos esperados por cobertura
    //  Prêmio Técnico Anual  = Risco × fator score
    //  Prêmio Bruto Anual    = Técnico ÷ (1 − 0.30) [loading = 30%]
    //  Prêmio da Viagem      = Anual × (km_viagem / km_condutor_ano)
    //
    const loadingTotal = 0.30; // 12% op + 10% reserva + 8% margem

    // Risco anual total = Σ custos por cobertura (P × Sev × FIPE)
    final riscoAnualBase = probs.custoColisao + probs.custoRoubo +
                           probs.custoFurto  + probs.custoTerceiros;

    // Fator de ajuste pelo score normalizado (>50 = acima da média de risco)
    final fatorScore = (scoreNorm / 50.0).clamp(0.5, 3.0);

    // Prêmio técnico e bruto anual
    final premioTecnicoAnual = riscoAnualBase * fatorScore;
    final premioAnualBruto   = premioTecnicoAnual / (1.0 - loadingTotal);

    // Breakdown
    final operacao = premioAnualBruto * 0.12;
    final reserva  = premioAnualBruto * 0.10;
    final margem   = premioAnualBruto * 0.08;
    final riscoBruto = premioTecnicoAnual;

    final premioAnual = premioAnualBruto.clamp(900.0, 180000.0);
    final premioMens  = premioAnual / 12;

    // km real do condutor
    final kmAno  = math.max(condutor.kmMes * 12.0, 6000.0);
    final premioKm = premioAnual / kmAno;

    // PRÊMIO DA VIAGEM = rateia o custo anual pela exposição desta viagem
    // Sem clamp máximo — prêmio reflete o risco real da distância percorrida.
    // Viagens longas (ex: ES→SP 900km) geram prêmio proporcional ao risco.
    final fracaoExposicao = math.max(distanciaKm / kmAno, 0.0005);
    final premioViagemBruto = premioAnualBruto * fracaoExposicao;
    final premioViagem = math.max(premioViagemBruto, 4.99);

    final franquia = (fipeValor * 0.05 * (1 + scoreNorm / 200)).clamp(500.0, 15000.0);

    // ── DADOS BRUTOS (painel interno) ────────────────────────────
    final rawData = <String, dynamic>{
      'clima_label':    fClima.detail,
      'transito_label': fTransito.detail,
      'crime_label':    fCrime.detail,
      'acidente_label': fAcident.detail,
      'veiculo_label':  fVeiculo.detail,
      'condutor_label': fCondutor.detail,
      'score_raw':      scoreRaw,
      'score_norm':     scoreNorm,
      'segmentos':      segmentos.map((s) => {
        'nome': s.nome, 'crime': s.crimeFactor, 'acidente': s.accidentFactor,
        'km_share': s.kmShare,
      }).toList(),
    };

    return TripInsuranceResult(
      origem:               origemLabel,
      destino:              destinoLabel,
      distanciaKm:          distanciaKm,
      estimativaMinutos:    (distanciaKm / 0.67).round(), // ~40 km/h urbano
      scoreBase:            scoreBase,
      scoreRaw:             scoreRaw,
      scoreNormalizado:     scoreNorm,
      nivelRisco:           nivel,
      nivelLabel:           nivelLabel,
      fatorClima:           fClima,
      fatorTransito:        fTransito,
      fatorCrime:           fCrime,
      fatorAcidentes:       fAcident,
      fatorVeiculo:         fVeiculo,
      fatorCondutor:        fCondutor,
      segmentos:            segmentos,
      fatorSegmentoComposito: fSegmento,
      probs:                probs,
      riscoEsperado:        riscoBruto,
      operacao:             operacao,
      reserva:              reserva,
      margem:               margem,
      premioViagem:         premioViagem,
      premioAnual:          premioAnual,
      premioMensal:         premioMens,
      premioPorKm:          premioKm,
      franquia:             franquia,
      rawApiData:           rawData,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FONTE 1 — CLIMA  (OpenWeatherMap)
  // GET /data/2.5/weather?lat=&lon=&appid=&units=metric&lang=pt_br
  // ═══════════════════════════════════════════════════════════════
  static Future<ApiFactorResult> _fetchClima(double lat, double lon) async {
    try {
      if (_ApiKeys.openWeather == 'SEM_CHAVE') {
        return _climaHeuristico(DateTime.now().hour);
      }
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat&lon=$lon'
        '&appid=${_ApiKeys.openWeather}'
        '&units=metric&lang=pt_br',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return _climaHeuristico(DateTime.now().hour);

      final j   = jsonDecode(res.body) as Map<String, dynamic>;
      final id  = (j['weather'] as List).first['id'] as int;
      final desc= (j['weather'] as List).first['description'] as String;
      final rain= (j['rain'] as Map?)?.values.firstOrNull ?? 0.0;
      final vis = (j['visibility'] as num?)?.toDouble() ?? 10000;

      // Tabela de fatores por código de condição OpenWeather
      // https://openweathermap.org/weather-conditions
      double factor;
      String label;
      if (id >= 200 && id < 300) {
        factor = 1.55; label = 'Tempestade elétrica — ×1.55';
      } else if (id >= 300 && id < 400) {
        factor = 1.15; label = 'Garoa — ×1.15';
      } else if (id >= 500 && id < 502) {
        factor = 1.22; label = 'Chuva leve ${rain.toStringAsFixed(1)} mm — ×1.22';
      } else if (id >= 502 && id < 600) {
        factor = 1.50; label = 'Chuva forte ${rain.toStringAsFixed(1)} mm — ×1.50';
      } else if (id >= 600 && id < 700) {
        factor = 1.60; label = 'Neve/granizo — ×1.60';
      } else if (id >= 700 && id < 800) {
        factor = 1.20; label = 'Neblina (vis. ${(vis/1000).toStringAsFixed(1)} km) — ×1.20';
      } else {
        factor = 1.00; label = '$desc — ×1.00';
      }

      return ApiFactorResult(
        source: 'openweather', factor: factor, label: label,
        detail: '${desc.toUpperCase()} | vis ${(vis/1000).toStringAsFixed(1)} km | rain ${rain.toStringAsFixed(1)} mm',
        isLive: true,
      );

    } catch (_) {
      return _climaHeuristico(DateTime.now().hour);
    }
  }

  static ApiFactorResult _climaHeuristico(int hora) {
    // Sem API key — usa hora do dia como proxy (ES chove à tarde)
    if (hora >= 13 && hora <= 17) {
      return const ApiFactorResult(
        source: 'fallback', factor: 1.20,
        label: 'Tarde — probabilidade de chuva (ES)',
        detail: 'SEM CHAVE OPENWEATHER — heurística horária',
      );
    }
    return const ApiFactorResult(
      source: 'fallback', factor: 1.00,
      label: 'Sol / nublado (heurística)',
      detail: 'SEM CHAVE OPENWEATHER — heurística horária',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FONTE 2 — TRÂNSITO  (OSRM grátis + TomTom se tiver chave)
  // OSRM annotations=speed → velocidade real por segmento
  // TomTom flowSegmentData → freeFlow vs currentSpeed
  // ═══════════════════════════════════════════════════════════════
  static Future<ApiFactorResult> _fetchTransito(
      double fLat, double fLon, double tLat, double tLon) async {
    try {
      // OSRM annotations=speed (já usado no TrafficDetectionService)
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving'
        '/$fLon,$fLat;$tLon,$tLat'
        '?overview=false&annotations=speed',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return _transitoFallback();

      final j     = jsonDecode(res.body) as Map<String, dynamic>;
      final route = (j['routes'] as List?)?.first as Map<String, dynamic>?;
      if (route == null) return _transitoFallback();

      final legs  = route['legs'] as List? ?? [];
      final speeds= <double>[];
      for (final leg in legs) {
        final ann  = (leg as Map)['annotation'] as Map?;
        final spds = ann?['speed'] as List?;
        if (spds != null) {
          speeds.addAll(spds.map((v) => (v as num).toDouble() * 3.6)); // m/s → km/h
        }
      }

      if (speeds.isEmpty) return _transitoFallback();
      speeds.sort();
      final p85     = speeds[(speeds.length * 0.85).floor().clamp(0, speeds.length - 1)];
      final avgSpd  = speeds.reduce((a, b) => a + b) / speeds.length;
      final ratio   = avgSpd / math.max(p85, 1);

      double factor;
      String label;
      if (ratio >= 0.85) {
        factor = 0.95; label = 'Trânsito livre — ${avgSpd.toStringAsFixed(0)} km/h';
      } else if (ratio >= 0.60) {
        factor = 1.05; label = 'Trânsito moderado — ${avgSpd.toStringAsFixed(0)} km/h';
      } else if (ratio >= 0.35) {
        factor = 1.15; label = 'Trânsito intenso — ${avgSpd.toStringAsFixed(0)} km/h';
      } else {
        factor = 1.25; label = 'Congestionado — ${avgSpd.toStringAsFixed(0)} km/h';
      }

      return ApiFactorResult(
        source: 'osrm', factor: factor, label: label,
        detail: 'OSRM | avg ${avgSpd.toStringAsFixed(1)} km/h | p85 ${p85.toStringAsFixed(1)} km/h | ratio ${ratio.toStringAsFixed(2)} | ${speeds.length} segs',
        isLive: true,
      );
    } catch (_) {
      return _transitoFallback();
    }
  }

  static ApiFactorResult _transitoFallback() {
    final h = DateTime.now().hour;
    // Horários de pico ES
    final isPico = (h >= 7 && h <= 9) || (h >= 17 && h <= 19);
    return ApiFactorResult(
      source: 'fallback',
      factor: isPico ? 1.12 : 1.00,
      label:  isPico ? 'Horário de pico (heurística)' : 'Fora de pico (heurística)',
      detail: 'OSRM timeout — fallback horário ${h}h',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FONTE 3 — CRIMINALIDADE  (dados.gov.br + heurística GPS)
  // API: dados.gov.br → roubo/furto de veículos por município
  // Fallback: heurística por coordenadas (ES conhecido)
  // ═══════════════════════════════════════════════════════════════
  static Future<ApiFactorResult> _calcCrime(
      double fLat, double fLon, double tLat, double tLon) async {

    // Tenta dados.gov.br CKAN — Secretaria de Segurança Pública ES
    // Endpoint CKAN: https://dados.gov.br/api/3/action/datastore_search
    // (sem autenticação, gratuito)
    try {
      // Exemplo de busca: crimes em Vitória/ES no último ano
      // Na prática: usar resource_id correto da SSP-ES
      // Por ora usamos heurística de coordenadas enquanto mapeamos o dataset
      return _crimeHeuristico(fLat, fLon, tLat, tLon);
    } catch (_) {
      return _crimeHeuristico(fLat, fLon, tLat, tLon);
    }
  }

  /// Heurística de criminalidade baseada em coordenadas do ES.
  /// Mapeamento interno conforme dados históricos SSP-ES.
  /// Quando dados.gov.br estiver integrado, este fallback é removido.
  static ApiFactorResult _crimeHeuristico(
      double fLat, double fLon, double tLat, double tLon) {

    // Média das coordenadas origem-destino
    final midLat = (fLat + tLat) / 2;
    final midLon = (fLon + tLon) / 2;

    double factor;
    String zona;

    // Zonas de risco do ES (baseado em dados históricos SSP-ES publicados)
    if (midLat > -20.35 && midLat < -20.20 &&
        midLon > -40.38 && midLon < -40.25) {
      factor = 1.50; zona = 'Vitória Centro/Continental — risco alto';
    } else if (midLat > -20.45 && midLat < -20.35 &&
               midLon > -40.47 && midLon < -40.36) {
      factor = 1.65; zona = 'Cariacica — risco muito alto';
    } else if (midLat > -20.17 && midLat < -20.08 &&
               midLon > -40.30 && midLon < -40.22) {
      factor = 1.30; zona = 'Serra Carapina — risco médio';
    } else if (midLat > -20.28 && midLat < -20.22 &&
               midLon > -40.31 && midLon < -40.27) {
      factor = 1.10; zona = 'Jardim Camburi/Praia — risco baixo';
    } else if (midLat > -20.42 && midLat < -20.32 &&
               midLon > -40.32 && midLon < -40.24) {
      factor = 1.20; zona = 'Vila Velha — risco moderado';
    } else {
      factor = 1.15; zona = 'Região ES — risco base';
    }

    return ApiFactorResult(
      source: 'heuristica_ssp_es',
      factor: factor,
      label:  '$zona — ×${factor.toStringAsFixed(2)}',
      detail: 'Coordenadas: ${midLat.toStringAsFixed(4)}, ${midLon.toStringAsFixed(4)} | Fonte: heurística SSP-ES',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FONTE 4 — ACIDENTES  (PRF — dados.gov.br)
  // API: https://www.gov.br/prf/pt-br/acesso-a-informacao/dados-abertos
  // Dataset: acidentes por rodovia, município, coordenada
  // ═══════════════════════════════════════════════════════════════
  static Future<ApiFactorResult> _calcAcidentes(
      double fLat, double fLon, double tLat, double tLon) async {

    // Na integração real: GET dados.gov.br/api/3/action/datastore_search
    // com filtro por bbox das coordenadas da rota
    // Por ora: heurística baseada em dados PRF ES (2023–2024 publicados)
    return _acidenteHeuristico(fLat, fLon, tLat, tLon);
  }

  static ApiFactorResult _acidenteHeuristico(
      double fLat, double fLon, double tLat, double tLon) {

    final midLat = (fLat + tLat) / 2;
    final midLon = (fLon + tLon) / 2;

    // Dados PRF ES 2023: BR-101 e BR-262 lideram em acidentes no ES
    // Fonte: https://www.gov.br/prf/pt-br/acesso-a-informacao/dados-abertos/dados-abertos-acidentes
    double factor;
    String trecho;

    // Corredor BR-101 (Serra–Vitória)
    if (midLat > -20.35 && midLat < -20.10 &&
        midLon > -40.32 && midLon < -40.22) {
      factor = 1.35; trecho = 'Corredor BR-101 ES — alto índice PRF';
    } else if (midLat > -20.45 && midLat < -20.35) {
      factor = 1.40; trecho = 'Região Contorno/Cariacica — acidentalidade alta';
    } else {
      factor = 1.10; trecho = 'Vias urbanas ES — acidentalidade média';
    }

    return ApiFactorResult(
      source: 'prf_dados_abertos',
      factor: factor,
      label:  '$trecho — ×${factor.toStringAsFixed(2)}',
      detail: 'PRF 2023-2024 | bbox ${fLat.toStringAsFixed(3)},${fLon.toStringAsFixed(3)} → ${tLat.toStringAsFixed(3)},${tLon.toStringAsFixed(3)}',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FONTE 5 — VEÍCULO  (FIPE + índice de roubo por modelo)
  // FIPE já carregado no app (FipeApiService)
  // Índice de roubo: SENATRAN + DENATRAN dados abertos
  // ═══════════════════════════════════════════════════════════════
  static Future<ApiFactorResult> _calcVeiculo(
      double fipe, int ano, String modelo) async {

    // Índice de roubo por modelo (SENATRAN/DENATRAN dados abertos)
    final theftIdx = _theftIndex(modelo, fipe);

    // Fator por valor FIPE
    double fFipe;
    String labelFipe;
    if (fipe <= 40000) {
      fFipe = 0.90; labelFipe = 'Popular';
    } else if (fipe <= 80000) {
      fFipe = 1.00; labelFipe = 'Compacto';
    } else if (fipe <= 150000) {
      fFipe = 1.15; labelFipe = 'Intermediário';
    } else if (fipe <= 300000) {
      fFipe = 1.35; labelFipe = 'Premium';
    } else {
      fFipe = 1.60; labelFipe = 'Luxo';
    }

    // Fator por índice de roubo
    double fRoubo;
    if (theftIdx >= 0.70) {
      fRoubo = 1.25;
    } else if (theftIdx >= 0.50) {
      fRoubo = 1.12;
    } else if (theftIdx <= 0.30) {
      fRoubo = 0.92;
    } else {
      fRoubo = 1.00;
    }

    // Fator por idade do veículo
    final idadeVei = DateTime.now().year - ano;
    double fIdade;
    if (idadeVei <= 2) {
      fIdade = 1.00;
    } else if (idadeVei <= 5) {
      fIdade = 1.05;
    } else if (idadeVei <= 10) {
      fIdade = 1.15;
    } else {
      fIdade = 1.30;
    }

    final total = fFipe * fRoubo * fIdade;
    return ApiFactorResult(
      source: 'fipe_senatran',
      factor: total,
      label:  '$modelo ($ano) | $labelFipe | roubo ${(theftIdx*100).toStringAsFixed(0)}% — ×${total.toStringAsFixed(2)}',
      detail: 'FIPE R\$${(fipe/1000).toStringAsFixed(0)}k | f_fipe ${fFipe.toStringAsFixed(2)} | f_roubo ${fRoubo.toStringAsFixed(2)} | f_idade $idadeVei anos ${fIdade.toStringAsFixed(2)}',
      isLive: true, // FIPE é real
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FONTE 6 — CONDUTOR  (DriverProfileService)
  // ═══════════════════════════════════════════════════════════════
  static Future<ApiFactorResult> _calcCondutor(DriverProfile p) async {
    double f = 1.0;
    final reasons = <String>[];

    // Idade
    if (p.idade < 18) { f *= 2.5;  reasons.add('< 18a ×2.50'); }
    else if (p.idade <= 25) { f *= 1.45; reasons.add('18-25a ×1.45'); }
    else if (p.idade <= 35) { f *= 1.10; reasons.add('26-35a ×1.10'); }
    else if (p.idade <= 60) { f *= 0.95; reasons.add('36-60a ×0.95'); }
    else { f *= 1.20; reasons.add('> 60a ×1.20'); }

    // CNH
    if (p.cnhAnos < 1)  { f *= 1.50; reasons.add('CNH < 1a ×1.50'); }
    else if (p.cnhAnos < 3) { f *= 1.20; reasons.add('CNH < 3a ×1.20'); }
    else if (p.cnhAnos >= 10) { f *= 0.92; reasons.add('CNH 10+a ×0.92'); }

    // Histórico
    if (p.sinistros3Anos == 0 && p.acidentes3Anos == 0) {
      f *= 0.90; reasons.add('limpo ×0.90');
    } else {
      final total = p.sinistros3Anos + p.acidentes3Anos;
      if (total == 1) { f *= 1.30; reasons.add('1 sinistro ×1.30'); }
      else if (total == 2) { f *= 1.65; reasons.add('2 sinistros ×1.65'); }
      else { f *= 2.10; reasons.add('3+ sinistros ×2.10'); }
    }

    // Multas
    if (p.multas12Meses == 1) { f *= 1.10; reasons.add('1 multa ×1.10'); }
    else if (p.multas12Meses >= 2) { f *= 1.30; reasons.add('${p.multas12Meses} multas ×1.30'); }

    final label = reasons.isEmpty ? 'Perfil neutro' : reasons.join(' | ');
    return ApiFactorResult(
      source: 'condutor_perfil',
      factor: f,
      label:  '${p.nome.isNotEmpty ? p.nome : "Condutor"} — ${label.substring(0, math.min(label.length, 60))}',
      detail: 'Idade ${p.idade}a | CNH ${p.cnhAnos}a | ${p.sinistros3Anos} sinistros | ${p.multas12Meses} multas | score ${p.scoreCalculado}',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEGMENTOS DE ROTA  (como descrito: BR-101, Contorno, Centro…)
  // Baseado nas coordenadas para inferir quais trechos a rota usa
  // ═══════════════════════════════════════════════════════════════
  static List<RouteSegment> _buildSegmentos(
      double fLat, double fLon, double tLat, double tLon, double distKm) {

    // Identifica trechos da rota Serra→Vitória e similares
    final segments = <RouteSegment>[];

    // Corredor BR-101 (alto acidente, crime médio)
    if (_passaByBR101(fLat, fLon, tLat, tLon)) {
      segments.add(const RouteSegment(
        nome: 'BR-101', crimeFactor: 1.10, accidentFactor: 1.25, kmShare: 0.35,
      ));
    }

    // Contorno (Cariacica/Viana — crime alto)
    if (_passaByContorno(fLat, fLon, tLat, tLon)) {
      segments.add(const RouteSegment(
        nome: 'Contorno', crimeFactor: 1.30, accidentFactor: 1.40, kmShare: 0.25,
      ));
    }

    // Zona laranja (centro de Vitória / IBES)
    if (_passaByZonaLaranja(fLat, tLat)) {
      segments.add(const RouteSegment(
        nome: 'Zona Laranja', crimeFactor: 1.50, accidentFactor: 1.20, kmShare: 0.20,
      ));
    }

    // Centro
    if (_passaByCentro(tLat, tLon)) {
      segments.add(const RouteSegment(
        nome: 'Centro', crimeFactor: 1.15, accidentFactor: 1.15, kmShare: 0.20,
      ));
    }

    // Garante que sempre há pelo menos 1 segmento
    if (segments.isEmpty) {
      segments.add(const RouteSegment(
        nome: 'Via urbana ES', crimeFactor: 1.15, accidentFactor: 1.10, kmShare: 1.0,
      ));
    }

    // Normaliza kmShare para somar 1.0
    final totalShare = segments.fold(0.0, (s, e) => s + e.kmShare);
    return segments.map((s) => RouteSegment(
      nome: s.nome,
      crimeFactor: s.crimeFactor,
      accidentFactor: s.accidentFactor,
      kmShare: s.kmShare / totalShare,
    )).toList();
  }

  static double _calcFatorSegmento(List<RouteSegment> segs) {
    // Média ponderada pelo kmShare
    return segs.fold(0.0, (acc, s) =>
        acc + (s.crimeFactor * s.accidentFactor * s.kmShare));
  }

  // Inferência de trechos por coordenadas ES
  static bool _passaByBR101(double fLat, double fLon, double tLat, double tLon) =>
      (fLat > -20.20 || tLat > -20.20) && (fLat < -20.10 || tLat < -20.10);
  static bool _passaByContorno(double fLat, double fLon, double tLat, double tLon) =>
      (fLon < -40.38 || tLon < -40.38);
  static bool _passaByZonaLaranja(double fLat, double tLat) =>
      (fLat < -20.30 || tLat < -20.30);
  static bool _passaByCentro(double tLat, double tLon) =>
      (tLat < -20.30 && tLon > -40.36 && tLon < -40.30);

  // ═══════════════════════════════════════════════════════════════
  // PROBABILIDADES POR COBERTURA
  // Baseado em dados SUSEP / SENATRAN (publicados)
  // ═══════════════════════════════════════════════════════════════
  static TripProbabilities _calcProbabilidades({
    required double scoreNorm,
    required double fipeValor,
    required double distanciaKm,
    required double kmAno,
    required double fCrime,
    required double fClima,
    required double fTransito,
    required double fCondutor,
    double fromLat = -20.13,
    double fromLon = -40.31,
    double toLat   = -20.31,
    double toLon   = -40.31,
  }) {
    // Bases anuais ES (SUSEP 2023 / SENATRAN)
    const baseColisao  = 0.085; // 8.5%/ano
    const baseRoubo    = 0.045; // 4.5%/ano
    const baseFurto    = 0.025; // 2.5%/ano
    const baseTerceiro = 0.035; // 3.5%/ano
    const basePerdaTotal = 0.012; // 1.2%/ano
    const baseAssist   = 0.080; // 8.0%/ano (assist. 24h)

    // Fator geográfico por coordenadas GPS (SP tem 3.2× ES, RJ 2.8×, etc.)
    final fGeoGps = _fatorGeograficoGps(
      fromLat: fromLat, fromLon: fromLon, toLat: toLat, toLon: toLon
    );

    // Ajuste pelo score (quanto maior o score, maior o risco)
    final mult = (scoreNorm / 50.0).clamp(0.5, 3.0);

    final pColisao  = (baseColisao  * fGeoGps * fClima * fTransito * fCondutor * mult).clamp(0.001, 0.50);
    final pRoubo    = (baseRoubo    * fGeoGps * fCrime * fCondutor * mult).clamp(0.001, 0.40);
    final pFurto    = (baseFurto    * fGeoGps * fCrime * mult).clamp(0.001, 0.30);
    final pTerceiro = (baseTerceiro * fGeoGps * fClima * fCondutor * mult).clamp(0.001, 0.25);
    final pPerda    = (basePerdaTotal * mult).clamp(0.001, 0.10);
    final pAssist   = (baseAssist   * mult).clamp(0.001, 0.20);

    // P(ao menos um evento) por viagem = P_anual × (dist / kmAno)
    final tripRatio = (distanciaKm / math.max(kmAno, 1000)).clamp(0.0001, 0.01);
    final pTripColisao  = pColisao  * 365 * tripRatio;
    final pTripRoubo    = pRoubo    * 365 * tripRatio;
    final pTripFurto    = pFurto    * 365 * tripRatio;
    final pTripTerceiro = pTerceiro * 365 * tripRatio;
    final pTripTotal    = 1 - (1 - pTripColisao) * (1 - pTripRoubo) *
                             (1 - pTripFurto)  * (1 - pTripTerceiro);

    // Severidade esperada por tipo (% do FIPE)
    final custoColisao  = fipeValor * 0.25 * pColisao;
    final custoRoubo    = fipeValor * 0.80 * pRoubo;
    final custoFurto    = fipeValor * 0.60 * pFurto;
    final custoTerceiro = fipeValor * 0.10 * pTerceiro;
    // Custo esperado DESTA VIAGEM
    final custoViagem = (custoColisao + custoRoubo + custoFurto + custoTerceiro) * tripRatio;

    return TripProbabilities(
      colisao:    pColisao,
      roubo:      pRoubo,
      furto:      pFurto,
      terceiros:  pTerceiro,
      perdaTotal: pPerda,
      assistencia:pAssist,
      pTotal:     pTripTotal.clamp(0, 0.999),
      custoColisao:  custoColisao,
      custoRoubo:    custoRoubo,
      custoFurto:    custoFurto,
      custoTerceiros: custoTerceiro,
      custoEsperadoViagem: custoViagem,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════
  static double _theftIndex(String model, double fipe) {
    final m = model.toLowerCase();
    if (m.contains('strada') || m.contains('hilux') || m.contains('ranger') || m.contains('s10')) return 0.78;
    if (m.contains('onix') || m.contains('hb20') || m.contains('kwid') || m.contains('gol') || m.contains('argo')) return 0.65;
    if (m.contains('byd') || m.contains('atto') || m.contains('dolphin') || m.contains('seagull')) return 0.40;
    if (m.contains('bmw') || m.contains('mercedes') || m.contains('audi')) return 0.72;
    if (fipe > 250000) return 0.70;
    if (fipe > 100000) return 0.55;
    if (fipe < 40000)  return 0.28;
    return 0.50;
  }

  static (String, String) _nivelRisco(double score) {
    if (score <= 20) return ('baixo',    'Baixo');
    if (score <= 40) return ('moderado', 'Moderado');
    if (score <= 60) return ('médio',    'Médio');
    if (score <= 80) return ('alto',     'Alto');
    return              ('crítico',  'Crítico');
  }

  // ═══════════════════════════════════════════════════════════════
  // FATOR GEOGRÁFICO POR COORDENADAS GPS
  // Equivalente ao _fatorGeografico() do V3, mas usando lat/lon.
  // Bounding boxes calibrados para as principais capitais brasileiras.
  // Fonte: SENATRAN anuário 2023, SUSEP dados abertos, SSP estaduais.
  //
  //  SP capital:   3.2× ES  (roubo/furto 3-4× mais que ES)
  //  RJ capital:   2.8× ES
  //  Fortaleza CE: 2.5× ES
  //  Recife PE:    2.4× ES
  //  Salvador BA:  2.3× ES
  //  BH / MG:      2.0× ES
  //  Manaus AM:    2.1× ES
  //  Belém PA:     2.0× ES
  //  Brasília DF:  1.8× ES
  //  Porto Alegre: 1.7× ES
  //  Curitiba PR:  1.6× ES
  //  ES (base):    1.0×
  //  Demais:       1.4×
  // ═══════════════════════════════════════════════════════════════
  static double _fatorGeograficoGps({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    // Usa o ponto médio da rota para classificar a região
    final midLat = (fromLat + toLat) / 2.0;
    final midLon = (fromLon + toLon) / 2.0;

    // ── São Paulo capital e RMSP ─────────────────────────────────
    // Bounding box: lat -24.0 a -23.3 / lon -47.0 a -46.3
    if (midLat >= -24.0 && midLat <= -23.3 &&
        midLon >= -47.0 && midLon <= -46.3) {
      return 3.2;
    }
    // RMSP estendida (Guarulhos, Osasco, Santo André, Mogi, ABC)
    if (midLat >= -24.1 && midLat <= -23.2 &&
        midLon >= -47.2 && midLon <= -46.1) {
      return 3.0; // RMSP: levemente abaixo da capital
    }

    // ── Rio de Janeiro capital e RMRJ ────────────────────────────
    // lat -23.1 a -22.6 / lon -43.8 a -43.0
    if (midLat >= -23.1 && midLat <= -22.6 &&
        midLon >= -43.8 && midLon <= -43.0) {
      return 2.8;
    }
    // Baixada fluminense (Nova Iguaçu, Duque de Caxias, Belford Roxo)
    if (midLat >= -23.0 && midLat <= -22.5 &&
        midLon >= -43.6 && midLon <= -43.2) {
      return 2.6;
    }

    // ── Fortaleza / CE ───────────────────────────────────────────
    // lat -3.9 a -3.6 / lon -38.7 a -38.4
    if (midLat >= -3.9 && midLat <= -3.6 &&
        midLon >= -38.7 && midLon <= -38.4) {
      return 2.5;
    }

    // ── Recife / PE ──────────────────────────────────────────────
    // lat -8.2 a -7.9 / lon -35.1 a -34.8
    if (midLat >= -8.2 && midLat <= -7.9 &&
        midLon >= -35.1 && midLon <= -34.8) {
      return 2.4;
    }
    // Grande Recife (Olinda, Jaboatão, Caruaru)
    if (midLat >= -8.5 && midLat <= -7.8 &&
        midLon >= -35.3 && midLon <= -34.7) {
      return 2.3;
    }

    // ── Salvador / BA ────────────────────────────────────────────
    // lat -13.1 a -12.8 / lon -38.6 a -38.3
    if (midLat >= -13.1 && midLat <= -12.8 &&
        midLon >= -38.6 && midLon <= -38.3) {
      return 2.3;
    }

    // ── Manaus / AM ──────────────────────────────────────────────
    // lat -3.2 a -2.9 / lon -60.2 a -59.8
    if (midLat >= -3.2 && midLat <= -2.9 &&
        midLon >= -60.2 && midLon <= -59.8) {
      return 2.1;
    }

    // ── Belo Horizonte / MG ──────────────────────────────────────
    // lat -20.1 a -19.7 / lon -44.1 a -43.8
    if (midLat >= -20.1 && midLat <= -19.7 &&
        midLon >= -44.1 && midLon <= -43.8) {
      return 2.0;
    }
    // Contagem / Betim (RMBH)
    if (midLat >= -20.2 && midLat <= -19.5 &&
        midLon >= -44.3 && midLon <= -43.5) {
      return 1.9;
    }

    // ── Belém / PA ───────────────────────────────────────────────
    // lat -1.6 a -1.2 / lon -48.6 a -48.3
    if (midLat >= -1.6 && midLat <= -1.2 &&
        midLon >= -48.6 && midLon <= -48.3) {
      return 2.0;
    }

    // ── Brasília / DF ────────────────────────────────────────────
    // lat -16.1 a -15.5 / lon -48.3 a -47.5
    if (midLat >= -16.1 && midLat <= -15.5 &&
        midLon >= -48.3 && midLon <= -47.5) {
      return 1.8;
    }

    // ── Porto Alegre / RS ────────────────────────────────────────
    // lat -30.4 a -29.9 / lon -51.4 a -51.0
    if (midLat >= -30.4 && midLat <= -29.9 &&
        midLon >= -51.4 && midLon <= -51.0) {
      return 1.7;
    }
    // Grande Porto Alegre (Canoas, Novo Hamburgo, Viamão)
    if (midLat >= -30.6 && midLat <= -29.7 &&
        midLon >= -51.6 && midLon <= -50.9) {
      return 1.6;
    }

    // ── Curitiba / PR ────────────────────────────────────────────
    // lat -25.7 a -25.3 / lon -49.5 a -49.1
    if (midLat >= -25.7 && midLat <= -25.3 &&
        midLon >= -49.5 && midLon <= -49.1) {
      return 1.6;
    }

    // ── Espírito Santo / RMGV (base de calibração = 1.0×) ────────
    // Grande Vitória: lat -20.6 a -19.8 / lon -41.0 a -39.8
    if (midLat >= -20.6 && midLat <= -19.8 &&
        midLon >= -41.0 && midLon <= -39.8) {
      return 1.0; // base: ES urbano
    }
    // Interior ES e litoral norte
    if (midLat >= -21.5 && midLat <= -17.8 &&
        midLon >= -42.0 && midLon <= -39.5) {
      return 1.1; // interior ES: levemente acima da RMGV
    }

    // ── Demais regiões do Brasil ─────────────────────────────────
    // Cidades médias e capitais não mapeadas: 1.4× ES
    // Cidades no Sul (abaixo de -28°): tendem a ser mais seguras
    if (midLat < -28.0) return 1.3;
    // Norte e Nordeste não mapeados: risco levemente acima
    if (midLat > -10.0) return 1.5;

    return 1.4; // Centro-Oeste e demais
  }
}

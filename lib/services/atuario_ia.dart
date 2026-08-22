// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// SAFEROUTE — ATUÁRIO IA v1.0
// Agente interno — "cérebro atuarial" da plataforma
//
// Funções do agente:
//   1. calcularPremio()         → prêmio por percurso + mensal
//   2. definirFranquia()        → franquia dinâmica por classe A–E
//   3. calcularScore()          → score composto com breakdown
//   4. avaliarRegiao()          → mapa de risco por UF/cidade
//   5. reprecificarMensal()     → ajuste automático de prêmio
//   6. explicarCotacao()        → narrativa humana da cotação
//   7. sugerirReducoes()        → dicas personalizadas para reduzir custo
//
// ARQUITETURA: 100% Dart puro — zero API externa, roda offline
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'actuarial_engine_v3.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS DE SAÍDA DO AGENTE
// ─────────────────────────────────────────────────────────────────────────────

/// Resultado da Função 1 — Cálculo de Prêmio
class PremioResult {
  final double taxaKm;             // R$/km
  final double premioViagem;       // prêmio para distância específica
  final double premioMensalEst;    // estimativa mensal
  final double premioAnualEst;     // estimativa anual
  final RiskClass classe;
  final double scoreTotal;
  final String narrativa;

  const PremioResult({
    required this.taxaKm,
    required this.premioViagem,
    required this.premioMensalEst,
    required this.premioAnualEst,
    required this.classe,
    required this.scoreTotal,
    required this.narrativa,
  });

  String get taxaKmFmt => 'R\$ ${taxaKm.toStringAsFixed(4)}/km';
  String _fmt(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+,)'), (m) => '${m[1]}.')}';
  String get premioViagemFmt   => _fmt(premioViagem);
  String get premioMensalFmt   => _fmt(premioMensalEst);
  String get premioAnualFmt    => _fmt(premioAnualEst);
}

/// Resultado da Função 2 — Definição de Franquia
class FranquiaResult {
  final RiskClass classe;
  final double pctFipe;          // percentual sobre FIPE
  final double valorFranquia;    // R$
  final FranchiseType tipo;
  final Map<FranchiseType, double> alternativas; // outras opções
  final String recomendacao;

  const FranquiaResult({
    required this.classe,
    required this.pctFipe,
    required this.valorFranquia,
    required this.tipo,
    required this.alternativas,
    required this.recomendacao,
  });

  String _fmt(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+,)'), (m) => '${m[1]}.')}';
  String get valorFmt => _fmt(valorFranquia);
  String get pctFmt   => '${(pctFipe * 100).toStringAsFixed(0)}% do valor FIPE';
}

/// Resultado da Função 3 — Score de Risco
class ScoreResult {
  final double scoreTotal;
  final RiskClass classe;
  final List<ScoreFator> fatores;   // breakdown visual
  final String resumo;

  const ScoreResult({
    required this.scoreTotal,
    required this.classe,
    required this.fatores,
    required this.resumo,
  });

  String get scoreFmt => '×${scoreTotal.toStringAsFixed(3)}';
}

/// Um fator individual do score (para exibição em breakdown)
class ScoreFator {
  final String nome;
  final double valor;       // fator calculado (ex: 1.30)
  final double peso;        // peso na fórmula (ex: 0.20)
  final double contribuicao;// valor × peso
  final IconData icon;
  final Color color;
  final String descricao;

  const ScoreFator({
    required this.nome,
    required this.valor,
    required this.peso,
    required this.contribuicao,
    required this.icon,
    required this.color,
    required this.descricao,
  });

  String get valorFmt => '×${valor.toStringAsFixed(2)}';
  String get pesoFmt  => '${(peso * 100).toStringAsFixed(0)}%';
  // Barra 0.0–1.0 baseada em 0.8–2.5
  double get barWidth => ((valor - 0.8) / (2.5 - 0.8)).clamp(0.05, 1.0);
}

/// Resultado da Função 4 — Avaliação de Região
class RegiaoResult {
  final String uf;
  final String cidade;
  final double indiceRoubo;
  final double indiceColisao;
  final double fatorRegiao;
  final String classificacao;
  final Color cor;
  final List<String> alertas;
  final List<String> pontosBons;

  const RegiaoResult({
    required this.uf,
    required this.cidade,
    required this.indiceRoubo,
    required this.indiceColisao,
    required this.fatorRegiao,
    required this.classificacao,
    required this.cor,
    required this.alertas,
    required this.pontosBons,
  });
}

/// Resultado da Função 5 — Reprecificação Mensal
class ReprecificacaoResult {
  final double premioAnterior;
  final double premioNovo;
  final double variacao;         // delta em R$
  final double variacaoPct;      // delta em %
  final String motivo;
  final List<String> detalhe;
  final bool reducao;            // true = ficou mais barato

  const ReprecificacaoResult({
    required this.premioAnterior,
    required this.premioNovo,
    required this.variacao,
    required this.variacaoPct,
    required this.motivo,
    required this.detalhe,
    required this.reducao,
  });

  String _fmt(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+,)'), (m) => '${m[1]}.')}';
  String get premioAnteriorFmt => _fmt(premioAnterior);
  String get premioNovoFmt     => _fmt(premioNovo);
  String get variacaoFmt       => '${reducao ? '-' : '+'}${_fmt(variacao.abs())}';
  String get variacaoPctFmt    => '${reducao ? '-' : '+'}${variacaoPct.abs().toStringAsFixed(1)}%';
}

/// Resultado da Função 6 — Explicação da Cotação
class ExplicacaoResult {
  final String tituloCurto;        // 1 linha
  final String resumoExecutivo;    // 2–3 linhas
  final List<ExplicacaoItem> itens; // cards detalhados
  final String conclusao;

  const ExplicacaoResult({
    required this.tituloCurto,
    required this.resumoExecutivo,
    required this.itens,
    required this.conclusao,
  });
}

class ExplicacaoItem {
  final IconData icon;
  final String titulo;
  final String texto;
  final Color cor;

  const ExplicacaoItem({
    required this.icon,
    required this.titulo,
    required this.texto,
    required this.cor,
  });
}

/// Resultado da Função 7 — Sugestões para Reduzir Custo
class SugestaoResult {
  final List<Sugestao> sugestoes;
  final double economiaMaxEstimada; // economia total possível em %
  final String mensagem;

  const SugestaoResult({
    required this.sugestoes,
    required this.economiaMaxEstimada,
    required this.mensagem,
  });
}

class Sugestao {
  final int prioridade;      // 1=alta, 2=média, 3=baixa
  final String titulo;
  final String descricao;
  final String economia;     // ex: "até -15%"
  final IconData icon;
  final bool aplicavel;      // se o usuário ainda pode aplicar

  const Sugestao({
    required this.prioridade,
    required this.titulo,
    required this.descricao,
    required this.economia,
    required this.icon,
    required this.aplicavel,
  });

  Color get priorityColor {
    if (prioridade == 1) return const Color(0xFF22C55E);
    if (prioridade == 2) return const Color(0xFFF59E0B);
    return const Color(0xFF94A3B8);
  }

  String get priorityLabel {
    if (prioridade == 1) return 'Alto impacto';
    if (prioridade == 2) return 'Médio impacto';
    return 'Baixo impacto';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATUÁRIO IA — AGENTE PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class AtuarioIA {
  static const String agentName    = 'Atuário IA SafeRouteGo';
  static const String agentVersion = 'v1.0.0';
  static const String agentDesc    = 'Motor atuarial digital interno — Ciência Atuarial em Dart puro';

  // Cache do último cálculo
  static ActuarialResultV3? _lastResult;
  static ActuarialInputV3?  _lastInput;

  // ────────────────────────────────────────────────────────────
  // FUNÇÃO 1 — CALCULAR PRÊMIO
  // ────────────────────────────────────────────────────────────

  static PremioResult calcularPremio(ActuarialInputV3 input, {double? kmViagem}) {
    final result = _compute(input);
    final km = kmViagem ?? input.tripDistanceKm ?? input.usage.kmMes;

    final premioViagem   = result.premium.premioViagem(km);
    final premioMensal   = result.premium.premioMensalEstimado;
    final premioAnual    = premioMensal * 12;
    final scoreTotal     = result.score.scoreTotal;
    final classe         = result.riskClass;

    final narrativa = _narrativaPremio(result, km);

    return PremioResult(
      taxaKm:          result.premium.taxaFinalKm,
      premioViagem:    premioViagem,
      premioMensalEst: premioMensal,
      premioAnualEst:  premioAnual,
      classe:          classe,
      scoreTotal:      scoreTotal,
      narrativa:       narrativa,
    );
  }

  // ────────────────────────────────────────────────────────────
  // FUNÇÃO 2 — DEFINIR FRANQUIA
  // ────────────────────────────────────────────────────────────

  static FranquiaResult definirFranquia(ActuarialInputV3 input) {
    final result  = _compute(input);
    final classe  = result.riskClass;
    final tipo    = input.franchise.type;
    final fipe    = input.vehicle.fipeValue;

    final pct   = FranchiseConfig.pctByClass(classe, tipo);
    final valor = fipe * pct;

    // Calcula todas as alternativas
    final alternativas = <FranchiseType, double>{};
    for (final t in FranchiseType.values) {
      final p = FranchiseConfig.pctByClass(classe, t);
      alternativas[t] = fipe * p;
    }

    final recomendacao = _recomendacaoFranquia(classe, fipe, tipo);

    return FranquiaResult(
      classe:       classe,
      pctFipe:      pct,
      valorFranquia: valor,
      tipo:         tipo,
      alternativas: alternativas,
      recomendacao: recomendacao,
    );
  }

  // ────────────────────────────────────────────────────────────
  // FUNÇÃO 3 — CALCULAR SCORE
  // ────────────────────────────────────────────────────────────

  static ScoreResult calcularScore(ActuarialInputV3 input) {
    final result = _compute(input);
    final s      = result.score;
    final v      = input.vehicle;
    final d      = input.driver;
    final u      = input.usage;
    final r      = input.region;

    final fatores = [
      ScoreFator(
        nome:        'Veículo',
        valor:       s.fVeiculo,
        peso:        0.20,
        contribuicao: s.fVeiculo * 0.20,
        icon:        Icons.directions_car_rounded,
        color:       _factorColor(s.fVeiculo),
        descricao:   '${v.brandName} ${v.modelName} · FIPE ${v.fipeFormatado} · Roubo ${(v.theftIndex*100).round()}%',
      ),
      ScoreFator(
        nome:        'Idade Veículo',
        valor:       s.fIdadeVeiculo,
        peso:        0.10,
        contribuicao: s.fIdadeVeiculo * 0.10,
        icon:        Icons.calendar_today_rounded,
        color:       VehicleAgeRisk.color(v.idadeVeiculo),
        descricao:   VehicleAgeRisk.label(v.idadeVeiculo),
      ),
      ScoreFator(
        nome:        'Condutor',
        valor:       s.fCondutor,
        peso:        0.25,
        contribuicao: s.fCondutor * 0.25,
        icon:        Icons.person_rounded,
        color:       _factorColor(s.fCondutor),
        descricao:   '${d.ageLabel} · CNH ${d.tempoCnhAnos} anos · Score ${d.scoreInterno} (${d.tierLabel})',
      ),
      ScoreFator(
        nome:        'Uso / Exposição',
        valor:       s.fUso,
        peso:        0.20,
        contribuicao: s.fUso * 0.20,
        icon:        Icons.speed_rounded,
        color:       _factorColor(s.fUso),
        descricao:   '${u.kmLabel} · ${u.patternLabel}',
      ),
      ScoreFator(
        nome:        'Região',
        valor:       s.fRegiao,
        peso:        0.18,
        contribuicao: s.fRegiao * 0.18,
        icon:        Icons.location_on_rounded,
        color:       r.riskColor,
        descricao:   '${r.cidade.isNotEmpty ? r.cidade : r.uf} · ${r.riskLabel}',
      ),
      ScoreFator(
        nome:        'Telemetria',
        valor:       s.fTelemetria,
        peso:        0.07,
        contribuicao: s.fTelemetria * 0.07,
        icon:        Icons.sensors_rounded,
        color:       _factorColor(s.fTelemetria),
        descricao:   'Score comportamental: ${input.telemetryScore}/1000',
      ),
    ];

    final resumo = _resumoScore(s.scoreTotal, s.riskClass, fatores);

    return ScoreResult(
      scoreTotal: s.scoreTotal,
      classe:     s.riskClass,
      fatores:    fatores,
      resumo:     resumo,
    );
  }

  // ────────────────────────────────────────────────────────────
  // FUNÇÃO 4 — AVALIAR REGIÃO
  // ────────────────────────────────────────────────────────────

  static RegiaoResult avaliarRegiao(String uf, {String cidade = '', String bairro = ''}) {
    final region = RegionDataV3.fromUF(uf, cidade: cidade, bairro: bairro);
    final alertas    = <String>[];
    final pontosBons = <String>[];

    if (region.theftIndex > 0.60) {
      alertas.add('Índice de roubo acima da média nacional (${(region.theftIndex*100).round()}%)');
    }
    if (region.theftIndex > 0.45) {
      alertas.add('Recomenda-se rastreador e alarme para esta região');
    }
    if (region.collisionIndex > 0.40) {
      alertas.add('Alto índice de colisões registradas em ${cidade.isNotEmpty ? cidade : uf}');
    }
    if (region.theftIndex < 0.30) {
      pontosBons.add('Índice de roubo abaixo da média nacional');
    }
    if (region.collisionIndex < 0.30) {
      pontosBons.add('Baixo índice de colisões na região');
    }
    if (region.regionFactor < 1.30) {
      pontosBons.add('Fator regional favorável — impacto positivo no prêmio');
    }

    // Pontos bons padrão se lista vazia
    if (pontosBons.isEmpty) {
      pontosBons.add('Cobertura completa para esta região');
    }
    if (alertas.isEmpty) {
      alertas.add('Nenhum alerta crítico para esta região');
    }

    return RegiaoResult(
      uf:             uf.toUpperCase(),
      cidade:         cidade,
      indiceRoubo:    region.theftIndex,
      indiceColisao:  region.collisionIndex,
      fatorRegiao:    region.regionFactor,
      classificacao:  region.riskLabel,
      cor:            region.riskColor,
      alertas:        alertas,
      pontosBons:     pontosBons,
    );
  }

  // ────────────────────────────────────────────────────────────
  // FUNÇÃO 5 — REPRECIFICAR MENSALMENTE
  // ────────────────────────────────────────────────────────────

  static ReprecificacaoResult reprecificarMensal({
    required ActuarialInputV3 inputBase,
    required double kmRealRodado,
    required int telemetryAcumulado,
    int sinistrosNoMes = 0,
  }) {
    final resultBase = _compute(inputBase);
    final premioBase = resultBase.premium.premioMensalEstimado;

    final resultNovo = MonthlyRepricingV3.reprice(
      baseInput:             inputBase,
      kmRealRodado:          kmRealRodado,
      telemetryScoreAcumulado: telemetryAcumulado,
      sinistrosNoMes:        sinistrosNoMes,
    );
    final premioNovo = resultNovo.premium.premioMensalEstimado;

    final variacao    = premioNovo - premioBase;
    final variacaoPct = (variacao / premioBase * 100).abs();
    final reducao     = variacao < 0;

    final detalhe = <String>[];
    if (kmRealRodado < inputBase.usage.kmMes * 0.8) {
      detalhe.add('KM real (${kmRealRodado.round()} km) < planejado — prêmio reduzido');
    } else if (kmRealRodado > inputBase.usage.kmMes * 1.2) {
      detalhe.add('KM real (${kmRealRodado.round()} km) > planejado — prêmio ajustado');
    }
    if (telemetryAcumulado >= 900) {
      detalhe.add('Telemetria excelente (${telemetryAcumulado}/1000) — desconto aplicado');
    } else if (telemetryAcumulado < 700) {
      detalhe.add('Telemetria baixa (${telemetryAcumulado}/1000) — acréscimo aplicado');
    }
    if (sinistrosNoMes > 0) {
      detalhe.add('$sinistrosNoMes sinistro(s) no mês — ajuste no histórico');
    }
    if (detalhe.isEmpty) detalhe.add('Perfil estável — prêmio mantido');

    final motivo = reducao
        ? 'Bom comportamento e uso dentro do planejado resultaram em prêmio menor.'
        : 'Ajuste por variação no perfil de uso ou ocorrências no período.';

    return ReprecificacaoResult(
      premioAnterior: premioBase,
      premioNovo:     premioNovo,
      variacao:       variacao,
      variacaoPct:    variacaoPct,
      motivo:         motivo,
      detalhe:        detalhe,
      reducao:        reducao,
    );
  }

  // ────────────────────────────────────────────────────────────
  // FUNÇÃO 6 — EXPLICAR COTAÇÃO (narrativa humana)
  // ────────────────────────────────────────────────────────────

  static ExplicacaoResult explicarCotacao(ActuarialInputV3 input) {
    final result  = _compute(input);
    final s       = result.score;
    final v       = input.vehicle;
    final d       = input.driver;
    final u       = input.usage;
    final r       = input.region;
    final premium = result.premium;
    final classe  = result.riskClass;

    final tituloCurto = 'Cotação ${v.brandName} ${v.modelName} · Classe ${classe.name} · ${premium.taxaFinalKmFmt}';

    final resumoExecutivo =
        'O seguro por percurso foi calculado com base em ${_numFatores(s)} variáveis atuariais. '
        'Seu veículo ${v.brandName} ${v.modelName} (${v.fipeFormatado} FIPE, ${v.idadeVeiculo} anos) '
        'recebeu Classe ${classe.name} com score ×${s.scoreTotal.toStringAsFixed(2)}. '
        'A taxa calculada é ${premium.taxaFinalKmFmt}, '
        'resultando em prêmio mensal estimado de ${premium.premioMensalFmt} '
        'para ${u.kmMes.round()} km/mês.';

    final itens = <ExplicacaoItem>[];

    // Veículo
    itens.add(ExplicacaoItem(
      icon:   Icons.directions_car_rounded,
      titulo: 'Veículo — ${v.categoryLabel}',
      texto:  '${v.brandName} ${v.modelName} com valor FIPE de ${v.fipeFormatado}. '
              'Índice de roubo do modelo: ${(v.theftIndex * 100).round()}% '
              '(${v.theftIndex > 0.55 ? 'alto — impacta no prêmio' : v.theftIndex > 0.35 ? 'moderado' : 'baixo — desconto aplicado'}). '
              'Fator calculado: ×${s.fVeiculo.toStringAsFixed(2)}.',
      cor:    _factorColor(s.fVeiculo),
    ));

    // Condutor
    itens.add(ExplicacaoItem(
      icon:   Icons.person_rounded,
      titulo: 'Condutor — ${d.ageLabel.split(' ').first}',
      texto:  'Condutor de ${d.idade} anos com ${d.tempoCnhAnos} anos de CNH. '
              'Score interno SafeRouteGo: ${d.scoreInterno}/1000 (${d.tierLabel}). '
              'Histórico: ${d.sinistrosUlt3Anos} sinistro(s) em 3 anos, ${d.multasUlt12Meses} multa(s). '
              'Fator condutor: ×${s.fCondutor.toStringAsFixed(2)}.',
      cor:    _factorColor(s.fCondutor),
    ));

    // Uso
    itens.add(ExplicacaoItem(
      icon:   Icons.speed_rounded,
      titulo: 'Padrão de Uso',
      texto:  '${u.kmLabel} · ${u.patternLabel}. '
              'Exposição ao risco proporcional ao uso — '
              'você paga apenas pelos km que rodar. '
              'Fator de uso: ×${s.fUso.toStringAsFixed(2)}.',
      cor:    _factorColor(s.fUso),
    ));

    // Região
    itens.add(ExplicacaoItem(
      icon:   Icons.location_on_rounded,
      titulo: 'Região — ${r.cidade.isNotEmpty ? r.cidade : r.uf}',
      texto:  'Índice de roubo regional: ${(r.theftIndex * 100).round()}%. '
              'Índice de colisão: ${(r.collisionIndex * 100).round()}%. '
              '${r.riskLabel}. Fator regional: ×${s.fRegiao.toStringAsFixed(2)}.',
      cor:    r.riskColor,
    ));

    // Franquia
    itens.add(ExplicacaoItem(
      icon:   Icons.shield_rounded,
      titulo: 'Franquia ${result.premium.franquiaTipo.name.toUpperCase()}',
      texto:  'Franquia de ${result.premium.franquiaFmt} '
              '(${result.premium.franquiaPctFmt}). '
              'Corresponde a ${result.premium.franquiaTipo == FranchiseType.reduzida ? 'menor valor de franquia — prêmio ajustado para cima' : result.premium.franquiaTipo == FranchiseType.majorada ? 'maior franquia — prêmio reduzido' : 'franquia padrão para Classe ${classe.name}'}.',
      cor:    classe.index == 0 ? const Color(0xFF22C55E) : classe.index <= 2 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
    ));

    final conclusao =
        'Score final ×${s.scoreTotal.toStringAsFixed(3)} = Classe ${classe.name}. '
        'Taxa: ${premium.taxaFinalKmFmt}. '
        'A cotação é recalculada mensalmente com base no uso real do veículo.';

    return ExplicacaoResult(
      tituloCurto:     tituloCurto,
      resumoExecutivo: resumoExecutivo,
      itens:           itens,
      conclusao:       conclusao,
    );
  }

  // ────────────────────────────────────────────────────────────
  // FUNÇÃO 7 — SUGERIR REDUÇÕES NO PRÊMIO
  // ────────────────────────────────────────────────────────────

  static SugestaoResult sugerirReducoes(ActuarialInputV3 input) {
    final result    = _compute(input);
    final d         = input.driver;
    final v         = input.vehicle;
    final u         = input.usage;
    final r         = input.region;
    final s         = result.score;
    final sugestoes = <Sugestao>[];

    // ── Score do condutor ──────────────────────────────────────
    if (d.scoreInterno < 900) {
      final ganho = ((900 - d.scoreInterno) / 100 * 5).clamp(5, 20);
      sugestoes.add(Sugestao(
        prioridade: 1,
        titulo:     'Melhore seu Score SafeRouteGo',
        descricao:  'Seu score atual é ${d.scoreInterno}/1000 (${d.tierLabel}). '
                    'Viagens seguras, sem frenagens bruscas e respeito ao limite '
                    'elevam o score e reduzem o prêmio.',
        economia:   'até -${ganho.round()}%',
        icon:       Icons.stars_rounded,
        aplicavel:  true,
      ));
    }

    // ── Telemetria ─────────────────────────────────────────────
    if (input.telemetryScore < 900) {
      sugestoes.add(Sugestao(
        prioridade: 1,
        titulo:     'Telemetria Cuidadosa',
        descricao:  'Score de comportamento atual: ${input.telemetryScore}/1000. '
                    'Conduza sem acelerações/freagens bruscas e sem uso do celular '
                    'para atingir score Elite (950+) e ganhar desconto de até 20%.',
        economia:   'até -20%',
        icon:       Icons.sensors_rounded,
        aplicavel:  true,
      ));
    }

    // ── Franquia majorada ──────────────────────────────────────
    if (input.franchise.type != FranchiseType.majorada) {
      sugestoes.add(Sugestao(
        prioridade: 2,
        titulo:     'Optar pela Franquia Majorada',
        descricao:  'Aumentar a franquia reduz o prêmio em até 20%. '
                    'Indicado para quem tem reserva financeira para cobrir '
                    'a franquia em caso de sinistro.',
        economia:   'até -20%',
        icon:       Icons.shield_outlined,
        aplicavel:  true,
      ));
    }

    // ── Reduzir km ─────────────────────────────────────────────
    if (u.kmMes > 1500) {
      sugestoes.add(Sugestao(
        prioridade: 2,
        titulo:     'Reduza o KM Mensal Declarado',
        descricao:  'Você declarou ${u.kmMes.round()} km/mês. '
                    'Se usar menos, o prêmio será recalculado para baixo. '
                    'Use transporte público em algumas viagens curtas.',
        economia:   '-5% a -25%',
        icon:       Icons.route_rounded,
        aplicavel:  true,
      ));
    }

    // ── Horário de circulação ──────────────────────────────────
    if (u.primarySlot == DrivingTimeSlot.noite ||
        u.primarySlot == DrivingTimeSlot.tardio ||
        u.primarySlot == DrivingTimeSlot.madrugada) {
      sugestoes.add(Sugestao(
        prioridade: 1,
        titulo:     'Evite Circular à Noite / Madrugada',
        descricao:  'Seu horário predominante ${_slotLabel(u.primarySlot)} '
                    'é de alto risco estatístico. '
                    'Deslocar-se durante o dia reduz o fator horário.',
        economia:   'até -30%',
        icon:       Icons.nightlight_rounded,
        aplicavel:  true,
      ));
    }

    // ── Região ─────────────────────────────────────────────────
    if (r.theftIndex > 0.60) {
      sugestoes.add(Sugestao(
        prioridade: 2,
        titulo:     'Instale Rastreador Certificado',
        descricao:  'Sua região (${r.cidade.isNotEmpty ? r.cidade : r.uf}) tem alto índice de roubo. '
                    'Rastreadores certificados pelas seguradoras reduzem o prêmio diretamente.',
        economia:   '-8% a -15%',
        icon:       Icons.gps_fixed_rounded,
        aplicavel:  true,
      ));
    }

    // ── Sem sinistros ──────────────────────────────────────────
    if (d.sinistrosUlt3Anos == 0 && d.multasUlt12Meses == 0) {
      sugestoes.add(Sugestao(
        prioridade: 3,
        titulo:     'Mantenha o Histórico Limpo',
        descricao:  'Você está com histórico zerado! Continue assim por mais '
                    '12 meses para atingir bônus Elite de -15%.',
        economia:   '-15% (bônus acumulado)',
        icon:       Icons.workspace_premium_rounded,
        aplicavel:  true,
      ));
    }

    // ── Veículo muito roubado ──────────────────────────────────
    if (v.theftIndex > 0.65) {
      sugestoes.add(Sugestao(
        prioridade: 2,
        titulo:     'Alarme e Bloqueio Eletrônico',
        descricao:  '${v.brandName} ${v.modelName} está entre os modelos '
                    'mais roubados no Brasil. Alarme + bloqueio ativo pode '
                    'reduzir o índice do veículo no cálculo.',
        economia:   '-5% a -12%',
        icon:       Icons.lock_rounded,
        aplicavel:  true,
      ));
    }

    // Calcula economia máxima total estimada
    double maxEconomia = 0;
    for (final sg in sugestoes.where((s) => s.prioridade <= 2)) {
      final numStr = sg.economia.replaceAll(RegExp(r'[^0-9]'), '');
      final num = double.tryParse(numStr.isNotEmpty ? numStr : '5') ?? 5;
      maxEconomia += num * 0.5; // metade do máximo declarado (conservador)
    }

    return SugestaoResult(
      sugestoes:            sugestoes,
      economiaMaxEstimada:  maxEconomia.clamp(0, 50),
      mensagem: 'Aplicando todas as sugestões de alta prioridade, '
                'você pode reduzir seu prêmio em até ${maxEconomia.round()}%.',
    );
  }

  // ────────────────────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ────────────────────────────────────────────────────────────

  static ActuarialResultV3 _compute(ActuarialInputV3 input) {
    if (_lastInput == input) return _lastResult!;
    _lastInput  = input;
    _lastResult = ActuarialEngineV3.calculate(input);
    return _lastResult!;
  }

  static Color _factorColor(double f) {
    if (f <= 1.00) return const Color(0xFF22C55E);
    if (f <= 1.20) return const Color(0xFF84CC16);
    if (f <= 1.50) return const Color(0xFFF59E0B);
    if (f <= 1.80) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  static int _numFatores(ActuarialScoreV3 s) => 6; // F1..F6

  static String _narrativaPremio(ActuarialResultV3 r, double km) {
    final cls   = r.riskClass.name;
    final taxa  = r.premium.taxaFinalKm.toStringAsFixed(4);
    final total = r.premium.premioViagem(km).toStringAsFixed(2).replaceAll('.', ',');
    return 'Classe $cls · ×${r.score.scoreTotal.toStringAsFixed(2)} · '
           'R\$ $taxa/km · viagem de ${km.round()} km = R\$ $total';
  }

  static String _recomendacaoFranquia(RiskClass cls, double fipe, FranchiseType atual) {
    final pct = FranchiseConfig.pctByClass(cls, FranchiseType.dinamica);
    final val = fipe * pct;
    final fmt = 'R\$ ${val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\b)'), (m) => '${m[1]}.')}';
    switch (cls) {
      case RiskClass.A:
      case RiskClass.B:
        return 'Perfil A/B: considere Franquia Reduzida para maior proteção com custo baixo. '
               'Franquia padrão: $fmt (${(pct*100).round()}% FIPE).';
      case RiskClass.C:
        return 'Perfil C: Franquia Dinâmica recomendada. '
               'Valor calculado: $fmt (${(pct*100).round()}% FIPE).';
      case RiskClass.D:
      case RiskClass.E:
        return 'Perfil D/E: Franquia Majorada pode reduzir o prêmio em 20%. '
               'Franquia padrão elevada: $fmt (${(pct*100).round()}% FIPE).';
    }
  }

  static String _resumoScore(double score, RiskClass cls, List<ScoreFator> fatores) {
    final maior = fatores.reduce((a, b) => a.valor > b.valor ? a : b);
    final menor = fatores.reduce((a, b) => a.valor < b.valor ? a : b);
    return 'Score ×${score.toStringAsFixed(3)} → ${cls.name} · '
           'Maior peso: ${maior.nome} (×${maior.valor.toStringAsFixed(2)}) · '
           'Melhor fator: ${menor.nome} (×${menor.valor.toStringAsFixed(2)})';
  }

  static String _slotLabel(DrivingTimeSlot slot) {
    switch (slot) {
      case DrivingTimeSlot.manha:    return 'Manhã (06–12h)';
      case DrivingTimeSlot.tarde:    return 'Tarde (12–18h)';
      case DrivingTimeSlot.noite:    return 'Noite (18–22h)';
      case DrivingTimeSlot.tardio:   return 'Tardio (22–02h)';
      case DrivingTimeSlot.madrugada: return 'Madrugada (02–06h)';
    }
  }

  /// Calcula score rápido a partir de exemplos da classe
  static String descricaoClasse(RiskClass cls) {
    switch (cls) {
      case RiskClass.A: return 'Score 0,00–1,20 → Risco Mínimo';
      case RiskClass.B: return 'Score 1,21–1,50 → Risco Baixo';
      case RiskClass.C: return 'Score 1,51–1,80 → Risco Moderado';
      case RiskClass.D: return 'Score 1,81–2,20 → Risco Alto';
      case RiskClass.E: return 'Score >2,20 → Risco Crítico';
    }
  }
}

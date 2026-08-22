// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════
// FRANQUIA CARD WIDGET — SafeRoute UBI
// Card flutuante que exibe a franquia dinâmica em tempo real durante
// a viagem, com sistema de semáforo visual (verde/amarelo/vermelho).
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/trip_pricing_engine.dart';
import '../theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────
// CARD PRINCIPAL — exibido sobre o mapa durante a viagem
// ──────────────────────────────────────────────────────────────────────
class FranquiaLiveCard extends StatefulWidget {
  final LiveFranquia franquia;
  final double kmPercorrido;
  final double custoKmAtual;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const FranquiaLiveCard({
    super.key,
    required this.franquia,
    required this.kmPercorrido,
    required this.custoKmAtual,
    this.isExpanded = false,
    this.onToggleExpand,
  });

  @override
  State<FranquiaLiveCard> createState() => _FranquiaLiveCardState();
}

class _FranquiaLiveCardState extends State<FranquiaLiveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _semColor {
    switch (widget.franquia.corSemaforo) {
      case 'verde':    return AppTheme.green;
      case 'amarelo':  return AppTheme.yellow;
      case 'vermelho': return AppTheme.red;
      default:         return AppTheme.green;
    }
  }

  IconData get _semIcon {
    switch (widget.franquia.corSemaforo) {
      case 'verde':    return Icons.shield_rounded;
      case 'amarelo':  return Icons.warning_amber_rounded;
      case 'vermelho': return Icons.dangerous_rounded;
      default:         return Icons.shield_rounded;
    }
  }

  String get _franquiaFmt {
    final v = widget.franquia.valor;
    if (v >= 1000) {
      return 'R\$ ${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
    }
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final sem = _semColor;
    final isRed = widget.franquia.corSemaforo == 'vermelho';

    return GestureDetector(
      onTap: widget.onToggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: EdgeInsets.all(widget.isExpanded ? 14 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: sem.withValues(alpha: isRed ? 0.3 : 0.15),
              blurRadius: isRed ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: sem.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: widget.isExpanded
            ? _buildExpanded(sem)
            : _buildCollapsed(sem),
      ),
    );
  }

  // ── Versão compacta (padrão) ────────────────────────────────────
  Widget _buildCollapsed(Color sem) {
    return Row(
      children: [
        // Semáforo animado
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: sem.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: sem.withValues(alpha: 0.4 * _pulseAnim.value),
                blurRadius: 12,
              )],
            ),
            child: Icon(_semIcon, color: sem, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        // Franquia
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FRANQUIA DESTA VIAGEM',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted, letterSpacing: 0.5,
                ),
              ),
              Text(
                _franquiaFmt,
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: sem, height: 1.1,
                ),
              ),
              Text(
                widget.franquia.mensagem,
                style: const TextStyle(
                  fontSize: 10, color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Custo/km
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'R\$ ${widget.custoKmAtual.toStringAsFixed(2).replaceAll('.', ',')}/km',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            Text(
              '${widget.kmPercorrido.toStringAsFixed(1)} km',
              style: const TextStyle(
                fontSize: 10, color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
        Icon(Icons.expand_more_rounded, size: 16, color: AppTheme.textLight),
      ],
    );
  }

  // ── Versão expandida (ao tocar) ─────────────────────────────────
  Widget _buildExpanded(Color sem) {
    final f = widget.franquia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header com semáforo
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: sem.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: sem.withValues(alpha: 0.4 * _pulseAnim.value),
                    blurRadius: 14,
                  )],
                ),
                child: Icon(_semIcon, color: sem, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FRANQUIA DESTA VIAGEM',
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted, letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'R\$ ${f.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900,
                      color: sem, height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_less_rounded, size: 16, color: AppTheme.textLight),
          ],
        ),

        const SizedBox(height: 10),
        _divider(),
        const SizedBox(height: 8),

        // Fatores
        _factorRow(
          icon: Icons.access_time_rounded,
          label: 'Horário',
          value: '×${f.fatorHorario.toStringAsFixed(1)}',
          color: f.fatorHorario > 1.2
              ? AppTheme.red
              : f.fatorHorario > 1.0
                  ? AppTheme.yellow
                  : AppTheme.green,
          desc: f.fatorHorario == 1.0
              ? 'Horário comercial'
              : f.fatorHorario == 1.2
                  ? 'Período noturno'
                  : 'Madrugada',
        ),

        const SizedBox(height: 6),

        _factorRow(
          icon: Icons.location_on_rounded,
          label: 'Localização',
          value: '×${f.fatorLocalizacao.toStringAsFixed(2)}',
          color: f.fatorLocalizacao >= 1.6
              ? AppTheme.red
              : f.fatorLocalizacao > 1.0
                  ? AppTheme.yellow
                  : AppTheme.green,
          desc: TripPricingEngine.labelZona(f.zonaAtual),
        ),

        const SizedBox(height: 8),

        // Barra de cálculo
        _calcBar(f),

        const SizedBox(height: 8),

        // Custo por km
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Custo/km agora:',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            Text(
              'R\$ ${widget.custoKmAtual.toStringAsFixed(3).replaceAll('.', ',')}/km',
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary,
              ),
            ),
          ],
        ),

        // Dica (quando há sugestão de redução)
        if (f.dica != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.blueLight.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.blueLight.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, size: 14, color: AppTheme.blueLight),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    f.dica!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _divider() => Container(height: 1, color: AppTheme.border);

  Widget _factorRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String desc,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $desc',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _calcBar(LiveFranquia f) {
    // Barra visual: franquiaBase → franquiaAtual
    final maxFranquia = f.franquiaBase * 2.0;
    final pct = (f.valor / maxFranquia).clamp(0.0, 1.0);
    final sem = _semColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'R\$ ${f.franquiaBase.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
            ),
            Text(
              'R\$ ${(f.franquiaBase * 2).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: sem,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: sem.withValues(alpha: 0.4), blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Franquia base: R\$ ${f.franquiaBase.toStringAsFixed(0)} × ${(f.fatorHorario * f.fatorLocalizacao).toStringAsFixed(2)} = R\$ ${f.valor.toStringAsFixed(2).replaceAll('.', ',')}',
          style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// EXTRATO PÓS-VIAGEM — resumo completo
// ──────────────────────────────────────────────────────────────────────
class TripReceiptCard extends StatelessWidget {
  final TripPricingResult resultado;
  final VoidCallback? onClose;

  const TripReceiptCard({
    super.key,
    required this.resultado,
    this.onClose,
  });

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final score = resultado.scoreViagem;
    final scoreColor = score.nivel >= 4
        ? AppTheme.green
        : score.nivel == 3
            ? AppTheme.yellow
            : AppTheme.red;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header verde ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.green, AppTheme.greenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.sports_score_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 6),
                const Text('Viagem Concluída!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  '${resultado.totalKmCobrado.toStringAsFixed(1)} km · ${score.classificacao}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Franquia desta viagem (destaque) ────────────
                _franquiaDestaque(),
                const SizedBox(height: 14),

                // ── Breakdown de valores ─────────────────────────
                _sectionTitle('Detalhamento'),
                const SizedBox(height: 8),
                _lineItem('Taxa fixa (dia)', _fmt(resultado.taxaFixa)),
                _lineItem(
                  'Custo/km (${resultado.totalKmCobrado.toStringAsFixed(1)} km)',
                  _fmt(resultado.custoVariavel),
                ),
                if (resultado.ghostTripDetected) ...[
                  _lineItem(
                    '⚠️ Penalidade GPS (${resultado.ghostKmCobrado.toStringAsFixed(1)} km ×3)',
                    _fmt(resultado.custoVariavel * 0.3),
                    isRed: true,
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total cobrado',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.text)),
                    Text(
                      _fmt(resultado.premioTotal),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Fatores aplicados ────────────────────────────
                _sectionTitle('Fatores de Risco'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _fatorChip('Horário', '×${resultado.fatorHorarioMedio.toStringAsFixed(1)}',
                        resultado.fatorHorarioMedio > 1.2 ? AppTheme.red : resultado.fatorHorarioMedio > 1.0 ? AppTheme.yellow : AppTheme.green),
                    const SizedBox(width: 8),
                    _fatorChip('Local', '×${resultado.fatorLocalizacaoMax.toStringAsFixed(2)}',
                        resultado.fatorLocalizacaoMax >= 1.6 ? AppTheme.red : resultado.fatorLocalizacaoMax > 1.0 ? AppTheme.yellow : AppTheme.green),
                    const SizedBox(width: 8),
                    _fatorChip('Conduta', '×${resultado.fatorComportamento.toStringAsFixed(2)}',
                        resultado.fatorComportamento > 1.1 ? AppTheme.yellow : AppTheme.green),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Score ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Estrelas
                          ...List.generate(5, (i) => Icon(
                            i < score.nivel ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppTheme.yellow, size: 18,
                          )),
                          const SizedBox(width: 8),
                          Text(score.classificacao,
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: scoreColor)),
                          const Spacer(),
                          Text('+${score.pontosGanhos} pts',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                        ],
                      ),
                      if (score.descontoMensalidade > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.local_offer_rounded,
                                size: 14, color: AppTheme.green),
                            const SizedBox(width: 6),
                            Text(
                              '${score.descontoMensalidade.toStringAsFixed(0)}% de desconto na próxima mensalidade!',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                      if (score.conquistas.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: score.conquistas.map((c) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(c, style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Alertas ──────────────────────────────────────
                if (resultado.alertas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...resultado.alertas.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.info_rounded, size: 14, color: AppTheme.yellow),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(a,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ),
                      ],
                    ),
                  )),
                ],

                const SizedBox(height: 14),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Fechar Extrato',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _franquiaDestaque() {
    final f = resultado.franquiaAplicada;
    final cor = f <= resultado.franquiaBase * 1.05
        ? AppTheme.green
        : f <= resultado.franquiaBase * 1.5
            ? AppTheme.yellow
            : AppTheme.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, color: cor, size: 16),
              const SizedBox(width: 6),
              Text(
                'FRANQUIA DESTA VIAGEM',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted, letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _fmt(f),
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: cor,
            ),
          ),
          Text(
            f <= resultado.franquiaBase * 1.05
                ? '✅ Franquia mínima garantida — ótima direção!'
                : '⚠️ Franquia aumentou pela zona/horário da rota',
            style: TextStyle(fontSize: 11, color: cor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppTheme.textMuted, letterSpacing: 0.4,
        ),
      );

  Widget _lineItem(String label, String value, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isRed ? AppTheme.red : AppTheme.textMuted)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isRed ? AppTheme.red : AppTheme.text)),
        ],
      ),
    );
  }

  Widget _fatorChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// MINI BADGE — versão super compacta para sobrepor o mapa
// ──────────────────────────────────────────────────────────────────────
class FranquiaMinisBadge extends StatelessWidget {
  final LiveFranquia franquia;

  const FranquiaMinisBadge({super.key, required this.franquia});

  Color get _cor {
    switch (franquia.corSemaforo) {
      case 'verde':    return AppTheme.green;
      case 'amarelo':  return AppTheme.yellow;
      case 'vermelho': return AppTheme.red;
      default:         return AppTheme.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(99),
        boxShadow: AppTheme.shadowMd,
        border: Border.all(color: _cor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: _cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Franquia: R\$ ${franquia.valor.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

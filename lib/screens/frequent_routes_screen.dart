// ═══════════════════════════════════════════════════════════════
// FREQUENT ROUTES SCREEN — Gerenciar destinos frequentes
// ═══════════════════════════════════════════════════════════════
// ignore_for_file: prefer_single_quotes
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/frequent_routes_service.dart';
import '../services/mapbox_search_service.dart';

class FrequentRoutesScreen extends StatefulWidget {
  final VoidCallback onBack;

  const FrequentRoutesScreen({super.key, required this.onBack});

  @override
  State<FrequentRoutesScreen> createState() => _FrequentRoutesScreenState();
}

class _FrequentRoutesScreenState extends State<FrequentRoutesScreen> {
  List<FrequentRoute> _routes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routes = await FrequentRoutesService.load();
    if (mounted) {
      setState(() {
        _routes = routes..sort((a, b) => b.tripCount.compareTo(a.tripCount));
        _loading = false;
      });
    }
  }

  Future<void> _addRoute() async {
    final result = await showModalBottomSheet<FrequentRoute>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddRouteSheet(),
    );
    if (result != null) {
      await FrequentRoutesService.add(result);
      _load();
    }
  }

  Future<void> _deleteRoute(FrequentRoute route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remover rota?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remover "${route.label}" dos seus destinos frequentes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FrequentRoutesService.remove(route.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14),
          child: Row(children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Rotas Frequentes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ),
          ]),
        ),

        // ── Lista ────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _routes.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _routes.length,
                      itemBuilder: (_, i) => _RouteCard(
                        route: _routes[i],
                        onDelete: () => _deleteRoute(_routes[i]),
                      ),
                    ),
        ),
      ]),

      // ── FAB Adicionar ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRoute,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star_border_rounded, size: 40, color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        const Text('Nenhum destino frequente',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        const Text('Adicione Casa, Trabalho e outros\ndestinos que você visita com frequência.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        const SizedBox(height: 100),
      ]),
    );
  }
}

// ── Card de rota ─────────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final FrequentRoute route;
  final VoidCallback onDelete;

  const _RouteCard({required this.route, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: route.type.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(route.type.icon, color: route.type.color, size: 22),
        ),
        title: Text(route.label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(route.address,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.local_taxi_rounded, size: 11, color: Colors.grey.shade400),
            const SizedBox(width: 3),
            Text('${route.tripCount} viagem${route.tripCount != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ]),
        ]),
        trailing: GestureDetector(
          onTap: onDelete,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Bottom Sheet para adicionar rota ─────────────────────────────
class _AddRouteSheet extends StatefulWidget {
  const _AddRouteSheet();

  @override
  State<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends State<_AddRouteSheet> {
  FrequentRouteType _selectedType = FrequentRouteType.work;
  final _labelCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  double? _lat;
  double? _lon;
  bool _searching = false;
  List<MapboxSuggestion> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onAddressChanged(String q) {
    _debounce?.cancel();
    if (q.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final r = await MapboxSearchService.suggest(q);
        if (mounted) setState(() { _suggestions = r; _searching = false; });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _pickSuggestion(MapboxSuggestion s) async {
    setState(() => _searching = true);
    final r = await MapboxSearchService.retrieve(s);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _suggestions = [];
      _addressCtrl.text = '${s.name}, ${s.subtitle}';
      _lat = r?.lat;
      _lon = r?.lon;
    });
  }

  bool get _canSave =>
      _labelCtrl.text.trim().isNotEmpty &&
      _addressCtrl.text.trim().isNotEmpty &&
      _lat != null &&
      _lon != null;

  void _save() {
    if (!_canSave) return;
    HapticFeedback.mediumImpact();
    final route = FrequentRoute(
      id: FrequentRoutesService.generateId(),
      type: _selectedType,
      label: _labelCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      lat: _lat!,
      lon: _lon!,
      createdAt: DateTime.now(),
    );
    Navigator.pop(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          const Text('Novo destino frequente',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),

          // Tipo
          const Text('Tipo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FrequentRouteType.values.map((t) {
                final sel = t == _selectedType;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedType = t;
                    if (_labelCtrl.text.isEmpty) _labelCtrl.text = t.label;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? t.color : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.icon, size: 14, color: sel ? Colors.white : Colors.grey),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : Colors.grey.shade600)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Nome
          const Text('Nome', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          TextField(
            controller: _labelCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Ex: Meu escritório',
              filled: true, fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Endereço com busca
          const Text('Endereço', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          TextField(
            controller: _addressCtrl,
            onChanged: (v) { _onAddressChanged(v); setState(() { _lat = null; _lon = null; }); },
            decoration: InputDecoration(
              hintText: 'Digite o endereço...',
              filled: true, fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: _searching
                  ? const Padding(padding: EdgeInsets.all(12),
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : (_lat != null ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600) : null),
            ),
          ),

          // Sugestões
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
              ),
              child: Column(
                children: _suggestions.take(4).map((s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_rounded, size: 18, color: AppTheme.primary),
                  title: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(s.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  onTap: () => _pickSuggestion(s),
                )).toList(),
              ),
            ),
          const SizedBox(height: 20),

          // Botão salvar
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _canSave ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Salvar destino',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}



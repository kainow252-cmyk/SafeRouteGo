// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// LIVE GPS PANEL — Painel de geolocalização em tempo real
// Usa GPS nativo + BnL API para mostrar:
//   • Posição atual (lat/lon)
//   • País + UF (via Boxes'n'Lines API)
//   • Mapa interativo com flutter_map + OpenStreetMap
//   • Indicador de velocidade e precisão
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LiveGpsPanel extends StatefulWidget {
  const LiveGpsPanel({super.key});

  @override
  State<LiveGpsPanel> createState() => _LiveGpsPanelState();
}

class _LiveGpsPanelState extends State<LiveGpsPanel>
    with AutomaticKeepAliveClientMixin {
  final _mapController = MapController();
  LocationState _loc = const LocationState();
  bool _mapReady = false;
  bool _followUser = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Escuta o stream de localização
    LocationService.instance.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _loc = state);
      // Move mapa para nova posição se seguindo usuário
      if (_followUser && _mapReady && state.hasPosition) {
        _mapController.move(
          LatLng(state.lat!, state.lon!),
          _mapController.camera.zoom,
        );
      }
    });
    // Inicia rastreamento ao abrir o painel
    _startGps();
  }

  Future<void> _startGps() async {
    await LocationService.instance.getCurrentPosition();
  }

  Future<void> _refreshGps() async {
    setState(() => _loc = _loc.copyWith(isLoading: true, error: null));
    await LocationService.instance.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildHeader(),
            _buildMap(),
            _buildInfoBar(),
            _buildGeoDetails(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Minha Localização',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _loc.statusText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Botão seguir usuário
          InkWell(
            onTap: () => setState(() => _followUser = !_followUser),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _followUser
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _followUser ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botão atualizar
          InkWell(
            onTap: _loc.isLoading ? null : _refreshGps,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: _loc.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAPA INTERATIVO ──────────────────────────────────────────────────
  Widget _buildMap() {
    final hasPos = _loc.hasPosition;
    final center = hasPos
        ? LatLng(_loc.lat!, _loc.lon!)
        : const LatLng(-15.77972, -47.92972); // Brasília como padrão

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: hasPos ? 14.0 : 5.0,
              onMapReady: () => setState(() => _mapReady = true),
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) setState(() => _followUser = false);
              },
            ),
            children: [
              // Tiles OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.saferoute.insurance',
                maxZoom: 19,
              ),
              // Pin da posição atual
              if (hasPos)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_loc.lat!, _loc.lon!),
                      width: 56,
                      height: 56,
                      child: _buildLocationPin(),
                    ),
                  ],
                ),
              // Círculo de precisão
              if (hasPos && _loc.accuracy != null && _loc.accuracy! < 500)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_loc.lat!, _loc.lon!),
                      radius: _loc.accuracy!,
                      useRadiusInMeter: true,
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderColor: AppTheme.primary.withValues(alpha: 0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
            ],
          ),
          // Loading overlay
          if (_loc.isLoading && !hasPos)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 12),
                      Text(
                        'Obtendo localização GPS…',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Erro overlay
          if (_loc.error != null && !hasPos)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.85),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gps_off, size: 40, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      _loc.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refreshGps,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Tentar novamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Badge UF no canto
          if (_loc.isBrazil && _loc.geo?.uf != null)
            Positioned(
              top: 8,
              right: 8,
              child: _buildUFBadge(_loc.geo!.uf!),
            ),
          // Controles de zoom
          Positioned(
            right: 8,
            bottom: 8,
            child: _buildZoomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 4,
          height: 8,
          color: AppTheme.primary,
        ),
      ],
    );
  }

  Widget _buildUFBadge(String uf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇧🇷', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            uf,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      children: [
        _ZoomButton(
          icon: Icons.add,
          onTap: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom + 1,
          ),
        ),
        const SizedBox(height: 4),
        _ZoomButton(
          icon: Icons.remove,
          onTap: () => _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom - 1,
          ),
        ),
      ],
    );
  }

  // ─── INFO BAR ─────────────────────────────────────────────────────────
  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(
          top: BorderSide(color: Color(0xFFE9ECEF), width: 1),
          bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1),
        ),
      ),
      child: Row(
        children: [
          _InfoChip(
            icon: Icons.gps_fixed,
            label: _loc.coordsText,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          if (_loc.accuracy != null)
            _InfoChip(
              icon: Icons.radar,
              label: _loc.accuracyText,
              color: _loc.accuracy! < 50 ? Colors.green : Colors.orange,
            ),
          const Spacer(),
          if (_loc.updatedAt != null)
            Text(
              _timeAgo(_loc.updatedAt!),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // ─── GEO DETAILS ──────────────────────────────────────────────────────
  Widget _buildGeoDetails() {
    final geo = _loc.geo;
    if (geo == null && !_loc.hasPosition) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _loc.isLoading
              ? 'Consultando BnL Geolocation API…'
              : 'Ative o GPS para ver detalhes de localização',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _GeoDetailCard(
              icon: Icons.public,
              title: 'País',
              value: geo?.countryDisplay ?? '…',
              subtitle: geo?.country ?? '',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GeoDetailCard(
              icon: Icons.map_outlined,
              title: 'Estado',
              value: geo?.ufFullName ?? '…',
              subtitle: geo?.uf ?? '',
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GeoDetailCard(
              icon: Icons.speed,
              title: 'Velocidade',
              value: '${_loc.speedKmh} km/h',
              subtitle: _loc.accuracy != null
                  ? _loc.accuracyText
                  : 'GPS',
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'agora';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s atrás';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    return '${diff.inHours}h atrás';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _GeoDetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _GeoDetailCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

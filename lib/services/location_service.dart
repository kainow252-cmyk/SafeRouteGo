// ignore_for_file: prefer_single_quotes
// ═══════════════════════════════════════════════════════════════════════════
// LOCATION SERVICE — GPS nativo + BnL reverse geocode em tempo real
//
// Fluxo:
// 1. Solicita permissão de localização (geolocator)
// 2. Obtém posição GPS atual (lat/lon)
// 3. Chama BnLGeoService.getFullGeoFromGps() → país + UF
// 4. Notifica ouvintes via Stream (para atualizar UI em tempo real)
//
// Web: usa geolocation da browser (HTML5)
// Android/iOS: usa GPS nativo via geolocator
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'bnl_geo_service.dart';
import 'browser_geo_fallback.dart';

// ─────────────────────────────────────────────────────────────────────────
// MODELO DE ESTADO DE LOCALIZAÇÃO
// ─────────────────────────────────────────────────────────────────────────
class LocationState {
  final double? lat;
  final double? lon;
  final double? accuracy;    // metros
  final double? heading;     // graus (0 = norte)
  final double? speed;       // m/s
  final GpsGeoResult? geo;   // país + UF via BnL API
  final bool isLoading;
  final String? error;
  final DateTime? updatedAt;

  const LocationState({
    this.lat,
    this.lon,
    this.accuracy,
    this.heading,
    this.speed,
    this.geo,
    this.isLoading = false,
    this.error,
    this.updatedAt,
  });

  bool get hasPosition => lat != null && lon != null;

  bool get isBrazil => geo?.isBrazil ?? false;

  String get ufDisplay => geo?.uf ?? '??';

  String get statusText {
    if (isLoading) return 'Obtendo localização…';
    if (error != null) return error!;
    if (!hasPosition) return 'Posição não disponível';
    return geo?.isBrazil == true
        ? 'Brasil — ${geo!.ufFullName} (${geo!.uf})'
        : 'Fora do Brasil — ${geo?.countryDisplay ?? "País desconhecido"}';
  }

  String get coordsText {
    if (!hasPosition) return '--';
    final latStr = lat!.toStringAsFixed(4);
    final lonStr = lon!.toStringAsFixed(4);
    return '$latStr, $lonStr';
  }

  String get accuracyText {
    if (accuracy == null) return '';
    if (accuracy! < 10) return '±${accuracy!.toStringAsFixed(0)}m (GPS)';
    if (accuracy! < 50) return '±${accuracy!.toStringAsFixed(0)}m (Boa)';
    if (accuracy! < 200) return '±${accuracy!.toStringAsFixed(0)}m (OK)';
    return '±${accuracy!.toStringAsFixed(0)}m (Baixa)';
  }

  String get speedKmh {
    if (speed == null || speed! < 0.5) return '0';
    return (speed! * 3.6).toStringAsFixed(0);
  }

  LocationState copyWith({
    double? lat,
    double? lon,
    double? accuracy,
    double? heading,
    double? speed,
    GpsGeoResult? geo,
    bool? isLoading,
    String? error,
    DateTime? updatedAt,
  }) {
    return LocationState(
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      geo: geo ?? this.geo,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// LOCATION SERVICE
// ─────────────────────────────────────────────────────────────────────────
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  // Registra esta instância no BrowserGeoFallback para que ele possa
  // reutilizar o GPS já inicializado sem criar dependência circular
  LocationService._() {
    registerLocationServiceForFallback(this);
  }

  final _stateController = StreamController<LocationState>.broadcast();
  Stream<LocationState> get stateStream => _stateController.stream;

  LocationState _state = const LocationState();
  LocationState get state => _state;

  StreamSubscription<Position>? _positionSub;
  bool _isTracking = false;

  // ─────────────────────────────────────────────────────────────────────
  // INICIALIZA E SOLICITA PERMISSÃO
  // ─────────────────────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    try {
      // Verifica se localização está habilitada no dispositivo
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _emit(_state.copyWith(
          error: 'GPS desabilitado. Ative nas configurações.',
          isLoading: false,
        ));
        return false;
      }

      // Verifica permissão atual
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _emit(_state.copyWith(
            error: 'Permissão de localização negada.',
            isLoading: false,
          ));
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _emit(_state.copyWith(
          error: 'Localização bloqueada permanentemente. Abra as configurações do app.',
          isLoading: false,
        ));
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('LocationService.requestPermission: $e');
      _emit(_state.copyWith(error: 'Erro ao verificar permissão: $e', isLoading: false));
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // OBTÉM POSIÇÃO UMA VEZ
  // ─────────────────────────────────────────────────────────────────────
  Future<LocationState> getCurrentPosition() async {
    _emit(_state.copyWith(isLoading: true, error: null));

    final hasPermission = await requestPermission();
    if (!hasPermission) return _state;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Geocodifica via BnL API em paralelo
      final geo = await BnLGeoService.getFullGeoFromGps(pos.latitude, pos.longitude);

      final newState = LocationState(
        lat: pos.latitude,
        lon: pos.longitude,
        accuracy: pos.accuracy,
        heading: pos.heading,
        speed: pos.speed,
        geo: geo,
        isLoading: false,
        updatedAt: DateTime.now(),
      );

      _state = newState;
      _emit(newState);
      return newState;
    } catch (e) {
      if (kDebugMode) debugPrint('LocationService.getCurrentPosition: $e');
      final errState = _state.copyWith(
        error: 'Erro ao obter posição: ${_friendlyError(e)}',
        isLoading: false,
      );
      _emit(errState);
      return errState;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // RASTREAMENTO CONTÍNUO (atualiza a cada ~5 segundos ou 10m de movimento)
  // ─────────────────────────────────────────────────────────────────────
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _isTracking = true;
    _emit(_state.copyWith(isLoading: true, error: null));

    // Obtém posição inicial imediatamente
    await getCurrentPosition();

    // Stream de updates contínuos
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,        // mínimo 10 metros de mudança
        timeLimit: Duration(seconds: 30),
      ),
    ).listen(
      (pos) async {
        // Só re-geocodifica se moveu mais de 500m (evita calls excessivas à API)
        final oldLat = _state.lat ?? 0;
        final oldLon = _state.lon ?? 0;
        final movedFar = _distance(oldLat, oldLon, pos.latitude, pos.longitude) > 500;

        GpsGeoResult? geo = movedFar || _state.geo == null
            ? await BnLGeoService.getFullGeoFromGps(pos.latitude, pos.longitude)
            : _state.geo;

        final newState = LocationState(
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy,
          heading: pos.heading,
          speed: pos.speed,
          geo: geo,
          isLoading: false,
          updatedAt: DateTime.now(),
        );
        _state = newState;
        _emit(newState);
      },
      onError: (e) {
        if (kDebugMode) debugPrint('LocationService stream error: $e');
        _emit(_state.copyWith(error: _friendlyError(e), isLoading: false));
      },
    );
  }

  void stopTracking() {
    _isTracking = false;
    _positionSub?.cancel();
    _positionSub = null;
  }

  void dispose() {
    stopTracking();
    _stateController.close();
  }

  void _emit(LocationState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  // Distância aproximada em metros (fórmula simplificada para curtas distâncias)
  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const earthR = 6371000.0;
    final dLat = (lat2 - lat1) * (3.14159 / 180);
    final dLon = (lon2 - lon1) * (3.14159 / 180);
    return earthR * ((dLat * dLat + dLon * dLon) > 0
        ? (dLat * dLat + dLon * dLon)
        : 0);
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Tempo esgotado. Tente novamente.';
    if (msg.contains('denied')) return 'Permissão negada.';
    if (msg.contains('disabled')) return 'GPS desabilitado.';
    return 'Erro de localização.';
  }
}

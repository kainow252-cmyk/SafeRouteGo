import 'package:flutter/material.dart';

// ── Singleton global de sessão de viagem ─────────────────────────
// Acesso direto via TripSession.current sem precisar de context/Provider.
// Usado por DestinationScreen (salva) e QuoteScreen (lê).
class TripSession {
  TripSession._();
  static final TripSession current = TripSession._();

  double? originLat;
  double? originLon;
  double? destLat;
  double? destLon;
  String? destLabel;

  bool get hasCoords =>
      originLat != null && originLon != null &&
      destLat   != null && destLon   != null;

  void setDestination({
    required double lat,
    required double lon,
    String? label,
  }) {
    destLat   = lat;
    destLon   = lon;
    if (label != null) destLabel = label;
  }

  void setOrigin({required double lat, required double lon}) {
    originLat = lat;
    originLon = lon;
  }

  void clear() {
    originLat = originLon = destLat = destLon = null;
    destLabel = null;
  }
}

class AppState extends ChangeNotifier {
  String _currentScreen = 'splash';
  final List<String> _history = ['splash'];
  bool _tripActive = false;
  bool _darkMode = false;
  int _tripSeconds = 0;
  double _tripKm = 0;
  String _selectedColor = 'black';

  // ── Coordenadas da viagem atual ─────────────────────────────────
  // Salvas ao selecionar origem (GPS) e destino (DestinationScreen)
  // Usadas pelo TrafficDetectionService para detecção automática
  double? originLat;
  double? originLon;
  double? destLat;
  double? destLon;
  String? destLabel; // nome do destino para exibição

  // Getters
  String get currentScreen => _currentScreen;
  List<String> get history => _history;
  bool get tripActive => _tripActive;
  bool get darkMode => _darkMode;
  int get tripSeconds => _tripSeconds;
  double get tripKm => _tripKm;
  String get selectedColor => _selectedColor;

  /// Retorna true se tem coords de origem E destino disponíveis
  bool get hasTripCoords =>
      originLat != null && originLon != null &&
      destLat != null && destLon != null;

  void goTo(String screen) {
    _currentScreen = screen;
    _history.add(screen);
    notifyListeners();
  }

  void goBack() {
    if (_history.length > 1) {
      _history.removeLast();
      _currentScreen = _history.last;
      notifyListeners();
    }
  }

  void setTripActive(bool active) {
    _tripActive = active;
    notifyListeners();
  }

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }

  void updateTripMetrics(int seconds, double km) {
    _tripSeconds = seconds;
    _tripKm = km;
    notifyListeners();
  }

  void resetTrip() {
    _tripSeconds = 0;
    _tripKm = 0;
    _tripActive = false;
    notifyListeners();
  }

  void selectColor(String color) {
    _selectedColor = color;
    notifyListeners();
  }

  /// Salva coordenadas de origem e/ou destino da viagem.
  /// Parâmetros são opcionais — pass apenas o que mudou.
  void setTripCoords({
    double? oLat, double? oLon,
    double? dLat, double? dLon,
    String? dLabel,
  }) {
    if (oLat != null) originLat = oLat;
    if (oLon != null) originLon = oLon;
    if (dLat != null) destLat   = dLat;
    if (dLon != null) destLon   = dLon;
    if (dLabel != null) destLabel = dLabel;
    notifyListeners();
  }

  /// Limpa coords ao encerrar viagem
  void clearTripCoords() {
    originLat = originLon = destLat = destLon = null;
    destLabel = null;
    notifyListeners();
  }
}

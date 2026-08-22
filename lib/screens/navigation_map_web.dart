// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

void registerMapView(String viewId, String htmlContent) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
    // Usa Blob URL para permitir fetch externo (OSRM, OSM tiles)
    // srcdoc implicitamente sandbox bloqueia network requests
    final blob = html.Blob([htmlContent], 'text/html');
    final blobUrl = html.Url.createObjectUrl(blob);

    final iframe = html.IFrameElement()
      ..src = blobUrl
      ..width = '100%'
      ..height = '100%'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('allow', 'geolocation *; camera *')
      ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
    return iframe;
  });
}

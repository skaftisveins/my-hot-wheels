import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Les halla símans í vafranum (`deviceorientation`).
class DeviceTilt {
  const DeviceTilt._();

  static JSObject? get _event => globalContext.has('DeviceOrientationEvent')
      ? globalContext['DeviceOrientationEvent'] as JSObject?
      : null;

  /// Safari á iPhone krefst leyfis, og það má bara biðja um það þegar ýtt er á hnapp.
  static bool get needsPermission => available && (_event?.has('requestPermission') ?? false);

  /// Bara á snertitækjum (símum og spjaldtölvum); tölvur hafa engan hallaskynjara.
  static bool get available => _event != null && web.window.navigator.maxTouchPoints > 0;

  static Future<bool> requestPermission() async {
    final event = _event;
    if (event == null) return false;
    if (!event.has('requestPermission')) return true;
    try {
      // Kallið verður að gerast strax í smellinum, áður en beðið er eftir nokkru.
      final promise = event.callMethod<JSPromise<JSString>>('requestPermission'.toJS);
      return (await promise.toDart).toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void Function() listen(void Function(double degrees) onTilt) {
    final handler = ((web.Event event) {
      final gamma = (event as web.DeviceOrientationEvent).gamma;
      if (gamma != null) onTilt(gamma);
    }).toJS;
    web.window.addEventListener('deviceorientation', handler);
    return () => web.window.removeEventListener('deviceorientation', handler);
  }
}

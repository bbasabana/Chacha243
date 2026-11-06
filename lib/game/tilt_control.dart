import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Lit l'inclinaison du téléphone tenu à l'horizontale.
///
/// [vertical] > 0 : le haut de l'écran part vers l'avant, l'avion descend.
/// [horizontal] > 0 : on tourne le téléphone comme un volant vers la droite, l'avion avance.
class TiltControl {
  StreamSubscription<AccelerometerEvent>? _sub;
  double _pitch = 0, _roll = 0, _basePitch = 0, _baseRoll = 0;
  bool _hasData = false;
  bool _calibrated = false;

  bool get available => _hasData;

  void start() {
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (e) {
          final side = e.x >= 0 ? 1.0 : -1.0;
          _pitch = math.atan2(e.z, e.x.abs());
          _roll = math.atan2(e.y * side, e.x.abs());
          _hasData = true;
          if (!_calibrated) calibrate();
        },
        onError: (_) {},
        cancelOnError: true,
      );
    } catch (_) {
      // Pas de capteur (navigateur, simulateur) : clavier et doigt prennent le relais.
    }
  }

  /// La position actuelle du téléphone devient la position neutre.
  void calibrate() {
    _basePitch = _pitch;
    _baseRoll = _roll;
    _calibrated = _hasData;
  }

  double _axis(double v) {
    if (v.abs() < 0.06) return 0;
    return (v / 0.32).clamp(-1.0, 1.0);
  }

  double get vertical => _hasData ? _axis(_pitch - _basePitch) : 0;
  double get horizontal => _hasData ? _axis(_roll - _baseRoll) : 0;

  void stop() => _sub?.cancel();
}

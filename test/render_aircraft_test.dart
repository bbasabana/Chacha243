import 'dart:io';
import 'dart:ui' as ui;

import 'package:chacha243/data/aircraft_types.dart';
import 'package:chacha243/data/eras.dart';
import 'package:chacha243/painting/aircraft_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exporte chaque avion en PNG 4K (3840 × 1920, fond transparent) dans design/avions.
///
/// Lancer : flutter test test/render_aircraft_test.dart
void main() {
  // Livrée de l'époque où chaque avion vole au Congo.
  const debutYear = {
    'dc3': 1962.0,
    'dc6': 1960.2,
    'b707': 1966.0,
    'caravelle': 1968.0,
    'dc10': 1975.0,
    'b747': 1974.0,
    'b737': 2025.0,
    'a320': 2016.0,
    'atr72': 2025.0,
    'b787': 2026.0,
  };

  testWidgets('exporte les avions en 4K', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory('design/avions')..createSync(recursive: true);
      const w = 3840.0, h = 1920.0;
      for (final type in aircraftTypes) {
        final livery = airlineAt(debutYear[type.id] ?? 1960).livery;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final len = w * 0.92;
        canvas.translate((w - len) / 2, (h - len * 0.5) / 2);
        AircraftPainter.paint(canvas, Size(len, len * 0.5), type, livery, propPhase: 0.6, gear: 1, blink: 0.5);
        final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/${type.id}-4k.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
  });
}

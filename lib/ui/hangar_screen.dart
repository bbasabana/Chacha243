import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/aircraft_types.dart';
import '../data/eras.dart';
import '../painting/aircraft_painter.dart';
import '../theme/chacha_colors.dart';
import 'glass.dart';

/// Le hangar : le joueur choisit son avion, du DC-3 au Boeing 787.
class HangarScreen extends StatefulWidget {
  const HangarScreen({super.key});

  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

/// Livrée montrée au hangar : l'époque où l'avion vole au Congo.
const _showcaseYear = {
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

class _HangarScreenState extends State<HangarScreen> with SingleTickerProviderStateMixin {
  late final _page = PageController(
    viewportFraction: 0.62,
    initialPage: aircraftTypes.indexOf(selectedAircraft.value),
  );
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  late int _index = aircraftTypes.indexOf(selectedAircraft.value);

  @override
  void dispose() {
    _page.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = aircraftTypes[_index];
    final era = airlineAt(_showcaseYear[type.id] ?? 1960);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1C4A8F), ChachaColors.night],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    GlassButton(
                      onTap: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.all(12),
                      radius: 18,
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Text('Hangar', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text('${_index + 1} / ${aircraftTypes.length}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: aircraftTypes.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final t = aircraftTypes[i];
                    final livery = airlineAt(_showcaseYear[t.id] ?? 1960).livery;
                    return AnimatedBuilder(
                      animation: Listenable.merge([_page, _spin]),
                      builder: (_, _) {
                        final page = _page.hasClients && _page.position.haveDimensions ? _page.page ?? i.toDouble() : _index.toDouble();
                        final d = (page - i).abs().clamp(0.0, 1.0);
                        return Transform.scale(
                          scale: 1 - d * 0.25,
                          child: Opacity(
                            opacity: 1 - d * 0.55,
                            child: CustomPaint(
                              painter: AircraftView(t, livery, propPhase: _spin.value * 40, gear: 1),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Glass(
                  padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${type.maker} ${type.name}',
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text('Au Congo : ${type.inCongo} · livrée ${era.name}',
                                style: const TextStyle(color: ChachaColors.yellow, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(type.story, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                            const SizedBox(height: 4),
                            Text('${type.seats} passagers · au Congo ${type.inCongo}',
                                style: const TextStyle(color: ChachaColors.yellow, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 190,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Stat('Vitesse', type.speed),
                            _Stat('Maniabilité', type.handling),
                            _Stat('Réservoir', type.tank),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ValueListenableBuilder(
                        valueListenable: selectedAircraft,
                        builder: (_, selected, _) {
                          final chosen = selected == type;
                          // On décolle en 1960 : seuls les avions de 1960 se choisissent.
                          // Les autres arrivent en vol, avec leur époque.
                          if (!type.fliesIn(1960.5)) {
                            return Glass(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.lock_clock_rounded, color: Colors.white70),
                                Text('Arrive en vol\nen ${type.from.floor()}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              ]),
                            );
                          }
                          return GlassButton(
                            tint: chosen ? const Color(0x5539D98A) : const Color(0x55CE1021),
                            onTap: chosen ? null : () => selectedAircraft.value = type,
                            child: Text(chosen ? 'Choisi ✓' : 'Choisir pour 1960'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 7, color: const Color(0x33FFFFFF)),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 7,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [ChachaColors.yellow, ChachaColors.red]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

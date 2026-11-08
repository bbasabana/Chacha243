import 'package:flutter/painting.dart';

import 'eras.dart';

/// Les avions que le joueur peut piloter, du DC-3 de 1960 au Boeing 787 d'Air Congo.
///
/// Sources : Wikipédia (Air Zaïre, Air Congo, Congo Airways), consultées en novembre 2026.
enum EngineLayout { twinProps, fourProps, twinJets, fourJets, rearJets, triJet }

class AircraftType {
  const AircraftType({
    required this.id,
    required this.name,
    required this.maker,
    required this.layout,
    required this.inCongo,
    required this.from,
    required this.to,
    required this.seats,
    required this.story,
    required this.length,
    required this.bodyHeight,
    required this.speed,
    required this.handling,
    required this.tank,
    this.operator,
    this.livery,
    this.hump = false,
    this.highWing = false,
  });

  final String id;
  final String name;
  final String maker;
  final EngineLayout layout;

  /// Quand le type a volé sous les couleurs congolaises.
  final String inCongo;

  /// La compagnie montrée au hangar quand ce n'est pas celle de l'époque (Hewa Bora, par exemple).
  final String? operator;

  /// La peinture propre à cette compagnie, quand elle ne suit pas celle de l'époque.
  final Livery? livery;

  /// Les années où ce type vole pour le Congo : on ne peut le prendre qu'à ces dates.
  final double from, to;

  /// Places passagers (configuration typique, environ).
  final int seats;
  final String story;

  bool fliesIn(double year) => year >= from && year <= to;

  /// Longueur relative (1 = gros-porteur) et hauteur du fuselage, en unités du dessin (sur 100).
  final double length;
  final double bodyHeight;

  /// Qualités en vol, de 0 à 1.
  final double speed;
  final double handling;
  final double tank;

  /// Pont supérieur (747) et aile haute (ATR).
  final bool hump;
  final bool highWing;

  bool get hasPropellers => layout == EngineLayout.twinProps || layout == EngineLayout.fourProps;
}

const aircraftTypes = <AircraftType>[
  AircraftType(
    id: 'dc3',
    name: 'DC-3',
    maker: 'Douglas',
    layout: EngineLayout.twinProps,
    inCongo: '1960 – années 1970',
    from: 1960.0,
    to: 1976.0,
    seats: 28,
    story: "L'avion à hélices des débuts : Air Congo en comptait 11 à sa création en 1961.",
    length: 0.62,
    bodyHeight: 12,
    speed: 0.35,
    handling: 0.95,
    tank: 0.55,
  ),
  AircraftType(
    id: 'dc6',
    name: 'DC-6',
    maker: 'Douglas',
    layout: EngineLayout.fourProps,
    inCongo: '1960 – années 1960',
    from: 1960.0,
    to: 1972.0,
    seats: 68,
    story: 'Quadrimoteur à hélices de la Sabena, puis d\'Air Congo dès 1961.',
    length: 0.74,
    bodyHeight: 11.5,
    speed: 0.45,
    handling: 0.8,
    tank: 0.75,
  ),
  AircraftType(
    id: 'b707',
    name: '707',
    maker: 'Boeing',
    layout: EngineLayout.fourJets,
    inCongo: 'années 1960 – 1970',
    from: 1960.0,
    to: 1990.0,
    seats: 147,
    story: "Premier jet d'Air Congo, sur la ligne Léopoldville – Douala – Paris.",
    length: 0.9,
    bodyHeight: 9.5,
    speed: 0.75,
    handling: 0.6,
    tank: 0.8,
  ),
  AircraftType(
    id: 'caravelle',
    name: 'Caravelle',
    maker: 'Sud Aviation',
    layout: EngineLayout.rearJets,
    inCongo: 'fin des années 1960',
    from: 1967.0,
    to: 1985.0,
    seats: 80,
    story: "Biréacteur français aux moteurs à l'arrière, arrivé dans la flotte vers 1967.",
    length: 0.78,
    bodyHeight: 10,
    speed: 0.65,
    handling: 0.75,
    tank: 0.55,
  ),
  AircraftType(
    id: 'dc10',
    name: 'DC-10',
    maker: 'McDonnell Douglas',
    layout: EngineLayout.triJet,
    inCongo: '1973 – années 1990',
    from: 1973.0,
    to: 1995.0,
    seats: 270,
    story: "Le gros-porteur à trois moteurs d'Air Zaïre, livré en 1973.",
    length: 1.0,
    bodyHeight: 14,
    speed: 0.8,
    handling: 0.5,
    tank: 0.95,
  ),
  AircraftType(
    id: 'b747',
    name: '747',
    maker: 'Boeing',
    layout: EngineLayout.fourJets,
    inCongo: 'années 1970',
    from: 1973.0,
    to: 1995.0,
    seats: 400,
    story: "Le géant d'Air Zaïre, annoncé en 1973 et souvent réquisitionné par Mobutu.",
    length: 1.1,
    bodyHeight: 14.5,
    speed: 0.85,
    handling: 0.4,
    tank: 1.0,
    hump: true,
  ),
  AircraftType(
    id: 'b737',
    name: '737',
    maker: 'Boeing',
    layout: EngineLayout.twinJets,
    inCongo: '1970 – aujourd\'hui',
    from: 1974.0,
    to: 2027.6,
    seats: 162,
    story: "Du 737-200 d'Air Zaïre aux 737-800 d'Air Congo depuis 2024.",
    length: 0.8,
    bodyHeight: 10.5,
    speed: 0.7,
    handling: 0.8,
    tank: 0.65,
  ),
  AircraftType(
    id: 'l1011',
    name: 'L-1011 TriStar',
    maker: 'Lockheed',
    layout: EngineLayout.triJet,
    inCongo: '1998 – 2011',
    operator: 'Hewa Bora Airways',
    livery: Livery(
      body: Color(0xFFF4F5F7),
      belly: Color(0xFFC9D1DB),
      stripe: Color(0x00000000),
      stripe2: Color(0xFF1F2A5C),
      tail: Color(0xFFF4F5F7),
      emblem: TailEmblem.none,
      word: 'HBA',
      wordSub: 'HEWA BORA AIRWAYS',
      wordColor: Color(0xFF1F3E8C),
      wordX: 77,
      wordSize: 7.2,
      tailWord: 'HBA',
      tailBase: Color(0xFF1F3E8C),
    ),
    from: 1998.3,
    to: 2011.52,
    seats: 246,
    story: "Le trimoteur de Hewa Bora Airways, la grande compagnie privée de Kinshasa, de ses débuts en 1998 jusqu'à sa fin le 8 juillet 2011.",
    length: 0.95,
    bodyHeight: 12.5,
    speed: 0.78,
    handling: 0.5,
    tank: 0.9,
  ),
  AircraftType(
    id: 'b767',
    name: '767',
    maker: 'Boeing',
    layout: EngineLayout.twinJets,
    inCongo: '2005 – 2013',
    operator: 'LAC',
    livery: Livery(
      body: Color(0xFFF1EEE6),
      belly: Color(0xFFCFCCC4),
      stripe: Color(0x00000000),
      stripe2: Color(0x00000000),
      tail: Color(0xFF2468D8),
      emblem: TailEmblem.star,
      engine: Color(0xFF2468D8),
      word: 'LAC',
      wordColor: Color(0xFF6B6B6B),
      wordX: 77,
      wordSize: 8.5,
      wordSerif: true,
      tailStars: true,
    ),
    from: 2005.0,
    to: 2013.5,
    seats: 200,
    story: "Le biréacteur moyen-porteur des LAC (Lignes Aériennes Congolaises), la compagnie créée en 2005 et liquidée en 2013.",
    length: 0.92,
    bodyHeight: 12,
    speed: 0.8,
    handling: 0.65,
    tank: 0.85,
  ),
  AircraftType(
    id: 'a320',
    name: 'A320',
    maker: 'Airbus',
    layout: EngineLayout.twinJets,
    inCongo: '2015 – 2025',
    from: 2015.8,
    to: 2025.0,
    seats: 150,
    story: 'Congo Airways a fait son premier vol le 20 octobre 2015 avec deux A320.',
    length: 0.82,
    bodyHeight: 11,
    speed: 0.72,
    handling: 0.82,
    tank: 0.68,
  ),
  AircraftType(
    id: 'atr72',
    name: 'ATR 72-600',
    maker: 'ATR',
    layout: EngineLayout.twinProps,
    inCongo: '2024 – aujourd\'hui',
    from: 2024.92,
    to: 2027.6,
    seats: 70,
    story: "Turbopropulseur régional d'Air Congo, idéal pour les pistes des provinces.",
    length: 0.7,
    bodyHeight: 10,
    speed: 0.5,
    handling: 0.9,
    tank: 0.6,
    highWing: true,
  ),
  AircraftType(
    id: 'b787',
    name: '787 Dreamliner',
    maker: 'Boeing',
    layout: EngineLayout.twinJets,
    inCongo: '2026',
    from: 2026.0,
    to: 2027.6,
    seats: 242,
    story: "Le long-courrier d'Air Congo, loué pour relier Kinshasa au monde.",
    length: 1.0,
    bodyHeight: 13,
    speed: 0.9,
    handling: 0.6,
    tank: 0.95,
  ),
];

AircraftType aircraftById(String id) => aircraftTypes.firstWhere((t) => t.id == id, orElse: () => aircraftTypes.first);

/// Les avions qui volent pour le Congo cette année-là.
List<AircraftType> fleetAt(double year) => [
  for (final t in aircraftTypes)
    if (t.fliesIn(year)) t,
];

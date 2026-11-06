import 'package:flutter/material.dart';

import '../theme/chacha_colors.dart';

/// Ce que porte la dérive de l'avion.
enum TailEmblem { none, star, zaire, flag, roundel }

/// Les drapeaux successifs du pays.
enum FlagStyle { star1960, diagonal1963, zaire1971, star1997, current2006 }

class Livery {
  const Livery({
    required this.body,
    required this.belly,
    required this.stripe,
    required this.stripe2,
    required this.tail,
    required this.emblem,
    this.nose,
    this.engine,
    this.fuselageFlag = false,
  });

  final Color body;
  final Color belly;
  final Color stripe;
  final Color stripe2;
  final Color tail;
  final TailEmblem emblem;

  /// Avant du fuselage peint d'une autre couleur, séparé par une diagonale rouge et jaune.
  final Color? nose;

  /// Couleur des capots moteurs (blancs par défaut).
  final Color? engine;

  /// Petit drapeau peint à l'arrière du fuselage.
  final bool fuselageFlag;
}

/// Une compagnie nationale et la période où elle vole.
///
/// Les livrées sont « inspirées » des couleurs de l'époque, sans logo réel : les vrais
/// logos des compagnies demandent une autorisation.
class AirlineEra {
  const AirlineEra(this.from, this.name, this.note, this.livery, {required this.flagship});

  final double from;

  /// L'avion que la compagnie fait voler en premier : l'avion du joueur change avec elle.
  final String flagship;
  final String name;
  final String note;
  final Livery livery;
}

const airlineEras = <AirlineEra>[
  AirlineEra(
    1960.0,
    'Sabena',
    "Avant Air Congo, c'est la compagnie belge qui relie le Congo au monde.",
    Livery(
      body: Color(0xFFF4F6FA),
      belly: Color(0xFFB9C3CF),
      stripe: Color(0xFF1F4E9C),
      stripe2: Color(0xFF1F4E9C),
      tail: Color(0xFF1F4E9C),
      emblem: TailEmblem.none,
    ),
    flagship: 'dc6',
  ),
  AirlineEra(
    1961.49,
    'Air Congo',
    'Air Congo naît et fait son premier vol le 29 juin 1961.',
    Livery(
      body: Color(0xFFF7F8FB),
      belly: Color(0xFFC9D1DB),
      stripe: ChachaColors.sky,
      stripe2: ChachaColors.yellow,
      tail: ChachaColors.sky,
      emblem: TailEmblem.star,
    ),
    flagship: 'dc6',
  ),
  AirlineEra(
    1971.82,
    'Air Zaïre',
    'Le pays devient le Zaïre : sa compagnie aussi.',
    Livery(
      body: Color(0xFFF7F8FB),
      belly: Color(0xFFC9D1DB),
      stripe: ChachaColors.zaireGreen,
      stripe2: ChachaColors.yellow,
      tail: ChachaColors.zaireGreen,
      emblem: TailEmblem.zaire,
    ),
    flagship: 'b707',
  ),
  AirlineEra(
    1995.45,
    'Compagnies privées',
    'Air Zaïre disparaît en 1995 : des compagnies privées prennent le relais.',
    Livery(
      body: Color(0xFFEEF0F3),
      belly: Color(0xFF9AA3AE),
      stripe: Color(0xFF59606B),
      stripe2: Color(0xFF8E96A1),
      tail: Color(0xFF59606B),
      emblem: TailEmblem.none,
    ),
    flagship: 'b737',
  ),
  AirlineEra(
    1997.4,
    'Lignes Aériennes Congolaises',
    'Après 1997, les LAC deviennent la compagnie nationale, jusqu\'en 2013.',
    Livery(
      body: Color(0xFFF7F8FB),
      belly: Color(0xFFC9D1DB),
      stripe: ChachaColors.sky,
      stripe2: ChachaColors.red,
      tail: ChachaColors.sky,
      emblem: TailEmblem.star,
    ),
    flagship: 'b737',
  ),
  AirlineEra(
    2013.5,
    'Compagnies privées',
    'Les LAC sont liquidées en 2013.',
    Livery(
      body: Color(0xFFEEF0F3),
      belly: Color(0xFF9AA3AE),
      stripe: Color(0xFF59606B),
      stripe2: Color(0xFF8E96A1),
      tail: Color(0xFF59606B),
      emblem: TailEmblem.none,
    ),
    flagship: 'b737',
  ),
  AirlineEra(
    2015.8,
    'Congo Airways',
    'Premier vol de Congo Airways le 20 octobre 2015.',
    Livery(
      body: Color(0xFFF7F8FB),
      belly: Color(0xFFC9D1DB),
      stripe: ChachaColors.red,
      stripe2: ChachaColors.yellow,
      tail: ChachaColors.sky,
      emblem: TailEmblem.flag,
    ),
    flagship: 'a320',
  ),
  // D'après la photo du Boeing 737-800 9S-AOA : avant bleu ciel, diagonale rouge et jaune,
  // moteurs bleus, dérive blanche avec un médaillon bleu, drapeau à l'arrière.
  // Le nom et le personnage du logo ne sont pas reproduits sans l'accord de la compagnie.
  AirlineEra(
    2024.92,
    'Air Congo',
    'Air Congo, la nouvelle compagnie nationale, décolle le 1er décembre 2024.',
    Livery(
      body: Color(0xFFF9FAFC),
      belly: Color(0xFFD5DCE5),
      stripe: Color(0x00000000),
      stripe2: Color(0x00000000),
      tail: Color(0xFFF4F6F9),
      emblem: TailEmblem.roundel,
      nose: Color(0xFF3FB6E8),
      engine: Color(0xFF3FB6E8),
      fuselageFlag: true,
    ),
    flagship: 'b737',
  ),
];

class FlagEra {
  const FlagEra(this.from, this.style, this.label);

  final double from;
  final FlagStyle style;
  final String label;
}

const flagEras = <FlagEra>[
  FlagEra(1960.0, FlagStyle.star1960, "Drapeau de l'Indépendance"),
  FlagEra(1963.0, FlagStyle.diagonal1963, 'Drapeau à la diagonale'),
  FlagEra(1971.89, FlagStyle.zaire1971, 'Drapeau du Zaïre'),
  FlagEra(1997.38, FlagStyle.star1997, "Retour du drapeau à l'étoile"),
  FlagEra(2006.13, FlagStyle.current2006, "Drapeau d'aujourd'hui"),
];

T _atYear<T>(List<T> eras, double Function(T) from, double year) {
  var current = eras.first;
  for (final e in eras) {
    if (from(e) <= year) current = e;
  }
  return current;
}

AirlineEra airlineAt(double year) => _atYear(airlineEras, (e) => e.from, year);

FlagEra flagAt(double year) => _atYear(flagEras, (e) => e.from, year);

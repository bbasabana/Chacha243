import 'package:flutter/material.dart';

import 'eras.dart';

/// Les avions des autres pays qui croisent le nôtre, et ce que se disent les pilotes.
///
/// Les livrées s'inspirent seulement des couleurs des compagnies, sans leurs logos.
/// Les échanges sont des blagues de jeu, pas de vraies communications radio.
class ForeignAirline {
  const ForeignAirline(this.name, this.from, this.livery, this.destinations, {this.to = 9999});

  final String name;

  /// Les années où la compagnie croise le Congo dans le jeu.
  final double from, to;
  final Livery livery;
  final List<String> destinations;
}

const _white = Color(0xFFF7F8FA), _belly = Color(0xFFC8CFD6);

const foreignAirlines = <ForeignAirline>[
  // Dérive blanche aux trois bandes vert, jaune, rouge.
  ForeignAirline(
    'Ethiopian',
    1960,
    Livery(
      body: _white,
      belly: _belly,
      stripe: Color(0xFFC8102E),
      stripe2: _white,
      tail: _white,
      emblem: TailEmblem.none,
      tailBands: [Color(0xFFD7262E), Color(0xFFF5C400), Color(0xFF1E8A3C)],
    ),
    ['Addis-Abeba', 'Lomé', 'Lagos'],
  ),
  // Dérive blanche aux bandes bleu, blanc, rouge.
  ForeignAirline(
    'Air France',
    1960,
    Livery(
      body: _white,
      belly: _belly,
      stripe: _white,
      stripe2: _white,
      tail: _white,
      emblem: TailEmblem.none,
      tailBands: [Color(0xFFD7262E), _white, Color(0xFF16307A), _white, Color(0xFF16307A)],
    ),
    ['Paris', 'Douala', 'Brazzaville'],
  ),
  ForeignAirline(
    'Sabena',
    1962,
    Livery(
      body: _white,
      belly: _belly,
      stripe: Color(0xFF1F4E9C),
      stripe2: Color(0xFF1F4E9C),
      tail: Color(0xFF1F4E9C),
      emblem: TailEmblem.disc,
    ),
    ['Bruxelles', 'Lusaka', 'Johannesburg'],
    to: 2001.8,
  ),
  // Dérive rouge, moteurs rouges, une bande verte et blanche en bas.
  ForeignAirline(
    'Kenya Airways',
    1977,
    Livery(
      body: _white,
      belly: _belly,
      stripe: Color(0xFFC8102E),
      stripe2: _white,
      tail: Color(0xFFC8102E),
      emblem: TailEmblem.none,
      engine: Color(0xFFC8102E),
      tailBands: [_white, Color(0xFF138A36), _white],
    ),
    ['Nairobi', 'Johannesburg', 'Mombasa'],
  ),
  ForeignAirline(
    'Royal Air Maroc',
    1990,
    Livery(
      body: _white,
      belly: _belly,
      stripe: Color(0xFFC1272D),
      stripe2: Color(0xFF006233),
      tail: Color(0xFFC1272D),
      emblem: TailEmblem.none,
    ),
    ['Casablanca', 'Dakar', 'Abidjan'],
  ),
  // Dérive bleu nuit semée de pastilles rouges.
  ForeignAirline(
    'Brussels Airlines',
    2007,
    Livery(
      body: _white,
      belly: _belly,
      stripe: _white,
      stripe2: _white,
      tail: Color(0xFF14285A),
      emblem: TailEmblem.none,
      tailDots: Color(0xFFE2342E),
    ),
    ['Bruxelles', 'Entebbe', 'Luanda'],
  ),
  // Dérive rouge avec un disque blanc.
  ForeignAirline(
    'Turkish Airlines',
    2012,
    Livery(
      body: _white,
      belly: _belly,
      stripe: _white,
      stripe2: _white,
      tail: Color(0xFFC70A0C),
      emblem: TailEmblem.disc,
    ),
    ['Istanbul', 'Douala', 'Entebbe'],
  ),
];

/// Un échange entre leur pilote (à la radio) et notre commandant (dans la cabine).
class PilotBanter {
  const PilotBanter(this.theirLingala, this.theirs, this.oursLingala, this.ours);

  final String theirLingala;
  final String theirs;
  final String oursLingala;
  final String ours;
}

const pilotBanter = <PilotBanter>[
  PilotBanter(
    'Mbote, Congo !',
    'Bonjour Congo ! Votre avion fait trop de bruit là-bas !',
    'Tozali Bakongomani !',
    'On est Congolais, on parle toujours beaucoup : c\'est notre ADN. Bon voyage !',
  ),
  PilotBanter(
    'Mbote, ndeko !',
    'Salut l\'ami ! Vous avez de la rumba à bord ?',
    'Ntango nyonso !',
    'Toujours ! La cabine fait déjà l\'ambiance. Bon vol vers {to} !',
  ),
  PilotBanter(
    'Eh, Congo !',
    'On sent l\'odeur du pondu jusqu\'à notre cockpit !',
    'Boya kolia na Kinshasa !',
    'Venez manger à Kinshasa, il y en a pour tout le monde !',
  ),
  PilotBanter(
    'Bozali kokende wapi ?',
    'Vous allez où si vite, Congo ?',
    'Tozali kolanda lisolo ya mboka.',
    'On suit l\'histoire du pays, mon frère. Bon voyage vers {to} !',
  ),
  PilotBanter(
    'Mbote !',
    'On vous entend chanter depuis notre avion !',
    'Ezali kabine, bazali kobina !',
    'C\'est la cabine, ils dansent ! Tokende !',
  ),
  PilotBanter(
    'Keba, ndeko.',
    'Attention, il y a des orages plus loin.',
    'Matondo mingi !',
    'Merci beaucoup ! Bon vol vers {to}.',
  ),
  PilotBanter(
    'Congo, mbote !',
    'Votre pilote danse ? Vos ailes bougent dans tous les sens !',
    'Ezali ndombolo ya likolo !',
    'C\'est le ndombolo des airs ! Bon voyage !',
  ),
  PilotBanter(
    'Mbote, Kinshasa !',
    'Vous nous gardez une place pour le 30 juin ?',
    'Bino nyonso boyei !',
    'Venez tous, la fête sera grande ! Bon vol vers {to}.',
  ),
];

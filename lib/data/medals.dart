import 'package:flutter/material.dart';

/// La médaille d'un pilote, selon jusqu'où il a volé (les mêmes seuils que le tableau de bord).
class Medal {
  const Medal(this.name, this.color, this.from);

  final String name;
  final Color color;

  /// L'année à atteindre ; Diamant demande d'arriver à Kinshasa en 2027.
  final int from;
}

const medals = <Medal>[
  Medal('Bronze', Color(0xFFC98A4B), 1970),
  Medal('Argent', Color(0xFFAEB6C2), 1990),
  Medal('Or', Color(0xFFF2C230), 2005),
  Medal('Platine', Color(0xFFC9D3E6), 2020),
  Medal('Diamant', Color(0xFF5AD7FF), 2027),
];

/// Sa médaille, ou null tant que le pilote n'a pas atteint 1970.
Medal? medalFor(double bestYear, int wins) {
  if (wins > 0) return medals.last;
  Medal? m;
  for (final x in medals.take(medals.length - 1)) {
    if (bestYear >= x.from) m = x;
  }
  return m;
}

/// La médaille suivante et l'année qui la donne.
Medal? nextMedal(double bestYear, int wins) {
  if (wins > 0) return null;
  for (final x in medals) {
    if (bestYear < x.from || x == medals.last) return x;
  }
  return null;
}

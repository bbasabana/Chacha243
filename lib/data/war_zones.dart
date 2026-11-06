/// Les zones de turbulence : les années de guerre se traversent vague après vague.
///
/// Dans une zone, le temps n'avance qu'avec les vagues passées : des avions de chasse noirs
/// arrivent, un, puis deux, puis trois… Après la dernière vague, une étape de paix.
/// Les avions de guerre restent abstraits : pas d'insignes, pas de tirs, aucun camp désigné.
///
/// Les textes en lingala sont à faire valider par des locuteurs avant la sortie.
class WarZone {
  const WarZone({
    required this.from,
    required this.to,
    required this.name,
    required this.place,
    required this.waves,
    required this.peaceTitle,
    required this.peaceText,
  });

  /// L'année d'entrée et l'année de sortie (années décimales).
  final double from, to;
  final String name;
  final String place;

  /// Nombre de vagues ; la vague n envoie n avions de chasse.
  final int waves;

  /// L'étape qui suit : paix, réconciliation qui continue.
  final String peaceTitle;
  final String peaceText;

  bool contains(double year) => year >= from && year < to;
}

const warZones = <WarZone>[
  WarZone(
    from: 1960.53,
    to: 1963.05,
    name: 'Sécession du Katanga',
    place: 'Katanga, Sud-Kasaï',
    waves: 3,
    peaceTitle: 'Le pays se réunit',
    peaceText: 'Janvier 1963 : la sécession du Katanga prend fin.',
  ),
  WarZone(
    from: 1964.5,
    to: 1965.3,
    name: 'Rébellions',
    place: "L'Est et le centre",
    waves: 3,
    peaceTitle: 'Le calme revient',
    peaceText: "En 1965, les rébellions s'éteignent.",
  ),
  WarZone(
    from: 1977.2,
    to: 1978.5,
    name: 'Guerres du Shaba',
    place: 'Katanga, Kolwezi',
    waves: 3,
    peaceTitle: 'Kolwezi respire',
    peaceText: 'En 1978, les combats du Shaba prennent fin.',
  ),
  WarZone(
    from: 1996.8,
    to: 1997.38,
    name: "Guerre de l'AFDL",
    place: "De l'Est à Kinshasa",
    waves: 4,
    peaceTitle: 'Une nouvelle page',
    peaceText: "Mai 1997 : la guerre s'arrête, le Zaïre redevient le Congo.",
  ),
  WarZone(
    from: 1998.6,
    to: 2003.3,
    name: 'Deuxième guerre du Congo',
    place: "L'Est, puis tout le pays",
    waves: 6,
    peaceTitle: 'La réconciliation',
    peaceText: 'Les accords de paix de 2002 et 2003 ouvrent une transition qui réunit le pays.',
  ),
  WarZone(
    from: 2012.88,
    to: 2013.85,
    name: 'Le M23 à Goma',
    place: 'Nord-Kivu',
    waves: 4,
    peaceTitle: 'Goma respire',
    peaceText: 'Fin 2013, le M23 dépose les armes.',
  ),
  WarZone(
    from: 2021.9,
    to: 2025.45,
    name: 'Retour du M23',
    place: 'Nord-Kivu, Sud-Kivu',
    waves: 6,
    peaceTitle: "L'espoir revient",
    peaceText: 'Juin 2025 : un accord de paix est signé. La réconciliation continue.',
  ),
];

/// Les phrases en lingala du jeu, toujours avec leur traduction.
///
/// À faire valider par des locuteurs avant la sortie.
abstract final class Lingala {
  /// « Allons-y ! »
  static const tokende = 'Tokende !';

  /// « Bonjour ! », la tour de contrôle qui répond.
  static const mbote = 'Mbote !';

  /// « Attention ! Le désordre est devant », à l'entrée d'une zone.
  static const keba = 'Keba ! Mobulu ezali liboso';

  /// « La paix est revenue », à la sortie d'une zone.
  static const kimia = 'Kimia ezongi';

  /// « Courage ! », entre deux vagues.
  static const makasi = 'Makasi !';

  /// « Le carburant va finir. »
  static const mafuta = 'Mafuta ezali kosila';

  /// « Descends doucement. »
  static const kitaMalembe = 'Kita malembe';

  /// « Patiente un peu. »
  static const zelaMoke = 'Zela moke';

  /// « Merci. »
  static const matondo = 'Matondo !';

  /// « Victoire ! »
  static const elonga = 'Elonga !';

  /// « Attachez les ceintures ! »
  static const mikaba = 'Bokanga mikaba !';

  /// « Mangeons ! », l'heure du repas.
  static const tolia = 'Toliya !';

  /// « Indépendance ! », comme dans la chanson.
  static const dipanda = 'Dipanda !';
}

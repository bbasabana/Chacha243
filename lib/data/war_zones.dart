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
    this.part,
    this.chapters = const [],
    this.intro,
    this.fierce = false,
  });

  /// Les étapes de l'histoire racontées entre les vagues (la médiation, le refus…).
  final List<WarChapter> chapters;

  /// Pourquoi cette guerre commence, lu à l'entrée de la zone (sinon : sa date et son lieu).
  final String? intro;

  /// Une guerre plus dure : des missiles dès la deuxième vague, et plus nombreux.
  final bool fierce;

  /// Une crise dans la crise (le Sud-Kasaï dans la sécession du Katanga) : ses avions ont leurs couleurs,
  /// et elle s'arrête quand toutes ses vagues sont passées.
  final ZonePart? part;

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

/// Une étape racontée au milieu d'une guerre, quand [after] vagues sont passées : le jeu s'arrête,
/// on lit (« Boyebi ke… », savez-vous que…), puis les avions reviennent.
class WarChapter {
  const WarChapter({
    required this.after,
    required this.date,
    required this.title,
    required this.text,
    this.photo,
    this.face,
  });

  final int after;
  final String date, title, text;

  /// La photo (clé de archivePhotos) et le nom écrit dessous.
  final String? photo, face;
}

class ZonePart {
  const ZonePart({required this.name, required this.place, required this.from, required this.to, required this.end});

  final String name, place;

  /// Ses vagues, de [from] à [to] (comptées depuis 1).
  final int from, to;
  final String end;
}

const warZones = <WarZone>[
  WarZone(
    from: 1960.53,
    to: 1963.05,
    name: 'Sécession du Katanga',
    place: 'Katanga, Sud-Kasaï',
    waves: 3,
    part: ZonePart(
      name: 'Sécession du Sud-Kasaï',
      place: 'Bakwanga (Mbuji-Mayi)',
      from: 4,
      to: 7,
      end: 'Octobre 1962 : le Sud-Kasaï revient dans le pays.',
    ),
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
    place: "De l'est du Congo jusqu'à Kinshasa",
    waves: 4,
    fierce: true,
    peaceTitle: 'Une nouvelle page',
    peaceText:
        "Le 16 mai 1997, Mobutu quitte Kinshasa pour Gbadolite, puis l'exil. Le 17 mai, l'AFDL entre dans la capitale : "
        'le Zaïre redevient le Congo.',
    chapters: [
      WarChapter(
        after: 3,
        date: 'novembre 1996',
        title: 'La communauté internationale intervient',
        text:
            "Des centaines de milliers de réfugiés fuient les combats dans l'Est. Le 15 novembre 1996, le Conseil de sécurité "
            "de l'ONU vote la résolution 1080 pour une force multinationale humanitaire. L'ONU, l'OUA, les États-Unis "
            "et l'Afrique du Sud cherchent à arrêter la guerre.",
      ),
      WarChapter(
        after: 5,
        date: 'début 1997',
        title: 'Mandela, le médiateur',
        text:
            "L'ONU et l'OUA comptent sur Nelson Mandela, le président de l'Afrique du Sud. Avec son vice-président "
            'Thabo Mbeki, il accepte de servir de médiateur entre Mobutu et Laurent-Désiré Kabila.',
        photo: 'mandela',
        face: 'Nelson Mandela',
      ),
      WarChapter(
        after: 7,
        date: '4 mai 1997',
        title: "Rencontre sur l'Outeniqua",
        text:
            "Au large de Pointe-Noire, Mandela réunit Mobutu, déjà malade, et Kabila sur le navire sud-africain Outeniqua. "
            'Il veut que Mobutu quitte le pouvoir sans bataille pour Kinshasa.',
        photo: 'outeniqua',
        face: 'Mandela · 1997',
      ),
      WarChapter(
        after: 9,
        date: 'mai 1997',
        title: 'Mobutu refuse : la guerre continue',
        text:
            'Mobutu ne veut pas céder le pouvoir, et la seconde rencontre, prévue le 14 mai, n\'a pas lieu. '
            "L'AFDL reprend sa marche vers Kinshasa : tiens bon, ce sont les derniers combats.",
      ),
    ],
  ),
  WarZone(
    from: 1998.6,
    to: 2003.3,
    name: 'Deuxième guerre du Congo',
    place: "L'Est, puis tout le pays",
    waves: 6,
    intro:
        "Mzee a renvoyé les soldats rwandais et ougandais qui l'avaient porté au pouvoir. Repliés à l'Est, "
        'ils reviennent à l\'attaque avec une rébellion, le RCD ; au nord, Jean-Pierre Bemba et son MLC entrent aussi en guerre.',
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
  /// « Tu es touché ! Tu ne sais pas porter un avion ! Tu es un faux pilote. »
  static const ozui = 'Ozui ! Oyebi ko mema PEPO te ! Oza faux pilo pilo';

  /// « Si tu es fatigué, demain on change de pilote. »
  static const olembi = 'Soki olembi, lobi to changer pilo pilo';

  /// « Ta vie est comme cette guerre : cherche Dieu. »
  static const lukaNzambe = 'Vie na yo eza lokola guerre oyo. Luka Nzambe';

  /// Une pique par crash, à tour de rôle.
  static const crashes = [ozui, olembi, lukaNzambe];

  /// « Pilote, attention aux missiles ! Sois vigilant. »
  static const kebaMissile = 'Pilo pilo keba ba missile ! Zala ngele';

  /// « Eh maman, j'ai fait tuer des gens ! »
  static const mamaNaNga = 'Ehh mama na nga, na bomisi batu !';

  /// « Dieu, donne-moi la force de gagner ce combat. »
  static const nzambePesa = 'Nzambe, pesa nga makasi na longa etumba oyo';

  /// « Pilote, sois vigilant… », donné par l'auteur (la traduction complète reste à écrire).
  static const ekenge = 'Pilo pilo zala ekenge ndeti Mungala';

  /// Touché une fois, deux fois, trois fois… : le pilote ne dit pas la même chose.
  static const hits = [kebaMissile, ekenge, mamaNaNga, nzambePesa];

  /// « Savez-vous que… », avant un moment d'histoire (les mots du concepteur).
  static const boyebiKe = 'BOYEBI KE';

  /// « Tu as fait tomber un passager. Quel genre de pilote es-tu ? »
  static const okweyisi = 'Okweyisi passager. Yango ozali pilo pilo ya ndenge nini ?';

  /// « Allons-y ! »
  static const tokende = 'To kende !';

  /// « Aujourd'hui, les passagers ne mangeront pas. »
  static const bokoliate = 'Lelo ba passagers bako lia teeee !';

  /// « Encore une guerre ! Mon Dieu. »
  static const guerreLisusu = 'Guerre lisusu ! Nzambe na nga';

  /// « Ça va encore détruire le pays. »
  static const bomaMboka = 'Oyo eza ko boma lisusu mboka';

  /// « Le peuple est fatigué de Mobutu. »
  static const lembiMobutu = 'Peuple a lembi pe Mobutu';

  /// « Bonjour ! », la tour de contrôle qui répond.
  static const mbote = 'Mbote !';

  /// « Attention ! Le désordre est devant », à l'entrée d'une zone.
  static const keba = 'Keba ! Mobulu ezali liboso';

  /// « La paix est revenue », à la sortie d'une zone.
  static const kimia = 'Kimia ezongi';

  /// « Courage ! », entre deux vagues.
  static const makasi = 'Makasi !';

  /// « Le kérosène va finir. »
  static const mafuta = 'Kerozene ezali ya ko sila';

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

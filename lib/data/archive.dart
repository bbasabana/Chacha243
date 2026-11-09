/// Les photos d'archives : petites vignettes dans les fiches d'histoire.
///
/// Une photo ne s'affiche dans l'application publiée que si ses droits sont réglés
/// ([cleared]) ; en développement, toutes s'affichent pour juger de la mise en page.
class ArchivePhoto {
  const ArchivePhoto(
    this.file,
    this.caption, {
    this.credit = 'Source à confirmer',
    this.cleared = false,
    this.wide = false,
  });

  final String file;
  final String caption;
  final String credit;
  final bool cleared;

  /// Un bâtiment ou un logo : il se montre en rectangle, pas dans un rond de visage.
  final bool wide;

  String get asset => file.contains('/') ? 'assets/$file' : 'assets/photos/$file';

  /// Les photos et les billets sont gardés en local par l'auteur : quand un fichier manque,
  /// rien ne s'affiche à sa place.
  bool get visible => true;

  /// Un billet se montre en rectangle ; un visage, dans un rond.
  bool get isNote => file.startsWith('notes/');

  /// Un portrait de personne, qu'on peut mettre dans un médaillon.
  bool get isPortrait => !isNote && !wide && !file.startsWith('logo');
}

const archivePhotos = <String, ArchivePhoto>{
  'tshombe': ArchivePhoto('moise-tshombe.jpg', 'Moïse Tshombe'),
  'mobutu': ArchivePhoto('mobutu-au-pouvoir.jpg', 'Mobutu Sese Seko'),
  'afdl': ArchivePhoto('kabila-afdl-troupes.jpg', 'Laurent-Désiré Kabila passe ses troupes en revue'),
  'est': ArchivePhoto(
    'militaires-est-goma.jpg',
    'Des militaires dans l\'Est du Congo',
    credit: 'Hugh Kinsella Cunningham / Getty Images',
  ),
  'emotion': ArchivePhoto('mobutu-emotion-1990.jpg', 'Mobutu, ému, le 24 avril 1990'),
  'mobututoque': ArchivePhoto('mobutu-toque.jpg', 'Mobutu Sese Seko et sa toque de léopard'),
  'zaire': ArchivePhoto(
    'drapeau-zaire.jpg',
    'Le drapeau du Zaïre : la main et la torche',
    credit: 'République du Zaïre',
  ),
  'mpr': ArchivePhoto('logo-mpr.jpg', 'Le Mouvement populaire de la révolution', credit: 'MPR'),
  'leopards': ArchivePhoto('leopards-1974.jpg', 'Les Léopards du Zaïre, champions d\'Afrique 1974'),
  'carte': ArchivePhoto(
    'carte-citoyen-zaire.jpg',
    'La carte d\'identité pour citoyen, République du Zaïre',
    credit: 'République du Zaïre',
  ),
  'papawemba': ArchivePhoto('papa-wemba-2016.jpg', 'Papa Wemba, le roi de la Sape, sur scène'),
  'koffi': ArchivePhoto('koffi-olomide.jpg', 'Koffi Olomidé, « le Grand Mopao »'),
  'kester': ArchivePhoto('king-kester-emeneya.jpg', 'King Kester Emeneya'),
  'wenge': ArchivePhoto('wenge-musica.jpg', 'Wenge Musica, l\'orchestre de la jeunesse kinoise'),
  'jeanpaul2': ArchivePhoto('jean-paul-ii-zaire.jpg', 'Le pape Jean-Paul II reçu par Mobutu au Zaïre'),
  'francois': ArchivePhoto(
    'pape-francois-kinshasa-2023.jpg',
    'Le pape François et la jeunesse au stade des Martyrs, 2 février 2023',
  ),
  'aliforeman': ArchivePhoto('ali-foreman-1974.jpg', 'Mohamed Ali frappe George Foreman, Kinshasa, 30 octobre 1974'),
  'ali': ArchivePhoto('mobutu-ali-1974.jpg', 'Mobutu et Mohamed Ali, Kinshasa, 1974'),
  'abala': ArchivePhoto('ayidini-abala.jpg', 'Le pasteur Ayidini Abala'),
  'ldk': ArchivePhoto('laurent-desire-kabila.jpg', 'Laurent-Désiré Kabila'),
  'ldkserment': ArchivePhoto('serment-ldk-1997.jpg', 'Laurent-Désiré Kabila prête serment, 29 mai 1997'),
  'bembamlc': ArchivePhoto('bemba-mlc.jpg', 'Jean-Pierre Bemba, chef du MLC'),
  'franco': ArchivePhoto('franco-luambo.jpg', 'Franco Luambo Makiadi, le « Grand Maître »'),
  'cercueil': ArchivePhoto(
    'cercueil-mzee-2001.jpg',
    'Le cercueil de Mzee, et Joseph Kabila derrière lui, janvier 2001',
  ),
  'kapend': ArchivePhoto('eddy-kapend-2003.jpg', 'Le colonel Eddy Kapend perd ses insignes, 7 janvier 2003'),
  'obseques': ArchivePhoto('obseques-mzee-2001.jpg', 'Les obsèques de Mzee Laurent-Désiré Kabila, janvier 2001'),
  'serment': ArchivePhoto('serment-joseph-kabila-2001.jpg', 'Joseph Kabila prête serment, 26 janvier 2001'),
  'jkabila': ArchivePhoto('joseph-kabila.jpg', 'Joseph Kabila'),
  'tshisekedi': ArchivePhoto('felix-tshisekedi.jpg', 'Félix Tshisekedi'),
  'nyiragongo': ArchivePhoto('nyiragongo-goma.jpg', 'Le Nyiragongo au-dessus de Goma'),
  'gecamines': ArchivePhoto('gecamines-terril.jpg', 'Le terril de la Gécamines, Lubumbashi'),
  'outeniqua': ArchivePhoto('outeniqua-1997.jpg', 'Mobutu, Mandela et Kabila sur l\'Outeniqua, 1997'),
  'wagenia': ArchivePhoto('wagenia-kisangani.jpg', 'Les pêcheurs Wagenia, Kisangani'),
  'lumumba': ArchivePhoto('patrice-lumumba.jpg', 'Patrice Emery Lumumba'),
  'secessions': ArchivePhoto('secession-katanga-kasai.jpg', 'Moïse Tshombe (Katanga) et Albert Kalonji (Sud-Kasaï)'),
  'kasavubu': ArchivePhoto('joseph-kasa-vubu.jpg', 'Joseph Kasa-Vubu'),
  'kalle': ArchivePhoto('grand-kalle.webp', 'Grand Kallé, auteur d\'« Indépendance Cha Cha »'),
  'mulele': ArchivePhoto('pierre-mulele.jpg', 'Pierre Mulele'),
  'etienne': ArchivePhoto('etienne-tshisekedi.jpg', 'Étienne Tshisekedi'),
  'bemba': ArchivePhoto('jean-pierre-bemba.jpg', 'Jean-Pierre Bemba'),
  'kamerhe': ArchivePhoto('vital-kamerhe.jpg', 'Vital Kamerhe'),
  'unplusquatre': ArchivePhoto('un-plus-quatre.jpg', 'Le « 1 + 4 » : Joseph Kabila et ses quatre vice-présidents'),
  'gizenga': ArchivePhoto('antoine-gizenga.jpg', 'Antoine Gizenga'),
  'mukwege': ArchivePhoto('denis-mukwege.jpg', 'Le Dr Denis Mukwege à Panzi'),
  'marche2016': ArchivePhoto('marche-opposition-2016.jpg', 'La marche de l\'opposition, Kinshasa, septembre 2016'),
  'conclave': ArchivePhoto(
    'opposition-conclave-2018.jpg',
    'Les leaders de l\'opposition réunis pour choisir un candidat commun, novembre 2018',
  ),
  'cach': ArchivePhoto('cach-kamerhe-tshisekedi-2018.jpg', 'Vital Kamerhe et Félix Tshisekedi, le « Cach »'),
  'dokolo': ArchivePhoto('sindika-dokolo.jpg', 'Sindika Dokolo'),
  'elections2018': ArchivePhoto('elections-2018.jpg', 'Les élections du 30 décembre 2018'),
  'serment2019': ArchivePhoto('serment-felix-tshisekedi-2019.jpg', 'Félix Tshisekedi prête serment, 24 janvier 2019'),
  'passation': ArchivePhoto(
    'passation-kabila-tshisekedi-2019.jpg',
    'Joseph Kabila et Félix Tshisekedi : la passation du pouvoir, 24 janvier 2019',
  ),
  'afc': ArchivePhoto('afc-nangaa.jpg', 'Corneille Nangaa, à la tête de l\'AFC'),
  'frn': ArchivePhoto('joseph-kabila-2027.jpg', 'Joseph Kabila'),
  'suminwa': ArchivePhoto('judith-suminwa-2024.jpg', 'Judith Suminwa Tuluka, première femme Première ministre'),
  'serment2024': ArchivePhoto('serment-tshisekedi-2024-a.jpg', 'Félix Tshisekedi prête serment, 20 janvier 2024'),
  'serment2024b': ArchivePhoto('serment-tshisekedi-2024-b.jpg', 'Félix Tshisekedi à la tribune, stade des Martyrs'),
  'servicenational': ArchivePhoto('service-national-2024.jpg', 'Un officier du Service national'),
  'mutamba': ArchivePhoto('constant-mutamba.jpg', 'Constant Mutamba, ancien ministre de la Justice'),
  // Logos et billets : marques et signes monétaires, à n'afficher qu'avec l'accord de la banque.
  'bcc': ArchivePhoto(
    'banque-centrale-immeuble.jpg',
    'Le siège de la Banque centrale du Congo',
    credit: 'BCC',
    wide: true,
  ),
  'bcdc': ArchivePhoto('logo-banque-commerciale.png', 'Banque commerciale du Congo', credit: 'Logo BCDC', wide: true),
  'mamayemo': ArchivePhoto(
    'hopital-mama-yemo.jpg',
    'L\'Hôpital général de Kinshasa, ancien Mama Yemo',
    credit: 'CHU Renaissance',
    wide: true,
  ),
  'stade': ArchivePhoto(
    'stade-des-martyrs.jpg',
    'Le stade des Martyrs, ancien stade Kamanyola',
    credit: 'Stade des Martyrs',
    wide: true,
  ),
  'pontmarechal': ArchivePhoto(
    'pont-marechal-matadi.jpg',
    'Le pont Maréchal sur le fleuve Congo, à Matadi',
    credit: 'Pont Maréchal',
    wide: true,
  ),
  'kamanyola': ArchivePhoto(
    'monument-kamanyola.jpg',
    'Le monument de Kamanyola, en mémoire de la bataille de 1964',
    credit: 'Monument de Kamanyola',
    wide: true,
  ),
  'hewabora': ArchivePhoto(
    'hewa-bora-tristar.jpg',
    'Un TriStar de Hewa Bora Airways (HBA), immatriculé 9Q-CHC',
    credit: 'Hewa Bora Airways',
    wide: true,
  ),
  'lac767': ArchivePhoto(
    'lac-boeing-767.jpg',
    'Un Boeing 767 aux couleurs des Lignes Aériennes Congolaises (LAC)',
    credit: 'Lignes Aériennes Congolaises',
    wide: true,
  ),
  'washington': ArchivePhoto(
    'accord-washington-2025.jpg',
    'Félix Tshisekedi, Donald Trump et Paul Kagame à la Maison-Blanche',
    credit: 'Accords de Washington',
    wide: true,
  ),
  'julianalumumba': ArchivePhoto('juliana-lumumba.jpg', 'Juliana Lumumba, candidate de la RDC à la Francophonie'),
  'equity': ArchivePhoto('logo-equity-bcdc.png', 'Equity BCDC', credit: 'Logo Equity BCDC', wide: true),
  'fally2006': ArchivePhoto('fally-ipupa-2006.jpg', 'Fally Ipupa, « Droit chemin », 2006'),
  'fallysdf': ArchivePhoto('fally-stade-de-france-2026.jpg', 'Fally Ipupa au Stade de France, 2 et 3 mai 2026'),
  'fallychevalier': ArchivePhoto('fally-chevalier-2026.jpg', 'Fally Ipupa reçoit les insignes de chevalier du Léopard'),
  'president': ArchivePhoto('tshisekedi-president.jpg', 'Félix Tshisekedi, président de la République'),
  'billet1f': ArchivePhoto('notes/billet-1-franc-1997.jpg', 'Billet de 1 franc congolais', credit: 'BCC, 1997'),
  'billet1z': ArchivePhoto('notes/billet-1-zaire-1977.jpg', 'Billet de 1 zaïre', credit: 'Banque du Zaïre, 1977'),
  'billetnz': ArchivePhoto(
    'notes/billet-1-nouveau-zaire-1993.jpg',
    'Billet de 1 nouveau zaïre',
    credit: 'Banque du Zaïre, 1993',
  ),
};

/// Les billets du jour : le plus récent déjà émis s'affiche, tout petit, pour payer.
class Banknote {
  const Banknote(this.value, this.from, this.file);

  final int value;
  final double from;
  final String file;

  String get asset => 'assets/notes/$file';
}

const banknotes = <Banknote>[
  Banknote(500, 2013.5, 'billet-500-francs-2013.jpg'),
  Banknote(5000, 2013.5, 'billet-5000-francs-2013.jpg'),
  Banknote(1000, 2020.5, 'billet-1000-francs-2020.jpg'),
  Banknote(20000, 2022.01, 'billet-20000-francs-2022.jpg'),
];

/// Le billet qui paie [amount] cette année-là (le plus petit qui suffit, sinon le plus grand), ou null.
Banknote? noteFor(int amount, double year) {
  final out = [
    for (final b in banknotes)
      if (b.from <= year) b,
  ]..sort((a, b) => a.value.compareTo(b.value));
  if (out.isEmpty) return null;
  return out.firstWhere((b) => b.value >= amount, orElse: () => out.last);
}

/// Le nom de la monnaie en toutes lettres, sous le montant.
String currencyName(String code) => switch (code) {
  'F' => 'francs',
  'Z' => 'zaïres',
  'NZ' => 'nouveaux zaïres',
  _ => 'francs congolais',
};

/// La monnaie de l'époque : franc, zaïre, nouveau zaïre, puis franc congolais.
String currencyAt(double year) => year < 1967.48
    ? 'F'
    : year < 1993.8
    ? 'Z'
    : year < 1998.49
    ? 'NZ'
    : 'FC';

/// Les cartes postales des escales : une petite photo à l'atterrissage dans certaines villes.
const airportPostcards = <String, (String, String)>{
  'Kisangani': ('wagenia', 'Aux chutes Wagenia, les pêcheurs tendent leurs nasses dans le courant du fleuve.'),
  'Lubumbashi': ('gecamines', 'Le terril de la Gécamines domine la ville du cuivre.'),
};

/// Le repas à bord : un accompagnement, un plat, une boisson.
const mealBases = ['Fufu', 'Chikwangue', 'Loso (riz)'];
const mealDishes = [
  'Madesu',
  'Fumbwa',
  'Pondu',
  'Makayabu (poisson salé)',
  'Poisson grillé',
  'Poulet mayo',
  'Dindon',
  'Ntaba',
  'Liboke',
];
const mealBeers = ['Primus', 'Turbo King', 'Castel', 'Heineken', 'Nkoyi', 'Tembo'];
const mealSodas = ['Eau', 'Vitalo', 'Bavaria', 'Fanta', 'Coca-Cola'];
const mealSpirits = ['Amarula', 'Chivas', 'Red Label', 'Jameson'];

/// Les photos du menu (assets/meals).
const mealPhotos = <String, String>{
  'Fufu': 'fufu.jpg',
  'Chikwangue': 'chikwangue.jpg',
  'Loso (riz)': 'loso.jpg',
  'Madesu': 'madesu.jpg',
  'Fumbwa': 'fumbwa.jpg',
  'Pondu': 'pondu.jpg',
  'Makayabu (poisson salé)': 'makayabu.jpg',
  'Poisson grillé': 'poisson.jpg',
  'Poulet mayo': 'poulet.jpg',
  'Dindon': 'dindon.jpg',
  'Ntaba': 'ntaba.jpg',
  'Liboke': 'liboke.jpg',
  'Eau': 'eau.jpg',
  'Vitalo': 'vitalo.jpg',
  'Bavaria': 'bavaria.jpg',
  'Primus': 'primus.jpg',
  'Turbo King': 'turbo.jpg',
  'Castel': 'castel.jpg',
  'Heineken': 'heineken.jpg',
  'Nkoyi': 'nkoyi.jpg',
  'Tembo': 'tembo.jpg',
  'Fanta': 'fanta.jpg',
  'Coca-Cola': 'coca.jpg',
  'Amarula': 'amarula.jpg',
  'Chivas': 'chivas.jpg',
  'Red Label': 'redlabel.jpg',
  'Jameson': 'jameson.jpg',
};

const mealPhotoCredits =
    "Tshaka Madesu (Beans ＆ cassava leaves stew), OussamaHamama (CC BY-SA 4.0) · Bière Nkoyi, Serein (CC BY-SA 3.0) · Tembo- Congolese local beer, Rahul Tilak (CC BY-SA 4.0) · Fanta Orange Glass Bottle, Ayakln (CC BY-SA 4.0) · Coca-Cola glass bottle, Oleg Yunakov (CC BY-SA 4.0) · Chivas regal 12yo, Keeezawa (CC BY-SA 4.0) · Johnnie Walker Red Label, kallerna (CC BY-SA 3.0) · Jameson Irish Whiskey, Datenralfi (CC BY-SA 3.0 de)";

/// Le prix d'un verre : les liqueurs rapportent plus que les sucrés.
int drinkPrice(String drink) => mealSpirits.contains(drink) ? 60 : (mealBeers.contains(drink) ? 25 : 15);

/// Les chansons des moments : le jeu joue le fichier s'il est dans assets/audio,
/// une fois les droits obtenus. Sans fichier, le moment reste silencieux.
///
/// En vol, on n'entend qu'un extrait : la chanson part de [start], monte en douceur
/// pendant [fadeIn] jusqu'à [level] (une part du volume réglé), dure [seconds],
/// puis s'éteint en fondu. Entre deux chansons, le silence laisse le vol au calme.
class MomentSong {
  const MomentSong(
    this.file,
    this.title,
    this.artist, {
    this.start = 0,
    this.seconds = 40,
    this.level = 0.75,
    this.fadeIn = 1.5,
    this.then,
  });

  final String file;
  final String title;
  final String artist;

  /// Où commence l'extrait dans le fichier, en secondes (le refrain, par exemple).
  final double start;

  /// La durée de l'extrait en vol, fondu de fin compris.
  final double seconds;

  /// Le volume de la chanson, de 0 à 1 : une chanson ne couvre jamais le vol.
  final double level;

  /// La montée du début, en secondes.
  final double fadeIn;

  /// La chanson qui suit l'extrait sans silence (clé de momentSongs), ou null.
  final String? then;
}

const momentSongs = <String, MomentSong>{
  'chacha': MomentSong(
    'independance-cha-cha.mp3',
    'Indépendance Cha Cha',
    'Grand Kallé et l\'African Jazz',
    seconds: 50,
  ),
  // Quand rien d'autre ne joue : la chanson presque entière, doucement, sous le vol.
  'fond': MomentSong(
    'independance-cha-cha.mp3',
    'Indépendance Cha Cha',
    'Grand Kallé et l\'African Jazz',
    seconds: 180,
    level: 0.4,
    fadeIn: 3,
  ),
  // L'hymne du Zaïre : un court extrait, et la chanson du MPR prend la suite sans silence.
  'hymne': MomentSong(
    'zaire-hymne.mp3',
    'La Zaïroise',
    'Hymne national du Zaïre',
    seconds: 46,
    level: 0.6,
    fadeIn: 1,
    then: 'mpr',
  ),
  'congo': MomentSong(
    'congo-hymne.mp3',
    'Debout Congolais',
    'Hymne national de la RDC',
    seconds: 85,
    level: 0.6,
    fadeIn: 1,
  ),
  // Les tam-tams, les harpes et la forêt remplacent les chansons d'artistes ; les moments de joie restent à Indépendance Cha Cha.
  // Le retour du M23, à partir de 2022 : on entre dans le noir de la forêt.
  'm23': MomentSong('afrique/jungle-noire.mp3', 'Dans le noir', 'Chacha 243', seconds: 90, level: 0.6, fadeIn: 6),
  // La guerre finie : les tam-tams se réveillent, puis Indépendance Cha Cha prend la suite.
  'victoire': MomentSong(
    'afrique/reveil-tam-tams.mp3',
    'Le réveil des tam-tams',
    'Chacha 243',
    start: 22,
    seconds: 38,
    level: 0.6,
    fadeIn: 2,
    then: 'fond',
  ),
  // En vol : les tam-tams relaient Indépendance Cha Cha.
  'vol1': MomentSong(
    'afrique/tam-tam-village.mp3',
    'Tam-tams de la route',
    'Chacha 243',
    seconds: 74,
    level: 0.55,
    fadeIn: 2,
  ),
  'vol2': MomentSong(
    'afrique/harpe-foret.mp3',
    'Au cœur de la jungle',
    'Chacha 243',
    seconds: 80,
    level: 0.55,
    fadeIn: 2,
  ),
  'mpr': MomentSong(
    'afrique/harpe-foret.mp3',
    'Au cœur de la jungle',
    'Chacha 243',
    seconds: 75,
    level: 0.5,
    fadeIn: 2,
  ),
  // Le passage des années 1970 aux années 1980 : un court instant de calme, puis Indépendance Cha Cha.
  'ngwasuma': MomentSong(
    'afrique/harpe-foret.mp3',
    'Au cœur de la jungle',
    'Chacha 243',
    seconds: 28,
    level: 0.7,
    fadeIn: 0.5,
    then: 'chacha',
  ),
  // La paix revenue, la descente vers l'aéroport : deux passages d'Indépendance Cha Cha.
  'paix1': MomentSong(
    'independance-cha-cha.mp3',
    'Indépendance Cha Cha',
    'Grand Kallé et l\'African Jazz',
    seconds: 45,
    level: 0.55,
    fadeIn: 1.5,
  ),
  'paix2': MomentSong(
    'independance-cha-cha.mp3',
    'Indépendance Cha Cha',
    'Grand Kallé et l\'African Jazz',
    start: 70,
    seconds: 45,
    level: 0.55,
    fadeIn: 1.5,
  ),
  // Le Zaïre redevient le Congo : Indépendance Cha Cha joue de la fin de la guerre de l'AFDL à la mort de Mzee, en 2001.
  'franc': MomentSong(
    'independance-cha-cha.mp3',
    'Indépendance Cha Cha',
    'Grand Kallé et l\'African Jazz',
    seconds: 189,
    level: 0.5,
    fadeIn: 3,
  ),
  'okjazz': MomentSong('afrique/harpe-tristesse.mp3', 'Le prix de la liberté', 'Chacha 243', seconds: 72),
  // « Comprenez mon émotion », en 1990 : la harpe joue le temps de la fiche, puis s'arrête.
  'desire': MomentSong('afrique/harpe-foret.mp3', 'Au cœur de la jungle', 'Chacha 243', seconds: 20, fadeIn: 1),
  // La mort de Franco, en 1989 : la harpe dans la forêt, jusqu'au moment suivant.
  'mario': MomentSong(
    'afrique/harpe-foret.mp3',
    'Au cœur de la jungle',
    'Chacha 243',
    seconds: 78,
    level: 0.65,
    fadeIn: 3,
  ),
  'bomaye': MomentSong('afrique/tam-tam-village.mp3', 'Tam-tams de la route', 'Chacha 243', seconds: 66),
  'viva': MomentSong('afrique/tam-tam-village.mp3', 'Tam-tams de la route', 'Chacha 243', seconds: 70),
  'wenge': MomentSong('afrique/tam-tam-village.mp3', 'Tam-tams de la route', 'Chacha 243', seconds: 66),
  'koffi': MomentSong('afrique/tam-tam-village.mp3', 'Tam-tams de la route', 'Chacha 243', seconds: 70),
  'kester': MomentSong('afrique/harpe-tristesse.mp3', 'Le prix de la liberté', 'Chacha 243', seconds: 72),
  'reveil': MomentSong(
    'afrique/tam-tam-detresse.mp3',
    'Tam-tams de guerre',
    'Chacha 243',
    seconds: 78,
    level: 0.6,
    fadeIn: 5,
  ),
  // Les tam-tams des moments difficiles : doux, ils réconfortent sans couvrir le vol.
  'louange': MomentSong(
    'afrique/tam-tam-detresse.mp3',
    'Tam-tams de guerre',
    'Chacha 243',
    seconds: 45,
    level: 0.55,
    fadeIn: 6,
  ),
  // La dernière ligne droite, jusqu'au 30 juin 2027 : elle commence bas, puis remonte.
  'fally2006': MomentSong(
    'afrique/tam-tam-village.mp3',
    'Tam-tams de la route',
    'Chacha 243',
    seconds: 66,
    level: 0.7,
    fadeIn: 2,
  ),
  'fally2026': MomentSong(
    'afrique/tam-tam-village.mp3',
    'Tam-tams de la route',
    'Chacha 243',
    seconds: 60,
    level: 0.7,
    fadeIn: 2,
  ),
  'moloto': MomentSong(
    'afrique/reveil-tam-tams.mp3',
    'Le réveil des tam-tams',
    'Chacha 243',
    seconds: 60,
    level: 0.45,
    fadeIn: 3,
  ),
};

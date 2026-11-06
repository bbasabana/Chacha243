import 'package:flutter/foundation.dart';

/// Les photos d'archives : petites vignettes dans les fiches d'histoire.
///
/// Une photo ne s'affiche dans l'application publiée que si ses droits sont réglés
/// ([cleared]) ; en développement, toutes s'affichent pour juger de la mise en page.
class ArchivePhoto {
  const ArchivePhoto(this.file, this.caption, {this.credit = 'Source à confirmer', this.cleared = false});

  final String file;
  final String caption;
  final String credit;
  final bool cleared;

  String get asset => file.contains('/') ? 'assets/$file' : 'assets/photos/$file';
  bool get visible => cleared || kDebugMode;
}

const archivePhotos = <String, ArchivePhoto>{
  'tshombe': ArchivePhoto('moise-tshombe.jpg', 'Moïse Tshombe'),
  'mobutu': ArchivePhoto('mobutu-au-pouvoir.jpg', 'Mobutu Sese Seko'),
  'ali': ArchivePhoto('mobutu-ali-1974.jpg', 'Mobutu et Mohamed Ali, Kinshasa, 1974'),
  'abala': ArchivePhoto('ayidini-abala.jpg', 'Le pasteur Ayidini Abala'),
  'ldk': ArchivePhoto('laurent-desire-kabila.jpg', 'Laurent-Désiré Kabila'),
  'jkabila': ArchivePhoto('joseph-kabila.jpg', 'Joseph Kabila'),
  'tshisekedi': ArchivePhoto('felix-tshisekedi.jpg', 'Félix Tshisekedi'),
  'nyiragongo': ArchivePhoto('nyiragongo-goma.jpg', 'Le Nyiragongo au-dessus de Goma'),
  'gecamines': ArchivePhoto('gecamines-terril.jpg', 'Le terril de la Gécamines, Lubumbashi'),
  'outeniqua': ArchivePhoto('outeniqua-1997.jpg', 'Mobutu, Mandela et Kabila sur l\'Outeniqua, 1997'),
  'wagenia': ArchivePhoto('wagenia-kisangani.jpg', 'Les pêcheurs Wagenia, Kisangani'),
  // Logos et billets : marques et signes monétaires, à n'afficher qu'avec l'accord de la banque.
  'bcc': ArchivePhoto('logo-banque-centrale.png', 'Banque centrale du Congo', credit: 'Logo BCC'),
  'bcdc': ArchivePhoto('logo-banque-commerciale.png', 'Banque commerciale du Congo', credit: 'Logo BCDC'),
  'billet1f': ArchivePhoto('notes/billet-1-franc-1997.jpg', 'Billet de 1 franc congolais', credit: 'BCC, 1997'),
  'billetnz': ArchivePhoto('notes/billet-1-nouveau-zaire-1993.jpg', 'Billet de 1 nouveau zaïre', credit: 'Banque du Zaïre, 1993'),
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
  final out = [for (final b in banknotes) if (b.from <= year) b]..sort((a, b) => a.value.compareTo(b.value));
  if (out.isEmpty) return null;
  return out.firstWhere((b) => b.value >= amount, orElse: () => out.last);
}

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
const mealDishes = ['Madesu', 'Fumbwa', 'Pondu', 'Makayabu (poisson salé)', 'Poisson grillé', 'Poulet mayo', 'Dindon', 'Ntaba', 'Liboke'];
const mealBeers = ['Primus', 'Turbo King', 'Castel', 'Nkoyi', 'Tembo'];
const mealSodas = ['Vitalo', 'Fanta', 'Coca-Cola', 'Eau'];

/// Les chansons des moments : le jeu joue le fichier s'il est dans assets/audio,
/// une fois les droits obtenus. Sans fichier, le moment reste silencieux.
class MomentSong {
  const MomentSong(this.file, this.title, this.artist);

  final String file;
  final String title;
  final String artist;
}

const momentSongs = <String, MomentSong>{
  'chacha': MomentSong('independance-cha-cha.mp3', 'Indépendance Cha Cha', 'Grand Kallé et l\'African Jazz'),
  'okjazz': MomentSong('franco-ok-jazz.mp3', 'Une rumba de l\'OK Jazz', 'Franco Luambo Makiadi'),
  'bomaye': MomentSong('ali-bomaye.mp3', '« Ali, bomaye ! »', 'le chant du stade du 20-Mai'),
  'viva': MomentSong('viva-la-musica.mp3', 'Une chanson de Viva la Musica', 'Papa Wemba'),
  'wenge': MomentSong('wenge-musica.mp3', 'Une chanson de Wenge Musica', 'Wenge Musica 4×4'),
  'kester': MomentSong('victoria-eleison.mp3', 'Une chanson de Victoria Eleison', 'Kester Emeneya'),
  'reveil': MomentSong('chant-de-reveil.mp3', 'Un chant des églises de réveil', 'chorale'),
};

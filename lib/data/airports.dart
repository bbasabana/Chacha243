/// Les aéroports où l'avion peut faire escale pour le kérosène et l'entretien.
///
/// Avant 1966, les villes portent leur nom colonial.
class Airport {
  const Airport(this.city, this.name, {this.oldCity, this.closedFrom});

  final String city;
  final String name;

  /// Le nom de la ville jusqu'en 1966.
  final String? oldCity;

  /// Fermé aux vols à partir de cette année (zones occupées).
  final double? closedFrom;

  String cityAt(double year) => year < 1966.4 && oldCity != null ? oldCity! : city;

  /// « Aéroport de N'djili », « Aéroport de Goma ».
  String get label => 'Aéroport de $name';

  /// Pour les panneaux : « Kinshasa · N'djili », ou seulement « Goma ».
  String titleAt(double year) => name == city ? cityAt(year) : '${cityAt(year)} · $name';

  bool openAt(double year) => closedFrom == null || year < closedFrom!;
}

const airports = <Airport>[
  Airport('Kinshasa', "N'djili", oldCity: 'Léopoldville'),
  Airport('Lubumbashi', 'Luano', oldCity: 'Élisabethville'),
  Airport('Kisangani', 'Bangoka', oldCity: 'Stanleyville'),
  Airport('Mbuji-Mayi', 'Mbuji-Mayi', oldCity: 'Bakwanga'),
  Airport('Kananga', 'Kananga', oldCity: 'Luluabourg'),
  Airport('Mbandaka', 'Mbandaka', oldCity: 'Coquilhatville'),
  Airport('Kalemie', 'Kalemie', oldCity: 'Albertville'),
  Airport('Goma', 'Goma', closedFrom: 2025.08),
  Airport('Bukavu', 'Kavumu', closedFrom: 2025.08),
  Airport('Kindu', 'Kindu'),
  Airport('Kolwezi', 'Kolwezi'),
  Airport('Bunia', 'Bunia'),
  Airport('Gemena', 'Gemena'),
  Airport('Matadi', 'Tshimpi'),
  Airport('Kikwit', 'Kikwit'),
  Airport('Likasi', 'Likasi', oldCity: 'Jadotville'),
];

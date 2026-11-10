import 'package:flutter/painting.dart';

/// Ce qu'on voit par le hublot : un animal du Congo, en vraie photo.
///
/// Le chimpanzé et le bonobo reviendront avec une vraie photo d'eux.
enum WindowAnimal {
  gorilla('Gorille', 'Les forêts du Kivu', 'gorille', Alignment(0.2, -0.6)),
  okapi('Okapi', 'Forêt de l\'Ituri · il ne vit qu\'en RDC', 'okapi', Alignment(0.3, -0.75)),
  leopard('Léopard', 'L\'emblème des Léopards du Congo', 'leopard', Alignment(0.2, -0.1)),
  elephant('Éléphants', 'Parc de la Garamba · Haut-Uele', 'elephant', Alignment(-0.15, 0.1));

  const WindowAnimal(this.name, this.place, this.file, this.focus);

  final String name, place;

  /// La photo (dans assets/animaux/), et le point qu'on garde au centre du hublot.
  final String file;
  final Alignment focus;

  String get asset => 'assets/animaux/$file.jpg';
}

/// Une question « vrai ou faux » sur un animal vu par le hublot : une bonne réponse rapporte du kérosène.
class NatureQuiz {
  const NatureQuiz(this.animal, this.question, this.isTrue, this.why);

  final WindowAnimal animal;
  final String question;
  final bool isTrue;

  /// Ce qu'il faut retenir, affiché après la réponse.
  final String why;
}

const natureQuizzes = <NatureQuiz>[
  NatureQuiz(
    WindowAnimal.okapi,
    'Savez-vous que l\'okapi ne vit, à l\'état sauvage, qu\'en RDC ? Vrai ou faux ?',
    true,
    'On ne le trouve que dans les forêts du nord-est de la RDC, comme l\'Ituri.',
  ),
  NatureQuiz(
    WindowAnimal.okapi,
    'L\'okapi a des rayures : c\'est un cousin du zèbre. Vrai ou faux ?',
    false,
    'Son plus proche cousin est la girafe.',
  ),
  NatureQuiz(
    WindowAnimal.gorilla,
    'Le parc des Virunga, où vivent des gorilles de montagne, est le plus ancien parc national d\'Afrique. Vrai ou faux ?',
    true,
    'Il a été créé en 1925.',
  ),
  NatureQuiz(
    WindowAnimal.leopard,
    'Le léopard ne monte jamais aux arbres. Vrai ou faux ?',
    false,
    'Il y grimpe pour se reposer et pour y cacher ses proies.',
  ),
  NatureQuiz(
    WindowAnimal.elephant,
    'La RDC a aussi des éléphants de forêt, plus grands que ceux de la savane. Vrai ou faux ?',
    false,
    'L\'éléphant de forêt est plus petit, avec des oreilles plus rondes.',
  ),
];

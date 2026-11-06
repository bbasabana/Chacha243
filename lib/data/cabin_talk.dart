/// Ce que disent les gens dans l'avion : passagers et équipage, en lingala et en français.
///
/// Une conversation tient en deux ou trois répliques. Le jeu en tire une au hasard
/// selon le moment (guerre, orage, paix, repas, arrivée). Le lingala est à faire
/// valider par des locuteurs avant la sortie.
class TalkLine {
  const TalkLine(this.speaker, this.lingala, this.french);

  /// Qui parle : « Passagère, rang 12 », « Hôtesse », « Copilote »…
  final String speaker;
  final String lingala;
  final String french;
}

enum TalkMoment { war, storm, volcano, peace, glory, meal, finaleStart, finaleStorm, finaleCalm, approachHome, arrival }

const cabinTalks = <TalkMoment, List<List<TalkLine>>>{
  TalkMoment.war: [
    [
      TalkLine('Passagère, rang 12', 'Eh ! Bitumba lisusu…', 'Eh ! Encore la guerre…'),
      TalkLine('Passager, rang 7', 'Nzambe batela biso.', 'Que Dieu nous protège.'),
      TalkLine('Hôtesse', 'Kobanga te, bokanga mikaba.', 'N\'ayez pas peur, attachez vos ceintures.'),
    ],
    [
      TalkLine('Un enfant', 'Mama, nazali kobanga !', 'Maman, j\'ai peur !'),
      TalkLine('Sa maman', 'Kobanga te, pilote azali makasi.', 'N\'aie pas peur, le pilote est fort.'),
    ],
    [
      TalkLine('Copilote', 'Keba ! Mpepo ya bitumba.', 'Attention ! Des avions de chasse.'),
      TalkLine('Commandant', 'Tokokoka. Totikala kimia.', 'On va y arriver. Restons calmes.'),
    ],
  ],
  TalkMoment.storm: [
    [
      TalkLine('Passager, rang 3', 'Mbula makasi !', 'Quelle pluie !'),
      TalkLine('Copilote', 'Pilote, malembe…', 'Doucement, commandant…'),
    ],
    [
      TalkLine('Passagère, rang 18', 'Mama na ngai, ndenge avion eningani !', 'Mon Dieu, comme l\'avion tremble !'),
      TalkLine('Hôtesse', 'Ezali eloko te, ekoleka.', 'Ce n\'est rien, ça va passer.'),
    ],
  ],
  TalkMoment.volcano: [
    [
      TalkLine('Passager, rang 9', 'Tala ! Nyiragongo !', 'Regardez ! Le Nyiragongo !'),
      TalkLine('Passagère, rang 10', 'Nzambe batela bato ya Goma.', 'Que Dieu protège les gens de Goma.'),
    ],
  ],
  TalkMoment.peace: [
    [
      TalkLine('Passagère, rang 12', 'Kimia ezongi !', 'La paix est revenue !'),
      TalkLine('Passager, rang 7', 'Matondo Nzambe.', 'Merci mon Dieu.'),
    ],
    [
      TalkLine('Hôtesse', 'Bokoki kofungola mikaba.', 'Vous pouvez détacher vos ceintures.'),
      TalkLine('Un enfant', 'Esengo !', 'Youpi !'),
    ],
  ],
  TalkMoment.glory: [
    [
      TalkLine('Passager, rang 4', 'Esengo !', 'Quelle joie !'),
      TalkLine('Passagère, rang 5', 'Congo na biso !', 'Notre Congo !'),
    ],
    [TalkLine('Copilote', 'Elonga !', 'Victoire !'), TalkLine('Passagers', 'Eeeeh !', 'Bravo !')],
  ],
  TalkMoment.meal: [
    [
      TalkLine('Passager, rang 14', 'Bilei ezali elengi !', 'Le repas est délicieux !'),
      TalkLine('Hôtesse', 'Matondo. Bolia malamu.', 'Merci. Bon appétit.'),
    ],
  ],
  TalkMoment.finaleStart: [
    [
      TalkLine('Commandant', 'Tokokoma !', 'Nous allons arriver !'),
      TalkLine('Passagère, rang 12', 'Mokolo ya Dipanda ekomi pene.', 'Le jour de l\'Indépendance approche.'),
    ],
  ],
  TalkMoment.finaleStorm: [
    [
      TalkLine('Passagère, rang 12', 'Mama na ngai !', 'Mon Dieu !'),
      TalkLine('Passager, rang 7', 'Nzambe batela biso !', 'Que Dieu nous protège !'),
    ],
    [
      TalkLine('Un enfant', 'Pilote, keba !', 'Pilote, attention !'),
      TalkLine('Copilote', 'Kobanga te, tokokoka !', 'N\'ayez pas peur, on va y arriver !'),
    ],
  ],
  TalkMoment.finaleCalm: [
    [
      TalkLine('Hôtesse', 'Kimia. Nzambe azali na biso.', 'Le calme. Dieu est avec nous.'),
      TalkLine('Passager, rang 7', 'Congo ekotelema !', 'Le Congo se relèvera !'),
    ],
  ],
  TalkMoment.approachHome: [
    [
      TalkLine('Commandant', 'Toyei na ndako.', 'Nous rentrons à la maison.'),
      TalkLine('Passagers', 'Dipanda ! Dipanda !', 'Indépendance ! Indépendance !'),
    ],
  ],
  TalkMoment.arrival: [
    [
      TalkLine('Passagers', 'Eeeeh ! Matondo, pilote !', 'Bravo ! Merci, pilote !'),
      TalkLine('Une maman', 'Esengo mingi !', 'Quelle grande joie !'),
      TalkLine('Un enfant', 'Dipanda cha cha !', 'Indépendance cha cha !'),
    ],
  ],
};

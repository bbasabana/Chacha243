/// Ce que disent les gens dans l'avion : passagers et équipage, en lingala et en français.
///
/// Une conversation tient en deux ou trois répliques. Le jeu en tire une selon le moment
/// (guerre, orage, choc, paix, joie, repas, bavardage, arrivée) et ne la répète qu'après
/// avoir passé toutes les autres. Le lingala est à faire valider par des locuteurs avant la sortie.
class TalkLine {
  const TalkLine(this.speaker, this.lingala, this.french);

  /// Qui parle : « Passagère, rang 12 », « Hôtesse », « Copilote »…
  final String speaker;
  final String lingala;
  final String french;
}

enum TalkMoment {
  takeoff,
  war,
  serving,
  storm,
  volcano,
  hit,
  danger,
  peace,
  glory,
  dance,
  meal,
  chat,
  finaleStart,
  finaleStorm,
  finaleCalm,
  approachHome,
  arrival,

  /// On vient d'échapper aux avions de chasse : on remercie Dieu.
  escape,

  /// Le 30 juin 1960 : la cabine crie sa joie.
  independence,
}

const cabinTalks = <TalkMoment, List<List<TalkLine>>>{
  // Au décollage : l'enfant a peur, la maman le rassure, l'équipage parle aux passagers.
  TalkMoment.takeoff: [
    [
      TalkLine('Un enfant', 'Mama ! Mpepo ezali komata !', 'Maman ! L\'avion monte !'),
      TalkLine('Sa maman', 'Nazali awa, mwana na ngai. Kobanga te.', 'Je suis là, mon enfant. N\'aie pas peur.'),
      TalkLine(
        'Hôtesse',
        'Bapasaze, bofanda malamu mpe bokanga mikaba.',
        'Chers passagers, restez assis et attachez vos ceintures.',
      ),
      TalkLine(
        'Commandant',
        'Bomitungisa te, tozali elongo. Mobembo malamu !',
        'Ne vous inquiétez pas, nous sommes ensemble. Bon voyage !',
      ),
    ],
    [
      TalkLine('Une petite fille', 'Mama, maboko na ngai ezali kolenga.', 'Maman, mes mains tremblent.'),
      TalkLine('Sa maman', 'Simba loboko na ngai. Nazali awa.', 'Tiens ma main. Je suis là.'),
      TalkLine(
        'Commandant',
        'Bapasaze na biso, bofanda kimia : likambo te.',
        'Chers passagers, restez calmes : tout va bien.',
      ),
    ],
    [
      TalkLine('Un petit garçon', 'Papa, tokokoma malamu ?', 'Papa, on va bien arriver ?'),
      TalkLine('Son papa', 'Ee, mwana na ngai. Tokokoma.', 'Oui, mon enfant. Nous allons arriver.'),
    ],
    [
      TalkLine('Une grand-mère', 'Nzambe akamba biso na mobembo oyo.', 'Que Dieu nous guide pendant ce voyage.'),
      TalkLine('Son petit-fils', 'Amen, koko !', 'Amen, grand-mère !'),
      TalkLine('Hôtesse', 'Bokanga mikaba, tokei.', 'Attachez vos ceintures, nous partons.'),
    ],
    [
      TalkLine('Un enfant', 'Mama, matoyi na ngai ezali kokangama !', 'Maman, mes oreilles se bouchent !'),
      TalkLine('Sa maman', 'Mela mwa mai, ekoleka.', 'Bois un peu d\'eau, ça va passer.'),
    ],
    [
      TalkLine('Une petite fille', 'Mama, tala engumba na nse !', 'Maman, regarde la ville en bas !'),
      TalkLine('Sa maman', 'Ezali kitoko, mwana na ngai.', 'C\'est beau, mon enfant.'),
      TalkLine('Commandant', 'Tokei liboso, mobembo malamu !', 'Nous repartons, bon voyage !'),
    ],
    [
      TalkLine('Passager, rang 3', 'Ngai nazali kobanga mpepo.', 'Moi, j\'ai peur de l\'avion.'),
      TalkLine('Sa voisine', 'Kanga miso, bondela, ekoleka.', 'Ferme les yeux, prie, ça va passer.'),
    ],
    [
      TalkLine('Un enfant', 'Mama, pilote ayebi nzela ?', 'Maman, le pilote connaît le chemin ?'),
      TalkLine('Sa maman', 'Ayebi yango malamu. Fanda kimia.', 'Il le connaît très bien. Reste tranquille.'),
    ],
  ],
  TalkMoment.independence: [
    [
      TalkLine(
        'Les passagers',
        'Woooooh ! Lipanda ! Tozwi indépendance !',
        'Woooooh ! L\'indépendance ! Nous avons pris l\'indépendance !',
      ),
      TalkLine('Un enfant', 'Papa, tozwi nini ?', 'Papa, on a eu quoi ? On a fait quoi ?'),
      TalkLine(
        'Son papa',
        'Tozwi indépendance, mwana na ngai. Mboka na biso ezali sikoyo na bonsomi.',
        'Nous avons eu l\'indépendance, mon enfant. Notre pays est maintenant libre.',
      ),
    ],
  ],
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
    [
      TalkLine('Passager, rang 22', 'Mboka oyo ekomona mpasi boni ?', 'Combien ce pays va-t-il encore souffrir ?'),
      TalkLine('Passagère, rang 23', 'Tobondela. Mokolo moko kimia ekoya.', 'Prions. Un jour, la paix viendra.'),
    ],
    [
      TalkLine('Un papa', 'Bana, bokita na se ya kiti te, botikala kimia.', 'Les enfants, restez assis et calmes.'),
      TalkLine('Un enfant', 'Papa, ezali bitumba ya solo ?', 'Papa, c\'est une vraie guerre ?'),
      TalkLine('Un papa', 'Iyo. Kasi tokoleka.', 'Oui. Mais on va passer.'),
    ],
    [
      TalkLine('Hôtesse', 'Botia mito na se, bokanga mikaba !', 'Baissez la tête, attachez vos ceintures !'),
      TalkLine('Passagère, rang 5', 'Yesu, sunga biso !', 'Jésus, aide-nous !'),
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
    [
      TalkLine('Passager, rang 9', 'Tala minda ya likolo !', 'Regardez les éclairs !'),
      TalkLine('Passagère, rang 10', 'Kotala te, kanga miso.', 'Ne regarde pas, ferme les yeux.'),
    ],
    [
      TalkLine('Copilote', 'Mipepe makasi liboso.', 'Vents forts devant.'),
      TalkLine('Commandant', 'Tokozinga yango.', 'On va les contourner.'),
    ],
    [
      TalkLine('Un enfant', 'Ezali lokola manège !', 'C\'est comme un manège !'),
      TalkLine('Sa maman', 'Kosepela te, bondela !', 'Ne rigole pas, prie !'),
    ],
  ],
  TalkMoment.volcano: [
    [
      TalkLine('Passager, rang 9', 'Tala ! Nyiragongo !', 'Regardez ! Le Nyiragongo !'),
      TalkLine('Passagère, rang 10', 'Nzambe batela bato ya Goma.', 'Que Dieu protège les gens de Goma.'),
    ],
    [
      TalkLine('Copilote', 'Moto ezali kobima na ngomba !', 'Le feu sort de la montagne !'),
      TalkLine('Commandant', 'Totikala mosika.', 'Restons à distance.'),
    ],
  ],
  TalkMoment.hit: [
    [
      TalkLine('Passagère, rang 4', 'Aïe ! Nini wana ?', 'Aïe ! Qu\'est-ce que c\'était ?'),
      TalkLine('Hôtesse', 'Botikala na bisika na bino !', 'Restez à vos places !'),
    ],
    [
      TalkLine('Passager, rang 15', 'Eh ! Avion ebeti !', 'Eh ! L\'avion a été touché !'),
      TalkLine('Copilote', 'Tozali malamu, tokobi.', 'Ça va, on continue.'),
    ],
    [
      TalkLine('Un enfant', 'Mama !', 'Maman !'),
      TalkLine('Sa maman', 'Nazali awa, kolela te.', 'Je suis là, ne pleure pas.'),
    ],
  ],
  TalkMoment.danger: [
    [
      TalkLine('Copilote', 'Commandant, avion ezali kolemba !', 'Commandant, l\'avion faiblit !'),
      TalkLine('Commandant', 'Mbala moko lisusu, tokokoka.', 'Encore une fois, on va y arriver.'),
    ],
    [
      TalkLine('Passagère, rang 12', 'Nzambe, tika tokoma malamu.', 'Mon Dieu, fais-nous arriver sains et saufs.'),
      TalkLine('Hôtesse', 'Bokanga mikaba makasi.', 'Serrez bien vos ceintures.'),
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
    [
      TalkLine('Passager, rang 22', 'Toyembela kimia !', 'Chantons pour la paix !'),
      TalkLine('Passagers', 'Kimia, kimia, kimia…', 'La paix, la paix, la paix…'),
    ],
    [
      TalkLine('Commandant', 'Tolekaki. Bino nyonso bozali malamu ?', 'On est passés. Tout le monde va bien ?'),
      TalkLine('Passagers', 'Iyo ! Matondo, pilote !', 'Oui ! Merci, pilote !'),
    ],
  ],
  TalkMoment.glory: [
    [
      TalkLine('Passager, rang 4', 'Esengo !', 'Quelle joie !'),
      TalkLine('Passagère, rang 5', 'Congo na biso !', 'Notre Congo !'),
    ],
    [TalkLine('Copilote', 'Elonga !', 'Victoire !'), TalkLine('Passagers', 'Eeeeh !', 'Bravo !')],
    [
      TalkLine('Une maman', 'Lelo ezali mokolo ya esengo.', 'Aujourd\'hui est un jour de joie.'),
      TalkLine('Un papa', 'Bana bakoyeba lisolo oyo.', 'Les enfants connaîtront cette histoire.'),
    ],
  ],
  TalkMoment.dance: [
    [
      TalkLine('Passager, rang 11', 'Tobina !', 'Dansons !'),
      TalkLine('Passagère, rang 12', 'Ndombolo na avion !', 'Le ndombolo dans l\'avion !'),
      TalkLine('Hôtesse', 'Malembe, bobina kasi botikala na bisika !', 'Doucement, dansez mais restez à vos places !'),
    ],
    [
      TalkLine('Un enfant', 'Tala pilote, azali kobina na avion !', 'Regarde, le pilote fait danser l\'avion !'),
      TalkLine('Passagers', 'Eeeeh ! Ambiance !', 'Eeeh ! Quelle ambiance !'),
    ],
    [
      TalkLine('Passager, rang 20', 'Bobeta maboko !', 'Tapez dans vos mains !'),
      TalkLine('Passagers', 'Cha cha cha !', 'Cha cha cha !'),
    ],
  ],
  // Pendant que le chariot passe : chacun a son avis sur le plat du jour. Une réplique à la fois.
  // Quand une réplique est déjà en français, la ligne du dessous reste vide.
  TalkMoment.serving: [
    [
      TalkLine('Passager, rang 9', 'Moi, je ne prends pas la bière. Je veux du vin, avec le fufu !', ''),
      TalkLine('Passager, rang 15', 'Nga na liaka kaka Badive na Mbolongo na likofi ya malili', ''),
      TalkLine('Maman, rang 11', 'Biloko ya ngo pilipili eza te !', 'Cette nourriture n\'a pas de piment !'),
      TalkLine('Passager, rang 4', 'Oh, nous sommes en avion, les Congolais !', ''),
      TalkLine('Hôtesse', 'Tokosalisa yo, mama.', 'Nous allons vous aider, maman.'),
    ],
  ],
  TalkMoment.meal: [
    [
      TalkLine('Passager, rang 14', 'Bilei ezali elengi !', 'Le repas est délicieux !'),
      TalkLine('Hôtesse', 'Matondo. Bolia malamu.', 'Merci. Bon appétit.'),
    ],
    [
      TalkLine('Passagère, rang 6', 'Pondu oyo ekokani na oyo ya mama !', 'Ce pondu ressemble à celui de maman !'),
      TalkLine('Passager, rang 7', 'Pesa ngai mwa fufu.', 'Donne-moi un peu de fufu.'),
    ],
    [
      TalkLine('Passager, rang 19', 'Hôtesse, Primus moko lisusu !', 'Hôtesse, encore une Primus !'),
      TalkLine('Hôtesse', 'Moko kaka, tozali na likolo !', 'Une seule, on est en l\'air !'),
    ],
  ],
  TalkMoment.chat: [
    [
      TalkLine('Passager, rang 8', 'Léopards bakolonga lobi ?', 'Les Léopards vont gagner demain ?'),
      TalkLine('Passager, rang 9', 'Ntango nyonso !', 'Toujours !'),
    ],
    [
      TalkLine('Passagère, rang 3', 'Nazali kokende kotala mama na Kisangani.', 'Je vais voir ma mère à Kisangani.'),
      TalkLine('Passagère, rang 4', 'Pesa ye mbote na ngai.', 'Salue-la de ma part.'),
    ],
    [
      TalkLine('Un enfant', 'Mama, tokomi ?', 'Maman, on est arrivés ?'),
      TalkLine('Sa maman', 'Naino te. Lala moke.', 'Pas encore. Dors un peu.'),
    ],
    [
      TalkLine(
        'Passager, rang 16',
        'Rumba ya Congo ezali na mokili mobimba.',
        'La rumba congolaise est partout dans le monde.',
      ),
      TalkLine('Passagère, rang 17', 'Ebinisaka mboka mobimba.', 'Elle fait danser tout le pays.'),
    ],
    [
      TalkLine(
        'Passager, rang 2',
        'Embouteillage ya Kinshasa ezali te awa likolo.',
        'Pas d\'embouteillage de Kinshasa ici en haut.',
      ),
      TalkLine('Passager, rang 3', 'Ha ha ! Avion eleki taxi-bus.', 'Ha ha ! L\'avion bat le taxi-bus.'),
    ],
    [
      TalkLine('Hôtesse', 'Bozali malamu ? Bolingi mai ?', 'Tout va bien ? Vous voulez de l\'eau ?'),
      TalkLine('Passagère, rang 12', 'Iyo, matondo mingi.', 'Oui, merci beaucoup.'),
    ],
    [
      TalkLine('Passager, rang 21', 'Tala ebale Congo na se !', 'Regardez le fleuve Congo en bas !'),
      TalkLine('Un enfant', 'Ezali monene boye !', 'Il est si grand !'),
    ],
    [
      TalkLine('Passagère, rang 14', 'Mwana na ngai akosala kelasi ya pilote.', 'Mon enfant fera l\'école de pilote.'),
      TalkLine('Un enfant', 'Nakokoma pilote lokola ye !', 'Je serai pilote comme lui !'),
    ],
    [
      TalkLine('Copilote', 'Lola ezali peto lelo.', 'Le ciel est clair aujourd\'hui.'),
      TalkLine('Commandant', 'Tosepela na yango.', 'Profitons-en.'),
    ],
    [
      TalkLine('Passager, rang 10', 'Oyoki sango ya mboka ?', 'Tu as entendu les nouvelles du pays ?'),
      TalkLine('Passager, rang 11', 'Tokotalaka, tokomona.', 'On verra bien.'),
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
  TalkMoment.escape: [
    [
      TalkLine('Une maman', 'Nkembo na Nzambe ! Nzambe abatela biso.', 'Gloire à Dieu ! Dieu, protège-nous.'),
      TalkLine('Passagers', 'Amen !', 'Amen !'),
    ],
    [TalkLine('Un papa', 'Nzambe azali na biso, tokokoma na 2027.', 'Dieu est avec nous, nous arriverons en 2027.')],
    [
      TalkLine('Hôtesse', 'Bopema, tolongi yango.', 'Respirez, nous y avons échappé.'),
      TalkLine('Une grand-mère', 'Nkembo na Nzambe !', 'Gloire à Dieu !'),
    ],
  ],
  TalkMoment.arrival: [
    [
      TalkLine('Commandant', 'Merci Nzambe ! Elonga eza ya biso', 'Merci Dieu ! La victoire est à nous.'),
      TalkLine('Un papa', 'Vive Lipanda, To longi', 'Vive l\'indépendance ! Nous avons gagné !'),
      TalkLine('Une maman', 'Nzambe ya Simon Kimbangu', 'Le Dieu de Simon Kimbangu !'),
    ],
  ],
};

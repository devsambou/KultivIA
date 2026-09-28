/// Points de vente d'intrants agricoles intégrés à l'app (Dakar et Thiès).
///
/// Source : recherche Google Maps du 24/09/2026 (nom, adresse, téléphone,
/// coordonnées). Les produits viennent de ce que chaque magasin affiche ;
/// une liste vide veut dire « non précisé ».
///
/// À FAIRE avant une publication : appeler chaque numéro pour confirmer que
/// le magasin est ouvert et vend bien des intrants, et corriger cette liste.
/// Pour en ajouter sans republier l'app, créez des documents dans la
/// collection Firestore `points_de_vente` (mêmes champs) : ils s'ajoutent
/// à cette liste.
const vendorsSeed = <Map<String, dynamic>>[
  {
    'name': 'Les Niayes Sarraut – Aristide Le Dantec',
    'address': '10 rue Aristide Le Dantec, Dakar',
    'latitude': 14.6703962,
    'longitude': -17.4294289,
    'phone': '+221 33 822 84 64',
    'products': ['Semences', 'Engrais', 'Matériel de jardinage'],
  },
  {
    'name': 'Les Niayes Sarraut – Route de Rufisque',
    'address': 'Route de Rufisque, km 3, Dakar',
    'latitude': 14.6940653,
    'longitude': -17.4369818,
    'phone': '+221 33 859 80 90',
    'products': ['Semences', 'Engrais', 'Tuyaux et arrosage'],
  },
  {
    'name': 'Terragrisen',
    'address': 'Villa n° 9, Dakar',
    'latitude': 14.7227325,
    'longitude': -17.466529,
    'phone': '+221 33 827 88 11',
    'products': ['Semences', 'Matériel agricole'],
  },
  {
    'name': 'Irrigation Semences Sénégal',
    'address': 'Cité Africa, près du restaurant Le Régal, Dakar',
    'latitude': 14.7156503,
    'longitude': -17.4862728,
    'phone': '+221 77 200 80 31',
    'products': ['Semences', 'Irrigation'],
  },
  {
    'name': 'ETC Commodities Senegal',
    'address': 'Route du Service géographique, Dakar',
    'latitude': 14.7192088,
    'longitude': -17.4391544,
    'phone': '+221 78 451 32 38',
    'products': ['Intrants agricoles'],
  },
  {
    'name': 'Agrophytex',
    'address': '19 rue de l\'Océan, Yoff, Dakar',
    'latitude': 14.760648,
    'longitude': -17.483296,
    'phone': '+221 33 820 45 30',
    'products': ['Engrais'],
  },
  {
    'name': 'AGROPHARM',
    'address': 'Dakar',
    'latitude': 14.7445718,
    'longitude': -17.3820296,
    'phone': '+221 77 635 03 04',
    'products': <String>[],
  },
  {
    'name': 'Le Comptoir Maraîcher',
    'address': 'Thiaroye, Dakar',
    'latitude': 14.747093,
    'longitude': -17.3580853,
    'phone': '+221 77 291 13 09',
    'products': ['Intrants pour le maraîchage'],
  },
  {
    'name': 'SPEM – Machines et équipements agricoles',
    'address': 'Route de Sindia, Thiès',
    'latitude': 14.7910769,
    'longitude': -16.9358857,
    'phone': '+221 78 186 74 87',
    'products': ['Machines agricoles'],
  },
];

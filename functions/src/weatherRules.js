/**
 * E6 - Règles météo -> risques agricoles
 *
 * Miroir des règles utilisées dans l'application Flutter (E1).
 *
 * Risque fongique :
 *   - humidité >= 80 %
 *   - probabilité de pluie >= 60 %
 *   - au moins 2 jours concernés
 *
 * Stress hydrique :
 *   - température >= 38 °C
 *   - probabilité de pluie <= 20 %
 *   - au moins 2 jours concernés
 */

function assessRisks(daily) {
  const hum = daily?.relative_humidity_2m_max || [];
  const rain = daily?.precipitation_probability_max || [];
  const temp = daily?.temperature_2m_max || [];

  const days = Math.max(
    hum.length,
    rain.length,
    temp.length,
  );

  let wetDays = 0;
  let hotDryDays = 0;

  for (let i = 0; i < days; i++) {
    const humidity = hum[i];
    const precipitation = rain[i];
    const temperature = temp[i];

    // Risque de maladie fongique
    if (
      humidity != null &&
      humidity >= 80 &&
      precipitation != null &&
      precipitation >= 60
    ) {
      wetDays++;
    }

    // Risque de stress hydrique
    if (
      temperature != null &&
      temperature >= 38 &&
      precipitation != null &&
      precipitation <= 20
    ) {
      hotDryDays++;
    }
  }

  return {
    fungal: wetDays >= 2,
    heat: hotDryDays >= 2,
  };
}

/**
 * Messages disponibles dans les 4 langues de KultivIA :
 * - fr : français
 * - en : anglais
 * - wo : wolof
 * - ln : lingala
 */
const MESSAGES = {
  fungal: {
    fr: {
      title: 'Risque de maladie des plantes',
      body:
        'Pluie et forte humidité annoncées. Surveillez vos cultures (mildiou, rouille).',
    },

    en: {
      title: 'Plant disease risk',
      body:
        'Rain and high humidity are forecast. Check your crops for mildew and rust.',
    },

    wo: {
      title: 'Feebar më́n na am ci sa mbay',
      body:
        'Taw dina di ñëw ay fan. Xool bu baax sa mbay ndax feebar.',
    },

    ln: {
      title: 'Likama ya banzambe ekoki kobimisa maladi',
      body:
        'Mbula mpe molunge makasi ya mopepe ezali kosakolama. Tala bilanga na yo mpo na bilembo ya maladi.',
    },
  },

  heat: {
    fr: {
      title: 'Forte chaleur annoncée',
      body:
        'Arrosez tôt le matin ou en fin de journée pour protéger vos plants.',
    },

    en: {
      title: 'Heat warning',
      body:
        'Water early in the morning or in the evening to protect your plants.',
    },

    wo: {
      title: 'Tàngoor bu tar dina am',
      body:
        'Ndoxal sa mbay ci suba walla ci ngoon.',
    },

    ln: {
      title: 'Molunge makasi ezali koya',
      body:
        'Bopesa bilanga na bino mai na ntongo to na mpokwa mpo na kobatela milona na bino.',
    },
  },
};

/**
 * Retourne le message correspondant au risque détecté
 * et à la langue de l'utilisateur.
 *
 * Le français est utilisé par défaut si la langue
 * n'est pas disponible.
 */
function alertMessage(risks, languageCode) {
  const lang = MESSAGES.fungal[languageCode]
    ? languageCode
    : 'fr';

  if (risks.fungal) {
    return MESSAGES.fungal[lang];
  }

  return MESSAGES.heat[lang];
}

module.exports = {
  assessRisks,
  alertMessage,
  MESSAGES,
};

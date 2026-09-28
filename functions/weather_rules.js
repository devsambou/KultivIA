/**
 * Règles météo -> risques agricoles, et messages d'alerte.
 * Miroir de `WeatherOutlook` (lib/services/weather_service.dart) : si vous
 * changez un seuil ici, changez-le aussi dans l'app.
 *
 * `daily` = objet `daily` renvoyé par Open-Meteo (3 jours) avec
 * precipitation_probability_max, relative_humidity_2m_max, temperature_2m_max.
 */

function assessRisks(daily) {
  const hum = (daily && daily.relative_humidity_2m_max) || [];
  const rain = (daily && daily.precipitation_probability_max) || [];
  const temp = (daily && daily.temperature_2m_max) || [];
  const days = Math.max(hum.length, temp.length);

  let wetDays = 0;
  let hotDryDays = 0;
  for (let i = 0; i < days; i++) {
    const r = rain[i];
    // Humidité élevée + pluie probable : maladies fongiques (mildiou, rouille...).
    if (hum[i] != null && hum[i] >= 80 && r != null && r >= 60) wetDays++;
    // Forte chaleur + peu de pluie : stress hydrique.
    if (temp[i] != null && temp[i] >= 38 && r != null && r <= 20) hotDryDays++;
  }
  return { fungal: wetDays >= 2, heat: hotDryDays >= 2 };
}

// Textes courts, lus sur l'écran de verrouillage. Le wolof est à faire relire
// par un locuteur natif avant publication.
const MESSAGES = {
  fungal: {
    fr: {
      title: 'Risque de maladie des plantes',
      body: 'Pluie et forte humidité annoncées. Surveillez vos cultures (mildiou, rouille).',
    },
    en: {
      title: 'Plant disease risk',
      body: 'Rain and high humidity are forecast. Check your crops for mildew and rust.',
    },
    wo: {
      title: 'Feebar mën na am ci sa mbay',
      body: 'Taw dina di ñëw ay fan. Xool bu baax sa mbay ndax feebar.',
    },
  },
  heat: {
    fr: {
      title: 'Forte chaleur annoncée',
      body: 'Arrosez tôt le matin ou en fin de journée pour protéger vos plants.',
    },
    en: {
      title: 'Heat warning',
      body: 'Water early in the morning or in the evening to protect your plants.',
    },
    wo: {
      title: 'Tàngoor bu tar dina am',
      body: 'Ndoxal sa mbay ci suba walla ci ngoon.',
    },
  },
};

function alertMessage(risks, languageCode) {
  const lang = MESSAGES.fungal[languageCode] ? languageCode : 'fr';
  return risks.fungal ? MESSAGES.fungal[lang] : MESSAGES.heat[lang];
}

module.exports = { assessRisks, alertMessage };

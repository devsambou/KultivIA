const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

const {
  assessRisks,
  alertMessage,
} = require('./weatherRules');

const GEOCODING_URL =
  'https://geocoding-api.open-meteo.com/v1/search';

const FORECAST_URL =
  'https://api.open-meteo.com/v1/forecast';

const ALERT_COOLDOWN_MS =
  3 * 24 * 60 * 60 * 1000;

/**
 * Cache de géocodage.
 *
 * Une même localité peut être utilisée par plusieurs utilisateurs.
 * On évite donc de faire plusieurs appels API pour la même localité
 * pendant une même exécution.
 */
const geocodeCache = new Map();

/**
 * Géocode une localité avec Open-Meteo.
 *
 * Retourne :
 * {
 *   latitude,
 *   longitude
 * }
 *
 * ou null si la localité n'est pas trouvée.
 */
async function geocodeLocality(locality) {
  const normalizedLocality = locality.trim().toLowerCase();

  if (!normalizedLocality) {
    return null;
  }

  if (geocodeCache.has(normalizedLocality)) {
    return geocodeCache.get(normalizedLocality);
  }

  const url = new URL(GEOCODING_URL);

  url.searchParams.set(
    'name',
    locality.trim(),
  );

  url.searchParams.set(
    'count',
    '1',
  );

  url.searchParams.set(
    'language',
    'fr',
  );

  url.searchParams.set(
    'format',
    'json',
  );

  try {
    const response = await fetch(url.toString());

    if (!response.ok) {
      console.error(
        `Erreur géocodage ${locality}: HTTP ${response.status}`,
      );

      geocodeCache.set(
        normalizedLocality,
        null,
      );

      return null;
    }

    const data = await response.json();

    if (
      !data.results ||
      data.results.length === 0
    ) {
      console.warn(
        `Localité introuvable : ${locality}`,
      );

      geocodeCache.set(
        normalizedLocality,
        null,
      );

      return null;
    }

    const result = data.results[0];

    const coordinates = {
      latitude: result.latitude,
      longitude: result.longitude,
    };

    geocodeCache.set(
      normalizedLocality,
      coordinates,
    );

    return coordinates;
  } catch (error) {
    console.error(
      `Erreur pendant le géocodage de ${locality}:`,
      error,
    );

    geocodeCache.set(
      normalizedLocality,
      null,
    );

    return null;
  }
}

/**
 * Récupère les prévisions météo quotidiennes.
 *
 * Les champs utilisés sont exactement ceux de E1 :
 * - precipitation_probability_max
 * - relative_humidity_2m_max
 * - temperature_2m_max
 */
async function fetchDailyForecast(
  latitude,
  longitude,
) {
  const url = new URL(FORECAST_URL);

  url.searchParams.set(
    'latitude',
    latitude.toString(),
  );

  url.searchParams.set(
    'longitude',
    longitude.toString(),
  );

  url.searchParams.set(
    'daily',
    [
      'precipitation_probability_max',
      'relative_humidity_2m_max',
      'temperature_2m_max',
    ].join(','),
  );

  url.searchParams.set(
    'forecast_days',
    '3',
  );

  url.searchParams.set(
    'timezone',
    'auto',
  );

  const response = await fetch(url.toString());

  if (!response.ok) {
    throw new Error(
      `Erreur prévisions météo : HTTP ${response.status}`,
    );
  }

  const data = await response.json();

  return data.daily;
}

/**
 * Supprime le token FCM invalide du profil utilisateur.
 */
async function removeInvalidToken(userRef) {
  try {
    await userRef.update({
      fcmToken: admin.firestore.FieldValue.delete(),
    });

    console.log(
      `Token FCM invalide supprimé pour ${userRef.id}`,
    );
  } catch (error) {
    console.error(
      `Impossible de supprimer le token de ${userRef.id}:`,
      error,
    );
  }
}

/**
 * Envoie une notification météo à un utilisateur.
 */
async function sendWeatherAlert(
  userDoc,
  risks,
) {
  const userData = userDoc.data();

  const token = userData.fcmToken;
  const languageCode =
    userData.languageCode || 'fr';

  const message = alertMessage(
    risks,
    languageCode,
  );

  const payload = {
    token,
    notification: {
      title: message.title,
      body: message.body,
    },
    data: {
      type: 'weather_risk',
      risk: risks.fungal ? 'fungal' : 'heat',
    },
    android: {
      priority: 'high',
    },
  };

  try {
    await admin.messaging().send(payload);

    console.log(
      `Alerte météo envoyée à ${userDoc.id}`,
    );

    return true;
  } catch (error) {
    console.error(
      `Erreur FCM pour ${userDoc.id}:`,
      error,
    );

    /**
     * Les codes suivants indiquent généralement
     * qu'un token n'est plus utilisable.
     */
    const invalidTokenCodes = [
      'messaging/invalid-registration-token',
      'messaging/registration-token-not-registered',
    ];

    if (
      invalidTokenCodes.includes(error.code)
    ) {
      await removeInvalidToken(
        userDoc.ref,
      );
    }

    return false;
  }
}

/**
 * E6
 *
 * Chaque matin à 06h00.
 *
 * Fuseau :
 * Africa/Dakar
 *
 * Pour chaque utilisateur :
 * - notificationsEnabled === true
 * - fcmToken présent
 * - locality non vide
 * - dernière alerte >= 3 jours
 *
 * Puis :
 * - géocodage de la localité
 * - récupération météo
 * - analyse des risques
 * - notification FCM
 */
exports.dailyWeatherAlerts = onSchedule(
  {
    schedule: '0 6 * * *',
    timeZone: 'Africa/Dakar',
  },
  async () => {
    console.log(
      'Début de la vérification quotidienne des alertes météo.',
    );

    /**
     * On récupère uniquement les utilisateurs
     * ayant activé les notifications.
     */
    const snapshot = await admin
      .firestore()
      .collection('users')
      .where(
        'notificationsEnabled',
        '==',
        true,
      )
      .get();

    if (snapshot.empty) {
      console.log(
        'Aucun utilisateur avec notifications activées.',
      );

      return;
    }

    console.log(
      `${snapshot.size} utilisateur(s) trouvé(s).`,
    );

    const now = Date.now();

    for (const userDoc of snapshot.docs) {
      const userData = userDoc.data();

      const fcmToken = userData.fcmToken;
      const locality = userData.locality;

      /**
       * Token obligatoire.
       */
      if (
        typeof fcmToken !== 'string' ||
        !fcmToken.trim()
      ) {
        console.log(
          `Utilisateur ${userDoc.id} ignoré : aucun fcmToken.`,
        );

        continue;
      }

      /**
       * Localité obligatoire.
       */
      if (
        typeof locality !== 'string' ||
        !locality.trim()
      ) {
        console.log(
          `Utilisateur ${userDoc.id} ignoré : aucune localité.`,
        );

        continue;
      }

      /**
       * Respect de la fréquence maximale :
       * une alerte tous les 3 jours maximum.
       */
      const lastWeatherAlertAt =
        userData.lastWeatherAlertAt;

      if (lastWeatherAlertAt) {
        const lastAlertDate =
          lastWeatherAlertAt.toDate
            ? lastWeatherAlertAt.toDate()
            : new Date(lastWeatherAlertAt);

        const elapsed =
          now - lastAlertDate.getTime();

        if (
          elapsed < ALERT_COOLDOWN_MS
        ) {
          console.log(
            `Utilisateur ${userDoc.id} ignoré : cooldown de 3 jours.`,
          );

          continue;
        }
      }

      /**
       * Géocodage de la localité.
       */
      const coordinates =
        await geocodeLocality(locality);

      if (!coordinates) {
        console.log(
          `Utilisateur ${userDoc.id} ignoré : localité "${locality}" introuvable.`,
        );

        continue;
      }

      /**
       * Récupération des prévisions.
       */
      let daily;

      try {
        daily =
          await fetchDailyForecast(
            coordinates.latitude,
            coordinates.longitude,
          );
      } catch (error) {
        console.error(
          `Prévisions impossibles pour ${userDoc.id}:`,
          error,
        );

        continue;
      }

      /**
       * Analyse des risques.
       */
      const risks =
        assessRisks(daily);

      console.log(
        `Risques pour ${userDoc.id}:`,
        risks,
      );

      /**
       * Aucun risque détecté.
       */
      if (
        !risks.fungal &&
        !risks.heat
      ) {
        console.log(
          `Aucun risque météo pour ${userDoc.id}.`,
        );

        continue;
      }

      /**
       * Envoi FCM.
       */
      const sent =
        await sendWeatherAlert(
          userDoc,
          risks,
        );

      /**
       * On met à jour la date uniquement
       * si la notification a réellement
       * été envoyée.
       */
      if (sent) {
        await userDoc.ref.update({
          lastWeatherAlertAt:
            admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    console.log(
      'Fin de la vérification quotidienne des alertes météo.',
    );
  },
);

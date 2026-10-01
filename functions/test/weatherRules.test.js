const test = require('node:test');
const assert = require('node:assert');

const {
  assessRisks,
  alertMessage,
} = require('../src/weatherRules');


test(
  'risque fongique : 2 jours humides et pluvieux',
  () => {
    const daily = {
      relative_humidity_2m_max: [
        85,
        90,
        50,
      ],

      precipitation_probability_max: [
        70,
        80,
        10,
      ],

      temperature_2m_max: [
        30,
        31,
        32,
      ],
    };

    assert.deepStrictEqual(
      assessRisks(daily),
      {
        fungal: true,
        heat: false,
      },
    );
  },
);


test(
  'un seul jour humide ne déclenche rien',
  () => {
    const daily = {
      relative_humidity_2m_max: [
        85,
        60,
        50,
      ],

      precipitation_probability_max: [
        70,
        10,
        10,
      ],

      temperature_2m_max: [
        30,
        31,
        32,
      ],
    };

    assert.deepStrictEqual(
      assessRisks(daily),
      {
        fungal: false,
        heat: false,
      },
    );
  },
);


test(
  'stress hydrique : 2 jours très chauds et secs',
  () => {
    const daily = {
      relative_humidity_2m_max: [
        30,
        30,
        40,
      ],

      precipitation_probability_max: [
        5,
        10,
        50,
      ],

      temperature_2m_max: [
        39,
        41,
        30,
      ],
    };

    assert.deepStrictEqual(
      assessRisks(daily),
      {
        fungal: false,
        heat: true,
      },
    );
  },
);


test(
  'données manquantes : aucun risque, pas d’erreur',
  () => {
    assert.deepStrictEqual(
      assessRisks({}),
      {
        fungal: false,
        heat: false,
      },
    );

    assert.deepStrictEqual(
      assessRisks(undefined),
      {
        fungal: false,
        heat: false,
      },
    );
  },
);


test(
  'limite exacte : humidité 80 et pluie 60',
  () => {
    const daily = {
      relative_humidity_2m_max: [
        80,
        80,
        50,
      ],

      precipitation_probability_max: [
        60,
        60,
        10,
      ],

      temperature_2m_max: [
        30,
        31,
        32,
      ],
    };

    assert.deepStrictEqual(
      assessRisks(daily),
      {
        fungal: true,
        heat: false,
      },
    );
  },
);


test(
  'limite exacte : température 38 et pluie 20',
  () => {
    const daily = {
      relative_humidity_2m_max: [
        30,
        30,
        40,
      ],

      precipitation_probability_max: [
        20,
        20,
        50,
      ],

      temperature_2m_max: [
        38,
        38,
        30,
      ],
    };

    assert.deepStrictEqual(
      assessRisks(daily),
      {
        fungal: false,
        heat: true,
      },
    );
  },
);


test(
  'juste sous les seuils : aucun risque',
  () => {
    const daily = {
      relative_humidity_2m_max: [
        79,
        79,
        50,
      ],

      precipitation_probability_max: [
        59,
        59,
        10,
      ],

      temperature_2m_max: [
        37,
        37,
        30,
      ],
    };

    assert.deepStrictEqual(
      assessRisks(daily),
      {
        fungal: false,
        heat: false,
      },
    );
  },
);


test(
  'message français',
  () => {
    const message = alertMessage(
      {
        fungal: true,
        heat: false,
      },
      'fr',
    );

    assert.match(
      message.title,
      /maladie/i,
    );

    assert.ok(
      message.body.length > 0,
    );
  },
);


test(
  'message anglais',
  () => {
    const message = alertMessage(
      {
        fungal: true,
        heat: false,
      },
      'en',
    );

    assert.match(
      message.title,
      /disease/i,
    );

    assert.ok(
      message.body.length > 0,
    );
  },
);


test(
  'message wolof',
  () => {
    const message = alertMessage(
      {
        fungal: true,
        heat: false,
      },
      'wo',
    );

    assert.ok(
      message.title.length > 0,
    );

    assert.ok(
      message.body.length > 0,
    );
  },
);


test(
  'message lingala',
  () => {
    const message = alertMessage(
      {
        fungal: true,
        heat: false,
      },
      'ln',
    );

    assert.ok(
      message.title.length > 0,
    );

    assert.ok(
      message.body.length > 0,
    );
  },
);


test(
  'langue inconnue : français par défaut',
  () => {
    const message = alertMessage(
      {
        fungal: true,
        heat: false,
      },
      'xx',
    );

    assert.match(
      message.title,
      /maladie/i,
    );
  },
);

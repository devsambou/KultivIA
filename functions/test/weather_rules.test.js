const test = require('node:test');
const assert = require('node:assert');
const { assessRisks, alertMessage } = require('../weather_rules');

test('risque fongique : 2 jours humides et pluvieux', () => {
  const daily = {
    relative_humidity_2m_max: [85, 90, 50],
    precipitation_probability_max: [70, 80, 10],
    temperature_2m_max: [30, 31, 32],
  };
  assert.deepStrictEqual(assessRisks(daily), { fungal: true, heat: false });
});

test('un seul jour humide ne déclenche rien', () => {
  const daily = {
    relative_humidity_2m_max: [85, 60, 50],
    precipitation_probability_max: [70, 10, 10],
    temperature_2m_max: [30, 31, 32],
  };
  assert.deepStrictEqual(assessRisks(daily), { fungal: false, heat: false });
});

test('stress hydrique : 2 jours très chauds et secs', () => {
  const daily = {
    relative_humidity_2m_max: [30, 30, 40],
    precipitation_probability_max: [5, 10, 50],
    temperature_2m_max: [39, 41, 30],
  };
  assert.deepStrictEqual(assessRisks(daily), { fungal: false, heat: true });
});

test('données manquantes : aucun risque, pas d\'erreur', () => {
  assert.deepStrictEqual(assessRisks({}), { fungal: false, heat: false });
  assert.deepStrictEqual(assessRisks(undefined), { fungal: false, heat: false });
});

test('message dans la langue de l\'utilisateur, français par défaut', () => {
  assert.match(alertMessage({ fungal: true, heat: false }, 'en').title, /disease/i);
  assert.match(alertMessage({ fungal: false, heat: true }, 'xx').title, /chaleur/i);
  assert.ok(alertMessage({ fungal: true, heat: false }, 'wo').body.length > 0);
});

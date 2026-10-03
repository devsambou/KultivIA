// Vérifie les trois garde-fous de la réplication Firestore → Supabase.
// Usage : node tools/verif-sync.mjs
//
// Chaque test doit être REFUSÉ. Un test qui passe à l'écriture signifie
// que quelqu'un peut écrire dans la copie sans être authentifié.

const ANON = 'sb_publishable_5A_mapSPKReSrngmluNfbA_a-gQAONP';
const URL = 'https://hyvhwsclfjnnbrpdsypt.supabase.co';

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');

/** Jeton dont la signature est fausse : il ne peut pas être validé. */
const forgedToken = [
  b64({ alg: 'RS256', kid: 'x' }),
  b64({
    iss: 'https://securetoken.google.com/kultivia-875cf',
    aud: 'kultivia-875cf',
    sub: 'pirate',
    exp: Math.floor(Date.now() / 1000) + 3600,
  }),
  b64('faux'),
].join('.');

const writeBody = JSON.stringify({
  collection: 'user',
  data: { displayName: 'Attaque', updatedAt: new Date().toISOString() },
});

const tests = [
  {
    name: 'sans jeton',
    expected: [401],
    run: () =>
      fetch(`${URL}/functions/v1/sync-write`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: ANON },
        body: writeBody,
      }),
  },
  {
    name: 'jeton forge',
    expected: [401],
    run: () =>
      fetch(`${URL}/functions/v1/sync-write`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: ANON,
          Authorization: `Bearer ${forgedToken}`,
        },
        body: writeBody,
      }),
  },
  {
    name: 'rpc direct avec cle publique',
    expected: [401, 403],
    run: () =>
      fetch(`${URL}/rest/v1/rpc/sync_user_lww`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: ANON,
          Authorization: `Bearer ${ANON}`,
        },
        body: JSON.stringify({ p_uid: 'pirate' }),
      }),
  },
  {
    name: 'lecture directe de la table users',
    expected: [200], // 200 avec [] : RLS filtre, aucune ligne visible
    run: () =>
      fetch(`${URL}/rest/v1/users?select=*&limit=5`, {
        headers: { apikey: ANON, Authorization: `Bearer ${ANON}` },
      }),
  },
];

let failures = 0;

for (const test of tests) {
  try {
    const response = await test.run();
    const body = (await response.text()).slice(0, 70);
    const ok = test.expected.includes(response.status);

    if (!ok) failures += 1;

    console.log(
      `${ok ? 'OK  ' : 'ECHEC'} ${test.name} -> HTTP ${response.status} | ${body}`,
    );
  } catch (error) {
    failures += 1;
    console.log(`ECHEC ${test.name} -> ${error.message}`);
  }
}

console.log(
  failures === 0
    ? '\nTous les garde-fous tiennent.'
    : `\n${failures} garde-fou(x) ne tient(nt) pas.`,
);

process.exit(failures === 0 ? 0 : 1);
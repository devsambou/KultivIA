const test = require('node:test');
const assert = require('node:assert/strict');

const {
  aiProxy,
} = require('../src/aiProxy');

const ORIGINAL_ENV = {
  RODIUMAI_API_KEY: process.env.RODIUMAI_API_KEY,
  RODIUMAI_BASE_URL: process.env.RODIUMAI_BASE_URL,
  RODIUMAI_CHAT_MODEL: process.env.RODIUMAI_CHAT_MODEL,
};

function restoreEnv() {
  for (const [key, value] of Object.entries(ORIGINAL_ENV)) {
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }
}

function authenticatedContext() {
  return {
    auth: {
      uid: 'test-user',
    },
  };
}

test.afterEach(() => {
  restoreEnv();
});

test('aiProxy refuse un utilisateur non connecté', async () => {
  await assert.rejects(
    aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
      },
      {},
    ),
    (error) => {
      assert.equal(error.code, 'unauthenticated');
      return true;
    },
  );
});

test('aiProxy refuse si la clé API nest pas configurée', async () => {
  process.env.RODIUMAI_API_KEY = '';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  await assert.rejects(
    aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'failed-precondition');
      return true;
    },
  );
});

test('aiProxy refuse un tableau de messages vide', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  await assert.rejects(
    aiProxy(
      {
        messages: [],
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiProxy refuse plus de 20 messages', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const messages = Array.from({ length: 21 }, (_, i) => ({
    role: 'user',
    content: `Message ${i}`,
  }));

  await assert.rejects(
    aiProxy(
      {
        messages,
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiProxy accepte exactement 20 messages', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const originalFetch = global.fetch;

  global.fetch = async () => {
    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Réponse' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    const messages = Array.from({ length: 20 }, (_, i) => ({
      role: 'user',
      content: `Message ${i}`,
    }));

    const result = await aiProxy(
      {
        messages,
      },
      authenticatedContext(),
    );

    assert.equal(result.content, 'Réponse');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy refuse une température hors limites', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  await assert.rejects(
    aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
        temperature: 1.5,
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiProxy refuse maxTokens hors limites', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  await assert.rejects(
    aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
        maxTokens: 900,
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiProxy refuse une image trop volumineuse', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const largeBase64 = 'A'.repeat(6 * 1024 * 1024); // 6 Mo en base64

  await assert.rejects(
    aiProxy(
      {
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${largeBase64}`,
                },
              },
            ],
          },
        ],
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiProxy accepte une image de taille valide', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const originalFetch = global.fetch;

  global.fetch = async () => {
    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Diagnostic' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    const validBase64 = 'A'.repeat(1024); // 1 Ko

    const result = await aiProxy(
      {
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Diagnostique cette plante',
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${validBase64}`,
                },
              },
            ],
          },
        ],
      },
      authenticatedContext(),
    );

    assert.equal(result.content, 'Diagnostic');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy utilise RODIUMAI_BASE_URL', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://custom.example/v1';

  const originalFetch = global.fetch;

  let requestedUrl;

  global.fetch = async (url) => {
    requestedUrl = url;

    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Réponse' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    await aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
      },
      authenticatedContext(),
    );

    assert.equal(requestedUrl, 'https://custom.example/v1/chat/completions');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy utilise RODIUMAI_CHAT_MODEL', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_CHAT_MODEL = 'custom-model';

  const originalFetch = global.fetch;

  let requestBody;

  global.fetch = async (_url, options) => {
    requestBody = JSON.parse(options.body);

    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Réponse' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    await aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
      },
      authenticatedContext(),
    );

    assert.equal(requestBody.model, 'custom-model');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy utilise le modèle par défaut si non configuré', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const originalFetch = global.fetch;

  let requestBody;

  global.fetch = async (_url, options) => {
    requestBody = JSON.parse(options.body);

    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Réponse' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    await aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
      },
      authenticatedContext(),
    );

    assert.equal(requestBody.model, 'auto');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy transforme une erreur fournisseur en internal', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const originalFetch = global.fetch;

  global.fetch = async () => {
    return new Response(
      'SECRET_PROVIDER_ERROR',
      {
        status: 500,
      },
    );
  };

  try {
    await assert.rejects(
      aiProxy(
        {
          messages: [{ role: 'user', content: 'Bonjour' }],
        },
        authenticatedContext(),
      ),
      (error) => {
        assert.equal(error.code, 'internal');
        assert.notEqual(
          error.message.includes('SECRET_PROVIDER_ERROR'),
          true,
        );
        return true;
      },
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy renvoie le contenu de la réponse', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const originalFetch = global.fetch;

  global.fetch = async () => {
    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Contenu de test' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    const result = await aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
      },
      authenticatedContext(),
    );

    assert.equal(result.content, 'Contenu de test');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy inclut le language dans la requête', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const originalFetch = global.fetch;

  let requestBody;

  global.fetch = async (_url, options) => {
    requestBody = JSON.parse(options.body);

    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Réponse' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    await aiProxy(
      {
        messages: [{ role: 'user', content: 'Bonjour' }],
        language: 'wo',
      },
      authenticatedContext(),
    );

    assert.equal(requestBody.language, 'wo');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiProxy ne journalise jamais le contenu des messages', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';

  const originalFetch = global.fetch;

  const originalConsoleLog = console.log;
  const loggedMessages = [];

  console.log = (...args) => {
    loggedMessages.push(args.join(' '));
  };

  global.fetch = async () => {
    return new Response(
      JSON.stringify({ choices: [{ message: { content: 'Réponse' } }] }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    await aiProxy(
      {
        messages: [
          { role: 'user', content: 'Message secret' },
          { role: 'system', content: 'Instructions secrètes' },
        ],
      },
      authenticatedContext(),
    );

    const allLogs = loggedMessages.join(' ');
    assert.equal(allLogs.includes('Message secret'), false);
    assert.equal(allLogs.includes('Instructions secrètes'), false);
  } finally {
    global.fetch = originalFetch;
    console.log = originalConsoleLog;
  }
});

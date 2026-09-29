const test = require('node:test');
const assert = require('node:assert/strict');

const {
  handleAiTranscribe,
} = require('../src/aiTranscribe');

const ORIGINAL_ENV = {
  RODIUMAI_API_KEY: process.env.RODIUMAI_API_KEY,
  RODIUMAI_BASE_URL: process.env.RODIUMAI_BASE_URL,
  RODIUMAI_STT_MODEL: process.env.RODIUMAI_STT_MODEL,
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

function base64Audio(text = 'fake audio') {
  return Buffer.from(text).toString('base64');
}

test.afterEach(() => {
  restoreEnv();
});

test('aiTranscribe refuse un utilisateur non connecté', async () => {
  await assert.rejects(
    handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'audio/mp4',
        language: 'fr',
      },
      {},
    ),
    (error) => {
      assert.equal(error.code, 'unauthenticated');
      return true;
    },
  );
});

test('aiTranscribe refuse un audio vide', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  await assert.rejects(
    handleAiTranscribe(
      {
        audio: '',
        mime: 'audio/mp4',
        language: 'fr',
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiTranscribe refuse un MIME qui ne commence pas par audio/', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  await assert.rejects(
    handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'text/plain',
        language: 'fr',
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiTranscribe accepte un MIME audio/', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  const originalFetch = global.fetch;

  global.fetch = async () => {
    return new Response(
      JSON.stringify({
        text: 'Bonjour Kultivia',
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    const result = await handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'audio/mp4',
        language: 'fr',
      },
      authenticatedContext(),
    );

    assert.equal(result.text, 'Bonjour Kultivia');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiTranscribe utilise RODIUMAI_STT_MODEL', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'custom-stt-model';

  const originalFetch = global.fetch;

  let requestForm;

  global.fetch = async (_url, options) => {
    requestForm = options.body;

    return new Response(
      JSON.stringify({
        text: 'Test',
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
        },
      },
    );
  };

  try {
    await handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'audio/mp4',
        language: 'fr',
      },
      authenticatedContext(),
    );

    assert.ok(requestForm instanceof FormData);

    assert.equal(
      requestForm.get('model'),
      'custom-stt-model',
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiTranscribe envoie language pour une langue ISO standard', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  const originalFetch = global.fetch;

  let requestForm;

  global.fetch = async (_url, options) => {
    requestForm = options.body;

    return new Response(
      JSON.stringify({
        text: 'Bonjour',
      }),
      {
        status: 200,
      },
    );
  };

  try {
    await handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'audio/mp4',
        language: 'fr',
      },
      authenticatedContext(),
    );

    assert.equal(requestForm.get('language'), 'fr');
    assert.equal(requestForm.get('prompt'), null);
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiTranscribe utilise un prompt pour le Wolof', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  const originalFetch = global.fetch;

  let requestForm;

  global.fetch = async (_url, options) => {
    requestForm = options.body;

    return new Response(
      JSON.stringify({
        text: 'Nanga def',
      }),
      {
        status: 200,
      },
    );
  };

  try {
    await handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'audio/mp4',
        language: 'wo',
      },
      authenticatedContext(),
    );

    assert.equal(requestForm.get('language'), null);

    const prompt = requestForm.get('prompt');

    assert.ok(prompt);
    assert.match(prompt, /wolof/i);
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiTranscribe utilise un prompt pour le Lingala', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  const originalFetch = global.fetch;

  let requestForm;

  global.fetch = async (_url, options) => {
    requestForm = options.body;

    return new Response(
      JSON.stringify({
        text: 'Mbote',
      }),
      {
        status: 200,
      },
    );
  };

  try {
    await handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'audio/mp4',
        language: 'ln',
      },
      authenticatedContext(),
    );

    assert.equal(requestForm.get('language'), null);

    const prompt = requestForm.get('prompt');

    assert.ok(prompt);
    assert.match(prompt, /lingala/i);
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiTranscribe utilise RODIUMAI_BASE_URL', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://custom.example/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  const originalFetch = global.fetch;

  let requestedUrl;

  global.fetch = async (url) => {
    requestedUrl = url;

    return new Response(
      JSON.stringify({
        text: 'Test',
      }),
      {
        status: 200,
      },
    );
  };

  try {
    await handleAiTranscribe(
      {
        audio: base64Audio(),
        mime: 'audio/mp4',
        language: 'fr',
      },
      authenticatedContext(),
    );

    assert.equal(
      requestedUrl,
      'https://custom.example/v1/audio/transcriptions',
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiTranscribe refuse un audio supérieur à 10 Mo', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

  const audio = Buffer.alloc(
    10 * 1024 * 1024 + 1,
  ).toString('base64');

  await assert.rejects(
    handleAiTranscribe(
      {
        audio,
        mime: 'audio/mp4',
        language: 'fr',
      },
      authenticatedContext(),
    ),
    (error) => {
      assert.equal(error.code, 'invalid-argument');
      return true;
    },
  );
});

test('aiTranscribe transforme une erreur fournisseur en internal sans détail', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_STT_MODEL = 'test-stt';

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
      handleAiTranscribe(
        {
          audio: base64Audio(),
          mime: 'audio/mp4',
          language: 'fr',
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
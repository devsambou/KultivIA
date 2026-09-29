const test = require('node:test');
const assert = require('node:assert/strict');

const {
  handleAiSpeech,
} = require('../src/aiSpeech');

const ORIGINAL_ENV = {
  RODIUMAI_API_KEY: process.env.RODIUMAI_API_KEY,
  RODIUMAI_BASE_URL: process.env.RODIUMAI_BASE_URL,
  RODIUMAI_TTS_MODEL: process.env.RODIUMAI_TTS_MODEL,
  RODIUMAI_TTS_MODEL_FR: process.env.RODIUMAI_TTS_MODEL_FR,
  RODIUMAI_TTS_MODEL_WO: process.env.RODIUMAI_TTS_MODEL_WO,
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

test('aiSpeech refuse un utilisateur non connecté', async () => {
  await assert.rejects(
    handleAiSpeech(
      {
        text: 'Bonjour',
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

test('aiSpeech refuse un texte vide', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_TTS_MODEL = 'test-tts';

  await assert.rejects(
    handleAiSpeech(
      {
        text: '',
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

test('aiSpeech refuse un texte de 601 caractères', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_TTS_MODEL = 'test-tts';

  const text = 'a'.repeat(601);

  await assert.rejects(
    handleAiSpeech(
      {
        text,
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

test('aiSpeech accepte exactement 600 caractères', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_TTS_MODEL = 'test-tts';

  const originalFetch = global.fetch;

  global.fetch = async () => {
    return new Response(
      Buffer.from('fake-mp3-audio'),
      {
        status: 200,
        headers: {
          'Content-Type': 'audio/mpeg',
        },
      },
    );
  };

  try {
    const result = await handleAiSpeech(
      {
        text: 'a'.repeat(600),
        language: 'fr',
      },
      authenticatedContext(),
    );

    assert.ok(result.audio);
    assert.equal(
      Buffer.from(result.audio, 'base64').toString(),
      'fake-mp3-audio',
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiSpeech utilise le modèle spécifique à la langue', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_TTS_MODEL = 'default-tts';
  process.env.RODIUMAI_TTS_MODEL_WO = 'wolof-tts';

  const originalFetch = global.fetch;

  let requestBody;

  global.fetch = async (_url, options) => {
    requestBody = JSON.parse(options.body);

    return new Response(
      Buffer.from('fake-audio'),
      {
        status: 200,
      },
    );
  };

  try {
    await handleAiSpeech(
      {
        text: 'Bonjour',
        language: 'wo',
      },
      authenticatedContext(),
    );

    assert.equal(requestBody.model, 'wolof-tts');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiSpeech revient au modèle par défaut si aucun modèle de langue existe', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_TTS_MODEL = 'default-tts';

  delete process.env.RODIUMAI_TTS_MODEL_WO;

  const originalFetch = global.fetch;

  let requestBody;

  global.fetch = async (_url, options) => {
    requestBody = JSON.parse(options.body);

    return new Response(
      Buffer.from('fake-audio'),
      {
        status: 200,
      },
    );
  };

  try {
    await handleAiSpeech(
      {
        text: 'Bonjour',
        language: 'wo',
      },
      authenticatedContext(),
    );

    assert.equal(requestBody.model, 'default-tts');
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiSpeech utilise RODIUMAI_BASE_URL', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://custom.example/v1';
  process.env.RODIUMAI_TTS_MODEL = 'test-tts';

  const originalFetch = global.fetch;

  let requestedUrl;

  global.fetch = async (url) => {
    requestedUrl = url;

    return new Response(
      Buffer.from('fake-audio'),
      {
        status: 200,
      },
    );
  };

  try {
    await handleAiSpeech(
      {
        text: 'Bonjour',
        language: 'fr',
      },
      authenticatedContext(),
    );

    assert.equal(
      requestedUrl,
      'https://custom.example/v1/audio/speech',
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test('aiSpeech transforme une erreur fournisseur en internal sans exposer le détail', async () => {
  process.env.RODIUMAI_API_KEY = 'test-key';
  process.env.RODIUMAI_BASE_URL = 'https://example.test/v1';
  process.env.RODIUMAI_TTS_MODEL = 'test-tts';

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
      handleAiSpeech(
        {
          text: 'Bonjour',
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
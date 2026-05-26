module.exports = async function handler(request, response) {
  setCorsHeaders(response);

  if (request.method === 'OPTIONS') {
    response.status(204).end();
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const payload = typeof request.body === 'string' ? safeJson(request.body) : request.body || {};
  const locator = payload.locator || payload.localizador;

  if (!locator) {
    response.status(400).json({ error: 'Missing locator' });
    return;
  }

  response.status(200).json({
    provider: process.env.FLIGHTS_PROVIDER || 'mock',
    locator,
    status: 'CANCELLED',
    createdAt: new Date().toISOString(),
    homologation: {
      step: 'cancel-booking',
      mock: true,
    },
  });
};

function setCorsHeaders(response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function safeJson(value) {
  try {
    return JSON.parse(value);
  } catch (error) {
    return {};
  }
}

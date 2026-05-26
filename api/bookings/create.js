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
  const passenger = payload.passenger || {};
  const offer = payload.offer || {};

  if (!passenger.firstName || !passenger.lastName || !passenger.email) {
    response.status(400).json({ error: 'Missing required passenger fields' });
    return;
  }

  const locator = `TST${Date.now().toString().slice(-6)}`;

  response.status(200).json({
    provider: process.env.FLIGHTS_PROVIDER || 'mock',
    locator,
    status: 'RESERVED',
    createdAt: new Date().toISOString(),
    offer,
    passenger: {
      firstName: passenger.firstName,
      lastName: passenger.lastName,
      email: passenger.email,
    },
    homologation: {
      step: 'create-booking',
      mock: true,
      nextSteps: ['get-booking', 'cancel-booking'],
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

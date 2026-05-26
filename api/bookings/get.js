module.exports = async function handler(request, response) {
  setCorsHeaders(response);

  if (request.method === 'OPTIONS') {
    response.status(204).end();
    return;
  }

  if (request.method !== 'GET') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const locator = request.query.locator || request.query.localizador;

  if (!locator) {
    response.status(400).json({ error: 'Missing locator' });
    return;
  }

  response.status(200).json({
    provider: process.env.FLIGHTS_PROVIDER || 'mock',
    locator,
    status: 'RESERVED',
    createdAt: new Date().toISOString(),
    homologation: {
      step: 'get-booking',
      mock: true,
    },
  });
};

function setCorsHeaders(response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

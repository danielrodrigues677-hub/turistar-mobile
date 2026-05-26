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

  const offerId = request.query.offerId || request.query.id || 'mock-offer';

  response.status(200).json({
    provider: process.env.FLIGHTS_PROVIDER || 'mock',
    offerId,
    summary: 'Tarifa mock para homologacao: validar regra real no retorno do fornecedor.',
    penalty: 'Alteracao e cancelamento sujeitos a multa, diferenca tarifaria e regra da companhia.',
    baggage: '1 bagagem de mao inclusa. Bagagem despachada conforme familia tarifaria retornada.',
    refundable: false,
    timestamp: new Date().toISOString(),
  });
};

function setCorsHeaders(response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

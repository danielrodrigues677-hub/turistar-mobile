const DEFAULT_AMADEUS_BASE_URL = 'https://test.api.amadeus.com';

const tokenCache = new Map();

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

  try {
    const query = normalizeQuery(request.query);
    const provider = activeProvider();
    const providerPayload = provider === 'wooba'
      ? await searchWoobaFlightOffers(query)
      : await searchAmadeusFlightOffers(query);

    response.status(200).json({
      source: provider,
      items: normalizeFlightOffers(providerPayload, provider),
      data: providerPayload.data || providerPayload.results || providerPayload.items || [],
      raw: providerPayload,
    });
  } catch (error) {
    const statusCode = error.statusCode || 500;
    response.status(statusCode).json({
      error: error.message || 'Unexpected flight search error',
    });
  }
};

function setCorsHeaders(response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function activeProvider() {
  return String(process.env.FLIGHTS_PROVIDER || 'amadeus').trim().toLowerCase();
}

function normalizeQuery(query) {
  const originLocationCode = iataCode(query.originLocationCode || query.origin);
  const destinationLocationCode = iataCode(query.destinationLocationCode || query.destination);
  const departureDate = isoDate(query.departureDate);
  const returnDate = query.returnDate ? isoDate(query.returnDate) : undefined;
  const adults = integerInRange(query.adults, 1, 9, 1);
  const max = integerInRange(query.max, 1, 50, 10);
  const currencyCode = String(query.currencyCode || 'BRL').toUpperCase();

  return {
    originLocationCode,
    destinationLocationCode,
    departureDate,
    returnDate,
    adults,
    max,
    currencyCode,
    travelClass: query.travelClass ? String(query.travelClass).toUpperCase() : undefined,
    nonStop: query.nonStop === 'true' || query.nonStop === true ? 'true' : undefined,
  };
}

function iataCode(value) {
  const normalized = String(value || '').trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(normalized)) {
    const error = new Error(`Invalid IATA code: ${value || ''}`);
    error.statusCode = 400;
    throw error;
  }
  return normalized;
}

function isoDate(value) {
  const normalized = String(value || '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
    const error = new Error(`Invalid date, expected YYYY-MM-DD: ${value || ''}`);
    error.statusCode = 400;
    throw error;
  }
  return normalized;
}

function integerInRange(value, min, max, fallback) {
  const parsed = Number.parseInt(String(value || fallback), 10);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, min), max);
}

async function searchAmadeusFlightOffers(query) {
  const accessToken = await getAmadeusAccessToken();
  const amadeusBaseUrl = process.env.AMADEUS_BASE_URL || DEFAULT_AMADEUS_BASE_URL;
  const searchUrl = new URL('/v2/shopping/flight-offers', amadeusBaseUrl);

  Object.entries(query).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchUrl.searchParams.set(key, String(value));
    }
  });

  const searchResponse = await fetch(searchUrl, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/vnd.amadeus+json, application/json',
    },
  });

  const payload = await searchResponse.json().catch(() => ({}));

  if (!searchResponse.ok) {
    const amadeusError = Array.isArray(payload.errors) && payload.errors.length > 0
      ? payload.errors[0].detail || payload.errors[0].title
      : undefined;
    const error = new Error(amadeusError || 'Failed to search Amadeus flight offers');
    error.statusCode = searchResponse.status;
    throw error;
  }

  return payload;
}

async function getAmadeusAccessToken() {
  const cached = tokenCache.get('amadeus');
  if (cached && Date.now() < cached.expiresAt) {
    return cached.value;
  }

  const clientId = process.env.AMADEUS_API_KEY;
  const clientSecret = process.env.AMADEUS_API_SECRET;

  if (!clientId || !clientSecret) {
    const error = new Error('Missing AMADEUS_API_KEY or AMADEUS_API_SECRET');
    error.statusCode = 500;
    throw error;
  }

  const amadeusBaseUrl = process.env.AMADEUS_BASE_URL || DEFAULT_AMADEUS_BASE_URL;
  const tokenUrl = `${amadeusBaseUrl}/v1/security/oauth2/token`;
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: clientId,
    client_secret: clientSecret,
  });

  const tokenResponse = await fetch(tokenUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  const tokenPayload = await tokenResponse.json().catch(() => ({}));

  if (!tokenResponse.ok) {
    const error = new Error(tokenPayload.error_description || tokenPayload.error || 'Failed to authenticate with Amadeus');
    error.statusCode = tokenResponse.status;
    throw error;
  }

  return cacheToken('amadeus', tokenPayload.access_token, tokenPayload.expires_in);
}

async function searchWoobaFlightOffers(query) {
  const woobaBaseUrl = requiredEnv('WOOBA_BASE_URL');
  const searchPath = process.env.WOOBA_FLIGHTS_SEARCH_PATH || '/flights/search';
  const requestMethod = String(process.env.WOOBA_REQUEST_METHOD || 'POST').toUpperCase();
  const searchUrl = new URL(searchPath, woobaBaseUrl);
  const woobaPayload = buildWoobaSearchPayload(query);
  const headers = {
    Accept: 'application/json',
    ...await woobaAuthHeaders(),
  };

  const requestOptions = {
    method: requestMethod,
    headers,
  };

  if (requestMethod === 'GET') {
    Object.entries(flattenForQuery(woobaPayload)).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        searchUrl.searchParams.set(key, String(value));
      }
    });
  } else {
    headers['Content-Type'] = 'application/json';
    requestOptions.body = JSON.stringify(woobaPayload);
  }

  const woobaResponse = await fetch(searchUrl, requestOptions);
  const text = await woobaResponse.text();
  const payload = parseBody(text);

  if (!woobaResponse.ok) {
    const errorMessage = extractErrorMessage(payload) || `Failed to search Wooba flight offers (${woobaResponse.status})`;
    const error = new Error(errorMessage);
    error.statusCode = woobaResponse.status;
    throw error;
  }

  return payload;
}

function buildWoobaSearchPayload(query) {
  const passengers = [{ type: 'ADT', quantity: query.adults }];
  const payload = {
    originLocationCode: query.originLocationCode,
    destinationLocationCode: query.destinationLocationCode,
    departureDate: query.departureDate,
    returnDate: query.returnDate,
    adults: query.adults,
    passengers,
    currencyCode: query.currencyCode,
    max: query.max,
    travelClass: query.travelClass,
    nonStop: query.nonStop,
    tripType: query.returnDate ? 'ROUND_TRIP' : 'ONE_WAY',
  };

  // Common Portuguese aliases keep the proxy ready for SOAP/REST wrappers or
  // normalized Wooba endpoints without changing the Flutter client.
  payload.origem = query.originLocationCode;
  payload.destino = query.destinationLocationCode;
  payload.dataIda = query.departureDate;
  payload.dataVolta = query.returnDate;
  payload.adultos = query.adults;
  payload.moeda = query.currencyCode;

  return removeEmptyValues(payload);
}

async function woobaAuthHeaders() {
  const method = String(process.env.WOOBA_AUTH_METHOD || 'auto').toLowerCase();

  if (method === 'none') {
    return {};
  }

  if (process.env.WOOBA_BEARER_TOKEN) {
    return { Authorization: `Bearer ${process.env.WOOBA_BEARER_TOKEN}` };
  }

  if (process.env.WOOBA_AUTH_URL) {
    return { Authorization: `Bearer ${await getWoobaAccessToken()}` };
  }

  if (process.env.WOOBA_API_KEY) {
    const headerName = process.env.WOOBA_API_KEY_HEADER || 'x-api-key';
    return { [headerName]: process.env.WOOBA_API_KEY };
  }

  if (process.env.WOOBA_USERNAME && process.env.WOOBA_PASSWORD) {
    const credentials = Buffer.from(`${process.env.WOOBA_USERNAME}:${process.env.WOOBA_PASSWORD}`).toString('base64');
    return { Authorization: `Basic ${credentials}` };
  }

  if (method === 'auto') {
    const error = new Error('Wooba auth not configured. Set WOOBA_AUTH_URL, WOOBA_BEARER_TOKEN, WOOBA_API_KEY, or WOOBA_USERNAME/WOOBA_PASSWORD.');
    error.statusCode = 500;
    throw error;
  }

  const error = new Error(`Unsupported WOOBA_AUTH_METHOD: ${method}`);
  error.statusCode = 500;
  throw error;
}

async function getWoobaAccessToken() {
  const cached = tokenCache.get('wooba');
  if (cached && Date.now() < cached.expiresAt) {
    return cached.value;
  }

  const tokenUrl = process.env.WOOBA_AUTH_URL;
  const bodyStyle = String(process.env.WOOBA_AUTH_BODY_STYLE || 'json').toLowerCase();
  const credentials = woobaAuthPayload();
  const headers = {};
  const requestOptions = { method: 'POST', headers };

  if (bodyStyle === 'form') {
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    requestOptions.body = new URLSearchParams(credentials);
  } else {
    headers['Content-Type'] = 'application/json';
    requestOptions.body = JSON.stringify(credentials);
  }

  const tokenResponse = await fetch(tokenUrl, requestOptions);
  const tokenPayload = parseBody(await tokenResponse.text());

  if (!tokenResponse.ok) {
    const error = new Error(extractErrorMessage(tokenPayload) || 'Failed to authenticate with Wooba');
    error.statusCode = tokenResponse.status;
    throw error;
  }

  const accessToken = tokenPayload.access_token || tokenPayload.accessToken || tokenPayload.token || tokenPayload.Token;
  if (!accessToken) {
    const error = new Error('Wooba auth response did not include a token');
    error.statusCode = 500;
    throw error;
  }

  return cacheToken('wooba', accessToken, tokenPayload.expires_in || tokenPayload.expiresIn || tokenPayload.expiraEm);
}

function woobaAuthPayload() {
  const payload = {
    client_id: process.env.WOOBA_CLIENT_ID,
    client_secret: process.env.WOOBA_CLIENT_SECRET,
    username: process.env.WOOBA_USERNAME,
    password: process.env.WOOBA_PASSWORD,
    grant_type: process.env.WOOBA_GRANT_TYPE || (process.env.WOOBA_CLIENT_ID ? 'client_credentials' : undefined),
  };

  return removeEmptyValues(payload);
}

function cacheToken(provider, token, expiresIn) {
  const ttl = Math.max(Number.parseInt(String(expiresIn || 3600), 10) - 60, 60);
  tokenCache.set(provider, {
    value: token,
    expiresAt: Date.now() + ttl * 1000,
  });
  return token;
}

function normalizeFlightOffers(payload, provider) {
  const normalizedItems = payload && Array.isArray(payload.items) ? payload.items : undefined;
  if (normalizedItems) {
    return normalizedItems.map((item) => normalizeGenericOffer(item, provider));
  }

  const amadeusOffers = payload && Array.isArray(payload.data) ? payload.data : undefined;
  if (provider === 'amadeus' && amadeusOffers) {
    return amadeusOffers.map(normalizeAmadeusOffer);
  }

  return extractOfferArray(payload).map((offer) => normalizeGenericOffer(offer, provider));
}

function normalizeAmadeusOffer(offer) {
  const itinerary = Array.isArray(offer.itineraries) ? offer.itineraries[0] : undefined;
  const segments = itinerary && Array.isArray(itinerary.segments) ? itinerary.segments : [];
  const firstSegment = segments[0] || {};
  const lastSegment = segments[segments.length - 1] || firstSegment;
  const carrier = firstSegment.carrierCode || firstString(offer.validatingAirlineCodes) || 'Cia aerea';
  const flightNumber = firstSegment.number ? `${carrier} ${firstSegment.number}` : carrier;
  const departureCode = firstSegment.departure && firstSegment.departure.iataCode ? firstSegment.departure.iataCode : '---';
  const arrivalCode = lastSegment.arrival && lastSegment.arrival.iataCode ? lastSegment.arrival.iataCode : '---';
  const departureTime = timeFromDateTime(firstSegment.departure && firstSegment.departure.at);
  const arrivalTime = timeFromDateTime(lastSegment.arrival && lastSegment.arrival.at);
  const total = offer.price && (offer.price.grandTotal || offer.price.total) ? offer.price.grandTotal || offer.price.total : 'Consultar';
  const currency = offer.price && offer.price.currency ? offer.price.currency : 'BRL';
  const stops = segments.length <= 1 ? 'Direto' : `${segments.length - 1} parada(s)`;

  return {
    title: flightNumber,
    subtitle: `${departureCode} - ${arrivalCode} | ${departureTime} - ${arrivalTime}`,
    details: `${formatDuration(itinerary && itinerary.duration)} - ${stops}`,
    price: `${currency} ${total}`,
    badge: 'API Amadeus',
  };
}

function normalizeGenericOffer(offer, provider) {
  const airline = pickString(offer, ['title', 'airline', 'airlineName', 'cia', 'ciaAerea', 'companhia', 'nomeCompanhia', 'carrier', 'carrierCode']) || 'Oferta de voo';
  const flightNumber = pickString(offer, ['flightNumber', 'numeroVoo', 'voo', 'number']);
  const origin = pickString(offer, ['origin', 'origem', 'originLocationCode', 'departureAirport', 'aeroportoOrigem']) || '---';
  const destination = pickString(offer, ['destination', 'destino', 'destinationLocationCode', 'arrivalAirport', 'aeroportoDestino']) || '---';
  const departure = pickString(offer, ['departureTime', 'saida', 'horaSaida', 'departureDateTime', 'departure']) || '--:--';
  const arrival = pickString(offer, ['arrivalTime', 'chegada', 'horaChegada', 'arrivalDateTime', 'arrival']) || '--:--';
  const duration = pickString(offer, ['duration', 'duracao', 'tempoVoo']) || 'Duracao nao informada';
  const stops = pickString(offer, ['stops', 'paradas', 'conexoes']) || 'Consultar paradas';
  const price = pickPrice(offer);

  return {
    title: flightNumber ? `${airline} ${flightNumber}` : airline,
    subtitle: `${origin} - ${destination} | ${formatTime(departure)} - ${formatTime(arrival)}`,
    details: `${duration} - ${stops}`,
    price,
    badge: provider === 'wooba' ? 'API Wooba' : 'API',
  };
}

function extractOfferArray(payload) {
  if (Array.isArray(payload)) {
    return payload;
  }

  if (!payload || typeof payload !== 'object') {
    return [];
  }

  const directKeys = ['results', 'data', 'offers', 'ofertas', 'flights', 'voos', 'itineraries', 'disponibilidades'];
  for (const key of directKeys) {
    if (Array.isArray(payload[key])) {
      return payload[key];
    }
  }

  for (const value of Object.values(payload)) {
    if (Array.isArray(value) && value.length > 0 && typeof value[0] === 'object') {
      return value;
    }
  }

  return [];
}

function pickString(object, keys) {
  for (const key of keys) {
    const value = object && object[key];
    if (value !== undefined && value !== null && value !== '') {
      if (typeof value === 'object') {
        const nested = value.iataCode || value.codigo || value.code || value.name || value.nome || value.at;
        if (nested) return String(nested);
      } else {
        return String(value);
      }
    }
  }
  return undefined;
}

function pickPrice(offer) {
  const direct = pickString(offer, ['price', 'preco', 'total', 'valor', 'tarifa']);
  if (direct) {
    return direct.startsWith('R$') || /^[A-Z]{3}\s/.test(direct) ? direct : `R$ ${direct}`;
  }

  const priceObject = offer && (offer.price || offer.preco || offer.valorTotal || offer.totalPrice);
  if (priceObject && typeof priceObject === 'object') {
    const currency = priceObject.currency || priceObject.moeda || 'BRL';
    const total = priceObject.grandTotal || priceObject.total || priceObject.amount || priceObject.valor || 'Consultar';
    return `${currency} ${total}`;
  }

  return 'Consultar';
}

function firstString(value) {
  return Array.isArray(value) && value.length > 0 ? String(value[0]) : undefined;
}

function timeFromDateTime(value) {
  if (!value || !String(value).includes('T')) {
    return '--:--';
  }
  return String(value).split('T')[1].slice(0, 5);
}

function formatTime(value) {
  const text = String(value || '');
  if (text.includes('T')) return timeFromDateTime(text);
  const match = text.match(/\d{2}:\d{2}/);
  return match ? match[0] : text;
}

function formatDuration(value) {
  if (!value) {
    return 'Duracao nao informada';
  }
  return String(value)
    .replace(/^PT/, '')
    .replace('H', 'h ')
    .replace('M', 'm')
    .trim();
}

function flattenForQuery(object) {
  return Object.entries(object).reduce((accumulator, [key, value]) => {
    if (Array.isArray(value) || (value && typeof value === 'object')) {
      accumulator[key] = JSON.stringify(value);
    } else {
      accumulator[key] = value;
    }
    return accumulator;
  }, {});
}

function removeEmptyValues(object) {
  return Object.entries(object).reduce((accumulator, [key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      accumulator[key] = value;
    }
    return accumulator;
  }, {});
}

function parseBody(text) {
  if (!text) {
    return {};
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    return { raw: text };
  }
}

function extractErrorMessage(payload) {
  if (!payload || typeof payload !== 'object') {
    return undefined;
  }
  if (payload.error) return String(payload.error);
  if (payload.message) return String(payload.message);
  if (payload.mensagem) return String(payload.mensagem);
  if (Array.isArray(payload.errors) && payload.errors.length > 0) {
    const first = payload.errors[0];
    return first.detail || first.title || first.message || String(first);
  }
  return undefined;
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    const error = new Error(`Missing ${name}`);
    error.statusCode = 500;
    throw error;
  }
  return value;
}

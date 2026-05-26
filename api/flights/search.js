const DEFAULT_AMADEUS_BASE_URL = 'https://test.api.amadeus.com';

let cachedToken = null;
let cachedTokenExpiresAt = 0;

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
    const accessToken = await getAccessToken();
    const amadeusPayload = await searchFlightOffers(query, accessToken);

    response.status(200).json({
      source: 'amadeus',
      items: normalizeFlightOffers(amadeusPayload),
      data: amadeusPayload.data || [],
      dictionaries: amadeusPayload.dictionaries || {},
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

async function getAccessToken() {
  if (cachedToken && Date.now() < cachedTokenExpiresAt) {
    return cachedToken;
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

  cachedToken = tokenPayload.access_token;
  cachedTokenExpiresAt = Date.now() + Math.max((tokenPayload.expires_in || 0) - 60, 60) * 1000;
  return cachedToken;
}

async function searchFlightOffers(query, accessToken) {
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
    const error = new Error(amadeusError || 'Failed to search flight offers');
    error.statusCode = searchResponse.status;
    throw error;
  }

  return payload;
}

function normalizeFlightOffers(payload) {
  const offers = Array.isArray(payload.data) ? payload.data : [];

  return offers.map((offer) => {
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
  });
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

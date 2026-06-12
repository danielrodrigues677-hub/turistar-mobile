# Wooba / Travellink homologation checklist

This checklist tracks the minimum flow needed to prepare the Turistar site for
Wooba homologation. The current implementation uses mock responses for booking
steps and keeps provider credentials only in the backend environment
(Firebase Cloud Functions secrets or equivalent).

## Current mock flow

- [x] Flight search through `GET /api/flights/search`
- [x] Fare rules through `GET /api/flights/rules`
- [x] Passenger data capture in Flutter
- [x] Booking review before reservation
- [x] Mock booking creation through `POST /api/bookings/create`
- [x] Booking lookup through `GET /api/bookings/get`
- [x] Booking cancellation through `POST /api/bookings/cancel`
- [x] Fallback to demo data when provider credentials are unavailable
- [x] Provider switch prepared with `FLIGHTS_PROVIDER=wooba`

## Environment variables for Wooba

Set these in the backend environment when Wooba provides the official sandbox
credentials (for example Firebase Cloud Functions config/secrets):

```text
FLIGHTS_PROVIDER=wooba
WOOBA_BASE_URL=https://...
WOOBA_FLIGHTS_SEARCH_PATH=/...
WOOBA_REQUEST_METHOD=POST
```

Authentication will depend on the credential package received:

```text
WOOBA_AUTH_URL=https://...
WOOBA_AUTH_BODY_STYLE=json
WOOBA_CLIENT_ID=...
WOOBA_CLIENT_SECRET=...
WOOBA_GRANT_TYPE=client_credentials
```

or:

```text
WOOBA_BEARER_TOKEN=...
```

or:

```text
WOOBA_API_KEY=...
WOOBA_API_KEY_HEADER=x-api-key
```

or:

```text
WOOBA_USERNAME=...
WOOBA_PASSWORD=...
```

## Evidence to collect during homologation

For each scenario, save request, response, timestamp, and screen capture:

1. One-way flight search.
2. Round-trip flight search.
3. No availability / empty result treatment.
4. Provider error treatment.
5. Fare rules retrieval.
6. Booking creation with valid passenger data.
7. Booking lookup by locator.
8. Booking cancellation.
9. Invalid passenger data validation.
10. Timeout or provider unavailable fallback.

## Mapping still pending real documentation

These fields must be confirmed against the official Wooba/Travellink contract:

- Search endpoint path.
- Authentication method and token payload.
- Request body field names for air availability.
- Offer identifier used for fare rules and booking.
- Passenger document requirements.
- Required contact and billing fields.
- Booking response locator/status fields.
- Cancellation endpoint and allowed statuses.
- Error code catalog.

## Acceptance target

The Flutter app should keep calling stable Turistar endpoints:

```text
/api/flights/search
/api/flights/rules
/api/bookings/create
/api/bookings/get
/api/bookings/cancel
```

Only the backend provider adapter should change when replacing mock behavior with
the real Wooba/Travellink sandbox contract.

# Turistar Mobile

Aplicativo Flutter limpo para a experiencia mobile e web da Turistar.

## O que esta incluido

- Home mobile-first com identidade Turistar em azul e laranja
- Landing page web inspirada no layout Turistar Premium
- Busca inicial para voos, hoteis, carros e pacotes
- Resultados simulados para voos, hoteis, carros e pacotes
- Layout responsivo para desktop, tablet e mobile
- Tela de login/cadastro pronta para futura autenticacao real
- Estrutura pronta para substituir dados simulados por chamadas de API
- Projeto sem assets ou dependencias externas obrigatorias

## Estrutura principal

```text
lib/
`-- main.dart
```

Toda a interface inicial esta concentrada em `lib/main.dart` para manter a base simples e facil de evoluir.

## Como executar

```bash
flutter pub get
flutter create . --platforms=android,ios,web
flutter run
```

Para testar no navegador:

```bash
flutter create . --platforms=web
flutter run -d chrome
```

## Integracao de fornecedores

O app esta preparado para buscar voos reais por meio de um backend/proxy seguro.
Nao coloque secrets de fornecedores no Flutter.

Fluxo recomendado:

```text
Flutter/Web -> Vercel Function -> fornecedor de voos
```

O backend deve expor:

```text
GET /flights/search
GET /flights/rules
POST /bookings/create
GET /bookings/get
POST /bookings/cancel
```

Com query params compativeis com a Amadeus:

```text
originLocationCode=GRU
destinationLocationCode=MIA
departureDate=2026-06-20
returnDate=2026-06-27
adults=1
currencyCode=BRL
max=10
```

O backend pode devolver a resposta bruta da Amadeus (`data`) ou uma lista
normalizada em `items`.

Para apontar o Flutter para o backend:

```bash
flutter run -d chrome --dart-define=TURISTAR_FLIGHTS_API_BASE_URL=https://seu-backend.com/api
```

Se a variavel nao estiver configurada ou a API falhar, o app mostra dados
demonstrativos automaticamente.

### Proxy Vercel incluido

Este repositorio ja inclui uma Vercel Function em:

```text
api/flights/search.js
```

Ela suporta `FLIGHTS_PROVIDER=amadeus` e `FLIGHTS_PROVIDER=wooba`.

### Amadeus

```text
FLIGHTS_PROVIDER=amadeus
AMADEUS_API_KEY=sua_api_key
AMADEUS_API_SECRET=seu_api_secret
AMADEUS_BASE_URL=https://test.api.amadeus.com
```

### Wooba / Travellink

Quando receber os acessos oficiais da Wooba, configure:

```text
FLIGHTS_PROVIDER=wooba
WOOBA_BASE_URL=https://url-oficial-da-wooba
WOOBA_FLIGHTS_SEARCH_PATH=/caminho/oficial/de/busca/aerea
WOOBA_REQUEST_METHOD=POST
```

Escolha tambem uma forma de autenticacao, conforme a documentacao/credenciais
recebidas:

```text
# OAuth/token endpoint
WOOBA_AUTH_URL=https://url-oficial-da-wooba/oauth/token
WOOBA_AUTH_BODY_STYLE=json
WOOBA_CLIENT_ID=seu_client_id
WOOBA_CLIENT_SECRET=seu_client_secret
WOOBA_GRANT_TYPE=client_credentials
```

ou:

```text
# Bearer token fixo
WOOBA_BEARER_TOKEN=seu_token
```

ou:

```text
# API key
WOOBA_API_KEY=sua_api_key
WOOBA_API_KEY_HEADER=x-api-key
```

ou:

```text
# Basic auth
WOOBA_USERNAME=seu_usuario
WOOBA_PASSWORD=sua_senha
```

Depois do deploy, o endpoint ficara disponivel em:

```text
https://seu-projeto.vercel.app/api/flights/search
```

Para rodar o Flutter Web usando esse proxy:

```bash
flutter run -d chrome --dart-define=TURISTAR_FLIGHTS_API_BASE_URL=https://seu-projeto.vercel.app/api
```

## Fluxo de homologacao Wooba

O projeto tambem inclui endpoints mock para exercitar o fluxo de homologacao
antes da credencial real:

```text
GET /api/flights/rules
POST /api/bookings/create
GET /api/bookings/get
POST /api/bookings/cancel
```

O checklist de cenarios esta em:

```text
docs/wooba-homologation-checklist.md
```

## Validacao recomendada

```bash
flutter analyze
flutter test
```

> Observacao: o ambiente atual do agente nao possui Flutter/Dart instalados, entao essas validacoes precisam ser executadas em uma maquina com o SDK Flutter configurado.

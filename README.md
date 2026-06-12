# Turistar Mobile

Aplicativo Flutter limpo para a experiencia mobile e web da Turistar.

## O que esta incluido

- Home mobile-first com identidade Turistar em azul e laranja
- Landing page web inspirada no layout Turistar Premium
- Busca inicial para voos, hoteis, carros e pacotes
- Calendario para selecao de datas e seletor de passageiros/carros
- Area "Minhas Reservas" com historico mockado do cliente
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

## Fase 1 - leads via WhatsApp

Os botoes de busca e os pacotes mais vendidos abrem o WhatsApp comercial com
uma mensagem de cotacao pronta. Numero padrao: **+55 11 97891-6580**
(`5511978916580`).

```bash
flutter run -d chrome --dart-define=TURISTAR_WHATSAPP_NUMBER=5511978916580
```

## Deploy no Firebase Hosting

O site web esta publicado no **Firebase Hosting** (projeto `app-turistar`):

```text
https://app-turistar.web.app
```

### Build e deploy

```bash
flutter pub get
flutter build web --dart-define=TURISTAR_WHATSAPP_NUMBER=5511978916580
firebase deploy --only hosting
```

Requisitos: [Firebase CLI](https://firebase.google.com/docs/cli) instalado e
login feito com `firebase login`.

Arquivos de configuracao:

```text
firebase.json   # aponta para build/web
.firebaserc     # projeto app-turistar
```

## Integracao de fornecedores

O app esta preparado para buscar voos reais por meio de um backend/proxy seguro.
Nao coloque secrets de fornecedores no Flutter.

Fluxo recomendado:

```text
Flutter/Web -> backend/proxy -> fornecedor de voos
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

### Proxy de voos incluido (fase futura)

Este repositorio ja inclui handlers em `api/` (formato serverless) para:

```text
api/flights/search.js
api/flights/rules.js
api/bookings/create.js
api/bookings/get.js
api/bookings/cancel.js
```

Eles suportam `FLIGHTS_PROVIDER=amadeus` e `FLIGHTS_PROVIDER=wooba`.
Na Fase 1 atual o site usa WhatsApp e nao depende desses endpoints.
Quando reativar a API, publique esse codigo em **Firebase Cloud Functions**
(ou outro backend) e configure os secrets no ambiente do provedor escolhido.

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

Depois do deploy do backend, o endpoint ficara disponivel em:

```text
https://seu-dominio/api/flights/search
```

Para rodar o Flutter Web usando esse proxy:

```bash
flutter run -d chrome --dart-define=TURISTAR_FLIGHTS_API_BASE_URL=https://seu-dominio/api
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

> Observacao: execute `flutter analyze` e `flutter test` em uma maquina com o
> SDK Flutter configurado antes de cada deploy.

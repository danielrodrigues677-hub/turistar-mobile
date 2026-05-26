# Turistar Mobile

Aplicativo Flutter limpo para a experiencia mobile e web da Turistar.

## O que esta incluido

- Home mobile-first com identidade Turistar em azul e laranja
- Landing page web inspirada no layout Turistar Premium
- Busca inicial para voos, hoteis, carros e pacotes
- Resultados simulados para voos, hoteis, carros e pacotes
- Layout responsivo para desktop, tablet e mobile
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

## Integracao Amadeus

O app esta preparado para buscar voos reais por meio de um backend/proxy seguro.
Nao coloque `AMADEUS_API_SECRET` no Flutter.

Fluxo recomendado:

```text
Flutter/Web -> seu backend -> Amadeus Flight Offers Search
```

O backend deve expor:

```text
GET /flights/search
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

No painel da Vercel, configure as variaveis de ambiente:

```text
AMADEUS_API_KEY=sua_api_key
AMADEUS_API_SECRET=seu_api_secret
AMADEUS_BASE_URL=https://test.api.amadeus.com
```

Depois do deploy, o endpoint ficara disponivel em:

```text
https://seu-projeto.vercel.app/api/flights/search
```

Para rodar o Flutter Web usando esse proxy:

```bash
flutter run -d chrome --dart-define=TURISTAR_FLIGHTS_API_BASE_URL=https://seu-projeto.vercel.app/api
```

## Validacao recomendada

```bash
flutter analyze
flutter test
```

> Observacao: o ambiente atual do agente nao possui Flutter/Dart instalados, entao essas validacoes precisam ser executadas em uma maquina com o SDK Flutter configurado.

# Turistar Mobile

Aplicativo Flutter limpo para a experiencia mobile e web da Turistar.

## O que esta incluido

- Home mobile-first com identidade Turistar em azul e laranja
- Landing page web inspirada no layout Turistar Premium
- Busca inicial para voos, hoteis, carros e pacotes
- Lista de ofertas de voos com selecao
- Checkout com formulario de passageiro e metodo de pagamento
- Tela de confirmacao de reserva
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

## Validacao recomendada

```bash
flutter analyze
flutter test
```

> Observacao: o ambiente atual do agente nao possui Flutter/Dart instalados, entao essas validacoes precisam ser executadas em uma maquina com o SDK Flutter configurado.

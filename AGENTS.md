# AGENTS.md

## Cursor Cloud specific instructions

This repo is a single product: **Turistar Mobile**, a Flutter (Dart) cross-platform travel-booking app
(`lib/main.dart`), plus an optional dependency-free Vercel serverless proxy under `api/` (Node.js).

### Environment

- The **Flutter SDK** (stable, includes Dart) is installed at `/home/ubuntu/flutter` and added to `PATH`
  via `~/.bashrc`. New login shells (e.g. `bash -l`, tmux login sessions) pick it up automatically; if a
  shell does not have it, run `export PATH="$PATH:/home/ubuntu/flutter/bin"`.
- The startup update script runs `flutter pub get`. It does **not** reinstall the SDK (the SDK persists in
  the VM snapshot).
- The platform folders (`android/`, `ios/`, `web/`) are gitignored and are not committed. The `web/` folder
  is generated with `flutter create . --platforms=web`. It persists in the VM snapshot, but if it is ever
  missing, regenerate it with that command before running/building for web.

### Run / lint / test (web is the runnable target in this headless VM)

- Run (dev mode): `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`. First compile takes
  ~15-20s. Open `http://localhost:8080/` in Chrome (`/usr/local/bin/google-chrome`).
- Lint: `flutter analyze`. Note: it currently exits non-zero, but **only `info`-level lints** exist in
  `lib/main.dart` (e.g. `withOpacity` deprecation, brace-in-string interps) — there are no errors/warnings.
- Test: `flutter test`. Note: the widget tests in `test/widget_test.dart` currently **fail** due to
  pre-existing `RenderFlex overflowed` layout errors at the default 800x600 test surface (the `HeroStats`
  `Row` overflows). This is a code/test issue, not an environment issue.

### Key behavior

- The app talks only to stable `/api/*` endpoints and **auto-falls back to demo/mock flight data** when
  `TURISTAR_FLIGHTS_API_BASE_URL` is unset or the backend is unreachable. So the full UI (including flight
  search results) is demoable with **no backend running**.
- To point the app at a backend: `flutter run -d chrome --dart-define=TURISTAR_FLIGHTS_API_BASE_URL=<url>`.
- The `api/` Vercel functions have **no `package.json` / npm deps** (use global `fetch`); they require
  the Vercel CLI (`vercel dev`) to run locally and are optional. Real flight search needs Amadeus/Wooba
  credentials (see `README.md`).

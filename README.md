# RAHI

RAHI is a Flutter-based smart navigation application.

## Current bootstrap

Development branch: `bootstrap-v0.1.0`

CI gates:
- Dart formatting
- Flutter static analysis
- Unit tests
- Android debug APK build

## Development policy

- Real API tokens must never be committed.
- Mapping providers are isolated behind `MapService`.
- CI must pass before changes are merged into `main`.

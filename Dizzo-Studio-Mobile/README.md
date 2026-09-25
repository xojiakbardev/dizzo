# Dizzo (mobile)

The Dizzo customer app: design mugs, clocks, T-shirts, hoodies, caps and
business cards, then order them. Built with Flutter for Android and iOS.

- Architecture, conventions and how to add screens: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Build config: `config/prod.json` holds the public ids (API, Google,
  Telegram). Run with `flutter run --dart-define-from-file=config/prod.json`,
  or copy it to `config/dev.json` (ignored by git) for local changes.

```
flutter analyze
flutter test
flutter build apk --debug
```

## Release builds

Step by step for the stores (keystore, App Links files, Play/App Store
checklists): [RELEASE.md](RELEASE.md); listing texts: `store/listing_uz.md`.

Signing: put the upload keystore's `key.properties` (`storePassword`,
`keyPassword`, `keyAlias`, `storeFile`) at `android/key.properties`, or point
`DIZZO_KEY_PROPERTIES` at it. Never commit it or the `.jks`.

```
export DIZZO_KEY_PROPERTIES='D:\Hojiakbar\keys\key.properties'   # bash
$env:DIZZO_KEY_PROPERTIES='D:\Hojiakbar\keys\key.properties'     # PowerShell

# Play Store bundle
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json

# APKs per ABI (direct installs, testing)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json

# iOS (on a Mac)
flutter build ipa --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
```

Keep `build/symbols` for each release. You need it to read obfuscated stack
traces (`flutter symbolize`, or upload it to Play Console). The version comes
from `pubspec.yaml`: `version: 1.2.3+45` gives versionName 1.2.3 and
versionCode 45.

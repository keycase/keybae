# Keybae

Flutter client for [KeyCase](https://github.com/keycase). Manage your cryptographic identity across iOS, Android, desktop, and web.

Part of the [KeyCase](https://github.com/keycase) ecosystem. See the [spec](https://github.com/keycase/spec) for the full vision.

## Setup

```bash
git clone https://github.com/keycase/keybae.git
cd keybae
flutter create . --platforms=ios,android,macos,linux,windows,web
flutter pub get
flutter run
```

Note: Run `flutter create .` after cloning to generate platform directories.

## Architecture

```
lib/
  main.dart                    # entry point
  app.dart                     # MaterialApp, routing, theming
  screens/
    home_screen.dart            # bottom nav with tabs
    identity_screen.dart        # identity management
    proofs_screen.dart          # proof management
    settings_screen.dart        # server config, key management
  services/
    keycase_client.dart         # HTTP client for KeyCase server
```

## Dependencies

- [keycase_core](https://github.com/keycase/core) — shared models and crypto
- Flutter 3.x

## Features

- **Identity** — Create and manage your cryptographic key pair
- **Proofs** — Link your identity to domains (DNS) and URLs
- **Discover** — Find and verify other KeyCase identities
- **Settings** — Configure server, manage keys, preferences

## License

BSD-3-Clause

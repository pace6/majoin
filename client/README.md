# majoin client

Flutter chat client for the **majoin** project — a LINE-style chat over
[Matrix](https://matrix.org). Targets Android, iOS, macOS, Windows, Linux.

See the [repository README](../README.md) for the full monorepo layout and
production setup.

## Run

```bash
flutter pub get
flutter run -d macos        # or any connected device
```

Homeserver is hardcoded in [lib/core/config.dart](lib/core/config.dart)
(`https://chat.tokens2.io`). Register in-app on the login screen.

## Layout

```
lib/
├── core/        auth, Matrix client, i18n, push, storage, config
├── features/    call, flex, home, rooms, stickers, timeline
└── ui/          pages, shells, theme, widgets
```

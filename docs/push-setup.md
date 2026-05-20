# Push notifications — FCM setup

majoin uses two notification layers:

1. **Local notifications** — driven by the live Matrix `/sync` stream. Works on
   every platform while the app is running (incl. desktop). No setup needed.
2. **FCM remote push** — relayed Synapse → sygnal → FCM/APNs. Delivers
   notifications while the app is backgrounded or killed on Android & iOS.

The client code (`client/lib/core/push/push_service.dart`) is already wired.
Remote push stays **inactive until the Firebase config files below are added** —
without them `Firebase.initializeApp()` fails gracefully and only layer 1 runs.

## 1. Create a Firebase project

1. <https://console.firebase.google.com> → add project.
2. Add an **Android app**, package name `app.majoin.majoin`.
3. Add an **iOS app**, bundle id `app.majoin.ios` (match Xcode bundle id).

## 2. Drop the config files

| File | Destination | Notes |
|------|-------------|-------|
| `google-services.json` | `client/android/app/` | gitignored |
| `GoogleService-Info.plist` | `client/ios/Runner/` | gitignored, add to Xcode target |

The Android Gradle plugin (`com.google.gms.google-services`) is applied
**only when `google-services.json` exists** — see `android/app/build.gradle.kts`.
No file → build still succeeds, remote push off.

## 3. iOS / APNs

- Xcode → Runner target → Signing & Capabilities → add **Push Notifications**.
- Upload an APNs key/cert to Firebase project settings → Cloud Messaging.
- Drop the APNs `.p12` (or use a token key) into `infra/sygnal/keys/`.

## 4. sygnal gateway

Edit `infra/sygnal/sygnal.yaml`:

- `app.majoin.android` → `api_key`: path to the **FCM v1 service account JSON**
  (download from Firebase → Project settings → Service accounts).
- `app.majoin.ios` → `certfile`: `/sygnal/keys/apns.p12`, set `platform`
  (`sandbox` for dev builds, `production` for release).

`AppConfig.pushGatewayUrl` (`client/lib/core/config.dart`) must point at the
sygnal `/_matrix/push/v1/notify` endpoint exposed through Caddy.

## 5. Verify

1. `flutter run` on a physical device (FCM does not work on emulators without
   Play Services / on the iOS simulator).
2. Log in — the app calls `postPusher` automatically with the FCM token.
3. Check the pusher landed: `GET /_matrix/client/v3/pushers` on the homeserver.
4. Background the app, send a message from another account — a notification
   should arrive.

Push format is `event_id_only`: the FCM payload carries only room/event ids,
so notification content is fetched by the app, never sent in cleartext through
the gateway.

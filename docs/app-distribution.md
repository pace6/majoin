# App distribution — Firebase App Distribution

The Flutter client ships to testers via **Firebase App Distribution**, driven
by `.github/workflows/distribute-app.yml`. Android builds on every run; iOS
builds only when `IOS_ENABLED` repo variable is `true`.

## How a release works

1. Bump `version:` in `client/pubspec.yaml` (e.g. `0.1.1+2`).
2. Tag and push:
   ```bash
   git tag app-v0.1.1
   git push origin app-v0.1.1
   ```
   — or run the workflow manually from the Actions tab (lets you type
   release notes).
3. CI builds → uploads to Firebase → testers in the `testers` group get a
   notification + install link.

## One-time setup

### 1. Firebase project

Reuse the existing FCM project if there is one (see `docs/push-setup.md`),
otherwise create a project at <https://console.firebase.google.com>.

- **Add an Android app** — package name `app.majoin.majoin`.
- **Add an iOS app** — bundle id `app.majoin.majoin2`.

Copy each app's **App ID** (looks like `1:1234567890:android:abc123`) from
Project settings → General.

### 2. Service account (CI auth)

Firebase console → Project settings → Service accounts → Generate new private
key. This downloads a JSON file. The service account needs the
**Firebase App Distribution Admin** role (grant it in the GCP IAM console if
missing).

### 3. Tester group

App Distribution → Testers & Groups → create a group named **`testers`** and
add tester emails. (Change `FIREBASE_GROUPS` in the workflow to rename.)

### 4. Android release keystore

Generate once, keep the `.jks` safe — losing it means testers must uninstall
to take a future build:
```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias majoin
```
Base64-encode it for the GitHub secret:
```bash
base64 -i release.jks | pbcopy
```

### 5. iOS signing (only if distributing iOS)

Requires an **Apple Developer account** ($99/yr). On a Mac with Xcode:

- Create an **Apple Distribution** certificate, export it as `.p12` (with a
  password).
- Create an **Ad Hoc** provisioning profile for bundle id
  `app.majoin.majoin2`, including every tester device UDID. (Or use App
  Distribution's automatic device registration.)
- Base64-encode both:
  ```bash
  base64 -i cert.p12 | pbcopy
  base64 -i majoin.mobileprovision | pbcopy
  ```
- Set the repo **variable** `IOS_ENABLED` = `true` (Settings → Secrets and
  variables → Actions → Variables) to switch the iOS job on.

## GitHub secrets

Settings → Secrets and variables → Actions → Secrets.

| Secret | What |
|--------|------|
| `FIREBASE_SERVICE_ACCOUNT` | full contents of the service-account JSON |
| `FIREBASE_ANDROID_APP_ID` | Firebase Android App ID |
| `ANDROID_KEYSTORE_BASE64` | base64 of `release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias (`majoin` above) |
| `ANDROID_KEY_PASSWORD` | key password |

iOS only (plus repo variable `IOS_ENABLED=true`):

| Secret | What |
|--------|------|
| `FIREBASE_IOS_APP_ID` | Firebase iOS App ID |
| `IOS_CERTIFICATE_BASE64` | base64 of the `.p12` certificate |
| `IOS_CERTIFICATE_PASSWORD` | `.p12` export password |
| `IOS_PROVISIONING_PROFILE_BASE64` | base64 of the `.mobileprovision` |
| `APPLE_TEAM_ID` | 10-char Apple Team ID |

## Local release build (optional)

Android, with signing — drop `release.jks` at `client/android/app/release.jks`
and create `client/android/key.properties`:
```properties
storeFile=release.jks
storePassword=...
keyAlias=majoin
keyPassword=...
```
Then `flutter build apk --release`. Without `key.properties` the release build
falls back to debug signing.

## Notes

- App Distribution is for **testers**, not public store listings. For Play
  Store / App Store, a separate signing + review pipeline is needed.
- The keystore signs every Android build — back it up. A new keystore =
  testers must uninstall before the next update installs.

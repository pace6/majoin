/// App-wide constants. Single place to change brand + endpoints.
class AppConfig {
  static const appName = 'majoin';
  static const homeserver = 'https://chat.tokens2.io';

  /// Sticker store API base (FastAPI service behind Caddy).
  static const stickerApi = 'https://chat.tokens2.io';

  /// Matrix account_data event type holding the user's installed pack IDs.
  static const stickerAccountDataType = 'app.majoin.stickers';

  /// Sygnal push gateway notify endpoint. Registered with Synapse as the
  /// pusher URL; sygnal relays pushes to FCM / APNs. Must match infra/sygnal.
  static const pushGatewayUrl =
      'https://chat.tokens2.io/_matrix/push/v1/notify';

  /// Pusher app IDs — must match the `apps:` keys in infra/sygnal/sygnal.yaml.
  static const fcmAppId = 'app.majoin.android';
  static const apnsAppId = 'app.majoin.ios';
}

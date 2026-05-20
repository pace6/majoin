/// App-wide constants. Single place to change brand + endpoints.
class AppConfig {
  static const appName = 'majoin';
  static const homeserver = 'https://chat.tokens2.io';

  /// Sticker store API base (FastAPI service behind Caddy).
  static const stickerApi = 'https://chat.tokens2.io';

  /// Matrix account_data event type holding the user's installed pack IDs.
  static const stickerAccountDataType = 'app.majoin.stickers';
}

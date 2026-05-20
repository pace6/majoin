import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight i18n. Thai default, English fallback. Persisted in prefs.
///
/// Why not gen_l10n/ARB: MVP — single map cuts boilerplate. Swap to ARB later.
class L10n {
  static const _kLocale = 'locale';
  static const _supported = ['th', 'en'];

  static String get(String key) {
    final l = LocaleController.instance.locale.languageCode;
    final t = _bundles[l]?[key] ?? _bundles['en']?[key];
    return t ?? key;
  }

  static Future<Locale> initialLocale() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_kLocale);
    if (code != null && _supported.contains(code)) return Locale(code);
    return const Locale('th');
  }

  static Future<void> setLocale(String code) async {
    if (!_supported.contains(code)) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocale, code);
  }
}

class LocaleController extends ChangeNotifier {
  LocaleController._(this._locale);
  static late LocaleController instance;

  Locale _locale;
  Locale get locale => _locale;

  static Future<void> init() async {
    final loc = await L10n.initialLocale();
    instance = LocaleController._(loc);
  }

  Future<void> setLocale(Locale loc) async {
    _locale = loc;
    await L10n.setLocale(loc.languageCode);
    notifyListeners();
  }
}

/// Convenience extension: `'login.title'.tr` reads from current locale.
extension TrString on String {
  String get tr => L10n.get(this);
}

const Map<String, Map<String, String>> _bundles = {
  'th': {
    // App
    'app.tagline': 'แชทกับคนทั้งโลก',
    'app.poweredBy': 'Powered by Matrix',

    // Login
    'login.title': 'majoin',
    'login.username': 'ชื่อผู้ใช้',
    'login.password': 'รหัสผ่าน',
    'login.homeserver': 'Homeserver URL',
    'login.changeServer': 'เปลี่ยน server',
    'login.hideServer': 'ซ่อน server',
    'login.signIn': 'เข้าสู่ระบบ',
    'login.noAccount': 'ยังไม่มีบัญชี?',
    'login.createOne': 'สมัครสมาชิก',
    'register.title': 'สมัครสมาชิก',
    'register.passwordConfirm': 'ยืนยันรหัสผ่าน',
    'register.create': 'สร้างบัญชี',
    'register.passwordTooShort': 'รหัสผ่านต้องอย่างน้อย 8 ตัว',
    'register.passwordMismatch': 'รหัสผ่านไม่ตรงกัน',

    // Tabs
    'tab.home': 'หน้าหลัก',
    'tab.chats': 'แชท',
    'tab.voom': 'VOOM',
    'tab.news': 'ข่าว',
    'tab.wallet': 'วอลเล็ต',

    // Common actions
    'common.cancel': 'ยกเลิก',
    'common.ok': 'ตกลง',
    'common.search': 'ค้นหา',
    'common.signOut': 'ออกจากระบบ',
    'common.settings': 'ตั้งค่า',
    'common.account': 'บัญชี',
    'common.language': 'ภาษา',

    // Room list
    'rooms.empty': 'ยังไม่มีแชท แตะ + เพื่อเริ่มแชทใหม่',
    'rooms.invitation': 'คำเชิญ',
    'rooms.accept': 'รับ',
    'rooms.decline': 'ปฏิเสธ',
    'rooms.newChat': 'แชทใหม่',

    // New chat
    'newChat.title': 'แชทใหม่',
    'newChat.direct': 'แชทตัวต่อตัว',
    'newChat.directDesc': 'แชท 1-on-1 กับ Matrix user',
    'newChat.group': 'สร้างกลุ่ม',
    'newChat.groupDesc': 'แชทกลุ่มหลายคน',
    'newChat.directTitle': 'แชทตัวต่อตัวใหม่',
    'newChat.directHint': 'กรอก Matrix ID ของผู้ติดต่อ',
    'newChat.startChat': 'เริ่มแชท',
    'newChat.groupTitle': 'สร้างกลุ่มใหม่',
    'newChat.groupName': 'ชื่อกลุ่ม',
    'newChat.groupNameRequired': 'ต้องระบุชื่อกลุ่ม',
    'newChat.invite': 'เชิญ (ไม่บังคับ)',
    'newChat.create': 'สร้าง',
    'newChat.badMxid': 'Matrix ID ไม่ถูกต้อง',
    'newChat.mxidFormatHint': 'ใช้ Matrix ID เต็ม เช่น @bob:localhost',

    // Composer
    'composer.hint': 'ข้อความ',
    'composer.photoGallery': 'รูปภาพจากแกลเลอรี',
    'composer.takePhoto': 'ถ่ายรูป',
    'composer.sticker': 'สติกเกอร์',
    'composer.flexDemo': 'Flex demo',
    'composer.videoGallery': 'วิดีโอจากแกลเลอรี',
    'composer.recordVideo': 'อัดวิดีโอ',
    'composer.file': 'ไฟล์',
    'composer.attach': 'แนบไฟล์',
    'composer.replyingTo': 'ตอบกลับ',
    'composer.editing': 'กำลังแก้ไขข้อความ',

    // Message actions
    'msg.reply': 'ตอบกลับ',
    'msg.edit': 'แก้ไข',
    'msg.edited': '(แก้ไขแล้ว)',
    'msg.copy': 'คัดลอก',
    'msg.forward': 'ส่งต่อ',
    'msg.forwardTo': 'ส่งต่อไปยัง',
    'msg.forwarded': 'ส่งต่อแล้ว',
    'msg.forwardBlocked': 'ส่งต่อไปห้องที่ไม่เข้ารหัสไม่ได้',
    'msg.unsend': 'ยกเลิกการส่ง',
    'msg.read': 'อ่านแล้ว',
    'msg.sticker': '[สติกเกอร์]',
    'msg.flex': '[Flex message]',
    'msg.file': '[ไฟล์]',

    // Chat
    'chat.typing': 'กำลังพิมพ์…',
    'file.downloading': 'กำลังดาวน์โหลด…',
    'file.saved': 'บันทึกไฟล์แล้ว',

    // Security / E2EE
    'security.title': 'ความปลอดภัย',
    'security.unavailable': 'อุปกรณ์นี้ไม่รองรับการเข้ารหัส',
    'security.recovery': 'รหัสกู้คืน',
    'security.crossSigning': 'การลงนามข้ามอุปกรณ์',
    'security.keyBackup': 'สำรองคีย์บนเซิร์ฟเวอร์',
    'security.on': 'เปิดใช้งาน',
    'security.off': 'ยังไม่ตั้งค่า',
    'security.setUp': 'ตั้งค่าการเข้ารหัส',
    'security.restore': 'กู้คืนด้วยรหัสกู้คืน',
    'security.devices': 'อุปกรณ์ของฉัน',
    'security.verified': 'ยืนยันแล้ว',
    'security.unverified': 'ยังไม่ยืนยัน',
    'security.verify': 'ยืนยัน',
    'security.unknownDevice': 'อุปกรณ์ไม่ทราบชื่อ',
    'security.noOtherDevices': 'ไม่มีอุปกรณ์อื่น',
    'security.setupFailed': 'ตั้งค่าไม่สำเร็จ',
    'security.recoveryKeyTitle': 'รหัสกู้คืนของคุณ',
    'security.recoveryKeyWarning':
        'เก็บรหัสนี้ไว้ในที่ปลอดภัย ถ้าทำหาย จะกู้ข้อความที่เข้ารหัสไม่ได้',
    'security.copied': 'คัดลอกแล้ว',
    'security.savedIt': 'บันทึกแล้ว',
    'security.restored': 'กู้คืนสำเร็จ',
    'security.restoreFailed': 'กู้คืนไม่สำเร็จ',
    'security.enterRecoveryKey': 'ใส่รหัสกู้คืน',
    'security.recoveryKeyHint': 'วางรหัสกู้คืนที่นี่',

    // Key verification
    'verify.title': 'ยืนยันอุปกรณ์',
    'verify.incoming': 'มีอุปกรณ์ขอยืนยันตัวตนกับคุณ',
    'verify.compareEmoji': 'ตรวจว่าอีโมจิตรงกันทั้งสองอุปกรณ์',
    'verify.accept': 'ยอมรับ',
    'verify.reject': 'ปฏิเสธ',
    'verify.match': 'ตรงกัน',
    'verify.noMatch': 'ไม่ตรง',
    'verify.done': 'ยืนยันสำเร็จ',
    'verify.failed': 'ยืนยันไม่สำเร็จ',
    'verify.waiting': 'กำลังรอ…',

    // Date separator
    'date.today': 'วันนี้',
    'date.yesterday': 'เมื่อวาน',

    // Home
    'home.friends': 'เพื่อน',
    'home.groups': 'กลุ่ม',
    'home.officialAccounts': 'บัญชีทางการ',
    'home.addFriend': 'เพิ่ม\nเพื่อน',
    'home.qrCode': 'QR\ncode',
    'home.search': 'ค้นหา',
    'home.stickerShop': 'ร้าน\nสติกเกอร์',
    'home.themeShop': 'ร้าน\nธีม',

    // Picker
    'picker.empty': 'ไม่มีสติกเกอร์',
    'picker.loadFailed': 'โหลดสติกเกอร์ไม่ได้',
    'store.title': 'ร้านสติกเกอร์',
    'store.add': 'เพิ่ม',
    'store.remove': 'ลบออก',
    'store.default': 'มีอยู่แล้ว',
    'store.featured': 'แนะนำ',
    'store.allPacks': 'แพ็กทั้งหมด',
    'store.loadFailed': 'โหลดร้านไม่ได้',

    // Call
    'call.incoming': 'สายเรียกเข้า',
    'call.ringing': 'กำลังโทร...',
    'call.calling': 'กำลังโทร...',
    'call.connecting': 'กำลังเชื่อมต่อ...',
    'call.voiceCall': 'สนทนาด้วยเสียง',
    'call.videoCall': 'วิดีโอคอล',
    'call.ended': 'จบสายแล้ว',
    'call.missed': 'สายที่ไม่ได้รับ',
    'call.accept': 'รับ',
    'call.decline': 'ปฏิเสธ',
    'call.notDm': 'ใช้ได้เฉพาะแชทตัวต่อตัว',

    // Misc
    'pickerError': 'เปิดตัวเลือกรูปไม่ได้',
  },
  'en': {
    'app.tagline': 'Chat with the world',
    'app.poweredBy': 'Powered by Matrix',

    'login.title': 'majoin',
    'login.username': 'Username',
    'login.password': 'Password',
    'login.homeserver': 'Homeserver URL',
    'login.changeServer': 'Change server',
    'login.hideServer': 'Hide server',
    'login.signIn': 'Log in',
    'login.noAccount': "Don't have an account?",
    'login.createOne': 'Sign up',
    'register.title': 'Sign up',
    'register.passwordConfirm': 'Confirm password',
    'register.create': 'Create account',
    'register.passwordTooShort': 'Password must be at least 8 characters',
    'register.passwordMismatch': 'Passwords do not match',

    'tab.home': 'Home',
    'tab.chats': 'Chats',
    'tab.voom': 'VOOM',
    'tab.news': 'News',
    'tab.wallet': 'Wallet',

    'common.cancel': 'Cancel',
    'common.ok': 'OK',
    'common.search': 'Search',
    'common.signOut': 'Sign out',
    'common.settings': 'Settings',
    'common.account': 'Account',
    'common.language': 'Language',

    'rooms.empty': 'No chats yet. Tap + to start one.',
    'rooms.invitation': 'Invitation',
    'rooms.accept': 'Accept',
    'rooms.decline': 'Decline',
    'rooms.newChat': 'New chat',

    'newChat.title': 'New chat',
    'newChat.direct': 'New direct chat',
    'newChat.directDesc': '1-on-1 chat with a Matrix user',
    'newChat.group': 'New group room',
    'newChat.groupDesc': 'Group chat with multiple people',
    'newChat.directTitle': 'New direct chat',
    'newChat.directHint': 'Enter the Matrix ID of your contact.',
    'newChat.startChat': 'Start chat',
    'newChat.groupTitle': 'New group room',
    'newChat.groupName': 'Group name',
    'newChat.groupNameRequired': 'Group name required',
    'newChat.invite': 'Invite (optional)',
    'newChat.create': 'Create',
    'newChat.badMxid': 'Bad Matrix ID',
    'newChat.mxidFormatHint': 'Use full Matrix ID, e.g. @bob:localhost',

    'composer.hint': 'Message',
    'composer.photoGallery': 'Photo from gallery',
    'composer.takePhoto': 'Take photo',
    'composer.sticker': 'Sticker',
    'composer.flexDemo': 'Flex demo',
    'composer.videoGallery': 'Video from gallery',
    'composer.recordVideo': 'Record video',
    'composer.file': 'File',
    'composer.attach': 'Attach',
    'composer.replyingTo': 'Replying to',
    'composer.editing': 'Editing message',

    'msg.reply': 'Reply',
    'msg.edit': 'Edit',
    'msg.edited': '(edited)',
    'msg.copy': 'Copy',
    'msg.forward': 'Forward',
    'msg.forwardTo': 'Forward to',
    'msg.forwarded': 'Forwarded',
    'msg.forwardBlocked': "Can't forward into an unencrypted room",
    'msg.unsend': 'Unsend',
    'msg.read': 'Read',
    'msg.sticker': '[sticker]',
    'msg.flex': '[flex message]',
    'msg.file': '[file]',

    'chat.typing': 'typing…',
    'file.downloading': 'Downloading…',
    'file.saved': 'File saved',

    'security.title': 'Security',
    'security.unavailable': 'Encryption not available on this device',
    'security.recovery': 'Recovery key',
    'security.crossSigning': 'Cross-signing',
    'security.keyBackup': 'Online key backup',
    'security.on': 'Active',
    'security.off': 'Not set up',
    'security.setUp': 'Set up encryption',
    'security.restore': 'Restore with recovery key',
    'security.devices': 'My devices',
    'security.verified': 'Verified',
    'security.unverified': 'Unverified',
    'security.verify': 'Verify',
    'security.unknownDevice': 'Unknown device',
    'security.noOtherDevices': 'No other devices',
    'security.setupFailed': 'Setup failed',
    'security.recoveryKeyTitle': 'Your recovery key',
    'security.recoveryKeyWarning':
        'Store this somewhere safe. Lose it and encrypted messages cannot be recovered.',
    'security.copied': 'Copied',
    'security.savedIt': 'I saved it',
    'security.restored': 'Restored',
    'security.restoreFailed': 'Restore failed',
    'security.enterRecoveryKey': 'Enter recovery key',
    'security.recoveryKeyHint': 'Paste your recovery key here',

    'verify.title': 'Verify device',
    'verify.incoming': 'A device wants to verify with you',
    'verify.compareEmoji': 'Check the emoji match on both devices',
    'verify.accept': 'Accept',
    'verify.reject': 'Reject',
    'verify.match': 'They match',
    'verify.noMatch': "They don't match",
    'verify.done': 'Verified',
    'verify.failed': 'Verification failed',
    'verify.waiting': 'Waiting…',

    'date.today': 'Today',
    'date.yesterday': 'Yesterday',

    'home.friends': 'Friends',
    'home.groups': 'Groups',
    'home.officialAccounts': 'Official accounts',
    'home.addFriend': 'Add\nfriend',
    'home.qrCode': 'QR\ncode',
    'home.search': 'Search',
    'home.stickerShop': 'Sticker\nshop',
    'home.themeShop': 'Theme\nshop',

    'picker.empty': 'No stickers in pack.',
    'picker.loadFailed': 'Pack load failed',
    'store.title': 'Sticker Store',
    'store.add': 'Add',
    'store.remove': 'Remove',
    'store.default': 'Installed',
    'store.featured': 'Featured',
    'store.allPacks': 'All packs',
    'store.loadFailed': 'Failed to load store',

    'pickerError': 'Picker error',

    'call.incoming': 'Incoming call',
    'call.ringing': 'Ringing...',
    'call.calling': 'Calling...',
    'call.connecting': 'Connecting...',
    'call.voiceCall': 'Voice call',
    'call.videoCall': 'Video call',
    'call.ended': 'Call ended',
    'call.missed': 'Missed call',
    'call.accept': 'Accept',
    'call.decline': 'Decline',
    'call.notDm': 'Calls only available in direct chats',
  },
};

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveCredentials(String user, String pass) async {
    await _storage.write(key: 'user', value: user);
    await _storage.write(key: 'pass', value: pass);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final user = await _storage.read(key: 'user');
    final pass = await _storage.read(key: 'pass');

    if (user != null && pass != null) {
      return {'user': user, 'pass': pass};
    }
    return null;
  }

  static Future<void> clearCredentials() async {
    await _storage.deleteAll();
  }
}
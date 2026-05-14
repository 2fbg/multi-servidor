import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'user', value: username);
    await _storage.write(key: 'password', value: password);
    await _storage.write(key: 'pass', value: password);
  }

  static Future<Map<String, String?>> getCredentials() async {
    final username = await _storage.read(key: 'username');
    final user = await _storage.read(key: 'user');
    final password = await _storage.read(key: 'password');
    final pass = await _storage.read(key: 'pass');

    return {
      'username': username ?? user,
      'user': user ?? username,
      'password': password ?? pass,
      'pass': pass ?? password,
    };
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'user');
    await _storage.delete(key: 'password');
    await _storage.delete(key: 'pass');
  }
}

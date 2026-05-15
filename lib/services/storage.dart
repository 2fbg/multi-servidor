import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveCredentials(
    String username,
    String password, {
    String? server,
  }) async {
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'user', value: username);
    await _storage.write(key: 'password', value: password);
    await _storage.write(key: 'pass', value: password);

    if (server != null) {
      await _storage.write(key: 'server', value: server);
    }
  }

  static Future<Map<String, String?>> getCredentials() async {
    final username = await _storage.read(key: 'username');
    final user = await _storage.read(key: 'user');
    final password = await _storage.read(key: 'password');
    final pass = await _storage.read(key: 'pass');
    final server = await _storage.read(key: 'server');

    return {
      'username': username ?? user,
      'user': user ?? username,
      'password': password ?? pass,
      'pass': pass ?? password,
      'server': server,
    };
  }

  static Future<void> clearCredentials() async {
    await _storage.deleteAll();
  }
}

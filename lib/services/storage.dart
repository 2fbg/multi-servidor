import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/servers.dart';
import '../models/channel.dart';

class AppStorage {
  static const _secure = FlutterSecureStorage();

  static Future<void> saveCredentials(String user, String pass) async {
    await _secure.write(key: 'login_user', value: user);
    await _secure.write(key: 'login_pass', value: pass);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final user = await _secure.read(key: 'login_user');
    final pass = await _secure.read(key: 'login_pass');

    if (user == null || pass == null) return null;
    return {'user': user, 'pass': pass};
  }

  static Future<void> clearCredentials() async {
    await _secure.delete(key: 'login_user');
    await _secure.delete(key: 'login_pass');
  }

  static Future<List<Server>> getCustomPlaylists() async {
    final raw = await _secure.read(key: 'custom_playlists');
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Server.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCustomPlaylists(List<Server> playlists) async {
    final raw = jsonEncode(playlists.map((e) => e.toJson()).toList());
    await _secure.write(key: 'custom_playlists', value: raw);
  }

  static Future<void> addCustomPlaylist(Server server) async {
    final current = await getCustomPlaylists();
    current.removeWhere((e) => e.name == server.name);
    current.add(server);
    await saveCustomPlaylists(current);
  }

  static Future<void> removeCustomPlaylist(String name) async {
    final current = await getCustomPlaylists();
    current.removeWhere((e) => e.name == name);
    await saveCustomPlaylists(current);
  }

  static Future<void> saveWatch(Channel channel, Duration position, Duration duration) async {
    if (channel.streamUrl == null) return;

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('continue_watching') ?? [];

    final item = {
      'id': channel.id,
      'title': channel.title,
      'group': channel.group,
      'logo': channel.logo,
      'streamUrl': channel.streamUrl,
      'sourceName': channel.sourceName,
      'position': position.inMilliseconds,
      'duration': duration.inMilliseconds,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final filtered = rawList.where((raw) {
      try {
        final decoded = jsonDecode(raw);
        return decoded['streamUrl'] != channel.streamUrl;
      } catch (_) {
        return false;
      }
    }).toList();

    filtered.insert(0, jsonEncode(item));

    if (filtered.length > 30) {
      filtered.removeRange(30, filtered.length);
    }

    await prefs.setStringList('continue_watching', filtered);
  }

  static Future<List<Channel>> getContinueWatching() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('continue_watching') ?? [];

    final result = <Channel>[];

    for (final raw in rawList) {
      try {
        final json = jsonDecode(raw);
        result.add(Channel(
          id: json['id'] ?? '',
          title: json['title'] ?? 'Sem título',
          group: json['group'],
          logo: json['logo'],
          streamUrl: json['streamUrl'],
          sourceName: json['sourceName'],
        ));
      } catch (_) {}
    }

    return result;
  }
}

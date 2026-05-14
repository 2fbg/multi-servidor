#!/usr/bin/env bash
set -e

echo "🚀 Corrigindo servidores, categorias e player..."

mkdir -p lib/config lib/models lib/services lib/screens android/app/src/main/res/xml

cat > lib/config/servers.dart <<'EOF'
class Server {
  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final bool directUrl;
  final String outputFormat;

  const Server({
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    this.directUrl = false,
    this.outputFormat = 'm3u8',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseUrl': baseUrl,
        'username': username,
        'password': password,
        'directUrl': directUrl,
        'outputFormat': outputFormat,
      };

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      name: json['name'] ?? 'Playlist',
      baseUrl: json['baseUrl'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      directUrl: json['directUrl'] == true,
      outputFormat: json['outputFormat'] ?? 'm3u8',
    );
  }
}

class ServerConfig {
  static List<Server> buildDefaultServers(String user, String pass) {
    return [
      Server(name: 'VLOG', baseUrl: 'http://vlogmk.de', username: user, password: pass),
      Server(name: 'LUB TV', baseUrl: 'http://triimundial.shop', username: user, password: pass),
      Server(name: 'CINELON21', baseUrl: 'http://cinelontv.work', username: user, password: pass),
      Server(name: 'TANNIX', baseUrl: 'http://zeip.fun', username: user, password: pass),
      Server(name: 'CB6000', baseUrl: 'http://kraewert.top', username: user, password: pass),
      Server(name: 'MK21 TV', baseUrl: 'http://mk21.uk', username: user, password: pass),
      Server(name: 'NOVATV', baseUrl: 'http://novatv.news', username: user, password: pass),
    ];
  }

  static String buildM3UUrl(Server server) {
    if (server.directUrl) {
      return server.baseUrl.trim();
    }

    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/get.php?username=${Uri.encodeComponent(server.username)}&password=${Uri.encodeComponent(server.password)}&type=m3u_plus&output=${server.outputFormat}';
  }

  static String safeUrlForDebug(Server server) {
    if (server.directUrl) return server.baseUrl;
    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/get.php?username=***&password=***&type=m3u_plus&output=${server.outputFormat}';
  }
}
EOF

cat > lib/models/channel.dart <<'EOF'
enum ChannelType {
  live,
  movie,
  series,
  unknown,
}

class Channel {
  final String id;
  final String title;
  final String? group;
  final String? logo;
  final String? streamUrl;
  final String? sourceName;
  final ChannelType type;

  Channel({
    required this.id,
    required this.title,
    this.group,
    this.logo,
    this.streamUrl,
    this.sourceName,
    this.type = ChannelType.unknown,
  });

  Channel copyWith({
    String? id,
    String? title,
    String? group,
    String? logo,
    String? streamUrl,
    String? sourceName,
    ChannelType? type,
  }) {
    return Channel(
      id: id ?? this.id,
      title: title ?? this.title,
      group: group ?? this.group,
      logo: logo ?? this.logo,
      streamUrl: streamUrl ?? this.streamUrl,
      sourceName: sourceName ?? this.sourceName,
      type: type ?? this.type,
    );
  }
}
EOF

cat > lib/services/m3u_parser.dart <<'EOF'
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url, {String? sourceName}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 MultiServidor',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 22));

      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        return [];
      }

      final lines = response.body.split(RegExp(r'\r?\n'));
      final channels = <Channel>[];
      Channel? current;

      for (final raw in lines) {
        final line = raw.trim();

        if (line.isEmpty) continue;

        if (line.startsWith('#EXTINF:')) {
          final title = _extractTitle(line);
          final attrs = _extractAttrs(line);
          final group = attrs['group-title'] ?? attrs['group'] ?? 'Geral';
          final type = _detectType(title, group, null);

          current = Channel(
            id: '${sourceName ?? 'src'}_${channels.length}_${title.hashCode}',
            title: title.isEmpty ? 'Sem título' : title,
            group: group,
            logo: attrs['tvg-logo'],
            sourceName: sourceName,
            type: type,
          );
        } else if ((line.startsWith('http://') || line.startsWith('https://')) && current != null) {
          final type = _detectType(current.title, current.group, line);
          channels.add(current.copyWith(streamUrl: line, type: type));
          current = null;
        }
      }

      return channels;
    } catch (_) {
      return [];
    }
  }

  static String _extractTitle(String line) {
    final comma = line.lastIndexOf(',');
    if (comma >= 0 && comma < line.length - 1) {
      return line.substring(comma + 1).trim();
    }
    return 'Canal';
  }

  static Map<String, String> _extractAttrs(String line) {
    final attrs = <String, String>{};

    final regexDouble = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');
    final regexSingle = RegExp(r"([A-Za-z0-9_-]+)='([^']*)'");

    for (final match in regexDouble.allMatches(line)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    for (final match in regexSingle.allMatches(line)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    return attrs;
  }

  static ChannelType _detectType(String title, String? group, String? url) {
    final text = '${title.toLowerCase()} ${(group ?? '').toLowerCase()} ${(url ?? '').toLowerCase()}';

    final movieWords = [
      'filme',
      'filmes',
      'movie',
      'movies',
      'cinema',
      'vod',
      '/movie/',
      'lançamento',
      'lancamento',
      '4k filmes',
    ];

    final seriesWords = [
      'serie',
      'série',
      'series',
      'séries',
      '/series/',
      'temporada',
      'season',
      'episodio',
      'episódio',
      's01',
      's02',
      's03',
      's04',
      'e01',
      'e02',
    ];

    for (final word in seriesWords) {
      if (text.contains(word)) return ChannelType.series;
    }

    for (final word in movieWords) {
      if (text.contains(word)) return ChannelType.movie;
    }

    return ChannelType.live;
  }
}
EOF

cat > lib/services/storage.dart <<'EOF'
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
      'type': channel.type.name,
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
        final typeName = json['type'] ?? 'unknown';
        final type = ChannelType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => ChannelType.unknown,
        );

        result.add(Channel(
          id: json['id'] ?? '',
          title: json['title'] ?? 'Sem título',
          group: json['group'],
          logo: json['logo'],
          streamUrl: json['streamUrl'],
          sourceName: json['sourceName'],
          type: type,
        ));
      } catch (_) {}
    }

    return result;
  }
}
EOF

cat > lib/screens/player_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/channel.dart';
import '../services/storage.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _startPlayer();
  }

  Future<void> _startPlayer() async {
    try {
      final url = widget.channel.streamUrl;

      if (url == null || url.isEmpty) {
        setState(() {
          _error = 'Link inválido.';
          _loading = false;
        });
        return;
      }

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent': 'Mozilla/5.0 MultiServidor',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize().timeout(const Duration(seconds: 35));

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        playbackSpeeds: const [0.5, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Não foi possível reproduzir.\n\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _video = controller;
        _chewie = chewie;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Falha ao abrir o vídeo.\n\nDetalhe técnico:\n$e\n\nTente outro canal, outro servidor ou playlist em formato M3U8.';
        _loading = false;
      });
    }
  }

  Future<void> _saveProgress() async {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;

    await AppStorage.saveWatch(
      widget.channel,
      video.value.position,
      video.value.duration,
    );
  }

  @override
  void dispose() {
    _saveProgress();

    _chewie?.dispose();
    _video?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.channel.title)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 16),
              Text('Abrindo player...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.channel.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.channel.title)),
      body: Center(
        child: AspectRatio(
          aspectRatio: _video!.value.aspectRatio <= 0 ? 16 / 9 : _video!.value.aspectRatio,
          child: Chewie(controller: _chewie!),
        ),
      ),
    );
  }
}
EOF

python3 - <<'PY'
from pathlib import Path

main = Path("lib/main.dart")
text = main.read_text()

# Corrige função _channelsByType, se existir no modelo anterior
old = """  List<Channel> _channelsByType(CategoryFilter type) {
    final old = _filter;
    _filter = type;
    final result = _filteredChannels;
    _filter = old;
    return result;
  }
"""

new = """  List<Channel> _channelsByType(CategoryFilter type) {
    if (type == CategoryFilter.all) return _channels;

    return _channels.where((channel) {
      if (type == CategoryFilter.live) return channel.type == ChannelType.live;
      if (type == CategoryFilter.movies) return channel.type == ChannelType.movie;
      if (type == CategoryFilter.series) return channel.type == ChannelType.series;
      return true;
    }).toList();
  }
"""

if old in text:
    text = text.replace(old, new)

# Corrige getter _filteredChannels, se existir no modelo anterior
start = text.find("  List<Channel> get _filteredChannels {")
if start != -1:
    brace = text.find("{", start)
    count = 0
    end = brace
    for i in range(brace, len(text)):
        if text[i] == "{":
            count += 1
        elif text[i] == "}":
            count -= 1
            if count == 0:
                end = i + 1
                break

    replacement = """  List<Channel> get _filteredChannels {
    if (_filter == CategoryFilter.all) return _channels;
    return _channelsByType(_filter);
  }"""
    text = text[:start] + replacement + text[end:]

# Ajusta dropdown para aparecer status ao selecionar servidor
# Mantém se já existir; sem patch agressivo.

main.write_text(text)
print("✅ main.dart corrigido para filtros puros.")
PY

cat > android/app/src/main/res/xml/network_security_config.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            system
        </trust-anchors>
    </base-config>
</network-security-config>
EOF

python3 - <<'PY'
from pathlib import Path
manifest = Path("android/app/src/main/AndroidManifest.xml")

if not manifest.exists():
    print("⚠️ AndroidManifest.xml não encontrado.")
    raise SystemExit

text = manifest.read_text()

if "android.permission.INTERNET" not in text:
    text = text.replace(
        "<application",
        '    <uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1
    )

if "<application" in text and "android:usesCleartextTraffic" not in text:
    text = text.replace(
        "<application",
        '<application android:usesCleartextTraffic="true" android:networkSecurityConfig="@xml/network_security_config"',
        1
    )
elif "<application" in text and "android:networkSecurityConfig" not in text:
    text = text.replace(
        "<application",
        '<application android:networkSecurityConfig="@xml/network_security_config"',
        1
    )

manifest.write_text(text)
print("✅ AndroidManifest.xml atualizado com INTERNET + cleartext.")
PY

flutter pub get
flutter clean

echo ""
echo "✅ Correção aplicada."
echo ""
echo "Agora execute:"
echo "git add ."
echo "git commit -m \"corrige player categorias e servidores\""
echo "git push"

#!/usr/bin/env bash
set -e

echo "🔧 Corrigindo links oficiais, output=mpegts, parser e player..."

mkdir -p lib/config lib/services lib/screens android/app/src/main/res/xml

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
    this.outputFormat = 'mpegts',
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
      outputFormat: json['outputFormat'] ?? 'mpegts',
    );
  }
}

class ServerConfig {
  static List<Server> buildDefaultServers(String user, String pass) {
    return [
      Server(
        name: 'VLOG',
        baseUrl: 'http://vlogmk.de',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'LUB TV',
        baseUrl: 'http://triimundial.shop',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'CINELON21',
        baseUrl: 'http://infinixparcerias.site',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'TANNIX',
        baseUrl: 'http://unituf.online',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'CB6000',
        baseUrl: 'http://cb6.fun',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'MK21 TV',
        baseUrl: 'http://appsmk.org',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
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

cat > lib/services/m3u_parser.dart <<'EOF'
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url, {String? sourceName}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android) MultiServidor/1.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        return [];
      }

      final body = response.body.trim();

      if (body.isEmpty) {
        return [];
      }

      if (!body.contains('#EXTINF')) {
        return [];
      }

      final lines = body.split(RegExp(r'\r?\n'));
      final channels = <Channel>[];
      Channel? current;

      for (final raw in lines) {
        final line = raw.trim();

        if (line.isEmpty) continue;

        if (line.startsWith('#EXTINF:')) {
          final title = _extractTitle(line);
          final attrs = _extractAttrs(line);
          final group = attrs['group-title'] ?? attrs['group'] ?? 'Geral';

          current = Channel(
            id: '${sourceName ?? 'src'}_${channels.length}_${title.hashCode}',
            title: title.isEmpty ? 'Sem título' : title,
            group: group,
            logo: attrs['tvg-logo'],
            sourceName: sourceName,
            type: _detectType(title, group, null),
          );
        } else if ((line.startsWith('http://') || line.startsWith('https://')) && current != null) {
          final type = _detectType(current.title, current.group, line);

          channels.add(
            current.copyWith(
              streamUrl: line,
              type: type,
            ),
          );

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

    final seriesWords = [
      'série',
      'serie',
      'series',
      'séries',
      '/series/',
      '/serie/',
      'temporada',
      'season',
      'episodio',
      'episódio',
      'capitulo',
      'capítulo',
      's01',
      's02',
      's03',
      's04',
      's05',
      'e01',
      'e02',
      'e03',
      'e04',
    ];

    final movieWords = [
      'filme',
      'filmes',
      'movie',
      'movies',
      'cinema',
      'vod',
      '/movie/',
      '/movies/',
      '/filme/',
      '/filmes/',
      'lançamento',
      'lancamento',
      'bluray',
      'dub',
      'legendado',
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
          'User-Agent': 'Mozilla/5.0 (Linux; Android) MultiServidor/1.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await controller.initialize().timeout(const Duration(seconds: 45));

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
        _error =
            'Falha ao abrir o vídeo.\n\n'
            'Esse canal pode estar offline, bloqueado ou em formato não suportado pelo player interno.\n\n'
            'Detalhe técnico:\n$e';
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
          child: SingleChildScrollView(
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

# Se application não tiver cleartext, adiciona de forma simples.
if "android:usesCleartextTraffic" not in text:
    text = text.replace(
        "<application",
        '<application android:usesCleartextTraffic="true"',
        1
    )

if "android:networkSecurityConfig" not in text:
    text = text.replace(
        "<application",
        '<application android:networkSecurityConfig="@xml/network_security_config"',
        1
    )

manifest.write_text(text)
print("✅ AndroidManifest.xml verificado.")
PY

# Limpa playlists adicionais salvas antigas apenas no código? Não dá para limpar armazenamento do APK já instalado.
# O usuário deve limpar dados do app ou reinstalar após desinstalar.

flutter pub get
flutter clean

echo ""
echo "✅ Hotfix aplicado."
echo ""
echo "IMPORTANTE:"
echo "1. Desinstale o app atual do celular antes de instalar o novo APK."
echo "2. Isso limpa listas antigas salvas com output=m3u8."
echo ""
echo "Agora rode:"
echo "git add ."
echo "git commit -m \"hotfix links mpegts\""
echo "git push"

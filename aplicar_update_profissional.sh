#!/usr/bin/env bash
set -e

echo "🚀 Aplicando atualização profissional Multi Servidor..."

mkdir -p lib/config lib/models lib/services lib/screens

cat > pubspec.yaml <<'EOF'
name: multi_servidor
description: App multi servidor com player profissional
publish_to: 'none'
version: 1.0.1+2

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2
  flutter_secure_storage: ^9.2.4
  shared_preferences: ^2.2.3
  video_player: ^2.8.6
  chewie: ^1.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.2

flutter:
  uses-material-design: true
EOF

cat > lib/models/channel.dart <<'EOF'
class Channel {
  final String id;
  final String title;
  final String? group;
  final String? logo;
  final String? streamUrl;
  final String? sourceName;

  Channel({
    required this.id,
    required this.title,
    this.group,
    this.logo,
    this.streamUrl,
    this.sourceName,
  });

  Channel copyWith({
    String? id,
    String? title,
    String? group,
    String? logo,
    String? streamUrl,
    String? sourceName,
  }) {
    return Channel(
      id: id ?? this.id,
      title: title ?? this.title,
      group: group ?? this.group,
      logo: logo ?? this.logo,
      streamUrl: streamUrl ?? this.streamUrl,
      sourceName: sourceName ?? this.sourceName,
    );
  }
}
EOF

cat > lib/config/servers.dart <<'EOF'
class Server {
  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final bool directUrl;

  const Server({
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    this.directUrl = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseUrl': baseUrl,
        'username': username,
        'password': password,
        'directUrl': directUrl,
      };

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      name: json['name'] ?? 'Playlist',
      baseUrl: json['baseUrl'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      directUrl: json['directUrl'] == true,
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
    return '$base/get.php?username=${Uri.encodeComponent(server.username)}&password=${Uri.encodeComponent(server.password)}&type=m3u_plus&output=mpegts';
  }
}
EOF

cat > lib/services/m3u_parser.dart <<'EOF'
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url, {String? sourceName}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'MultiServidor/1.0'})
          .timeout(const Duration(seconds: 12));

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

          current = Channel(
            id: '${sourceName ?? 'src'}_${channels.length}_${title.hashCode}',
            title: title.isEmpty ? 'Sem título' : title,
            group: attrs['group-title'] ?? 'Geral',
            logo: attrs['tvg-logo'],
            sourceName: sourceName,
          );
        } else if ((line.startsWith('http://') || line.startsWith('https://')) && current != null) {
          channels.add(current.copyWith(streamUrl: line));
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
    final regex = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

    for (final match in regex.allMatches(line)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    return attrs;
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
        httpHeaders: const {'User-Agent': 'MultiServidor/1.0'},
      );

      await controller.initialize().timeout(const Duration(seconds: 15));

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        playbackSpeeds: const [0.5, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0],
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Não foi possível reproduzir este conteúdo.\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Falha ao abrir o vídeo. Tente outro link ou servidor.';
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
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
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
              style: const TextStyle(color: Colors.white70, fontSize: 16),
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
          aspectRatio: _video!.value.aspectRatio,
          child: Chewie(controller: _chewie!),
        ),
      ),
    );
  }
}
EOF

cat > lib/main.dart <<'EOF'
import 'package:flutter/material.dart';
import 'config/servers.dart';
import 'models/channel.dart';
import 'services/m3u_parser.dart';
import 'services/storage.dart';
import 'screens/player_screen.dart';

void main() {
  runApp(const MultiServidorApp());
}

class MultiServidorApp extends StatelessWidget {
  const MultiServidorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Servidor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF181818),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(milliseconds: 700));
    final creds = await AppStorage.getCredentials();

    if (!mounted) return;

    if (creds == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: creds['user']!,
            pass: creds['pass']!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'MULTI SERVIDOR',
          style: TextStyle(
            color: Colors.red,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _remember = true;
  bool _loading = false;

  Future<void> _login() async {
    if (_user.text.trim().isEmpty || _pass.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe usuário e senha.')),
      );
      return;
    }

    setState(() => _loading = true);

    if (_remember) {
      await AppStorage.saveCredentials(_user.text.trim(), _pass.text.trim());
    } else {
      await AppStorage.clearCredentials();
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          user: _user.text.trim(),
          pass: _pass.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.play_circle_fill, size: 90, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'MULTI SERVIDOR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(
                    labelText: 'Usuário',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _remember,
                  onChanged: (value) => setState(() => _remember = value ?? true),
                  title: const Text('Salvar login'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ENTRAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String user;
  final String pass;

  const HomeScreen({
    super.key,
    required this.user,
    required this.pass,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum CategoryFilter { all, live, movies, series }

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String _status = 'Carregando servidor principal...';

  List<Server> _servers = [];
  Server? _selectedServer;

  List<Channel> _channels = [];
  List<Channel> _continueWatching = [];

  CategoryFilter _filter = CategoryFilter.all;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final defaults = ServerConfig.buildDefaultServers(widget.user, widget.pass);
    final custom = await AppStorage.getCustomPlaylists();

    _servers = [...defaults, ...custom];
    _selectedServer = _servers.isNotEmpty ? _servers.first : null;

    await _loadContinueWatching();
    await _loadServer(_selectedServer);
  }

  Future<void> _loadContinueWatching() async {
    final list = await AppStorage.getContinueWatching();
    if (!mounted) return;
    setState(() => _continueWatching = list);
  }

  Future<void> _loadServer(Server? server) async {
    if (server == null) {
      setState(() {
        _channels = [];
        _loading = false;
        _status = 'Nenhum servidor disponível.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Carregando ${server.name}...';
      _selectedServer = server;
    });

    try {
      final url = ServerConfig.buildM3UUrl(server);
      final result = await M3UParser
          .parseM3U(url, sourceName: server.name)
          .timeout(const Duration(seconds: 14));

      if (!mounted) return;

      setState(() {
        _channels = result;
        _loading = false;
        _status = result.isEmpty
            ? 'Nenhum conteúdo encontrado neste servidor.'
            : '${result.length} conteúdos carregados.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _channels = [];
        _loading = false;
        _status = 'Falha ao carregar ${server.name}. Tente outro servidor.';
      });
    }
  }

  List<Channel> get _filteredChannels {
    if (_filter == CategoryFilter.all) return _channels;

    return _channels.where((channel) {
      final group = (channel.group ?? '').toLowerCase();
      final title = channel.title.toLowerCase();

      if (_filter == CategoryFilter.movies) {
        return group.contains('filme') || group.contains('movie') || title.contains('filme');
      }

      if (_filter == CategoryFilter.series) {
        return group.contains('serie') || group.contains('série') || group.contains('series') || title.contains('s0');
      }

      if (_filter == CategoryFilter.live) {
        final isMovie = group.contains('filme') || group.contains('movie');
        final isSeries = group.contains('serie') || group.contains('série') || group.contains('series');
        return !isMovie && !isSeries;
      }

      return true;
    }).toList();
  }

  Future<void> _openPlayer(Channel channel) async {
    if (channel.streamUrl == null || channel.streamUrl!.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)),
    );

    await _loadContinueWatching();
  }

  void _showAddPlaylistDialog() {
    final name = TextEditingController();
    final url = TextEditingController();
    final user = TextEditingController(text: widget.user);
    final pass = TextEditingController(text: widget.pass);
    bool directUrl = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111111),
              title: const Text('Adicionar playlist'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nome da lista'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: url,
                      decoration: const InputDecoration(
                        labelText: 'URL/base do servidor',
                        hintText: 'http://servidor.com ou link M3U direto',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: directUrl,
                      onChanged: (v) => setDialogState(() => directUrl = v),
                      title: const Text('Este é um link M3U direto'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (!directUrl) ...[
                      TextField(
                        controller: user,
                        decoration: const InputDecoration(labelText: 'Usuário'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pass,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Senha'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty || url.text.trim().isEmpty) return;

                    final server = Server(
                      name: name.text.trim(),
                      baseUrl: url.text.trim(),
                      username: user.text.trim(),
                      password: pass.text.trim(),
                      directUrl: directUrl,
                    );

                    await AppStorage.addCustomPlaylist(server);

                    if (!mounted) return;

                    Navigator.pop(ctx);

                    final custom = await AppStorage.getCustomPlaylists();
                    setState(() {
                      _servers = [
                        ...ServerConfig.buildDefaultServers(widget.user, widget.pass),
                        ...custom,
                      ];
                    });

                    await _loadServer(server);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManagePlaylists() async {
    final custom = await AppStorage.getCustomPlaylists();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (_) {
        if (custom.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhuma playlist adicional cadastrada.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Playlists adicionais',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ...custom.map(
              (server) => ListTile(
                title: Text(server.name),
                subtitle: Text(server.directUrl ? 'Link direto' : server.baseUrl),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await AppStorage.removeCustomPlaylist(server.name);
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _prepare();
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _loadServer(server);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await AppStorage.clearCredentials();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChannels;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Multi Servidor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<Server>(
            icon: const Icon(Icons.cloud),
            tooltip: 'Selecionar servidor',
            onSelected: _loadServer,
            itemBuilder: (context) {
              return _servers.map((s) {
                return PopupMenuItem(
                  value: s,
                  child: Text(s.name),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Adicionar playlist',
            onPressed: _showAddPlaylistDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gerenciar playlists',
            onPressed: _showManagePlaylists,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () => _loadServer(_selectedServer),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : RefreshIndicator(
              onRefresh: () => _loadServer(_selectedServer),
              child: ListView(
                children: [
                  _buildHeroBanner(filtered),
                  _buildFilterBar(),
                  if (_continueWatching.isNotEmpty)
                    _buildSection('▶ Continuar assistindo', _continueWatching),
                  _buildSection('🔥 Destaques', filtered.take(25).toList()),
                  _buildSection('📺 Ao vivo', _channelsByType(CategoryFilter.live).take(40).toList()),
                  _buildSection('🎬 Filmes', _channelsByType(CategoryFilter.movies).take(40).toList()),
                  _buildSection('🍿 Séries', _channelsByType(CategoryFilter.series).take(40).toList()),
                  if (filtered.isEmpty) _buildEmpty(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.red),
          const SizedBox(height: 18),
          Text(_status, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          const Text(
            'Anti-travamento ativo: se falhar, tente outro servidor.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.tv_off, color: Colors.white38, size: 60),
          const SizedBox(height: 12),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddPlaylistDialog,
            icon: const Icon(Icons.add_link),
            label: const Text('Adicionar playlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(List<Channel> list) {
    final channel = list.isNotEmpty ? list.first : null;

    return Container(
      height: 230,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF181818),
        image: channel?.logo != null
            ? DecorationImage(
                image: NetworkImage(channel!.logo!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.42),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            bottom: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel?.title ?? 'Multi Servidor',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedServer == null
                      ? _status
                      : '${_selectedServer!.name} • $_status',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                if (channel?.streamUrl != null)
                  ElevatedButton.icon(
                    onPressed: () => _openPlayer(channel!),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Assistir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    Widget button(String label, CategoryFilter filter) {
      final selected = _filter == filter;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected,
          label: Text(label),
          selectedColor: Colors.red,
          onSelected: (_) => setState(() => _filter = filter),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          button('Todos', CategoryFilter.all),
          button('Ao vivo', CategoryFilter.live),
          button('Filmes', CategoryFilter.movies),
          button('Séries', CategoryFilter.series),
        ],
      ),
    );
  }

  List<Channel> _channelsByType(CategoryFilter type) {
    final old = _filter;
    _filter = type;
    final result = _filteredChannels;
    _filter = old;
    return result;
  }

  Widget _buildSection(String title, List<Channel> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 178,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: list.length,
            itemBuilder: (_, index) => _buildCard(list[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Channel channel) {
    return GestureDetector(
      onTap: () => _openPlayer(channel),
      child: Container(
        width: 126,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: channel.logo != null
                  ? Image.network(
                      channel.logo!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon(),
                    )
                  : _placeholderIcon(),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                channel.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF232323),
      child: const Center(
        child: Icon(Icons.live_tv, color: Colors.white54, size: 38),
      ),
    );
  }
}
EOF

python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
if manifest.exists():
    text = manifest.read_text()
    if "android.permission.INTERNET" not in text:
        text = text.replace(
            "<manifest",
            '<manifest',
            1
        )
        insert = '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        text = text.replace("<application", insert + "    <application", 1)
        manifest.write_text(text)
        print("✅ Permissão INTERNET adicionada.")
    else:
        print("✅ Permissão INTERNET já existia.")
else:
    print("⚠️ AndroidManifest.xml não encontrado.")
PY

echo "📦 Atualizando dependências..."
flutter pub get

echo "🧹 Limpando build antigo..."
flutter clean

echo "✅ Atualização aplicada com sucesso."
echo ""
echo "Agora rode:"
echo "git add ."
echo "git commit -m \"player profissional e visual netflix\""
echo "git push"

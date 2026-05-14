#!/usr/bin/env bash
set -e

echo "🚀 Corrigindo classificação TV Box, diagnóstico M3U e links MPEGTS..."

mkdir -p lib/config lib/models lib/services android/app/src/main/res/xml

# ============================
# 1. SERVIDORES CORRETOS
# ============================
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
      Server(name: 'VLOG', baseUrl: 'http://vlogmk.de', username: user, password: pass),
      Server(name: 'LUB TV', baseUrl: 'http://triimundial.shop', username: user, password: pass),
      Server(name: 'CINELON21', baseUrl: 'http://infinixparcerias.site', username: user, password: pass),
      Server(name: 'TANNIX', baseUrl: 'http://unituf.online', username: user, password: pass),
      Server(name: 'CB6000', baseUrl: 'http://cb6.fun', username: user, password: pass),
      Server(name: 'MK21 TV', baseUrl: 'http://appsmk.org', username: user, password: pass),
    ];
  }

  static String buildM3UUrl(Server server) {
    if (server.directUrl) return server.baseUrl.trim();

    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

    return '$base/get.php?username=${Uri.encodeComponent(server.username)}&password=${Uri.encodeComponent(server.password)}&type=m3u_plus&output=mpegts';
  }

  static String safeUrlForDebug(Server server) {
    if (server.directUrl) return server.baseUrl;

    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

    return '$base/get.php?username=***&password=***&type=m3u_plus&output=mpegts';
  }
}
EOF

# ============================
# 2. MODELO COM TIPO CORRETO
# ============================
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

# ============================
# 3. PARSER COM DIAGNÓSTICO
# ============================
cat > lib/services/m3u_parser.dart <<'EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3ULoadResult {
  final List<Channel> channels;
  final int? statusCode;
  final int bodyLength;
  final int extinfCount;
  final String preview;
  final String? error;
  final String urlMasked;

  M3ULoadResult({
    required this.channels,
    required this.statusCode,
    required this.bodyLength,
    required this.extinfCount,
    required this.preview,
    required this.error,
    required this.urlMasked,
  });

  bool get success => channels.isNotEmpty;
}

class M3UParser {
  static Future<List<Channel>> parseM3U(String url, {String? sourceName}) async {
    final result = await parseWithDiagnostics(url, sourceName: sourceName);
    return result.channels;
  }

  static Future<M3ULoadResult> parseWithDiagnostics(
    String url, {
    String? sourceName,
  }) async {
    final masked = _maskUrl(url);

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android) MultiServidor/1.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 90));

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final preview = body.length > 300 ? body.substring(0, 300) : body;
      final extinfCount = RegExp(r'#EXTINF', caseSensitive: false).allMatches(body).length;

      if (response.statusCode != 200) {
        return M3ULoadResult(
          channels: [],
          statusCode: response.statusCode,
          bodyLength: body.length,
          extinfCount: extinfCount,
          preview: preview,
          error: 'HTTP ${response.statusCode}',
          urlMasked: masked,
        );
      }

      if (body.trim().isEmpty) {
        return M3ULoadResult(
          channels: [],
          statusCode: response.statusCode,
          bodyLength: body.length,
          extinfCount: extinfCount,
          preview: preview,
          error: 'Resposta vazia',
          urlMasked: masked,
        );
      }

      if (!body.contains('#EXTINF')) {
        return M3ULoadResult(
          channels: [],
          statusCode: response.statusCode,
          bodyLength: body.length,
          extinfCount: extinfCount,
          preview: preview,
          error: 'Resposta não contém #EXTINF',
          urlMasked: masked,
        );
      }

      final channels = _parseBody(body, sourceName: sourceName);

      return M3ULoadResult(
        channels: channels,
        statusCode: response.statusCode,
        bodyLength: body.length,
        extinfCount: extinfCount,
        preview: preview,
        error: channels.isEmpty ? 'Nenhum canal parseado' : null,
        urlMasked: masked,
      );
    } catch (e) {
      return M3ULoadResult(
        channels: [],
        statusCode: null,
        bodyLength: 0,
        extinfCount: 0,
        preview: '',
        error: e.toString(),
        urlMasked: masked,
      );
    }
  }

  static List<Channel> _parseBody(String body, {String? sourceName}) {
    final lines = body.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    Channel? current;

    for (final raw in lines) {
      final line = raw.trim();

      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final title = _extractTitle(line);
        final attrs = _extractAttrs(line);
        final group = _cleanGroup(attrs['group-title'] ?? attrs['group'] ?? 'Sem grupo');

        current = Channel(
          id: '${sourceName ?? 'src'}_${channels.length}_${title.hashCode}',
          title: title.isEmpty ? 'Sem título' : title,
          group: group,
          logo: attrs['tvg-logo'],
          sourceName: sourceName,
          type: _detectType(title, group, null),
        );
      } else if ((line.startsWith('http://') || line.startsWith('https://')) && current != null) {
        final fixedType = _detectType(current.title, current.group, line);

        channels.add(
          current.copyWith(
            streamUrl: line,
            type: fixedType,
          ),
        );

        current = null;
      }
    }

    return channels;
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

  static String _cleanGroup(String group) {
    return group
        .replaceAll('|', ' | ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static ChannelType _detectType(String title, String? group, String? url) {
    final t = title.toLowerCase();
    final g = (group ?? '').toLowerCase();
    final u = (url ?? '').toLowerCase();
    final text = '$t $g $u';

    // Séries primeiro, pois várias séries também usam palavras parecidas com filme.
    final seriesWords = [
      '/series/',
      '/serie/',
      'series',
      'séries',
      'serie',
      'série',
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

    for (final word in seriesWords) {
      if (text.contains(word)) return ChannelType.series;
    }

    final movieWords = [
      '/movie/',
      '/movies/',
      '/filme/',
      '/filmes/',
      'filme',
      'filmes',
      'movie',
      'movies',
      'cinema',
      'vod',
      'lançamento',
      'lancamento',
      'top 10',
      'ação',
      'acao',
      'crime',
      'guerra',
      'animação',
      'animacao',
      'infantil',
      'família',
      'familia',
      'drama',
      'comédia',
      'comedia',
      'terror',
      'suspense',
      'romance',
      'ficção',
      'ficcao',
      'aventura',
      'documentário',
      'documentario',
    ];

    for (final word in movieWords) {
      if (text.contains(word)) return ChannelType.movie;
    }

    return ChannelType.live;
  }

  static String _maskUrl(String url) {
    return url
        .replaceAll(RegExp(r'username=[^&]+'), 'username=***')
        .replaceAll(RegExp(r'password=[^&]+'), 'password=***');
  }
}
EOF

# ============================
# 4. MAIN COM NAVEGAÇÃO TV BOX
# ============================
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(milliseconds: 600));
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
            fontSize: 28,
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
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 34),
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
                  onChanged: (v) => setState(() => _remember = v ?? true),
                  title: const Text('Salvar login'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
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

enum MainSection {
  home,
  live,
  movies,
  series,
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

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String _status = 'Carregando servidor principal...';

  List<Server> _servers = [];
  Server? _selectedServer;

  List<Channel> _channels = [];
  List<Channel> _continueWatching = [];

  M3ULoadResult? _lastDiagnostic;

  MainSection _section = MainSection.home;
  String _selectedGroup = 'Todos';

  final _search = TextEditingController();

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
        _loading = false;
        _channels = [];
        _status = 'Nenhum servidor disponível.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _selectedServer = server;
      _selectedGroup = 'Todos';
      _status = 'Carregando ${server.name}... Listas grandes podem demorar.';
    });

    final url = ServerConfig.buildM3UUrl(server);
    final result = await M3UParser.parseWithDiagnostics(url, sourceName: server.name);

    if (!mounted) return;

    setState(() {
      _lastDiagnostic = result;
      _channels = result.channels;
      _loading = false;

      if (result.channels.isEmpty) {
        _status = 'Falha ao carregar ${server.name}. Toque no ícone de informação para diagnóstico.';
      } else {
        _status = '${server.name} • ${result.channels.length} conteúdos carregados.';
      }
    });
  }

  List<Channel> get _liveChannels => _channels.where((c) => c.type == ChannelType.live).toList();
  List<Channel> get _movieChannels => _channels.where((c) => c.type == ChannelType.movie).toList();
  List<Channel> get _seriesChannels => _channels.where((c) => c.type == ChannelType.series).toList();

  List<Channel> _baseForSection() {
    if (_section == MainSection.live) return _liveChannels;
    if (_section == MainSection.movies) return _movieChannels;
    if (_section == MainSection.series) return _seriesChannels;
    return _channels;
  }

  List<Channel> _filteredForSection() {
    var list = _baseForSection();

    if (_selectedGroup != 'Todos') {
      list = list.where((c) => (c.group ?? 'Sem grupo') == _selectedGroup).toList();
    }

    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) => c.title.toLowerCase().contains(query)).toList();
    }

    return list;
  }

  Map<String, int> _groupCounts() {
    final source = _baseForSection();
    final counts = <String, int>{};

    counts['Todos'] = source.length;

    for (final channel in source) {
      final group = (channel.group == null || channel.group!.trim().isEmpty)
          ? 'Sem grupo'
          : channel.group!.trim();

      counts[group] = (counts[group] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Todos') return -1;
        if (b.key == 'Todos') return 1;
        return b.value.compareTo(a.value);
      });

    return Map.fromEntries(sorted);
  }

  Future<void> _openPlayer(Channel channel) async {
    if (channel.streamUrl == null || channel.streamUrl!.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)),
    );

    await _loadContinueWatching();
  }

  void _showDiagnostics() {
    final d = _lastDiagnostic;

    if (d == null) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Diagnóstico'),
          content: Text('Nenhum diagnóstico disponível ainda.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Diagnóstico da lista'),
        content: SingleChildScrollView(
          child: Text(
            'URL:\n${d.urlMasked}\n\n'
            'Status HTTP: ${d.statusCode ?? 'sem resposta'}\n'
            'Tamanho da resposta: ${d.bodyLength}\n'
            'Quantidade #EXTINF: ${d.extinfCount}\n'
            'Canais parseados: ${d.channels.length}\n'
            'Erro: ${d.error ?? 'nenhum'}\n\n'
            'Prévia da resposta:\n${d.preview}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
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
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: url,
                      decoration: const InputDecoration(
                        labelText: 'URL/base',
                        hintText: 'http://servidor.com ou link M3U completo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: directUrl,
                      onChanged: (v) => setDialogState(() => directUrl = v),
                      title: const Text('Link M3U direto'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (!directUrl) ...[
                      TextField(controller: user, decoration: const InputDecoration(labelText: 'Usuário')),
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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
                    await _prepare();
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
          children: [
            const ListTile(
              title: Text('Playlists adicionais', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...custom.map(
              (server) => ListTile(
                title: Text(server.name),
                subtitle: Text(server.directUrl ? 'Link direto' : server.baseUrl),
                onTap: () {
                  Navigator.pop(context);
                  _loadServer(server);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await AppStorage.removeCustomPlaylist(server.name);
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _prepare();
                  },
                ),
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
    final filtered = _filteredForSection();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Servidor', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<Server>(
            icon: const Icon(Icons.cloud),
            onSelected: _loadServer,
            itemBuilder: (_) => _servers.map((s) => PopupMenuItem(value: s, child: Text(s.name))).toList(),
          ),
          IconButton(icon: const Icon(Icons.info_outline), onPressed: _showDiagnostics),
          IconButton(icon: const Icon(Icons.add_link), onPressed: _showAddPlaylistDialog),
          IconButton(icon: const Icon(Icons.settings), onPressed: _showManagePlaylists),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadServer(_selectedServer)),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _channels.isEmpty
              ? _buildEmpty()
              : _section == MainSection.home
                  ? _buildHome()
                  : _buildLibrary(filtered),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.red),
          const SizedBox(height: 16),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        _buildHero(null),
        const SizedBox(height: 24),
        const Icon(Icons.tv_off, color: Colors.white38, size: 70),
        const SizedBox(height: 16),
        Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _showDiagnostics,
          icon: const Icon(Icons.info_outline),
          label: const Text('Ver diagnóstico'),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _showAddPlaylistDialog,
          icon: const Icon(Icons.add_link),
          label: const Text('Adicionar playlist'),
        ),
      ],
    );
  }

  Widget _buildHome() {
    final hero = _movieChannels.isNotEmpty
        ? _movieChannels.first
        : _channels.isNotEmpty
            ? _channels.first
            : null;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildHero(hero),
        const SizedBox(height: 14),
        _homeButton(Icons.live_tv, 'CANAIS', MainSection.live),
        _homeButton(Icons.play_circle_fill, 'FILMES', MainSection.movies),
        _homeButton(Icons.movie_creation_outlined, 'SÉRIES', MainSection.series),
        const SizedBox(height: 16),
        if (_continueWatching.isNotEmpty)
          _buildHorizontalSection('▶ Continuar assistindo', _continueWatching),
        _buildHorizontalSection('🔥 Destaques', _channels.take(30).toList()),
      ],
    );
  }

  Widget _homeButton(IconData icon, String label, MainSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _section = section;
            _selectedGroup = 'Todos';
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 86,
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade900, width: 2),
          ),
          child: Row(
            children: [
              const SizedBox(width: 22),
              Icon(icon, size: 44, color: Colors.white),
              const SizedBox(width: 22),
              Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibrary(List<Channel> filtered) {
    final groups = _groupCounts();

    return Column(
      children: [
        _buildTopTabs(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Procurar',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: groups.entries.map((e) {
              final selected = _selectedGroup == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  selectedColor: Colors.red,
                  label: Text('${e.key} (${e.value})'),
                  onSelected: (_) => setState(() => _selectedGroup = e.key),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _section == MainSection.live
              ? _buildLiveList(filtered)
              : _buildPosterGrid(filtered),
        ),
      ],
    );
  }

  Widget _buildTopTabs() {
    Widget tab(String label, MainSection section) {
      final selected = _section == section;

      return TextButton(
        onPressed: () {
          setState(() {
            _section = section;
            _selectedGroup = 'Todos';
          });
        },
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.yellow : Colors.white70,
            fontSize: 17,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Home', MainSection.home),
        tab('Canais', MainSection.live),
        tab('Filmes', MainSection.movies),
        tab('Séries', MainSection.series),
      ],
    );
  }

  Widget _buildLiveList(List<Channel> list) {
    if (list.isEmpty) return _nothingFound();

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final c = list[i];

        return ListTile(
          leading: _thumb(c, size: 42),
          title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(c.group ?? 'Sem grupo', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.play_arrow),
          onTap: () => _openPlayer(c),
        );
      },
    );
  }

  Widget _buildPosterGrid(List<Channel> list) {
    if (list.isEmpty) return _nothingFound();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) => _posterCard(list[i]),
    );
  }

  Widget _posterCard(Channel c) {
    return GestureDetector(
      onTap: () => _openPlayer(c),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(child: _thumb(c, size: double.infinity)),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Text(
                c.title,
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

  Widget _thumb(Channel c, {required double size}) {
    if (c.logo != null && c.logo!.isNotEmpty) {
      return Image.network(
        c.logo!,
        width: size,
        height: size == double.infinity ? double.infinity : size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(size),
      );
    }

    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size == double.infinity ? double.infinity : size,
      color: const Color(0xFF242424),
      child: const Center(child: Icon(Icons.live_tv, color: Colors.white54)),
    );
  }

  Widget _nothingFound() {
    return const Center(
      child: Text('Nenhum conteúdo encontrado nesta categoria.', style: TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildHero(Channel? channel) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        image: channel?.logo != null
            ? DecorationImage(
                image: NetworkImage(channel!.logo!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.45), BlendMode.darken),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channel?.title ?? 'Multi Servidor',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            if (channel?.streamUrl != null)
              ElevatedButton.icon(
                onPressed: () => _openPlayer(channel!),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Assistir'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSection(String title, List<Channel> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (_, i) => SizedBox(
              width: 120,
              child: _posterCard(list[i]),
            ),
          ),
        ),
      ],
    );
  }
}
EOF

# ============================
# 5. INTERNET HTTP LIBERADO
# ============================
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

if manifest.exists():
    text = manifest.read_text()

    if "android.permission.INTERNET" not in text:
        text = text.replace(
            "<application",
            '    <uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1
        )

    if "android:usesCleartextTraffic" not in text:
        text = text.replace("<application", '<application android:usesCleartextTraffic="true"', 1)

    if "android:networkSecurityConfig" not in text:
        text = text.replace("<application", '<application android:networkSecurityConfig="@xml/network_security_config"', 1)

    manifest.write_text(text)
    print("✅ AndroidManifest.xml atualizado.")
else:
    print("⚠️ AndroidManifest.xml não encontrado.")
PY

flutter pub get
flutter clean

echo ""
echo "✅ Correção aplicada com sucesso."
echo ""
echo "Agora rode:"
echo "git add ."
echo "git commit -m \"classificacao tvbox e diagnostico m3u\""
echo "git push"

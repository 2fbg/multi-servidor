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
    return _channelsByType(_filter);
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
    if (type == CategoryFilter.all) return _channels;

    return _channels.where((channel) {
      if (type == CategoryFilter.live) return channel.type == ChannelType.live;
      if (type == CategoryFilter.movies) return channel.type == ChannelType.movie;
      if (type == CategoryFilter.series) return channel.type == ChannelType.series;
      return true;
    }).toList();
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

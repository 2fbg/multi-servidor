import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/channel.dart';
import 'services/m3u_parser.dart';
import 'services/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MultiServidorApp());
}

class MultiServidorApp extends StatelessWidget {
  const MultiServidorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Servidor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final serverCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final data = await SecureStorage.getCredentials();

    serverCtrl.text = data['server'] ?? '';
    userCtrl.text = data['username'] ?? '';
    passCtrl.text = data['password'] ?? '';
  }

  Future<void> _login() async {
    final server = serverCtrl.text.trim();
    final user = userCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (server.isEmpty || user.isEmpty || pass.isEmpty) {
      _showMessage('Preencha servidor, usuário e senha.');
      return;
    }

    setState(() => loading = true);

    await SecureStorage.saveCredentials(
      user,
      pass,
      server: server,
    );

    if (!mounted) return;

    setState(() => loading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          server: server,
          username: user,
          password: pass,
        ),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Multi Servidor',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: serverCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Servidor ou URL M3U',
                              hintText: 'http://servidor.com:8080',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.dns),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Usuário',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: loading ? null : _login,
                                icon: loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login),
                                label: const Text('Entrar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: loading
                                    ? null
                                    : () async {
                                        await SecureStorage.clearCredentials();
                                        serverCtrl.clear();
                                        userCtrl.clear();
                                        passCtrl.clear();
                                      },
                                icon: const Icon(Icons.cleaning_services),
                                label: const Text('Limpar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String server;
  final String username;
  final String password;

  const HomeScreen({
    super.key,
    required this.server,
    required this.username,
    required this.password,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  String? error;

  List<Channel> channels = [];
  String selectedMenu = 'Destaques';
  String search = '';

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  String _buildM3uUrl() {
    var server = widget.server.trim();

    server = server
        .replaceAll('{username}', widget.username)
        .replaceAll('{user}', widget.username)
        .replaceAll('{password}', widget.password)
        .replaceAll('{pass}', widget.password);

    if (!server.startsWith('http://') && !server.startsWith('https://')) {
      server = 'http://$server';
    }

    if (server.contains('get.php') ||
        server.endsWith('.m3u') ||
        server.endsWith('.m3u8')) {
      return server;
    }

    server = server.replaceAll(RegExp(r'/+$'), '');

    return '$server/get.php?username=${Uri.encodeComponent(widget.username)}&password=${Uri.encodeComponent(widget.password)}&type=m3u_plus&output=ts';
  }

  Future<void> _loadChannels() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final url = _buildM3uUrl();
      final list = await M3UParser.parseM3U(url);

      if (!mounted) return;

      setState(() {
        channels = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  List<String> get menus {
    final groups = channels
        .map((e) => e.group ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ['Destaques', 'Todos', ...groups];
  }

  List<Channel> get visibleChannels {
    Iterable<Channel> result = channels;

    if (selectedMenu == 'Destaques') {
      result = channels.where((channel) {
        final group = (channel.group ?? '').toLowerCase();
        final title = channel.title.toLowerCase();

        return group.contains('filmes lançamento') ||
            group.contains('filmes lancamento') ||
            group.contains('lançamento') ||
            group.contains('lancamento') ||
            title.contains('lançamento') ||
            title.contains('lancamento');
      });

      if (result.isEmpty) {
        result = channels.take(30);
      }
    } else if (selectedMenu != 'Todos') {
      result = channels.where((channel) => channel.group == selectedMenu);
    }

    if (search.trim().isNotEmpty) {
      final query = search.toLowerCase().trim();

      result = result.where(
        (channel) =>
            channel.title.toLowerCase().contains(query) ||
            (channel.group ?? '').toLowerCase().contains(query),
      );
    }

    return result.toList();
  }

  Future<void> _logout() async {
    await SecureStorage.clearCredentials();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openChannel(Channel channel) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(channel.title),
        content: SelectableText(
          channel.streamUrl ?? 'URL do canal não encontrada.',
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

  @override
  Widget build(BuildContext context) {
    final list = visibleChannels;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 230,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Multi Servidor',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sair',
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() => search = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: menus.length,
                        itemBuilder: (context, index) {
                          final menu = menus[index];
                          final selected = menu == selectedMenu;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                backgroundColor: selected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                              ),
                              onPressed: () {
                                setState(() => selectedMenu = menu);
                              },
                              child: Text(
                                menu,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _buildContent(list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<Channel> list) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Carregando canais...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Erro ao carregar canais',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _loadChannels,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return const Center(
        child: Text('Nenhum canal encontrado.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedMenu,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${list.length} itens'),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              mainAxisExtent: 150,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final channel = list[index];

              return InkWell(
                onTap: () => _openChannel(channel),
                borderRadius: BorderRadius.circular(16),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: Colors.black12,
                          child: channel.logo != null &&
                                  channel.logo!.trim().isNotEmpty
                              ? Image.network(
                                  channel.logo!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    return const Icon(
                                      Icons.movie,
                                      size: 42,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.movie,
                                  size: 42,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          channel.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

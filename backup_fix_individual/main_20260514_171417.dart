import 'dart:async';
import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MultiServidorApp());
}

const Color kBg = Color(0xFF050505);
const Color kPanel = Color(0xFF141414);
const Color kPanel2 = Color(0xFF202020);
const Color kRed = Color(0xFFE50914);
const Color kText = Color(0xFFF4F4F4);

Map<String, String> iptvHeaders() {
  return {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12; MultiServidor) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
    'Accept': '*/*',
    'Connection': 'keep-alive',
    'Icy-MetaData': '1',
  };
}

String maskUrl(String url) {
  return url
      .replaceAll(RegExp(r'username=[^&]+'), 'username=***')
      .replaceAll(RegExp(r'password=[^&]+'), 'password=***');
}

enum ItemKind { live, movie, series }

class PlaylistSource {
  final String name;
  final String urlTemplate;
  final String? customUser;
  final String? customPassword;

  PlaylistSource({
    required this.name,
    required this.urlTemplate,
    this.customUser,
    this.customPassword,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'urlTemplate': urlTemplate,
        'customUser': customUser,
        'customPassword': customPassword,
      };

  factory PlaylistSource.fromJson(Map<String, dynamic> json) {
    return PlaylistSource(
      name: json['name'] ?? 'Playlist',
      urlTemplate: json['urlTemplate'] ?? '',
      customUser: json['customUser'],
      customPassword: json['customPassword'],
    );
  }

  String buildUrl(String loginUser, String loginPass) {
    final u =
        customUser?.trim().isNotEmpty == true ? customUser!.trim() : loginUser;
    final p = customPassword?.trim().isNotEmpty == true
        ? customPassword!.trim()
        : loginPass;

    var t = urlTemplate.trim();

    if (!t.startsWith('http://') && !t.startsWith('https://')) {
      t = 'http://$t';
    }

    if (!t.contains('get.php') && !t.contains('username=')) {
      if (t.endsWith('/')) t = t.substring(0, t.length - 1);
      t = '$t/get.php?username=USUARIO_DO_LOGIN&password=SENHA_DO_LOGIN&type=m3u_plus&output=mpegts';
    }

    t = t
        .replaceAll('USUARIO_DO_LOGIN', Uri.encodeComponent(u))
        .replaceAll('SENHA_DO_LOGIN', Uri.encodeComponent(p))
        .replaceAll('{user}', Uri.encodeComponent(u))
        .replaceAll('{pass}', Uri.encodeComponent(p))
        .replaceAll('{username}', Uri.encodeComponent(u))
        .replaceAll('{password}', Uri.encodeComponent(p));

    t = t.replaceAll('output=m3u8', 'output=mpegts');

    return t;
  }
}

class StreamItem {
  final String title;
  final String url;
  final String group;
  final String logo;
  final String server;
  final ItemKind kind;

  StreamItem({
    required this.title,
    required this.url,
    required this.group,
    required this.logo,
    required this.server,
    required this.kind,
  });
}

class LoadDiagnostic {
  final String server;
  final String maskedUrl;
  int? statusCode;
  int responseBytes = 0;
  int extinfCount = 0;
  int parsedCount = 0;
  bool foundExtinf = false;
  String? error;
  String preview = '';
  Duration elapsed = Duration.zero;

  LoadDiagnostic({
    required this.server,
    required this.maskedUrl,
  });
}

class M3uLoadResult {
  final List<StreamItem> items;
  final List<LoadDiagnostic> diagnostics;

  M3uLoadResult(this.items, this.diagnostics);
}

class M3uService {
  static final defaultSources = <PlaylistSource>[
    PlaylistSource(
      name: 'VLOG',
      urlTemplate:
          'http://vlogmk.de/get.php?username=USUARIO_DO_LOGIN&password=SENHA_DO_LOGIN&type=m3u_plus&output=mpegts',
    ),
    PlaylistSource(
      name: 'LUB TV',
      urlTemplate:
          'http://triimundial.shop/get.php?username=USUARIO_DO_LOGIN&password=SENHA_DO_LOGIN&type=m3u_plus&output=mpegts',
    ),
    PlaylistSource(
      name: 'CINELON21',
      urlTemplate:
          'http://infinixparcerias.site/get.php?username=USUARIO_DO_LOGIN&password=SENHA_DO_LOGIN&type=m3u_plus&output=mpegts',
    ),
    PlaylistSource(
      name: 'TANNIX',
      urlTemplate:
          'http://unituf.online/get.php?username=USUARIO_DO_LOGIN&password=SENHA_DO_LOGIN&type=m3u_plus&output=mpegts',
    ),
    PlaylistSource(
      name: 'CB6000',
      urlTemplate:
          'http://cb6.fun/get.php?username=USUARIO_DO_LOGIN&password=SENHA_DO_LOGIN&type=m3u_plus&output=mpegts',
    ),
    PlaylistSource(
      name: 'MK21 TV',
      urlTemplate:
          'http://appsmk.org/get.php?username=USUARIO_DO_LOGIN&password=SENHA_DO_LOGIN&type=m3u_plus&output=mpegts',
    ),
  ];

  static Future<M3uLoadResult> loadAll({
    required String user,
    required String pass,
    required List<PlaylistSource> extraSources,
  }) async {
    final sources = [...defaultSources, ...extraSources];
    final allItems = <StreamItem>[];
    final diagnostics = <LoadDiagnostic>[];

    for (final source in sources) {
      final url = source.buildUrl(user, pass);
      final diag = LoadDiagnostic(server: source.name, maskedUrl: maskUrl(url));
      diagnostics.add(diag);

      final sw = Stopwatch()..start();
      try {
        final uri = Uri.parse(url);
        final client = http.Client();
        try {
          final request = http.Request('GET', uri);
          request.headers.addAll(iptvHeaders());

          final streamed =
              await client.send(request).timeout(const Duration(seconds: 75));
          diag.statusCode = streamed.statusCode;

          final bytes = await streamed.stream.fold<List<int>>(<int>[], (a, b) {
            a.addAll(b);
            return a;
          }).timeout(const Duration(seconds: 120));

          diag.responseBytes = bytes.length;

          final body = utf8.decode(bytes, allowMalformed: true);
          diag.preview = body.length > 1200 ? body.substring(0, 1200) : body;
          diag.extinfCount =
              RegExp(r'#EXTINF', caseSensitive: false).allMatches(body).length;
          diag.foundExtinf = diag.extinfCount > 0;

          if (streamed.statusCode != 200) {
            diag.error = 'HTTP ${streamed.statusCode}';
            continue;
          }

          if (!diag.foundExtinf) {
            diag.error =
                'Resposta não contém #EXTINF. Pode ser HTML, bloqueio ou login inválido.';
            continue;
          }

          final parsed = parseM3u(body, source.name);
          diag.parsedCount = parsed.length;
          allItems.addAll(parsed);
        } finally {
          client.close();
        }
      } on TimeoutException catch (e) {
        diag.error = 'Timeout: ${e.message ?? 'servidor demorou demais'}';
      } catch (e) {
        diag.error = e.toString();
      } finally {
        sw.stop();
        diag.elapsed = sw.elapsed;
      }
    }

    final seen = <String>{};
    final unique = <StreamItem>[];
    for (final item in allItems) {
      final key = '${item.url}|${item.title}';
      if (seen.add(key)) unique.add(item);
    }

    return M3uLoadResult(unique, diagnostics);
  }

  static List<StreamItem> parseM3u(String body, String server) {
    final lines = const LineSplitter().convert(body);
    final items = <StreamItem>[];
    String? extinf;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.toUpperCase().startsWith('#EXTINF')) {
        extinf = line;
        continue;
      }

      if (extinf != null &&
          (line.startsWith('http://') || line.startsWith('https://'))) {
        final title = extractTitle(extinf!);
        final group = extractAttr(extinf!, 'group-title').trim().isEmpty
            ? 'Sem categoria'
            : extractAttr(extinf!, 'group-title').trim();
        final logo = extractAttr(extinf!, 'tvg-logo');
        final kind = classifyItem(title, group, line);

        items.add(StreamItem(
          title: title.isEmpty ? 'Sem nome' : title,
          url: line,
          group: group,
          logo: logo,
          server: server,
          kind: kind,
        ));

        extinf = null;
      }
    }

    return items;
  }

  static String extractAttr(String line, String attr) {
    final re = RegExp('$attr="([^"]*)"', caseSensitive: false);
    return re.firstMatch(line)?.group(1) ?? '';
  }

  static String extractTitle(String line) {
    final idx = line.lastIndexOf(',');
    if (idx >= 0 && idx + 1 < line.length) {
      return line.substring(idx + 1).trim();
    }
    return extractAttr(line, 'tvg-name').trim();
  }

  static ItemKind classifyItem(String title, String group, String url) {
    final t = title.toLowerCase();
    final g = group.toLowerCase();
    final u = url.toLowerCase();
    final joined = '$t $g $u';

    final seriesPattern = RegExp(
        r'(s\d{1,2}\s*e\d{1,3})|(\d{1,2}x\d{1,3})|(temporada)|(epis[oó]dio)');
    if (u.contains('/series/') ||
        seriesPattern.hasMatch(joined) ||
        g.contains('serie') ||
        g.contains('série') ||
        g.contains('series') ||
        g.contains('séries')) {
      return ItemKind.series;
    }

    if (u.contains('/movie/') ||
        u.contains('/vod/') ||
        g.contains('filme') ||
        g.contains('movie') ||
        g.contains('cinema') ||
        g.contains('lançamento') ||
        g.contains('lancamento') ||
        g.contains('top 10') ||
        g.contains('ação') ||
        g.contains('acao') ||
        g.contains('comédia') ||
        g.contains('comedia') ||
        g.contains('terror') ||
        g.contains('drama')) {
      return ItemKind.movie;
    }

    return ItemKind.live;
  }
}

class MultiServidorApp extends StatelessWidget {
  const MultiServidorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Servidor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kRed),
        appBarTheme:
            const AppBarTheme(backgroundColor: kBg, foregroundColor: kText),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kPanel2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const BootPage(),
    );
  }
}

class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  bool loading = true;
  String user = '';
  String pass = '';

  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    user = prefs.getString('login_user') ?? '';
    pass = prefs.getString('login_pass') ?? '';
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user.isEmpty || pass.isEmpty) return LoginPage(onLogin: boot);
    return HomePage(user: user, pass: pass, onLogout: boot);
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool hide = true;

  Future<void> save() async {
    if (userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_user', userCtrl.text.trim());
    await prefs.setString('login_pass', passCtrl.text.trim());
    widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: kPanel,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.live_tv, color: kRed, size: 54),
                    const SizedBox(height: 12),
                    const Text('Multi Servidor',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                        controller: userCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Usuário')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: hide,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                          icon: Icon(
                              hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => hide = !hide),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: kRed),
                        onPressed: save,
                        child: const Text('Entrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String user;
  final String pass;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.user,
    required this.pass,
    required this.onLogout,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

enum Section { home, live, movies, series, lists, settings }

class _HomePageState extends State<HomePage> {
  Section section = Section.home;
  bool loading = true;
  String? loadError;
  List<StreamItem> items = [];
  List<LoadDiagnostic> diagnostics = [];
  List<PlaylistSource> extraSources = [];

  @override
  void initState() {
    super.initState();
    loadExtraSources().then((_) => loadLists());
  }

  Future<void> loadExtraSources() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('extra_sources') ?? '[]';
    final decoded = jsonDecode(raw);
    extraSources = (decoded as List)
        .map((e) => PlaylistSource.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveExtraSources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('extra_sources',
        jsonEncode(extraSources.map((e) => e.toJson()).toList()));
  }

  Future<void> loadLists() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      final result = await M3uService.loadAll(
        user: widget.user,
        pass: widget.pass,
        extraSources: extraSources,
      );
      items = result.items;
      diagnostics = result.diagnostics;
    } catch (e) {
      loadError = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  List<StreamItem> get liveItems =>
      items.where((e) => e.kind == ItemKind.live).toList();
  List<StreamItem> get movieItems =>
      items.where((e) => e.kind == ItemKind.movie).toList();
  List<StreamItem> get seriesItems =>
      items.where((e) => e.kind == ItemKind.series).toList();

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_user');
    await prefs.remove('login_pass');
    widget.onLogout();
  }

  void showDiagnostics() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: kPanel,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                const Text('Diagnóstico da lista',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                for (final d in diagnostics)
                  Card(
                    color: kPanel2,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: SelectableText(
                        'Servidor: ${d.server}\n'
                        'URL: ${d.maskedUrl}\n'
                        'Status HTTP: ${d.statusCode ?? '-'}\n'
                        'Tempo: ${d.elapsed.inSeconds}s\n'
                        'Tamanho da resposta: ${d.responseBytes}\n'
                        'Encontrou #EXTINF: ${d.foundExtinf}\n'
                        'Quantidade #EXTINF: ${d.extinfCount}\n'
                        'Canais parseados: ${d.parsedCount}\n'
                        'Erro: ${d.error ?? '-'}\n\n'
                        'Prévia da resposta:\n${d.preview}',
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar')),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          children: [
            const Text('Multi Servidor',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              tooltip: 'Diagnóstico',
              icon: const Icon(Icons.info_outline),
              onPressed: showDiagnostics,
            ),
            IconButton(
              tooltip: 'Listas',
              icon: const Icon(Icons.playlist_add),
              onPressed: () => setState(() => section = Section.lists),
            ),
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: loadLists,
            ),
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget navButton(String label, IconData icon, Section target, int count) {
    final selected = section == target;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => section = target),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: selected ? kRed : kPanel2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              Text('$count'),
            ],
          ),
        ),
      ),
    );
  }

  Widget home() {
    return Row(
      children: [
        SizedBox(
          width: 310,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              navButton(
                  'CANAIS', Icons.live_tv, Section.live, liveItems.length),
              navButton(
                  'FILMES', Icons.movie, Section.movies, movieItems.length),
              navButton('SÉRIES', Icons.video_library, Section.series,
                  seriesItems.length),
              navButton('LISTAS', Icons.playlist_play, Section.lists,
                  extraSources.length),
              navButton('AJUSTES', Icons.settings, Section.settings, 0),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: logout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                    decoration: BoxDecoration(
                        color: kPanel2,
                        borderRadius: BorderRadius.circular(18)),
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 28),
                        SizedBox(width: 14),
                        Text('SAIR',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF3A0205), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.connected_tv, size: 88, color: kRed),
                    const SizedBox(height: 20),
                    const Text('Multi Servidor TV Box',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 34, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      'Canais: ${liveItems.length}  •  Filmes: ${movieItems.length}  •  Séries: ${seriesItems.length}',
                      style:
                          const TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kRed),
                      onPressed: showDiagnostics,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Ver diagnóstico de carregamento'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget currentBody() {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kRed),
            SizedBox(height: 16),
            Text('Carregando listas M3U MPEGTS...'),
          ],
        ),
      );
    }

    if (loadError != null) {
      return Center(child: Text('Erro: $loadError'));
    }

    switch (section) {
      case Section.home:
        return home();
      case Section.live:
        return CatalogPage(
            title: 'Canais', items: liveItems, mode: CatalogMode.channels);
      case Section.movies:
        return CatalogPage(
            title: 'Filmes', items: movieItems, mode: CatalogMode.movies);
      case Section.series:
        return CatalogPage(
            title: 'Séries', items: seriesItems, mode: CatalogMode.series);
      case Section.lists:
        return ListsPage(
          extraSources: extraSources,
          onChanged: (v) async {
            extraSources = v;
            await saveExtraSources();
            await loadLists();
          },
        );
      case Section.settings:
        return SettingsPage(
            onReload: loadLists, onDiagnostics: showDiagnostics);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          topBar(),
          Expanded(child: currentBody()),
        ],
      ),
    );
  }
}

enum CatalogMode { channels, movies, series }

class CatalogPage extends StatefulWidget {
  final String title;
  final List<StreamItem> items;
  final CatalogMode mode;

  const CatalogPage({
    super.key,
    required this.title,
    required this.items,
    required this.mode,
  });

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String selectedGroup = 'Todos';
  String query = '';

  Map<String, int> get groups {
    final map = <String, int>{'Todos': widget.items.length};
    for (final item in widget.items) {
      map[item.group] = (map[item.group] ?? 0) + 1;
    }
    final entries = map.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Todos') return -1;
        if (b.key == 'Todos') return 1;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return Map.fromEntries(entries);
  }

  List<StreamItem> get filtered {
    return widget.items.where((e) {
      final okGroup = selectedGroup == 'Todos' || e.group == selectedGroup;
      final okQuery = query.trim().isEmpty ||
          e.title.toLowerCase().contains(query.toLowerCase());
      return okGroup && okQuery;
    }).toList();
  }

  void openItem(StreamItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerPage(item: item)),
    );
  }

  Widget groupList() {
    final gs = groups;
    return Container(
      width: 260,
      color: const Color(0xFF0D0D0D),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('${widget.title} (${widget.items.length})',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          for (final e in gs.entries)
            ListTile(
              selected: selectedGroup == e.key,
              selectedTileColor: kRed.withOpacity(.75),
              title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text('${e.value}'),
              onTap: () => setState(() => selectedGroup = e.key),
            ),
        ],
      ),
    );
  }

  Widget channelsLayout() {
    final list = filtered;
    final selected = list.isNotEmpty ? list.first : null;
    return Row(
      children: [
        groupList(),
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final item = list[i];
              return ListTile(
                leading: item.logo.isNotEmpty
                    ? Image.network(item.logo,
                        width: 44,
                        height: 44,
                        errorBuilder: (_, __, ___) => const Icon(Icons.tv))
                    : const Icon(Icons.tv),
                title: Text(item.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${item.group} • ${item.server}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => openItem(item),
              );
            },
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: kPanel, borderRadius: BorderRadius.circular(22)),
            child: selected == null
                ? const Center(child: Text('Nenhum canal'))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      selected.logo.isNotEmpty
                          ? Image.network(selected.logo,
                              height: 110,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.live_tv, size: 90))
                          : const Icon(Icons.live_tv, size: 90),
                      const SizedBox(height: 18),
                      Text(selected.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(selected.group,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: kRed),
                        onPressed: () => openItem(selected),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Assistir'),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget gridLayout() {
    final list = filtered;
    return Row(
      children: [
        groupList(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              childAspectRatio: .62,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final item = list[i];
              return InkWell(
                onTap: () => openItem(item),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                      color: kPanel, borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: item.logo.isNotEmpty
                            ? Image.network(
                                item.logo,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.movie, size: 54)),
                              )
                            : Center(
                                child: Icon(
                                  widget.mode == CatalogMode.series
                                      ? Icons.video_library
                                      : Icons.movie,
                                  size: 54,
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Buscar em ${widget.title}',
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: widget.mode == CatalogMode.channels
              ? channelsLayout()
              : gridLayout(),
        ),
      ],
    );
  }
}

class PlayerPage extends StatefulWidget {
  final StreamItem item;
  const PlayerPage({super.key, required this.item});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? video;
  ChewieController? chewie;
  String? error;
  bool loading = true;

  bool get shouldSaveProgress =>
      widget.item.kind == ItemKind.movie || widget.item.kind == ItemKind.series;

  @override
  void initState() {
    super.initState();
    initPlayer();
  }

  Future<void> initPlayer() async {
    try {
      final uri = Uri.parse(widget.item.url);
      video = VideoPlayerController.networkUrl(uri, httpHeaders: iptvHeaders());

      await video!.initialize().timeout(const Duration(seconds: 35));

      if (shouldSaveProgress) {
        final prefs = await SharedPreferences.getInstance();
        final pos = prefs.getInt('progress_${widget.item.url}') ?? 0;
        if (pos > 60000 &&
            pos < (video!.value.duration.inMilliseconds - 60000)) {
          await video!.seekTo(Duration(milliseconds: pos));
        }
      }

      chewie = ChewieController(
        videoPlayerController: video!,
        autoPlay: true,
        looping: false,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 1, 1.25, 1.5, 2, 2.5, 3],
        errorBuilder: (context, message) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Falha ao abrir o vídeo.\n\n'
                'Esse canal pode estar offline, bloqueado, em 4K/codec incompatível '
                'ou em formato não suportado pelo player interno.\n\n'
                'Detalhe técnico:\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          );
        },
      );
    } on TimeoutException {
      error =
          'Timeout ao iniciar o vídeo. Pode ser canal pesado/4K, servidor lento ou link bloqueado.';
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> saveProgress() async {
    if (!shouldSaveProgress || video == null || !video!.value.isInitialized)
      return;
    final pos = video!.value.position.inMilliseconds;
    if (pos > 30000) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('progress_${widget.item.url}', pos);
      await prefs.setString(
          'progress_title_${widget.item.url}', widget.item.title);
    }
  }

  @override
  void dispose() {
    saveProgress();
    chewie?.dispose();
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.item.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: loading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: kRed),
                  SizedBox(height: 12),
                  Text('Abrindo player...'),
                ],
              )
            : error != null
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Falha ao abrir o vídeo.\n\n'
                      'Possíveis causas: canal offline, bloqueio do servidor, codec 4K/H.265 não suportado '
                      'pelo aparelho, link expirado ou servidor demorando demais.\n\n'
                      'Detalhe técnico:\n$error',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : Chewie(controller: chewie!),
      ),
    );
  }
}

class ListsPage extends StatefulWidget {
  final List<PlaylistSource> extraSources;
  final ValueChanged<List<PlaylistSource>> onChanged;

  const ListsPage({
    super.key,
    required this.extraSources,
    required this.onChanged,
  });

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  late List<PlaylistSource> list;

  @override
  void initState() {
    super.initState();
    list = [...widget.extraSources];
  }

  Future<void> addOrEdit({PlaylistSource? source, int? index}) async {
    final name = TextEditingController(text: source?.name ?? '');
    final url = TextEditingController(text: source?.urlTemplate ?? '');
    final user = TextEditingController(text: source?.customUser ?? '');
    final pass = TextEditingController(text: source?.customPassword ?? '');

    final result = await showDialog<PlaylistSource>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: Text(source == null ? 'Adicionar playlist' : 'Editar playlist'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 10),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(
                    labelText: 'URL/base',
                    hintText: 'http://servidor.com ou URL get.php completa',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: user,
                    decoration:
                        const InputDecoration(labelText: 'Usuário opcional')),
                const SizedBox(height: 10),
                TextField(
                    controller: pass,
                    decoration:
                        const InputDecoration(labelText: 'Senha opcional')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () {
              Navigator.pop(
                context,
                PlaylistSource(
                  name: name.text.trim().isEmpty
                      ? 'Playlist extra'
                      : name.text.trim(),
                  urlTemplate: url.text.trim(),
                  customUser:
                      user.text.trim().isEmpty ? null : user.text.trim(),
                  customPassword:
                      pass.text.trim().isEmpty ? null : pass.text.trim(),
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null && result.urlTemplate.isNotEmpty) {
      setState(() {
        if (index == null) {
          list.add(result);
        } else {
          list[index] = result;
        }
      });
      widget.onChanged(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Listas adicionais',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kRed),
                onPressed: () => addOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              )
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'As listas padrão usam usuário/senha do login. Aqui você pode adicionar playlists extras com usuário/senha próprios.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                return Card(
                  color: kPanel,
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(maskUrl(s.urlTemplate),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Wrap(
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => addOrEdit(source: s, index: i)),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            setState(() => list.removeAt(i));
                            widget.onChanged(list);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onReload;
  final VoidCallback onDiagnostics;

  const SettingsPage({
    super.key,
    required this.onReload,
    required this.onDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: kPanel, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings, size: 64, color: kRed),
            const SizedBox(height: 12),
            const Text('Ajustes',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Recarregar listas'),
              onTap: onReload,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Ver diagnóstico HTTP/M3U'),
              onTap: onDiagnostics,
            ),
            const Divider(),
            const Text(
              'Observação: canais 4K podem falhar em aparelhos sem suporte ao codec/bitrate usado pelo servidor. '
              'O app agora mostra erro técnico e evita loop infinito.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

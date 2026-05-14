#!/usr/bin/env bash
set -e

echo "== Multi Servidor - ajuste listas individuais/cache/menu/senha =="

if [ ! -f "pubspec.yaml" ]; then
  echo "ERRO: rode este script dentro da pasta do projeto Flutter."
  exit 1
fi

mkdir -p backup_fix_individual
cp lib/main.dart "backup_fix_individual/main_$(date +%Y%m%d_%H%M%S).dart"

echo "Adicionando dependência path_provider para cache local..."
flutter pub add path_provider

python3 - <<'PY'
from pathlib import Path
import re

p = Path("lib/main.dart")
txt = p.read_text()

# imports
if "import 'dart:io';" not in txt:
    txt = txt.replace("import 'dart:convert';", "import 'dart:convert';\nimport 'dart:io';")
if "package:path_provider/path_provider.dart" not in txt:
    txt = txt.replace(
        "import 'package:http/http.dart' as http;",
        "import 'package:http/http.dart' as http;\nimport 'package:path_provider/path_provider.dart';"
    )

# Replace M3uService class
start = txt.find("class M3uService {")
end = txt.find("class MultiServidorApp", start)
if start == -1 or end == -1:
    raise SystemExit("Não encontrei class M3uService ou class MultiServidorApp. Parei para não quebrar o arquivo.")

new_service = r'''
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

  static String safeFileName(String value) {
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  static Future<File> cacheFileFor(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/m3u_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/${safeFileName(key)}.m3u');
  }

  static Future<M3uLoadResult> loadOne({
    required String user,
    required String pass,
    required PlaylistSource source,
    bool preferCache = true,
    bool forceRefresh = false,
  }) async {
    final url = source.buildUrl(user, pass);
    final cacheKey = '${source.name}|$url';
    final cacheFile = await cacheFileFor(cacheKey);

    final diagnostics = <LoadDiagnostic>[];
    final diag = LoadDiagnostic(server: source.name, maskedUrl: maskUrl(url));
    diagnostics.add(diag);

    if (preferCache && !forceRefresh && await cacheFile.exists()) {
      try {
        final cached = await cacheFile.readAsString();
        diag.statusCode = 200;
        diag.responseBytes = utf8.encode(cached).length;
        diag.preview = cached.length > 1200 ? cached.substring(0, 1200) : cached;
        diag.extinfCount = RegExp(r'#EXTINF', caseSensitive: false).allMatches(cached).length;
        diag.foundExtinf = diag.extinfCount > 0;
        final parsed = parseM3u(cached, source.name);
        diag.parsedCount = parsed.length;
        diag.error = 'Carregado do cache local. Use Atualizar para baixar novamente.';
        return M3uLoadResult(_unique(parsed), diagnostics);
      } catch (_) {
        // Se cache falhar, baixa normal.
      }
    }

    final sw = Stopwatch()..start();

    try {
      final uri = Uri.parse(url);
      final client = http.Client();

      try {
        final request = http.Request('GET', uri);
        request.headers.addAll(iptvHeaders());

        final streamed = await client.send(request).timeout(const Duration(seconds: 90));
        diag.statusCode = streamed.statusCode;

        final bytes = await streamed.stream
            .fold<List<int>>(<int>[], (a, b) {
              a.addAll(b);
              return a;
            })
            .timeout(const Duration(seconds: 150));

        diag.responseBytes = bytes.length;

        final body = utf8.decode(bytes, allowMalformed: true);
        diag.preview = body.length > 1200 ? body.substring(0, 1200) : body;
        diag.extinfCount = RegExp(r'#EXTINF', caseSensitive: false).allMatches(body).length;
        diag.foundExtinf = diag.extinfCount > 0;

        if (streamed.statusCode != 200) {
          diag.error = 'HTTP ${streamed.statusCode}';
          return M3uLoadResult([], diagnostics);
        }

        if (!diag.foundExtinf) {
          diag.error = 'Resposta não contém #EXTINF. Pode ser HTML, bloqueio, login inválido ou acesso restrito.';
          return M3uLoadResult([], diagnostics);
        }

        await cacheFile.writeAsString(body, flush: true);

        final parsed = parseM3u(body, source.name);
        diag.parsedCount = parsed.length;
        return M3uLoadResult(_unique(parsed), diagnostics);
      } finally {
        client.close();
      }
    } on TimeoutException catch (e) {
      diag.error = 'Timeout: ${e.message ?? 'servidor demorou demais'}';
      return M3uLoadResult([], diagnostics);
    } catch (e) {
      diag.error = e.toString();
      return M3uLoadResult([], diagnostics);
    } finally {
      sw.stop();
      diag.elapsed = sw.elapsed;
    }
  }

  static List<StreamItem> _unique(List<StreamItem> allItems) {
    final seen = <String>{};
    final unique = <StreamItem>[];
    for (final item in allItems) {
      final key = '${item.url}|${item.title}';
      if (seen.add(key)) unique.add(item);
    }
    return unique;
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

      if (extinf != null && (line.startsWith('http://') || line.startsWith('https://'))) {
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
      r'(s\d{1,2}\s*e\d{1,3})|(\d{1,2}x\d{1,3})|(temporada)|(epis[oó]dio)|(\be\d{1,3}\b)',
      caseSensitive: false,
    );

    final movieWords = [
      'filme',
      'filmes',
      'movie',
      'movies',
      'vod',
      'cinema',
      'lançamento',
      'lancamento',
      'top 10',
      'ação',
      'acao',
      'crime',
      'guerra',
      'terror',
      'drama',
      'comédia',
      'comedia',
      'animação',
      'animacao',
      'infantil',
      'família',
      'familia',
      'romance',
      'suspense',
      'aventura',
      'documentário',
      'documentario'
    ];

    final seriesWords = [
      'serie',
      'série',
      'series',
      'séries',
      'temporada',
      'episodio',
      'episódio',
      'novela',
      'anime semanal'
    ];

    final liveWords = [
      'canais',
      'canal',
      'ao vivo',
      'aovivo',
      'live',
      'tv',
      '4k',
      'globo',
      'record',
      'sbt',
      'band',
      'sportv',
      'premiere',
      'espn',
      'telecine',
      'hbo'
    ];

    if (u.contains('/series/') ||
        seriesPattern.hasMatch(joined) ||
        seriesWords.any((w) => g.contains(w))) {
      return ItemKind.series;
    }

    if (u.contains('/movie/') ||
        u.contains('/vod/') ||
        movieWords.any((w) => g.contains(w))) {
      return ItemKind.movie;
    }

    if (liveWords.any((w) => g.contains(w))) {
      return ItemKind.live;
    }

    // Em Xtream/M3U MPEGTS, quando não é movie/series, normalmente é canal ao vivo.
    return ItemKind.live;
  }
}

'''
txt = txt[:start] + new_service + "\n" + txt[end:]

# Replace LoginPage class
start = txt.find("class LoginPage extends StatefulWidget")
end = txt.find("class HomePage extends StatefulWidget", start)
if start == -1 or end == -1:
    raise SystemExit("Não encontrei LoginPage/HomePage.")

new_login = r'''
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
  bool savePassword = true;

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    userCtrl.text = prefs.getString('login_user') ?? '';
    passCtrl.text = prefs.getString('login_pass') ?? '';
    savePassword = prefs.getBool('save_password') ?? true;
    if (mounted) setState(() {});
  }

  Future<void> save() async {
    final user = userCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (user.isEmpty || pass.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_user', user);
    await prefs.setBool('save_password', savePassword);

    if (savePassword) {
      await prefs.setString('login_pass', pass);
    } else {
      // Mantém senha só para a sessão atual.
      await prefs.setString('login_pass', pass);
      await prefs.setBool('erase_password_on_next_logout', true);
    }

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.live_tv, color: kRed, size: 54),
                    const SizedBox(height: 12),
                    const Text(
                      'Multi Servidor',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: userCtrl,
                      decoration: const InputDecoration(labelText: 'Usuário'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: hide,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                          icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => hide = !hide),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: savePassword,
                      activeColor: kRed,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Salvar senha neste aparelho'),
                      subtitle: const Text(
                        'Se desmarcar, a senha será removida ao sair.',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      onChanged: (v) => setState(() => savePassword = v ?? true),
                    ),
                    const SizedBox(height: 12),
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

'''
txt = txt[:start] + new_login + "\n" + txt[end:]

# Replace HomePage class through before enum CatalogMode
start = txt.find("class HomePage extends StatefulWidget")
end = txt.find("enum CatalogMode", start)
if start == -1 or end == -1:
    raise SystemExit("Não encontrei HomePage/enum CatalogMode.")

new_home = r'''
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

  int selectedSourceIndex = 0;

  List<PlaylistSource> get allSources => [...M3uService.defaultSources, ...extraSources];

  PlaylistSource get selectedSource {
    final sources = allSources;
    if (sources.isEmpty) {
      return M3uService.defaultSources.first;
    }
    if (selectedSourceIndex < 0 || selectedSourceIndex >= sources.length) {
      selectedSourceIndex = 0;
    }
    return sources[selectedSourceIndex];
  }

  @override
  void initState() {
    super.initState();
    bootHome();
  }

  Future<void> bootHome() async {
    await loadExtraSources();
    final prefs = await SharedPreferences.getInstance();
    selectedSourceIndex = prefs.getInt('selected_source_index') ?? 0;
    if (selectedSourceIndex >= allSources.length) selectedSourceIndex = 0;
    await loadSelectedList(preferCache: true, forceRefresh: false);
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
    await prefs.setString(
      'extra_sources',
      jsonEncode(extraSources.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> selectSource(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_source_index', index);
    setState(() {
      selectedSourceIndex = index;
      section = Section.home;
    });
    await loadSelectedList(preferCache: true, forceRefresh: false);
  }

  Future<void> loadSelectedList({
    bool preferCache = true,
    bool forceRefresh = false,
  }) async {
    setState(() {
      loading = true;
      loadError = null;
      items = [];
      diagnostics = [];
    });

    try {
      final result = await M3uService.loadOne(
        user: widget.user,
        pass: widget.pass,
        source: selectedSource,
        preferCache: preferCache,
        forceRefresh: forceRefresh,
      );

      items = result.items;
      diagnostics = result.diagnostics;
    } catch (e) {
      loadError = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  List<StreamItem> get liveItems => items.where((e) => e.kind == ItemKind.live).toList();
  List<StreamItem> get movieItems => items.where((e) => e.kind == ItemKind.movie).toList();
  List<StreamItem> get seriesItems => items.where((e) => e.kind == ItemKind.series).toList();

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final erase = prefs.getBool('erase_password_on_next_logout') ?? false;

    await prefs.remove('login_user');

    if (erase) {
      await prefs.remove('login_pass');
      await prefs.remove('erase_password_on_next_logout');
    }

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
                Text(
                  'Diagnóstico da lista - ${selectedSource.name}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
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
                        'Itens parseados: ${d.parsedCount}\n'
                        'Erro/Observação: ${d.error ?? '-'}\n\n'
                        'Prévia da resposta:\n${d.preview}',
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget sourceSelector() {
    final sources = allSources;
    if (sources.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kPanel2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedSourceIndex >= sources.length ? 0 : selectedSourceIndex,
          dropdownColor: kPanel2,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: [
            for (int i = 0; i < sources.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  sources[i].name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) selectSource(v);
          },
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
            const Text(
              'Multi Servidor',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            sourceSelector(),
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
              tooltip: 'Atualizar lista selecionada',
              icon: const Icon(Icons.refresh),
              onPressed: () => loadSelectedList(preferCache: false, forceRefresh: true),
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
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
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
              navButton('AO VIVO', Icons.live_tv, Section.live, liveItems.length),
              navButton('FILMES', Icons.movie, Section.movies, movieItems.length),
              navButton('SÉRIES', Icons.video_library, Section.series, seriesItems.length),
              navButton('LISTAS', Icons.playlist_play, Section.lists, extraSources.length),
              navButton('AJUSTES', Icons.settings, Section.settings, 0),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: logout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    decoration: BoxDecoration(
                      color: kPanel2,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 28),
                        SizedBox(width: 14),
                        Text(
                          'SAIR',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
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
                    Text(
                      selectedSource.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ao Vivo: ${liveItems.length}  •  Filmes: ${movieItems.length}  •  Séries: ${seriesItems.length}',
                      style: const TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: () => setState(() => section = Section.live),
                          icon: const Icon(Icons.live_tv),
                          label: const Text('Ao Vivo'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: () => setState(() => section = Section.movies),
                          icon: const Icon(Icons.movie),
                          label: const Text('Filmes'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: () => setState(() => section = Section.series),
                          icon: const Icon(Icons.video_library),
                          label: const Text('Séries'),
                        ),
                        OutlinedButton.icon(
                          onPressed: showDiagnostics,
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Diagnóstico'),
                        ),
                      ],
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: kRed),
            const SizedBox(height: 16),
            Text('Carregando ${selectedSource.name}...'),
            const SizedBox(height: 8),
            const Text(
              'Somente a lista selecionada será carregada.',
              style: TextStyle(color: Colors.white60),
            ),
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
        return CatalogPage(title: 'Ao Vivo', items: liveItems, mode: CatalogMode.channels);
      case Section.movies:
        return CatalogPage(title: 'Filmes', items: movieItems, mode: CatalogMode.movies);
      case Section.series:
        return CatalogPage(title: 'Séries', items: seriesItems, mode: CatalogMode.series);
      case Section.lists:
        return ListsPage(
          extraSources: extraSources,
          onBack: () => setState(() => section = Section.home),
          onChanged: (v) async {
            extraSources = v;
            if (selectedSourceIndex >= allSources.length) selectedSourceIndex = 0;
            await saveExtraSources();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('selected_source_index', selectedSourceIndex);
            setState(() => section = Section.home);
            await loadSelectedList(preferCache: true, forceRefresh: false);
          },
        );
      case Section.settings:
        return SettingsPage(
          onReload: () => loadSelectedList(preferCache: false, forceRefresh: true),
          onDiagnostics: showDiagnostics,
        );
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

'''
txt = txt[:start] + new_home + "\n" + txt[end:]

# Patch ListsPage constructor to include onBack and button
txt = txt.replace(
"""class ListsPage extends StatefulWidget {
  final List<PlaylistSource> extraSources;
  final ValueChanged<List<PlaylistSource>> onChanged;

  const ListsPage({
    super.key,
    required this.extraSources,
    required this.onChanged,
  });""",
"""class ListsPage extends StatefulWidget {
  final List<PlaylistSource> extraSources;
  final ValueChanged<List<PlaylistSource>> onChanged;
  final VoidCallback onBack;

  const ListsPage({
    super.key,
    required this.extraSources,
    required this.onChanged,
    required this.onBack,
  });"""
)

txt = txt.replace(
"""          Row(
            children: [
              const Text('Listas adicionais',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(""",
"""          Row(
            children: [
              IconButton(
                tooltip: 'Voltar ao menu',
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const Text('Listas adicionais',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.home),
                label: const Text('Menu'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon("""
)

p.write_text(txt)
PY

echo "Formatando..."
dart format lib/main.dart

echo "Limpando e baixando dependências..."
flutter clean
flutter pub get

echo "Analisando..."
flutter analyze || true

echo ""
echo "Ajustes aplicados."
echo ""
echo "Teste local:"
echo "flutter run"
echo ""
echo "Enviar para GitHub Actions gerar APK:"
echo "git add ."
echo "git commit -m 'Carrega lista individual com cache e corrige menu IPTV'"
echo "git push"

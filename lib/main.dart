import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'series_catalog_page.dart';
part 'mini_preview_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
    'Accept-Encoding': 'identity',
    'Connection': 'keep-alive',
    'Icy-MetaData': '1',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
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

    var t = urlTemplate.trim().replaceAll('&', '&');

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

    t = t.replaceAll('output=mpegts', 'output=mpegts');

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
        diag.preview =
            cached.length > 1200 ? cached.substring(0, 1200) : cached;
        diag.extinfCount =
            RegExp(r'#EXTINF', caseSensitive: false).allMatches(cached).length;
        diag.foundExtinf = diag.extinfCount > 0;
        final parsed = parseM3u(cached, source.name);
        diag.parsedCount = parsed.length;
        diag.error =
            'Carregado do cache local. Use Atualizar para baixar novamente.';
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

        final streamed =
            await client.send(request).timeout(const Duration(seconds: 90));
        diag.statusCode = streamed.statusCode;

        final bytes = await streamed.stream.fold<List<int>>(<int>[], (a, b) {
          a.addAll(b);
          return a;
        }).timeout(const Duration(seconds: 150));

        diag.responseBytes = bytes.length;

        final body = utf8.decode(bytes, allowMalformed: true);
        diag.preview = body.length > 1200 ? body.substring(0, 1200) : body;
        diag.extinfCount =
            RegExp(r'#EXTINF', caseSensitive: false).allMatches(body).length;
        diag.foundExtinf = diag.extinfCount > 0;

        if (streamed.statusCode != 200) {
          diag.error = 'HTTP ${streamed.statusCode}';
          return M3uLoadResult([], diagnostics);
        }

        if (!diag.foundExtinf) {
          diag.error =
              'Resposta não contém #EXTINF. Pode ser HTML, bloqueio, login inválido ou acesso restrito.';
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
    final u = url.toLowerCase();

    final g = group
        .toLowerCase()
        .replaceAll('♠', '')
        .replaceAll('♣', '')
        .replaceAll('♥', '')
        .replaceAll('♦', '')
        .trim();

    bool groupHas(List<String> words) => words.any((w) => g.contains(w));
    bool groupStarts(List<String> words) => words.any((w) => g.startsWith(w));

    // Primeiro respeita categoria da playlist.
    // Isso evita categoria de filmes aparecer dentro de séries.
    if (groupStarts([
          'filme',
          'filmes',
          'movie',
          'movies',
          'vod',
          'cinema',
          'lancamento',
          'lançamento',
        ]) ||
        groupHas([
          'filmes |',
          'filme |',
          'movies |',
          'movie |',
          'vod |',
        ])) {
      return ItemKind.movie;
    }

    if (groupStarts([
          'series',
          'séries',
          'serie',
          'série',
          'seriados',
          'novelas',
        ]) ||
        groupHas([
          'series |',
          'séries |',
          'serie |',
          'série |',
          'temporada',
          'episodio',
          'episódio',
        ])) {
      return ItemKind.series;
    }

    if (groupStarts([
      'canais',
      'canal',
      'ao vivo',
      'aovivo',
      'live',
      'tv',
    ])) {
      return ItemKind.live;
    }

    // Depois URL Xtream.
    if (u.contains('/movie/') || u.contains('/vod/')) {
      return ItemKind.movie;
    }

    if (u.contains('/series/')) {
      return ItemKind.series;
    }

    // Depois padrões no nome.
    final seriesPattern = RegExp(
      r'(s\d{1,2}\s*e\d{1,3})|(\d{1,2}x\d{1,3})|(temporada)|(epis[oó]dio)',
      caseSensitive: false,
    );

    if (seriesPattern.hasMatch('$t $g')) {
      return ItemKind.series;
    }

    if (groupHas([
      'ação',
      'acao',
      'aventura',
      'comedia',
      'comédia',
      'crime',
      'drama',
      'terror',
      'suspense',
      'romance',
      'animacao',
      'animação',
      'documentario',
      'documentário',
      'familia',
      'família',
    ])) {
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
  bool loggedOut = false;
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
    loggedOut = prefs.getBool('logged_out') ?? false;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user.isEmpty || pass.isEmpty || loggedOut) {
      return LoginPage(onLogin: boot);
    }

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

  final userFocus = FocusNode();
  final passFocus = FocusNode();

  bool hide = true;
  bool savePassword = true;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    userFocus.dispose();
    passFocus.dispose();
    super.dispose();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();

    userCtrl.text = prefs.getString('login_user') ?? '';
    passCtrl.text = prefs.getString('login_pass') ?? '';
    savePassword = prefs.getBool('save_password') ?? true;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> save() async {
    if (submitting) return;

    final user = userCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite usuário e senha para entrar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('login_user', user);
      await prefs.setBool('save_password', savePassword);
      await prefs.setBool('logged_out', false);

      if (savePassword) {
        await prefs.setString('login_pass', pass);
        await prefs.remove('erase_password_on_next_logout');
      } else {
        // Mantém a senha somente até sair do app pelo botão Sair.
        await prefs.setString('login_pass', pass);
        await prefs.setBool('erase_password_on_next_logout', true);
      }

      if (mounted) {
        widget.onLogin();
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Widget loginContent(double maxHeight) {
    final compact = maxHeight < 520;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Card(
        color: kPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 26 : 32,
            vertical: compact ? 18 : 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.live_tv,
                color: kRed,
                size: compact ? 44 : 58,
              ),
              SizedBox(height: compact ? 6 : 12),
              Text(
                'Multi Servidor',
                style: TextStyle(
                  fontSize: compact ? 34 : 42,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: compact ? 16 : 24),
              TextField(
                controller: userCtrl,
                focusNode: userFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(passFocus);
                },
                decoration: const InputDecoration(
                  labelText: 'Usuário',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              TextField(
                controller: passCtrl,
                focusNode: passFocus,
                obscureText: hide,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.visiblePassword,
                onSubmitted: (_) => save(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: hide ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => hide = !hide),
                  ),
                ),
              ),
              SizedBox(height: compact ? 6 : 10),
              Row(
                children: [
                  Checkbox(
                    value: savePassword,
                    activeColor: kRed,
                    onChanged: (v) => setState(() => savePassword = v ?? true),
                  ),
                  const Expanded(
                    child: Text(
                      'Salvar senha neste aparelho',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 14),
              SizedBox(
                width: double.infinity,
                height: compact ? 46 : 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kRed),
                  onPressed: submitting ? null : save,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(submitting ? 'Entrando...' : 'Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: loginContent(constraints.maxHeight),
              ),
            );
          },
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

  int selectedSourceIndex = 0;

  List<PlaylistSource> get allSources =>
      [...M3uService.defaultSources, ...extraSources];

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

  List<StreamItem> get liveItems =>
      items.where((e) => e.kind == ItemKind.live).toList();
  List<StreamItem> get movieItems =>
      items.where((e) => e.kind == ItemKind.movie).toList();
  List<StreamItem> get seriesItems =>
      items.where((e) => e.kind == ItemKind.series).toList();

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final savePassword = prefs.getBool('save_password') ?? true;

    await prefs.setBool('logged_out', true);

    if (!savePassword) {
      await prefs.remove('login_pass');
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
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
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
          value:
              selectedSourceIndex >= sources.length ? 0 : selectedSourceIndex,
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
              tooltip: 'Home',
              icon: const Icon(Icons.home),
              onPressed: () => setState(() => section = Section.home),
            ),
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
              onPressed: () =>
                  loadSelectedList(preferCache: false, forceRefresh: true),
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
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
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
              navButton(
                  'AO VIVO', Icons.live_tv, Section.live, liveItems.length),
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
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 28),
                        SizedBox(width: 14),
                        Text(
                          'SAIR',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
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
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ao Vivo: ${liveItems.length}  •  Filmes: ${movieItems.length}  •  Séries: ${seriesItems.length}',
                      style:
                          const TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: () =>
                              setState(() => section = Section.live),
                          icon: const Icon(Icons.live_tv),
                          label: const Text('Ao Vivo'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: () =>
                              setState(() => section = Section.movies),
                          icon: const Icon(Icons.movie),
                          label: const Text('Filmes'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: () =>
                              setState(() => section = Section.series),
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


  Widget homeRail(String title, List<StreamItem> list, IconData icon) {
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (_, i) {
              final item = list[i];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlayerPage(item: item)),
                  );
                },
                child: Container(
                  width: 135,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: kPanel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: item.logo.isNotEmpty
                            ? Image.network(
                                item.logo,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(child: Icon(icon, size: 52)),
                              )
                            : Center(child: Icon(icon, size: 52)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget homeExtraRails() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          homeRail('🔥 Lançamentos / VOD', movieItems.take(30).toList(), Icons.movie),
          homeRail('📺 Canais ao vivo', liveItems.take(30).toList(), Icons.live_tv),
          homeRail('🍿 Séries', seriesItems.take(30).toList(), Icons.video_library),
        ],
      ),
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
        return CatalogPage(
            title: 'Ao Vivo', items: liveItems, mode: CatalogMode.channels);
      case Section.movies:
        return CatalogPage(
            title: 'Filmes', items: movieItems, mode: CatalogMode.movies);
      case Section.series:
        return SeriesCatalogPage(title: 'Séries', items: seriesItems);
      case Section.lists:
        return ListsPage(
          extraSources: extraSources,
          onBack: () => setState(() => section = Section.home),
          onChanged: (v) async {
            extraSources = v;
            if (selectedSourceIndex >= allSources.length)
              selectedSourceIndex = 0;
            await saveExtraSources();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('selected_source_index', selectedSourceIndex);
            setState(() => section = Section.home);
            await loadSelectedList(preferCache: true, forceRefresh: false);
          },
        );
      case Section.settings:
        return SettingsPage(
          onReload: () =>
              loadSelectedList(preferCache: false, forceRefresh: true),
          onDiagnostics: showDiagnostics,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (section != Section.home) {
          setState(() => section = Section.home);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Column(
          children: [
            topBar(),
            Expanded(child: currentBody()),
          ],
        ),
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
  StreamItem? selectedPreviewItem;

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
    final selected =
        selectedPreviewItem != null && list.contains(selectedPreviewItem)
            ? selectedPreviewItem
            : (list.isNotEmpty ? list.first : null);
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
                onTap: () {
                  if (selectedPreviewItem == item) {
                    openItem(item);
                  } else {
                    setState(() => selectedPreviewItem = item);
                  }
                },
                onLongPress: () => openItem(item),
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
                : MiniPreviewPlayer(
                    item: selected,
                    onOpenFull: () => openItem(selected),
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
                onTap: () {
                  if (selectedPreviewItem == item) {
                    openItem(item);
                  } else {
                    setState(() => selectedPreviewItem = item);
                  }
                },
                onLongPress: () => openItem(item),
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

  double volume = 0.5;
  double brightness = 0.5;
  String? overlayText;

  bool get shouldSaveProgress =>
      widget.item.kind == ItemKind.movie || widget.item.kind == ItemKind.series;

  @override
  void initState() {
    super.initState();
    prepareScreen();
    initPlayer();
  }

  Future<void> prepareScreen() async {
    await WakelockPlus.enable();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      volume = await VolumeController.instance.getVolume();
    } catch (_) {}

    try {
      brightness = await ScreenBrightness().current;
    } catch (_) {}
  }

  Future<void> initPlayer() async {
    try {
      final uri = Uri.parse(widget.item.url);
      video = VideoPlayerController.networkUrl(uri, httpHeaders: iptvHeaders());

      await video!.initialize().timeout(const Duration(seconds: 60));

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
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        aspectRatio: video!.value.aspectRatio <= 0 ? 16 / 9 : video!.value.aspectRatio,
        playbackSpeeds: const [0.5, 1, 1.25, 1.5, 2, 2.5, 3],
        deviceOrientationsOnEnterFullScreen: const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        systemOverlaysOnEnterFullScreen: const [],
        systemOverlaysAfterFullScreen: const [],
      );
    } on TimeoutException {
      error = 'Timeout ao iniciar o vídeo.';
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> saveProgress() async {
    if (!shouldSaveProgress || video == null || !video!.value.isInitialized) {
      return;
    }

    final pos = video!.value.position.inMilliseconds;

    if (pos > 30000) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('progress_${widget.item.url}', pos);
      await prefs.setString('progress_title_${widget.item.url}', widget.item.title);
    }
  }

  void showOverlay(String text) {
    setState(() => overlayText = text);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && overlayText == text) {
        setState(() => overlayText = null);
      }
    });
  }

  Future<void> adjustVolume(double delta) async {
    volume = (volume - delta).clamp(0.0, 1.0);

    try {
      await VolumeController.instance.setVolume(volume);
    } catch (_) {
      await video?.setVolume(volume);
    }

    showOverlay('Volume ${(volume * 100).round()}%');
  }

  Future<void> adjustBrightness(double delta) async {
    brightness = (brightness - delta).clamp(0.05, 1.0);

    try {
      await ScreenBrightness().setScreenBrightness(brightness);
    } catch (_) {}

    showOverlay('Brilho ${(brightness * 100).round()}%');
  }

  void handleVerticalDrag(DragUpdateDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    final delta = details.primaryDelta == null ? 0.0 : details.primaryDelta! / 300;

    if (dx < width / 2) {
      adjustBrightness(delta);
    } else {
      adjustVolume(delta);
    }
  }

  @override
  void dispose() {
    saveProgress();
    chewie?.dispose();
    video?.dispose();

    WakelockPlus.disable();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (loading) {
      content = const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: kRed),
          SizedBox(height: 12),
          Text('Abrindo player...'),
        ],
      );
    } else if (error != null) {
      content = Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Falha ao abrir o vídeo.\n\nDetalhe técnico:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    } else {
      content = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: video!.value.size.width <= 0 ? 1920 : video!.value.size.width,
            height: video!.value.size.height <= 0 ? 1080 : video!.value.size.height,
            child: Chewie(controller: chewie!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: handleVerticalDrag,
        child: Stack(
          children: [
            Center(child: content),
            Positioned(
              left: 12,
              top: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            if (overlayText != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.72),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    overlayText!,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              bottom: 14,
              child: SafeArea(
                child: Text(
                  'Brilho',
                  style: TextStyle(color: Colors.white.withOpacity(.45)),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 14,
              child: SafeArea(
                child: Text(
                  'Volume',
                  style: TextStyle(color: Colors.white.withOpacity(.45)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListsPage extends StatefulWidget {
  final List<PlaylistSource> extraSources;
  final ValueChanged<List<PlaylistSource>> onChanged;
  final VoidCallback onBack;

  const ListsPage({
    super.key,
    required this.extraSources,
    required this.onChanged,
    required this.onBack,
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

#!/usr/bin/env bash
set -e

echo "== Remodelando Multi Servidor para layout TV Box simples =="

if [ ! -f "pubspec.yaml" ]; then
  echo "ERRO: rode dentro da pasta do projeto Flutter."
  exit 1
fi

mkdir -p backup_remodel_tvbox
cp lib/main.dart "backup_remodel_tvbox/main_$(date +%Y%m%d_%H%M%S).dart"
[ -f lib/tvbox_layout.dart ] && cp lib/tvbox_layout.dart "backup_remodel_tvbox/tvbox_layout_$(date +%Y%m%d_%H%M%S).dart" || true

python3 - <<'PY'
from pathlib import Path

p = Path("lib/main.dart")
txt = p.read_text()

# Garante part novo
if "part 'tvbox_layout.dart';" not in txt:
    if "part 'series_catalog_page.dart';" in txt:
        txt = txt.replace(
            "part 'series_catalog_page.dart';",
            "part 'series_catalog_page.dart';\npart 'tvbox_layout.dart';"
        )
    else:
        marker = "import 'package:video_player/video_player.dart';"
        txt = txt.replace(marker, marker + "\n\npart 'tvbox_layout.dart';")

# Troca Home antiga por Home TV Box
txt = txt.replace(
"""      case Section.home:
        return home();""",
"""      case Section.home:
        return TvBoxHomePage(
          sourceName: selectedSource.name,
          liveCount: liveItems.length,
          movieCount: movieItems.length,
          seriesCount: seriesItems.length,
          extraCount: extraSources.length,
          highlights: [
            ...movieItems.take(24),
            ...seriesItems.take(12),
          ],
          onOpenLive: () => setState(() => section = Section.live),
          onOpenMovies: () => setState(() => section = Section.movies),
          onOpenSeries: () => setState(() => section = Section.series),
          onOpenLists: () => setState(() => section = Section.lists),
          onOpenSettings: () => setState(() => section = Section.settings),
          onLogout: logout,
        );"""
)

# Troca Ao Vivo por tela nova
txt = txt.replace(
"""      case Section.live:
        return CatalogPage(title: 'Ao Vivo', items: liveItems, mode: CatalogMode.channels);""",
"""      case Section.live:
        return TvBoxLivePage(
          items: liveItems,
          onBackHome: () => setState(() => section = Section.home),
          onOpenMovies: () => setState(() => section = Section.movies),
          onOpenSeries: () => setState(() => section = Section.series),
        );"""
)

# Troca Ajustes por grade nova
txt = txt.replace(
"""      case Section.settings:
        return SettingsPage(
          onReload: () => loadSelectedList(preferCache: false, forceRefresh: true),
          onDiagnostics: showDiagnostics,
        );""",
"""      case Section.settings:
        return TvBoxSettingsPage(
          onBackHome: () => setState(() => section = Section.home),
          onLists: () => setState(() => section = Section.lists),
          onReload: () => loadSelectedList(preferCache: false, forceRefresh: true),
          onDiagnostics: showDiagnostics,
        );"""
)

# Player principal: MPEGTS
txt = txt.replace(
    "VideoPlayerController.networkUrl(uri, httpHeaders: iptvHeaders());",
    "VideoPlayerController.networkUrl(uri, httpHeaders: iptvHeaders(), formatHint: VideoFormat.other);"
)

p.write_text(txt)
print("main.dart ligado ao layout novo.")
PY

cat > lib/tvbox_layout.dart <<'DART'
part of 'main.dart';

class TvBoxHomePage extends StatelessWidget {
  final String sourceName;
  final int liveCount;
  final int movieCount;
  final int seriesCount;
  final int extraCount;
  final List<StreamItem> highlights;
  final VoidCallback onOpenLive;
  final VoidCallback onOpenMovies;
  final VoidCallback onOpenSeries;
  final VoidCallback onOpenLists;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const TvBoxHomePage({
    super.key,
    required this.sourceName,
    required this.liveCount,
    required this.movieCount,
    required this.seriesCount,
    required this.extraCount,
    required this.highlights,
    required this.onOpenLive,
    required this.onOpenMovies,
    required this.onOpenSeries,
    required this.onOpenLists,
    required this.onOpenSettings,
    required this.onLogout,
  });

  Widget bigMenuButton({
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF242424), Color(0xFF050505)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF04008F), width: 3),
          ),
          child: Row(
            children: [
              Icon(icon, size: 44, color: Colors.white),
              const SizedBox(width: 22),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(fontSize: 20, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget smallButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: const Color(0xFF04008F),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = highlights;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        children: [
          SizedBox(
            width: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: kRed, size: 42),
                    const SizedBox(width: 8),
                    const Text(
                      'MULTI\nSERVIDOR',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                bigMenuButton(
                  icon: Icons.live_tv,
                  label: 'CANAIS',
                  count: liveCount,
                  onTap: onOpenLive,
                ),
                bigMenuButton(
                  icon: Icons.play_circle,
                  label: 'FILMES',
                  count: movieCount,
                  onTap: onOpenMovies,
                ),
                bigMenuButton(
                  icon: Icons.movie_creation,
                  label: 'SÉRIES',
                  count: seriesCount,
                  onTap: onOpenSeries,
                ),
                Row(
                  children: [
                    smallButton(icon: Icons.playlist_add, label: 'Listas', onTap: onOpenLists),
                    const SizedBox(width: 12),
                    smallButton(icon: Icons.settings, label: 'Ajustes', onTap: onOpenSettings),
                    const SizedBox(width: 12),
                    smallButton(icon: Icons.logout, label: 'Sair', onTap: onLogout),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF04008F), width: 3),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D2B1A), Color(0xFF020202), Color(0xFF30000B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: list.isEmpty
                  ? const Center(
                      child: Text(
                        'Lançamentos e destaques aparecem aqui após carregar a lista.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, color: Colors.white70),
                      ),
                    )
                  : PageView.builder(
                      itemCount: list.length,
                      controller: PageController(viewportFraction: 1),
                      itemBuilder: (context, index) {
                        final item = list[index];

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TvBoxPlayerPage(item: item)),
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item.logo.isNotEmpty)
                                Image.network(
                                  item.logo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return const Center(
                                      child: Icon(Icons.local_movies, size: 120, color: kRed),
                                    );
                                  },
                                )
                              else
                                const Center(
                                  child: Icon(Icons.local_movies, size: 120, color: kRed),
                                ),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black87],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 30,
                                right: 30,
                                bottom: 30,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'LANÇAMENTO / DESTAQUE',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${item.group} • ${item.server}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: kRed),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => TvBoxPlayerPage(item: item)),
                                        );
                                      },
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Assistir'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class TvBoxLivePage extends StatefulWidget {
  final List<StreamItem> items;
  final VoidCallback onBackHome;
  final VoidCallback onOpenMovies;
  final VoidCallback onOpenSeries;

  const TvBoxLivePage({
    super.key,
    required this.items,
    required this.onBackHome,
    required this.onOpenMovies,
    required this.onOpenSeries,
  });

  @override
  State<TvBoxLivePage> createState() => _TvBoxLivePageState();
}

class _TvBoxLivePageState extends State<TvBoxLivePage> {
  String selectedGroup = 'Todos';
  String query = '';
  StreamItem? selected;
  Set<String> favorites = {};

  @override
  void initState() {
    super.initState();
    loadFavs();
  }

  Future<void> loadFavs() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = (prefs.getStringList('favorite_live_urls') ?? []).toSet();
    if (mounted) setState(() {});
  }

  Future<void> toggleFavorite(StreamItem item) async {
    final prefs = await SharedPreferences.getInstance();
    if (favorites.contains(item.url)) {
      favorites.remove(item.url);
    } else {
      favorites.add(item.url);
    }
    await prefs.setStringList('favorite_live_urls', favorites.toList());
    if (mounted) setState(() {});
  }

  Map<String, int> get groups {
    final map = <String, int>{
      'Visualizado recentemente': 0,
      'Todos': widget.items.length,
      'Favorito': favorites.length,
      'Lock': 0,
    };

    for (final item in widget.items) {
      map[item.group] = (map[item.group] ?? 0) + 1;
    }

    final entries = map.entries.toList()
      ..sort((a, b) {
        final order = ['Visualizado recentemente', 'Todos', 'Favorito', 'Lock'];
        final ia = order.indexOf(a.key);
        final ib = order.indexOf(b.key);
        if (ia != -1 || ib != -1) {
          return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
        }
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    return Map.fromEntries(entries);
  }

  List<StreamItem> get filtered {
    final q = query.trim().toLowerCase();

    return widget.items.where((item) {
      final okGroup = selectedGroup == 'Todos' ||
          item.group == selectedGroup ||
          (selectedGroup == 'Favorito' && favorites.contains(item.url));

      final okQuery = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.group.toLowerCase().contains(q);

      return okGroup && okQuery;
    }).toList();
  }

  void openFullscreen(StreamItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TvBoxPlayerPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    final current = selected != null && list.contains(selected)
        ? selected
        : (list.isNotEmpty ? list.first : null);

    return WillPopScope(
      onWillPop: () async {
        widget.onBackHome();
        return false;
      },
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: Row(
              children: [
                TextButton(onPressed: widget.onBackHome, child: const Text('Home')),
                const VerticalDivider(color: Colors.white54),
                TextButton(
                  onPressed: () {},
                  child: const Text('Canais', style: TextStyle(color: Colors.amber)),
                ),
                const VerticalDivider(color: Colors.white54),
                TextButton(onPressed: widget.onOpenMovies, child: const Text('Filmes')),
                const VerticalDivider(color: Colors.white54),
                TextButton(onPressed: widget.onOpenSeries, child: const Text('Series')),
                const SizedBox(width: 22),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar canal',
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 285,
                  color: const Color(0xFF202826),
                  child: ListView(
                    children: [
                      for (final e in groups.entries)
                        ListTile(
                          selected: selectedGroup == e.key,
                          selectedTileColor: Colors.black38,
                          title: Text(
                            e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selectedGroup == e.key ? Colors.amber : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Text('${e.value}'),
                          onTap: () {
                            setState(() {
                              selectedGroup = e.key;
                              selected = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 340,
                  color: const Color(0xFF171717),
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final item = list[i];
                      final isSelected = current?.url == item.url;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF332000),
                        leading: Text('${i + 1}', style: const TextStyle(color: Colors.white70)),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isSelected ? Colors.amber : Colors.white),
                        ),
                        subtitle: Text(
                          item.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            favorites.contains(item.url) ? Icons.star : Icons.star_border,
                            color: favorites.contains(item.url) ? Colors.amber : Colors.white54,
                          ),
                          onPressed: () => toggleFavorite(item),
                        ),
                        onTap: () => setState(() => selected = item),
                        onDoubleTap: () => openFullscreen(item),
                        onLongPress: () => openFullscreen(item),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: current == null
                      ? const Center(child: Text('Selecione um canal'))
                      : TvBoxLivePreview(
                          item: current,
                          isFavorite: favorites.contains(current.url),
                          onFavorite: () => toggleFavorite(current),
                          onFullscreen: () => openFullscreen(current),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TvBoxLivePreview extends StatefulWidget {
  final StreamItem item;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onFullscreen;

  const TvBoxLivePreview({
    super.key,
    required this.item,
    required this.isFavorite,
    required this.onFavorite,
    required this.onFullscreen,
  });

  @override
  State<TvBoxLivePreview> createState() => _TvBoxLivePreviewState();
}

class _TvBoxLivePreviewState extends State<TvBoxLivePreview> {
  VideoPlayerController? controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(covariant TvBoxLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.url != widget.item.url) restart();
  }

  Future<void> restart() async {
    await controller?.dispose();
    controller = null;
    loading = true;
    error = null;
    if (mounted) setState(() {});
    await start();
  }

  Future<void> start() async {
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url),
        httpHeaders: iptvHeaders(),
        formatHint: VideoFormat.other,
      );

      controller = c;
      await c.initialize().timeout(const Duration(seconds: 35));
      await c.setVolume(1);
      await c.play();

      if (mounted) setState(() => loading = false);
    } on TimeoutException {
      error = 'Timeout ao abrir prévia';
      if (mounted) setState(() => loading = false);
    } catch (e) {
      error = 'Falha ao abrir prévia';
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget videoArea() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: kRed));
    }

    if (error != null || controller == null || !controller!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.item.logo.isNotEmpty)
            Image.network(
              widget.item.logo,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, size: 100),
            )
          else
            const Center(child: Icon(Icons.live_tv, size: 100)),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black54,
              child: Text(error ?? 'Sem prévia'),
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller!.value.size.width,
        height: controller!.value.size.height,
        child: VideoPlayer(controller!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onFullscreen,
      child: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: SizedBox.expand(child: videoArea()),
            ),
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF250008), Color(0xFF100005)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.item.group} • ${widget.item.server}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kRed),
                          onPressed: widget.onFullscreen,
                          child: const Text('Tela cheia'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: widget.onFavorite,
                          icon: Icon(widget.isFavorite ? Icons.star : Icons.star_border),
                          label: Text(widget.isFavorite ? 'Favorito' : 'Adicionar aos favoritos'),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Duplo clique no vídeo para expandir',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TvBoxSettingsPage extends StatelessWidget {
  final VoidCallback onBackHome;
  final VoidCallback onLists;
  final VoidCallback onReload;
  final VoidCallback onDiagnostics;

  const TvBoxSettingsPage({
    super.key,
    required this.onBackHome,
    required this.onLists,
    required this.onReload,
    required this.onDiagnostics,
  });

  Widget tile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF05008F),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.lock_outline, 'Controle dos pais', () {}),
      (Icons.playlist_play, 'Listas', onLists),
      (Icons.language, 'Mudar idioma', () {}),
      (Icons.dashboard_customize, 'Change Layout', () {}),
      (Icons.visibility_off, 'Ocultar categorias ao vivo', () {}),
      (Icons.visibility_off, 'Ocultar categorias de Vod', () {}),
      (Icons.visibility_off, 'Ocultar categorias de séries', () {}),
      (Icons.delete_sweep, 'Limpar canais de histórico', () {}),
      (Icons.delete_sweep, 'Limpar histórico de filmes', () {}),
      (Icons.delete_sweep, 'Limpar série de histórico', () {}),
      (Icons.sort_by_alpha, 'classificação ao vivo', () {}),
      (Icons.live_tv, 'Live Stream Format', onDiagnostics),
      (Icons.play_circle_outline, 'Leitor externo', () {}),
      (Icons.sync, 'Automático', () {}),
      (Icons.access_time, 'Formato de hora', () {}),
      (Icons.subtitles, 'Configurações de legenda', () {}),
      (Icons.devices, 'Select Device Type', () {}),
      (Icons.refresh, 'Atualizar agora', onReload),
    ];

    return WillPopScope(
      onWillPop: () async {
        onBackHome();
        return false;
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF102117), Color(0xFF050505), Color(0xFF35000C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 34),
                    onPressed: onBackHome,
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Ajustes', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.builder(
                  itemCount: tiles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 4.4,
                  ),
                  itemBuilder: (_, i) {
                    final t = tiles[i];
                    return tile(t.$1, t.$2, t.$3);
                  },
                ),
              ),
              const Text(
                'Endereço MAC: D3:3B:0D:DC:30:AF\nChave do dispositivo: 594936',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TvBoxPlayerPage extends StatefulWidget {
  final StreamItem item;

  const TvBoxPlayerPage({super.key, required this.item});

  @override
  State<TvBoxPlayerPage> createState() => _TvBoxPlayerPageState();
}

class _TvBoxPlayerPageState extends State<TvBoxPlayerPage> {
  VideoPlayerController? video;
  bool loading = true;
  String? error;

  double appBrightness = 1.0;
  double appVolume = 1.0;
  bool showHint = true;

  @override
  void initState() {
    super.initState();
    start();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => showHint = false);
    });
  }

  Future<void> start() async {
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url),
        httpHeaders: iptvHeaders(),
        formatHint: VideoFormat.other,
      );

      video = c;
      await c.initialize().timeout(const Duration(seconds: 60));
      await c.setVolume(appVolume);
      await c.play();

      if (mounted) setState(() => loading = false);
    } on TimeoutException {
      error = 'Timeout ao abrir vídeo.';
      if (mounted) setState(() => loading = false);
    } catch (e) {
      error = e.toString();
      if (mounted) setState(() => loading = false);
    }
  }

  void adjustLeft(double delta) {
    appBrightness = (appBrightness - delta / 260).clamp(0.15, 1.0);
    setState(() {});
  }

  void adjustRight(double delta) {
    appVolume = (appVolume - delta / 260).clamp(0.0, 1.0);
    video?.setVolume(appVolume);
    setState(() {});
  }

  @override
  void dispose() {
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightnessOverlay = (1.0 - appBrightness) * .75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => showHint = !showHint),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (loading)
              const Center(child: CircularProgressIndicator(color: kRed))
            else if (error != null || video == null || !video!.value.isInitialized)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Falha ao abrir o vídeo.\n\n'
                    'Tente outro canal ou outro formato de lista.\n\n'
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ),
              )
            else
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: video!.value.size.width,
                  height: video!.value.size.height,
                  child: VideoPlayer(video!),
                ),
              ),
            IgnorePointer(
              child: Container(color: Colors.black.withOpacity(brightnessOverlay)),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * .28,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (d) => adjustLeft(d.delta.dy),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * .28,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (d) => adjustRight(d.delta.dy),
              ),
            ),
            if (showHint)
              Positioned(
                left: 18,
                right: 18,
                top: 18,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 34),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    IconButton(
                      icon: Icon(video?.value.isPlaying == true ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (video == null) return;
                        if (video!.value.isPlaying) {
                          video!.pause();
                        } else {
                          video!.play();
                        }
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            if (showHint)
              Positioned(
                left: 24,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.black54,
                  child: Text('Brilho: ${(appBrightness * 100).round()}%'),
                ),
              ),
            if (showHint)
              Positioned(
                right: 24,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.black54,
                  child: Text('Volume: ${(appVolume * 100).round()}%'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
DART

dart format lib/main.dart lib/tvbox_layout.dart
flutter analyze 2>&1 | tail -n 80

echo ""
echo "Se não aparecer ERROR acima, envie:"
echo "git add ."
echo "git commit -m 'Remodela layout TV Box simples'"
echo "git push"

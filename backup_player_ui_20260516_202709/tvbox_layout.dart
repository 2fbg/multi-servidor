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

  Widget menuButton(
      IconData icon, String label, int count, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF02008A), width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700),
                ),
              ),
              Text('$count',
                  style: const TextStyle(fontSize: 18, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYearItems =
        highlights.where(isCurrentYearMovieHighlight).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Row(
        children: [
          SizedBox(
            width: 390,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: kRed, size: 38),
                    const SizedBox(width: 10),
                    const Text(
                      'MULTI\nSERVIDOR',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                menuButton(Icons.live_tv, 'CANAIS', liveCount, onOpenLive),
                menuButton(
                    Icons.play_circle, 'FILMES', movieCount, onOpenMovies),
                menuButton(
                    Icons.movie_creation, 'SÉRIES', seriesCount, onOpenSeries),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF02008A), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: currentYearItems.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum filme de ${DateTime.now().year} encontrado nos destaques.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, color: Colors.white70),
                      ),
                    )
                  : PageView.builder(
                      itemCount: currentYearItems.length,
                      itemBuilder: (context, index) {
                        final item = currentYearItems[index];

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TvBoxPlayerPage(item: item)),
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
                                        child: Icon(Icons.movie,
                                            size: 90, color: kRed));
                                  },
                                )
                              else
                                const Center(
                                    child: Icon(Icons.movie,
                                        size: 90, color: kRed)),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black87
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 26,
                                right: 26,
                                bottom: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.group} • ${item.server}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.white70),
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
  bool restrictedUnlocked = false;

  @override
  void initState() {
    super.initState();
    loadPrefs();
  }

  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = (prefs.getStringList('favorite_live_urls') ?? []).toSet();
    restrictedUnlocked = prefs.getBool('restricted_unlocked') ?? false;
    if (mounted) setState(() {});
  }

  bool allowed(StreamItem item) {
    if (restrictedUnlocked) return true;
    return !isRestrictedIptvItem(item);
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

  List<StreamItem> get baseItems {
    return widget.items.where((item) {
      final url = item.url.toLowerCase();
      if (url.contains('/movie/') || url.contains('/series/')) return false;
      if (isProbablyVodGroup(item.group)) return false;
      return allowed(item);
    }).toList();
  }

  Map<String, int> get groups {
    final map = <String, int>{
      'Todos': baseItems.length,
      'Favoritos': baseItems.where((e) => favorites.contains(e.url)).length,
    };

    for (final item in baseItems) {
      map[item.group] = (map[item.group] ?? 0) + 1;
    }

    final entries = map.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Todos') return -1;
        if (b.key == 'Todos') return 1;
        if (a.key == 'Favoritos') return -1;
        if (b.key == 'Favoritos') return 1;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    return Map.fromEntries(entries);
  }

  List<StreamItem> get filtered {
    final q = query.trim().toLowerCase();

    return baseItems.where((item) {
      final groupOk = selectedGroup == 'Todos' ||
          item.group == selectedGroup ||
          (selectedGroup == 'Favoritos' && favorites.contains(item.url));

      final queryOk = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.group.toLowerCase().contains(q);

      return groupOk && queryOk;
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  TextButton(
                      onPressed: widget.onBackHome, child: const Text('Home')),
                  const SizedBox(width: 10),
                  const Text('Canais',
                      style: TextStyle(color: Colors.amber, fontSize: 18)),
                  const SizedBox(width: 18),
                  TextButton(
                      onPressed: widget.onOpenMovies,
                      child: const Text('Filmes')),
                  TextButton(
                      onPressed: widget.onOpenSeries,
                      child: const Text('Séries')),
                  const SizedBox(width: 18),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar em Ao Vivo',
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 270,
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Ao Vivo (${baseItems.length})',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        for (final e in groups.entries)
                          ListTile(
                            dense: true,
                            selected: selectedGroup == e.key,
                            title: Text(e.key,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Text('${e.value}'),
                            selectedColor: kRed,
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
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 360,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final item = list[i];
                        final isSelected = current?.url == item.url;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () => openFullscreen(item),
                          child: ListTile(
                            dense: true,
                            selected: isSelected,
                            leading: item.logo.isNotEmpty
                                ? Image.network(
                                    item.logo,
                                    width: 42,
                                    height: 42,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.live_tv),
                                  )
                                : const Icon(Icons.live_tv),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color:
                                      isSelected ? Colors.amber : Colors.white),
                            ),
                            subtitle: Text(
                              '${item.group} • ${item.server}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                favorites.contains(item.url)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: favorites.contains(item.url)
                                    ? Colors.amber
                                    : Colors.white70,
                              ),
                              onPressed: () => toggleFavorite(item),
                            ),
                            onTap: () => setState(() => selected = item),
                            onLongPress: () => openFullscreen(item),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
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
      await c.initialize().timeout(const Duration(seconds: 15));
      await c.setVolume(1);
      await c.play();

      if (mounted) setState(() => loading = false);
    } on TimeoutException {
      error = 'Timeout';
      if (mounted) setState(() => loading = false);
    } catch (_) {
      error = 'Sem prévia';
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

    if (error != null ||
        controller == null ||
        !controller!.value.isInitialized) {
      return Center(
        child: Text(
          error ?? 'Sem prévia',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: controller!.value.size.width,
        height: controller!.value.size.height,
        child: Center(
          child: AspectRatio(
            aspectRatio: controller!.value.isInitialized
                ? controller!.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(controller!),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onFullscreen,
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Center(child: videoArea()),
            ),
            SizedBox(
              height: 72,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Favorito',
                    onPressed: widget.onFavorite,
                    icon: Icon(
                      widget.isFavorite ? Icons.star : Icons.star_border,
                      color: widget.isFavorite ? Colors.amber : Colors.white70,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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

  Future<void> showRestrictedLockDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('restricted_pin') ?? '';
    final unlocked = prefs.getBool('restricted_unlocked') ?? false;
    final pinCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Bloqueio de conteúdo restrito'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: savedPin.isEmpty
                ? 'Criar PIN de 4 dígitos'
                : unlocked
                    ? 'PIN atual para bloquear/alterar'
                    : 'Digite o PIN para desbloquear',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('restricted_unlocked', false);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Bloquear'),
          ),
          TextButton(
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (savedPin.isNotEmpty && pin == savedPin) {
                await prefs.remove('restricted_pin');
                await prefs.setBool('restricted_unlocked', false);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Remover PIN'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.length < 4) return;

              if (savedPin.isEmpty) {
                await prefs.setString('restricted_pin', pin);
                await prefs.setBool('restricted_unlocked', false);
              } else if (pin == savedPin) {
                await prefs.setBool('restricted_unlocked', true);
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: Text(savedPin.isEmpty ? 'Salvar PIN' : 'Desbloquear'),
          ),
        ],
      ),
    );
  }

  Widget tile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF05008F),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      tile(Icons.arrow_back, 'Voltar para Home', onBackHome),
      tile(Icons.playlist_play, 'Listas', onLists),
      tile(Icons.refresh, 'Atualizar lista', onReload),
      tile(Icons.info_outline, 'Diagnóstico', onDiagnostics),
      tile(Icons.security, 'Bloqueio restrito / PIN',
          () => showRestrictedLockDialog(context)),
      tile(Icons.delete_sweep, 'Limpar histórico', () {}),
      tile(Icons.speed, 'Player / velocidade', () {}),
      tile(Icons.live_tv, 'Formato ao vivo', () {}),
      tile(Icons.subtitles, 'Legendas', () {}),
      tile(Icons.dashboard_customize, 'Layout', () {}),
      tile(Icons.logout, 'Sair dos ajustes', onBackHome),
    ];

    return WillPopScope(
      onWillPop: () async {
        onBackHome();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back, size: 34),
                    onPressed: onBackHome),
                const Expanded(
                  child: Center(
                    child: Text('Ajustes',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.builder(
                itemCount: actions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 4.2,
                ),
                itemBuilder: (_, i) => actions[i],
              ),
            ),
          ],
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
  bool showControls = true;

  double appBrightness = 1.0;
  double appVolume = 1.0;
  double playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    start();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => showControls = false);
    });
  }

  Future<VideoPlayerController> createController({required bool hint}) async {
    final uri = Uri.parse(widget.item.url);

    final c = hint
        ? VideoPlayerController.networkUrl(
            uri,
            httpHeaders: iptvHeaders(),
            formatHint: VideoFormat.other,
          )
        : VideoPlayerController.networkUrl(
            uri,
            httpHeaders: iptvHeaders(),
          );

    await c.initialize().timeout(const Duration(seconds: 45));
    return c;
  }

  Future<void> start() async {
    try {
      VideoPlayerController c;

      try {
        c = await createController(hint: true);
      } catch (_) {
        c = await createController(hint: false);
      }

      video = c;
      await c.setVolume(appVolume);
      await c.setPlaybackSpeed(playbackSpeed);
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

  Future<void> cycleSpeed() async {
    final speeds = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0];
    final index = speeds.indexOf(playbackSpeed);
    playbackSpeed = speeds[(index + 1) % speeds.length];
    await video?.setPlaybackSpeed(playbackSpeed);
    if (mounted) setState(() {});
  }

  Future<void> saveProgress() async {
    if (video == null || !video!.value.isInitialized) return;
    if (widget.item.kind != ItemKind.movie &&
        widget.item.kind != ItemKind.series) return;

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
    video?.dispose();
    super.dispose();
  }

  Widget videoWidget() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: kRed));
    }

    if (error != null || video == null || !video!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            'Falha ao abrir o vídeo.\n\n'
            'Tente outro canal ou outro formato de lista.\n\n'
            '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio:
            video!.value.aspectRatio == 0 ? 16 / 9 : video!.value.aspectRatio,
        child: Center(
          child: AspectRatio(
            aspectRatio: video!.value.isInitialized
                ? video!.value.aspectRatio
                : 16 / 9,
            child: VideoPlayer(video!),
          ),
        ),
      ),
    );
  }

  Widget progressBar() {
    if (video == null || !video!.value.isInitialized)
      return const SizedBox.shrink();

    final duration = video!.value.duration;
    if (duration.inMilliseconds <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 36, 14),
      child: VideoProgressIndicator(
        video!,
        allowScrubbing: true,
        colors: const VideoProgressColors(
          playedColor: kRed,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = (1.0 - appBrightness) * .75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => showControls = !showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            videoWidget(),
            IgnorePointer(
                child: Container(color: Colors.black.withOpacity(overlay))),
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
            if (showControls)
              Positioned(
                left: 18,
                right: 18,
                top: 16,
                child: SafeArea(
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
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      TextButton(
                        onPressed: cycleSpeed,
                        child: Text(
                          '${playbackSpeed.toStringAsFixed(playbackSpeed == playbackSpeed.roundToDouble() ? 0 : 2)}x',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: Icon(video?.value.isPlaying == true
                            ? Icons.pause
                            : Icons.play_arrow),
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
              ),
            if (showControls)
              Positioned(left: 0, right: 0, bottom: 0, child: progressBar()),
          ],
        ),
      ),
    );
  }
}

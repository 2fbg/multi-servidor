part of 'main.dart';

class SeriesMeta {
  final String show;
  final String season;
  final String episode;
  final String code;
  final int seasonNumber;
  final int episodeNumber;

  const SeriesMeta({
    required this.show,
    required this.season,
    required this.episode,
    required this.code,
    required this.seasonNumber,
    required this.episodeNumber,
  });
}

class SeriesCatalogPage extends StatefulWidget {
  final String title;
  final List<StreamItem> items;

  const SeriesCatalogPage({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  State<SeriesCatalogPage> createState() => _SeriesCatalogPageState();
}

class _SeriesCatalogPageState extends State<SeriesCatalogPage> {
  String selectedGroup = 'Todos';
  String selectedShow = '';
  String selectedSeason = 'Todas';
  String query = '';

  String clean(String value) {
    var v = value;
    v = v.replaceAll(RegExp(r'[_\.]+'), ' ');
    v = v.replaceAll(RegExp(r'\s+'), ' ');
    v = v.replaceAll(RegExp(r'^\s*[-|:]\s*'), '');
    v = v.replaceAll(RegExp(r'\s*[-|:]\s*$'), '');
    return v.trim();
  }

  SeriesMeta metaOf(StreamItem item) {
    final name = clean(item.title);

    final patterns = <RegExp>[
      RegExp(r'(.+?)[\s._\-]+S(\d{1,2})\s*E(\d{1,3})(.*)',
          caseSensitive: false),
      RegExp(r'(.+?)[\s._\-]+(\d{1,2})x(\d{1,3})(.*)', caseSensitive: false),
      RegExp(r'(.+?)[\s._\-]+T(\d{1,2})\s*E(\d{1,3})(.*)',
          caseSensitive: false),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(name);
      if (m != null) {
        final show = clean(m.group(1) ?? name);
        final season = int.tryParse(m.group(2) ?? '1') ?? 1;
        final ep = int.tryParse(m.group(3) ?? '0') ?? 0;
        final rest = clean(m.group(4) ?? '');

        return SeriesMeta(
          show: show.isEmpty ? item.group : show,
          season: 'Temporada $season',
          episode: rest.isEmpty ? 'Episódio $ep' : rest,
          code:
              'S${season.toString().padLeft(2, '0')}E${ep.toString().padLeft(2, '0')}',
          seasonNumber: season,
          episodeNumber: ep,
        );
      }
    }

    final sg = RegExp(
      r'(temporada|season)\s*(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(item.group);

    if (sg != null) {
      final season = int.tryParse(sg.group(2) ?? '1') ?? 1;
      return SeriesMeta(
        show: name,
        season: 'Temporada $season',
        episode: name,
        code: '',
        seasonNumber: season,
        episodeNumber: 0,
      );
    }

    return SeriesMeta(
      show: name,
      season: 'Temporada 1',
      episode: name,
      code: '',
      seasonNumber: 1,
      episodeNumber: 0,
    );
  }

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
    final q = query.trim().toLowerCase();

    return widget.items.where((item) {
      final meta = metaOf(item);
      final okGroup = selectedGroup == 'Todos' || item.group == selectedGroup;
      final okQuery = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.group.toLowerCase().contains(q) ||
          meta.show.toLowerCase().contains(q);

      return okGroup && okQuery;
    }).toList();
  }

  Map<String, List<StreamItem>> get shows {
    final map = <String, List<StreamItem>>{};

    for (final item in filtered) {
      final meta = metaOf(item);
      map.putIfAbsent(meta.show, () => []).add(item);
    }

    final entries = map.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Map.fromEntries(entries);
  }

  List<String> seasonsFor(String show) {
    final list = shows[show] ?? [];
    final seasons = <String>{'Todas'};

    for (final item in list) {
      seasons.add(metaOf(item).season);
    }

    final result = seasons.toList()
      ..sort((a, b) {
        if (a == 'Todas') return -1;
        if (b == 'Todas') return 1;

        final na =
            int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '0') ?? 0;
        final nb =
            int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '0') ?? 0;
        return na.compareTo(nb);
      });

    return result;
  }

  List<StreamItem> episodesFor(String show) {
    final list = [...(shows[show] ?? <StreamItem>[])];

    list.retainWhere((item) {
      final meta = metaOf(item);
      return selectedSeason == 'Todas' || meta.season == selectedSeason;
    });

    list.sort((a, b) {
      final ma = metaOf(a);
      final mb = metaOf(b);

      final s = ma.seasonNumber.compareTo(mb.seasonNumber);
      if (s != 0) return s;

      final e = ma.episodeNumber.compareTo(mb.episodeNumber);
      if (e != 0) return e;

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return list;
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
      width: 300,
      color: const Color(0xFF0D0D0D),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Text(
              'Séries (${widget.items.length})',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          for (final e in gs.entries)
            ListTile(
              selected: selectedGroup == e.key,
              selectedTileColor: kRed.withOpacity(.75),
              title: Text(
                e.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selectedGroup == e.key || e.key == 'Todos'
                      ? Colors.white
                      : Colors.white70,
                  fontWeight:
                      e.key == 'Todos' ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: Text('${e.value}'),
              onTap: () {
                setState(() {
                  selectedGroup = e.key;
                  selectedShow = '';
                  selectedSeason = 'Todas';
                });
              },
            ),
        ],
      ),
    );
  }

  Widget showGrid() {
    final entries = shows.entries.toList();

    if (entries.isEmpty) {
      return const Center(child: Text('Nenhuma série encontrada.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: .70,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final showName = entries[i].key;
        final list = entries[i].value;
        final first = list.first;

        final seasonCount = {
          for (final item in list) metaOf(item).season,
        }.length;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              selectedShow = showName;
              selectedSeason = 'Todas';
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: first.logo.isNotEmpty
                      ? Image.network(
                          first.logo,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Center(
                              child: Icon(Icons.video_library, size: 58),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(Icons.video_library, size: 58)),
                ),
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    children: [
                      Text(
                        showName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${list.length} episódios • $seasonCount temp.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget episodeGrid() {
    final episodes = episodesFor(selectedShow);
    final seasons = seasonsFor(selectedShow);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Voltar para séries',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedShow = '';
                    selectedSeason = 'Todas';
                  });
                },
              ),
              Expanded(
                child: Text(
                  selectedShow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = seasons[i];
              final selected = selectedSeason == s;

              return ChoiceChip(
                selected: selected,
                selectedColor: kRed,
                backgroundColor: kPanel2,
                label: Text(s),
                onSelected: (_) {
                  setState(() => selectedSeason = s);
                },
              );
            },
          ),
        ),
        Expanded(
          child: episodes.isEmpty
              ? const Center(child: Text('Nenhum episódio encontrado.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    childAspectRatio: .70,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: episodes.length,
                  itemBuilder: (_, i) {
                    final item = episodes[i];
                    final meta = metaOf(item);

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => openItem(item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPanel,
                          borderRadius: BorderRadius.circular(18),
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
                                      errorBuilder: (_, __, ___) {
                                        return const Center(
                                          child:
                                              Icon(Icons.play_circle, size: 58),
                                        );
                                      },
                                    )
                                  : const Center(
                                      child: Icon(Icons.play_circle, size: 58)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(9),
                              child: Column(
                                children: [
                                  Text(
                                    meta.code.isEmpty ? meta.season : meta.code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    meta.episode,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar em Séries',
            ),
            onChanged: (v) {
              setState(() {
                query = v;
                selectedShow = '';
                selectedSeason = 'Todas';
              });
            },
          ),
        ),
        Expanded(
          child: Row(
            children: [
              groupList(),
              Expanded(
                child: selectedShow.isEmpty ? showGrid() : episodeGrid(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

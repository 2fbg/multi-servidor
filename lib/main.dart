import 'package:flutter/material.dart break;import 'package:flutter/material.dart';

      case HomeSection.series:
        result = channels.where((c) => c.type == ChannelType.series);
        break;

      case HomeSection.live:
        result = channels.where((c) => c.type == ChannelType.live);
        break;

      case HomeSection.all:
        result = channels;
        break;
    }

    if (selectedGroup != null && selectedGroup!.trim().isNotEmpty) {
      result = result.where((c) => c.group == selectedGroup);
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

  List<String> get availableGroups {
    Iterable<Channel> base = channels;

    if (selectedSection == HomeSection.movies) {
      base = channels.where((c) => c.type == ChannelType.movie);
    } else if (selectedSection == HomeSection.series) {
      base = channels.where((c) => c.type == ChannelType.series);
    } else if (selectedSection == HomeSection.live) {
      base = channels.where((c) => c.type == ChannelType.live);
    } else if (selectedSection == HomeSection.releases) {
      base = channels.where(_isRelease);
    }

    final groups = base
        .map((e) => e.group ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return groups;
  }

  String get sectionTitle {
    switch (selectedSection) {
      case HomeSection.highlights:
        return 'Destaques';
      case HomeSection.releases:
        return 'Filmes Lançamento';
      case HomeSection.movies:
        return 'Filmes';
      case HomeSection.series:
        return 'Séries';
      case HomeSection.live:
        return 'Canais';
      case HomeSection.all:
        return 'Todos';
    }
  }

  void _selectSection(HomeSection section) {
    setState(() {
      selectedSection = section;
      selectedGroup = null;
    });
  }

  void _openChannel(Channel channel) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(channel.title),
        content: SelectableText(
          channel.streamUrl ?? 'URL não encontrada.',
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
            _SideBar(
              selected: selectedSection,
              onSelected: _selectSection,
              onLogout: _logout,
              totalChannels: channels.length,
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: sectionTitle,
                    count: list.length,
                    search: search,
                    onSearchChanged: (value) {
                      setState(() => search = value);
                    },
                    onRefresh: _loadChannels,
                  ),
                  if (!loading && error == null && availableGroups.isNotEmpty)
                    _GroupStrip(
                      groups: availableGroups,
                      selected: selectedGroup,
                      onSelected: (group) {
                        setState(() {
                          selectedGroup = group;
                        });
                      },
                    ),
                  Expanded(
                    child: _buildContent(list),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<Channel> list) {
    if (loading) {
      return const _LoadingView();
    }

    if (error != null) {
      return _ErrorView(
        error: error!,
        diagnostic: diagnostic,
        onRetry: _loadChannels,
        onLogout: _logout,
      );
    }

    if (list.isEmpty) {
      return _EmptyView(
        title: 'Nada encontrado',
        subtitle: 'Tente trocar o menu, limpar a busca ou recarregar a lista.',
        onRefresh: _loadChannels,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 172,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final channel = list[index];

        return _MediaCard(
          channel: channel,
          onTap: () => _openChannel(channel),
        );
      },
    );
  }
}

/* =========================
   COMPONENTES HOME
========================= */

class _SideBar extends StatelessWidget {
  final HomeSection selected;
  final ValueChanged<HomeSection> onSelected;
  final VoidCallback onLogout;
  final int totalChannels;

  const _SideBar({
    required this.selected,
    required this.onSelected,
    required this.onLogout,
    required this.totalChannels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 245,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0B1020),
            Color(0xFF111827),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          right: BorderSide(
            color: Color(0x1AFFFFFF),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFF22D3EE),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.live_tv_rounded),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Multi\nServidor',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$totalChannels itens carregados',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.72),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                _MenuButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Destaques',
                  selected: selected == HomeSection.highlights,
                  onTap: () => onSelected(HomeSection.highlights),
                ),
                _MenuButton(
                  icon: Icons.new_releases_rounded,
                  label: 'Filmes Lançamento',
                  selected: selected == HomeSection.releases,
                  onTap: () => onSelected(HomeSection.releases),
                ),
                _MenuButton(
                  icon: Icons.movie_filter_rounded,
                  label: 'Filmes',
                  selected: selected == HomeSection.movies,
                  onTap: () => onSelected(HomeSection.movies),
                ),
                _MenuButton(
                  icon: Icons.video_library_rounded,
                  label: 'Séries',
                  selected: selected == HomeSection.series,
                  onTap: () => onSelected(HomeSection.series),
                ),
                _MenuButton(
                  icon: Icons.tv_rounded,
                  label: 'Canais',
                  selected: selected == HomeSection.live,
                  onTap: () => onSelected(HomeSection.live),
                ),
                _MenuButton(
                  icon: Icons.apps_rounded,
                  label: 'Todos',
                  selected: selected == HomeSection.all,
                  onTap: () => onSelected(HomeSection.all),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: const Color(0xFFFCA5A5),
                side: BorderSide(
                  color: const Color(0xFFFCA5A5).withOpacity(0.45),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? const Color(0xFF8B5CF6).withOpacity(0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.55))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? const Color(0xFFC4B5FD) : Colors.white70,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? Colors.white : Colors.white70,
                    ),
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

class _TopBar extends StatelessWidget {
  final String title;
  final int count;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  const _TopBar({
    required this.title,
    required this.count,
    required this.search,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF070A12),
        border: Border(
          bottom: BorderSide(
            color: Color(0x1AFFFFFF),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22D3EE).withOpacity(0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count itens',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF67E8F9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 310,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar título ou categoria',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Recarregar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _GroupStrip extends StatelessWidget {
  final List<String> groups;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _GroupStrip({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas categorias'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  group,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: selected == group,
                onSelected: (_) => onSelected(group),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;

  const _MediaCard({
    required this.channel,
    required this.onTap,
  });

  IconData get fallbackIcon {
    switch (channel.type) {
      case ChannelType.movie:
        return Icons.movie_filter_rounded;
      case ChannelType.series:
        return Icons.video_library_rounded;
      case ChannelType.live:
        return Icons.tv_rounded;
    }
  }

  String get typeLabel {
    switch (channel.type) {
      case ChannelType.movie:
        return 'Filme';
      case ChannelType.series:
        return 'Série';
      case ChannelType.live:
        return 'Canal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF020617),
                    child: channel.logo != null && channel.logo!.trim().isNotEmpty
                        ? Image.network(
                            channel.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return Icon(
                                fallbackIcon,
                                size: 48,
                                color: Colors.white38,
                              );
                            },
                          )
                        : Icon(
                            fallbackIcon,
                            size: 48,
                            color: Colors.white38,
                          ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        channel.group ?? typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.52),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              const Text(
                'Carregando catálogo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Aguarde enquanto organizamos filmes, séries e canais.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final String? diagnostic;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const _ErrorView({
    required this.error,
    required this.diagnostic,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 54,
                  color: Color(0xFFFCA5A5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Não foi possível carregar a lista',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                  ),
                ),
                if (diagnostic != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        diagnostic!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded),
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
}

class _EmptyView extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  const _EmptyView({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 52),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Recarregar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

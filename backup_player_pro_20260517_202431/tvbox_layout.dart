part of 'package:multi_servidor/main.dart';

bool isRestrictedIptvItemLocal(StreamItem item) {
  final text =
      '${item.title} ${item.group} ${item.url}'.toLowerCase();

  return text.contains('adult') ||
      text.contains('adulto') ||
      text.contains('xxx') ||
      text.contains('[hot]') ||
      text.contains('hot ') ||
      text.contains('| hot') ||
      text.contains('18+') ||
      text.contains('18 anos') ||
      text.contains('maior de idade') ||
      text.contains('porn') ||
      text.contains('sexo') ||
      text.contains('pornô') ||
      text.contains('erótico') ||
      text.contains('erotico');
}

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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Home TV Box - ${sourceName}',
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}

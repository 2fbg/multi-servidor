import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url, {String? sourceName}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android) MultiServidor/1.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        return [];
      }

      final body = response.body.trim();

      if (body.isEmpty) {
        return [];
      }

      if (!body.contains('#EXTINF')) {
        return [];
      }

      final lines = body.split(RegExp(r'\r?\n'));
      final channels = <Channel>[];
      Channel? current;

      for (final raw in lines) {
        final line = raw.trim();

        if (line.isEmpty) continue;

        if (line.startsWith('#EXTINF:')) {
          final title = _extractTitle(line);
          final attrs = _extractAttrs(line);
          final group = attrs['group-title'] ?? attrs['group'] ?? 'Geral';

          current = Channel(
            id: '${sourceName ?? 'src'}_${channels.length}_${title.hashCode}',
            title: title.isEmpty ? 'Sem título' : title,
            group: group,
            logo: attrs['tvg-logo'],
            sourceName: sourceName,
            type: _detectType(title, group, null),
          );
        } else if ((line.startsWith('http://') || line.startsWith('https://')) && current != null) {
          final type = _detectType(current.title, current.group, line);

          channels.add(
            current.copyWith(
              streamUrl: line,
              type: type,
            ),
          );

          current = null;
        }
      }

      return channels;
    } catch (_) {
      return [];
    }
  }

  static String _extractTitle(String line) {
    final comma = line.lastIndexOf(',');

    if (comma >= 0 && comma < line.length - 1) {
      return line.substring(comma + 1).trim();
    }

    return 'Canal';
  }

  static Map<String, String> _extractAttrs(String line) {
    final attrs = <String, String>{};

    final regexDouble = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');
    final regexSingle = RegExp(r"([A-Za-z0-9_-]+)='([^']*)'");

    for (final match in regexDouble.allMatches(line)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    for (final match in regexSingle.allMatches(line)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    return attrs;
  }

  static ChannelType _detectType(String title, String? group, String? url) {
    final text = '${title.toLowerCase()} ${(group ?? '').toLowerCase()} ${(url ?? '').toLowerCase()}';

    final seriesWords = [
      'série',
      'serie',
      'series',
      'séries',
      '/series/',
      '/serie/',
      'temporada',
      'season',
      'episodio',
      'episódio',
      'capitulo',
      'capítulo',
      's01',
      's02',
      's03',
      's04',
      's05',
      'e01',
      'e02',
      'e03',
      'e04',
    ];

    final movieWords = [
      'filme',
      'filmes',
      'movie',
      'movies',
      'cinema',
      'vod',
      '/movie/',
      '/movies/',
      '/filme/',
      '/filmes/',
      'lançamento',
      'lancamento',
      'bluray',
      'dub',
      'legendado',
    ];

    for (final word in seriesWords) {
      if (text.contains(word)) return ChannelType.series;
    }

    for (final word in movieWords) {
      if (text.contains(word)) return ChannelType.movie;
    }

    return ChannelType.live;
  }
}

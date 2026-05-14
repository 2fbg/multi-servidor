import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3ULoadResult {
  final List<Channel> channels;
  final int? statusCode;
  final int bodyLength;
  final int extinfCount;
  final String preview;
  final String? error;
  final String urlMasked;

  M3ULoadResult({
    required this.channels,
    required this.statusCode,
    required this.bodyLength,
    required this.extinfCount,
    required this.preview,
    required this.error,
    required this.urlMasked,
  });

  bool get success => channels.isNotEmpty;
}

class M3UParser {
  static Future<List<Channel>> parseM3U(String url, {String? sourceName}) async {
    final result = await parseWithDiagnostics(url, sourceName: sourceName);
    return result.channels;
  }

  static Future<M3ULoadResult> parseWithDiagnostics(
    String url, {
    String? sourceName,
  }) async {
    final masked = _maskUrl(url);

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Linux; Android) MultiServidor/1.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 90));

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final preview = body.length > 300 ? body.substring(0, 300) : body;
      final extinfCount = RegExp(r'#EXTINF', caseSensitive: false).allMatches(body).length;

      if (response.statusCode != 200) {
        return M3ULoadResult(
          channels: [],
          statusCode: response.statusCode,
          bodyLength: body.length,
          extinfCount: extinfCount,
          preview: preview,
          error: 'HTTP ${response.statusCode}',
          urlMasked: masked,
        );
      }

      if (body.trim().isEmpty) {
        return M3ULoadResult(
          channels: [],
          statusCode: response.statusCode,
          bodyLength: body.length,
          extinfCount: extinfCount,
          preview: preview,
          error: 'Resposta vazia',
          urlMasked: masked,
        );
      }

      if (!body.contains('#EXTINF')) {
        return M3ULoadResult(
          channels: [],
          statusCode: response.statusCode,
          bodyLength: body.length,
          extinfCount: extinfCount,
          preview: preview,
          error: 'Resposta não contém #EXTINF',
          urlMasked: masked,
        );
      }

      final channels = _parseBody(body, sourceName: sourceName);

      return M3ULoadResult(
        channels: channels,
        statusCode: response.statusCode,
        bodyLength: body.length,
        extinfCount: extinfCount,
        preview: preview,
        error: channels.isEmpty ? 'Nenhum canal parseado' : null,
        urlMasked: masked,
      );
    } catch (e) {
      return M3ULoadResult(
        channels: [],
        statusCode: null,
        bodyLength: 0,
        extinfCount: 0,
        preview: '',
        error: e.toString(),
        urlMasked: masked,
      );
    }
  }

  static List<Channel> _parseBody(String body, {String? sourceName}) {
    final lines = body.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    Channel? current;

    for (final raw in lines) {
      final line = raw.trim();

      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final title = _extractTitle(line);
        final attrs = _extractAttrs(line);
        final group = _cleanGroup(attrs['group-title'] ?? attrs['group'] ?? 'Sem grupo');

        current = Channel(
          id: '${sourceName ?? 'src'}_${channels.length}_${title.hashCode}',
          title: title.isEmpty ? 'Sem título' : title,
          group: group,
          logo: attrs['tvg-logo'],
          sourceName: sourceName,
          type: _detectType(title, group, null),
        );
      } else if ((line.startsWith('http://') || line.startsWith('https://')) && current != null) {
        final fixedType = _detectType(current.title, current.group, line);

        channels.add(
          current.copyWith(
            streamUrl: line,
            type: fixedType,
          ),
        );

        current = null;
      }
    }

    return channels;
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

  static String _cleanGroup(String group) {
    return group
        .replaceAll('|', ' | ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static ChannelType _detectType(String title, String? group, String? url) {
    final t = title.toLowerCase();
    final g = (group ?? '').toLowerCase();
    final u = (url ?? '').toLowerCase();
    final text = '$t $g $u';

    // Séries primeiro, pois várias séries também usam palavras parecidas com filme.
    final seriesWords = [
      '/series/',
      '/serie/',
      'series',
      'séries',
      'serie',
      'série',
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

    for (final word in seriesWords) {
      if (text.contains(word)) return ChannelType.series;
    }

    final movieWords = [
      '/movie/',
      '/movies/',
      '/filme/',
      '/filmes/',
      'filme',
      'filmes',
      'movie',
      'movies',
      'cinema',
      'vod',
      'lançamento',
      'lancamento',
      'top 10',
      'ação',
      'acao',
      'crime',
      'guerra',
      'animação',
      'animacao',
      'infantil',
      'família',
      'familia',
      'drama',
      'comédia',
      'comedia',
      'terror',
      'suspense',
      'romance',
      'ficção',
      'ficcao',
      'aventura',
      'documentário',
      'documentario',
    ];

    for (final word in movieWords) {
      if (text.contains(word)) return ChannelType.movie;
    }

    return ChannelType.live;
  }

  static String _maskUrl(String url) {
    return url
        .replaceAll(RegExp(r'username=[^&]+'), 'username=***')
        .replaceAll(RegExp(r'password=[^&]+'), 'password=***');
  }
}

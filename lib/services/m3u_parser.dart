import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url, {String? sourceName}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'MultiServidor/1.0'})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200 || response.body.trim().isEmpty) {
        return [];
      }

      final lines = response.body.split(RegExp(r'\r?\n'));
      final channels = <Channel>[];
      Channel? current;

      for (final raw in lines) {
        final line = raw.trim();

        if (line.isEmpty) continue;

        if (line.startsWith('#EXTINF:')) {
          final title = _extractTitle(line);
          final attrs = _extractAttrs(line);

          current = Channel(
            id: '${sourceName ?? 'src'}_${channels.length}_${title.hashCode}',
            title: title.isEmpty ? 'Sem título' : title,
            group: attrs['group-title'] ?? 'Geral',
            logo: attrs['tvg-logo'],
            sourceName: sourceName,
          );
        } else if ((line.startsWith('http://') || line.startsWith('https://')) && current != null) {
          channels.add(current.copyWith(streamUrl: line));
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
    final regex = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

    for (final match in regex.allMatches(line)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    return attrs;
  }
}

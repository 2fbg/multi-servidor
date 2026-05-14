import 'dart:convert';
import 'dart:io';

class M3UParser {
  static Future<List<Map<String, String>>> parseM3U(String url) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erro ao carregar lista M3U: ${response.statusCode}');
    }

    final content = await response.transform(utf8.decoder).join();
    client.close();

    return parse(content);
  }

  static List<Map<String, String>> parse(String content) {
    final lines = const LineSplitter().convert(content);
    final channels = <Map<String, String>>[];

    String? currentName;
    String? currentLogo;
    String? currentGroup;

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty || line == '#EXTM3U') {
        continue;
      }

      if (line.startsWith('#EXTINF')) {
        currentName = _extractName(line);
        currentLogo = _extractAttribute(line, 'tvg-logo');
        currentGroup = _extractAttribute(line, 'group-title');
      } else if (line.startsWith('http')) {
        channels.add({
          'name': currentName ?? 'Canal',
          'url': line,
          'logo': currentLogo ?? '',
          'group': currentGroup ?? '',
        });

        currentName = null;
        currentLogo = null;
        currentGroup = null;
      }
    }

    return channels;
  }

  static String _extractName(String line) {
    final commaIndex = line.lastIndexOf(',');
    if (commaIndex != -1 && commaIndex < line.length - 1) {
      return line.substring(commaIndex + 1).trim();
    }
    return 'Canal';
  }

  static String? _extractAttribute(String line, String attribute) {
    final regex = RegExp('$attribute="([^"]*)"');
    final match = regex.firstMatch(line);
    return match?.group(1);
  }
}

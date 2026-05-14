import 'dart:convert';
import 'dart:io';

import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url) async {
    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Erro ao carregar lista M3U: ${response.statusCode}');
      }

      final content = await response.transform(utf8.decoder).join();
      return parse(content);
    } finally {
      client.close();
    }
  }

  static List<Channel> parse(String content) {
    final lines = const LineSplitter().convert(content);
    final channels = <Channel>[];

    String? currentTitle;
    String? currentLogo;
    String? currentGroup;

    var index = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty || line == '#EXTM3U') {
        continue;
      }

      if (line.startsWith('#EXTINF')) {
        currentTitle = _extractTitle(line);
        currentLogo = _extractAttribute(line, 'tvg-logo');
        currentGroup = _extractAttribute(line, 'group-title');
      } else if (line.startsWith('http')) {
        index++;

        channels.add(
          Channel(
            id: index.toString(),
            title: currentTitle ?? 'Canal $index',
            group: currentGroup,
            logo: currentLogo,
            streamUrl: line,
          ),
        );

        currentTitle = null;
        currentLogo = null;
        currentGroup = null;
      }
    }

    return channels;
  }

  static String _extractTitle(String line) {
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

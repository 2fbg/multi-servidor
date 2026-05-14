import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse(url);

      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));

      final response = await request
          .close()
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Servidor respondeu com erro: ${response.statusCode}');
      }

      final content = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 25));

      final channels = parse(content);

      if (channels.isEmpty) {
        throw Exception('Nenhum canal encontrado na lista M3U.');
      }

      return channels;
    } on TimeoutException {
      throw Exception('Tempo esgotado ao tentar carregar a lista.');
    } on SocketException {
      throw Exception('Falha de conexão com o servidor.');
    } on FormatException {
      throw Exception('URL inválida.');
    } finally {
      client.close(force: true);
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

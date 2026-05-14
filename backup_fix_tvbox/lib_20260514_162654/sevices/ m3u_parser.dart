import 'package:http/http.dart' as http;
import '../models/channel.dart';

class M3UParser {
  static Future<List<Channel>> parseM3U(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) return [];

      final lines = response.body.split('\n');
      final channels = <Channel>[];
      Channel? current;

      for (final line in lines) {
        if (line.startsWith('#EXTINF:')) {
          final title = line.split(',').last.trim();

          current = Channel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
          );
        } else if (line.startsWith('http') && current != null) {
          channels.add(current.copyWith(streamUrl: line));
          current = null;
        }
      }

      return channels;
    } catch (_) {
      return [];
    }
  }
}
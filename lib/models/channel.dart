// lib/models/channel.dart

class Channel {
  final String name;
  final String streamUrl;
  final String? logo;
  final String? groupTitle;
  final String category; // live, movies, series

  Channel({
    required this.name,
    required this.streamUrl,
    this.logo,
    this.groupTitle,
    required this.category,
  });

  // Parser básico de linha M3U (será melhorado depois)
  factory Channel.fromM3ULine(String extinfLine, String urlLine) {
    String name = 'Canal Desconhecido';
    String? logo;
    String? group;

    // Extrai nome
    if (extinfLine.contains(',')) {
      name = extinfLine.split(',').last.trim();
    }
    // Extrai logo
    if (extinfLine.contains('tvg-logo="')) {
      logo = extinfLine.split('tvg-logo="')[1].split('"')[0];
    }
    // Extrai grupo
    if (extinfLine.contains('group-title="')) {
      group = extinfLine.split('group-title="')[1].split('"')[0];
    }

    return Channel(
      name: name,
      streamUrl: urlLine.trim(),
      logo: logo,
      groupTitle: group,
      category: group?.toLowerCase().contains('filme') == true ? 'movies' :
                group?.toLowerCase().contains('serie') == true ? 'series' : 'live',
    );
  }
}

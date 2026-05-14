class Server {
  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final bool directUrl;
  final String outputFormat;

  const Server({
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    this.directUrl = false,
    this.outputFormat = 'm3u8',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseUrl': baseUrl,
        'username': username,
        'password': password,
        'directUrl': directUrl,
        'outputFormat': outputFormat,
      };

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      name: json['name'] ?? 'Playlist',
      baseUrl: json['baseUrl'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      directUrl: json['directUrl'] == true,
      outputFormat: json['outputFormat'] ?? 'm3u8',
    );
  }
}

class ServerConfig {
  static List<Server> buildDefaultServers(String user, String pass) {
    return [
      Server(name: 'VLOG', baseUrl: 'http://vlogmk.de', username: user, password: pass),
      Server(name: 'LUB TV', baseUrl: 'http://triimundial.shop', username: user, password: pass),
      Server(name: 'CINELON21', baseUrl: 'http://cinelontv.work', username: user, password: pass),
      Server(name: 'TANNIX', baseUrl: 'http://zeip.fun', username: user, password: pass),
      Server(name: 'CB6000', baseUrl: 'http://kraewert.top', username: user, password: pass),
      Server(name: 'MK21 TV', baseUrl: 'http://mk21.uk', username: user, password: pass),
      Server(name: 'NOVATV', baseUrl: 'http://novatv.news', username: user, password: pass),
    ];
  }

  static String buildM3UUrl(Server server) {
    if (server.directUrl) {
      return server.baseUrl.trim();
    }

    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/get.php?username=${Uri.encodeComponent(server.username)}&password=${Uri.encodeComponent(server.password)}&type=m3u_plus&output=${server.outputFormat}';
  }

  static String safeUrlForDebug(Server server) {
    if (server.directUrl) return server.baseUrl;
    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/get.php?username=***&password=***&type=m3u_plus&output=${server.outputFormat}';
  }
}

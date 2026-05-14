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
    this.outputFormat = 'mpegts',
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
      outputFormat: json['outputFormat'] ?? 'mpegts',
    );
  }
}

class ServerConfig {
  static List<Server> buildDefaultServers(String user, String pass) {
    return [
      Server(
        name: 'VLOG',
        baseUrl: 'http://vlogmk.de',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'LUB TV',
        baseUrl: 'http://triimundial.shop',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'CINELON21',
        baseUrl: 'http://infinixparcerias.site',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'TANNIX',
        baseUrl: 'http://unituf.online',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'CB6000',
        baseUrl: 'http://cb6.fun',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
      Server(
        name: 'MK21 TV',
        baseUrl: 'http://appsmk.org',
        username: user,
        password: pass,
        outputFormat: 'mpegts',
      ),
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

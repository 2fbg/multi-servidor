class Server {
  final String name;
  final String baseUrl;
  final String username;
  final String password;

  Server({
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
  });
}

class ServerConfig {
  static List<Server> buildServers(String user, String pass) {
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
    return '${server.baseUrl}/get.php?username=${server.username}&password=${server.password}&type=m3u_plus&output=mpegts';
  }
}
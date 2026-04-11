// lib/config/servers.dart

const List<Map<String, dynamic>> servers = [
  {
    'name': 'VLOG',
    'baseUrl': 'http://vlogmk.de',
  },
  {
    'name': 'LUB TV',
    'baseUrl': 'http://triimundial.shop',
  },
  {
    'name': 'CINELON21',
    'baseUrl': 'http://cinelontv.work',
  },
  {
    'name': 'TANNIX',
    'baseUrl': 'http://zeip.fun',
  },
  {
    'name': 'CB6000',
    'baseUrl': 'http://kraewert.top',
  },
  {
    'name': 'MK21 TV',
    'baseUrl': 'http://mk21.uk',
  },
  {
    'name': 'NOVATV',
    'baseUrl': 'http://novatv.news',
  },
];

// Função para gerar a URL da playlist M3U
String getM3UUrl(String baseUrl, String username, String password) {
  return '$baseUrl/get.php?username=$username&password=$password&type=m3u_plus&output=mpegts';
}

#!/usr/bin/env bash
set -e

echo "🔧 Aplicando correção de timeout, links MPEGTS e diagnóstico..."

mkdir -p lib/config android/app/src/main/res/xml

cat > lib/config/servers.dart <<'EOF'
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
      Server(name: 'VLOG', baseUrl: 'http://vlogmk.de', username: user, password: pass),
      Server(name: 'LUB TV', baseUrl: 'http://triimundial.shop', username: user, password: pass),
      Server(name: 'CINELON21', baseUrl: 'http://infinixparcerias.site', username: user, password: pass),
      Server(name: 'TANNIX', baseUrl: 'http://unituf.online', username: user, password: pass),
      Server(name: 'CB6000', baseUrl: 'http://cb6.fun', username: user, password: pass),
      Server(name: 'MK21 TV', baseUrl: 'http://appsmk.org', username: user, password: pass),
    ];
  }

  static String buildM3UUrl(Server server) {
    if (server.directUrl) return server.baseUrl.trim();

    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

    return '$base/get.php?username=${Uri.encodeComponent(server.username)}&password=${Uri.encodeComponent(server.password)}&type=m3u_plus&output=mpegts';
  }

  static String safeUrlForDebug(Server server) {
    if (server.directUrl) return server.baseUrl;

    final base = server.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

    return '$base/get.php?username=***&password=***&type=m3u_plus&output=mpegts';
  }
}
EOF

cat > android/app/src/main/res/xml/network_security_config.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            system
        </trust-anchors>
    </base-config>
</network-security-config>
EOF

python3 - <<'PY'
from pathlib import Path

main = Path("lib/main.dart")
text = main.read_text()

# Aumenta timeouts externos que podem cortar playlists grandes.
text = text.replace(".timeout(const Duration(seconds: 14))", ".timeout(const Duration(seconds: 90))")
text = text.replace(".timeout(const Duration(seconds: 12))", ".timeout(const Duration(seconds: 90))")
text = text.replace(".timeout(const Duration(seconds: 22))", ".timeout(const Duration(seconds: 90))")
text = text.replace(".timeout(const Duration(seconds: 45))", ".timeout(const Duration(seconds: 90))")

# Melhora mensagens de status para o usuário.
text = text.replace(
    "Carregando servidor principal...",
    "Carregando servidor principal... Aguarde, listas grandes podem demorar."
)

text = text.replace(
    "'Carregando ${server.name}...'",
    "'Carregando ${server.name}... Aguarde, lista grande pode demorar.'"
)

main.write_text(text)

parser = Path("lib/services/m3u_parser.dart")
if parser.exists():
    p = parser.read_text()
    p = p.replace(".timeout(const Duration(seconds: 45))", ".timeout(const Duration(seconds: 90))")
    p = p.replace(".timeout(const Duration(seconds: 22))", ".timeout(const Duration(seconds: 90))")
    parser.write_text(p)

manifest = Path("android/app/src/main/AndroidManifest.xml")
if manifest.exists():
    m = manifest.read_text()

    if "android.permission.INTERNET" not in m:
        m = m.replace(
            "<application",
            '    <uses-permission android:name="android.permission.INTERNET"/>\n    <application',
            1
        )

    if "android:usesCleartextTraffic" not in m:
        m = m.replace("<application", '<application android:usesCleartextTraffic="true"', 1)

    if "android:networkSecurityConfig" not in m:
        m = m.replace("<application", '<application android:networkSecurityConfig="@xml/network_security_config"', 1)

    manifest.write_text(m)

print("✅ Timeouts aumentados para 90s.")
print("✅ Links padrão corrigidos para output=mpegts.")
print("✅ Network security config corrigido.")
PY

flutter pub get
flutter clean

echo ""
echo "✅ Correção aplicada."
echo ""
echo "IMPORTANTE:"
echo "1. Gere um novo APK."
echo "2. Desinstale o app atual do celular."
echo "3. Instale o novo APK."
echo "4. Faça login novamente com usuário e senha válidos."
echo ""
echo "Agora rode:"
echo "git add ."
echo "git commit -m \"corrige timeout links mpegts\""
echo "git push"

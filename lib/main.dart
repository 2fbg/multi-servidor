import 'package:flutter/material.dart';
import 'config/servers.dart';
import 'models/channel.dart';
import 'services/m3u_parser.dart';
import 'services/storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// SPLASH
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _State();
}

class _State extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    final creds = await SecureStorage.getCredentials();

    Future.delayed(const Duration(seconds: 1), () {
      if (creds != null) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// LOGIN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _Login();
}

class _Login extends State<LoginScreen> {
  final user = TextEditingController();
  final pass = TextEditingController();
  bool remember = true;

  Future<void> login() async {
    await SecureStorage.saveCredentials(user.text, pass.text);

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: user, decoration: const InputDecoration(labelText: 'User')),
            TextField(controller: pass, decoration: const InputDecoration(labelText: 'Password')),
            Row(
              children: [
                Checkbox(
                  value: remember,
                  onChanged: (v) => setState(() => remember = v!),
                ),
                const Text('Salvar login'),
              ],
            ),
            ElevatedButton(onPressed: login, child: const Text("Entrar"))
          ],
        ),
      ),
    );
  }
}

// HOME
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _Home();
}

class _Home extends State<HomeScreen> {
  List<Channel> channels = [];
  bool loading = true;
  List<Server> servers = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final creds = await SecureStorage.getCredentials();

    servers = ServerConfig.buildServers(
      creds!['user']!,
      creds['pass']!,
    );

    final futures = servers.map((s) async {
      final url = ServerConfig.buildM3UUrl(s);
      return M3UParser.parseM3U(url);
    });

    final results = await Future.wait(futures);

    for (var list in results) {
      channels.addAll(list);
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Multi Servidor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SecureStorage.clearCredentials();
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: channels.length,
              itemBuilder: (_, i) {
                final c = channels[i];
                return ListTile(
                  title: Text(c.title),
                  trailing: const Icon(Icons.play_arrow),
                );
              },
            ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  runApp(MultiServidorApp(savedThemeMode: savedThemeMode));
}

class MultiServidorApp extends StatelessWidget {
  final AdaptiveThemeMode? savedThemeMode;
  
  const MultiServidorApp({this.savedThemeMode});
  
  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00E5FF)),
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.light().textTheme),
      ),
      dark: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
          background: const Color(0xFF0A0E17),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme)
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      initial: savedThemeMode ?? AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        title: 'Multi Servidor',
        theme: theme,
        darkTheme: darkTheme,
        home: const LoginScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController(text: '311235553');
  final _passCtrl = TextEditingController(text: '427591464');
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, const Color(0xFF0A0E17), Colors.black],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.smart_display, size: 80, color: Color(0xFF00E5FF)),
                const SizedBox(height: 24),
                Text('MULTI SERVIDOR', 
                  style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 32),
                _buildField('Usuário', _userCtrl, Icons.person),
                const SizedBox(height: 16),
                _buildField('Senha', _passCtrl, Icons.lock, obscure: true),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pushReplacement(context, 
                      MaterialPageRoute(builder: (_) => const HomeScreen())),
                    child: const Text('ENTRAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),          ),
        ),
      ),
    );
  }
  
  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: const Color(0xFF00E5FF)),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Multi Servidor'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.live_tv), text: 'Ao Vivo'),
              Tab(icon: Icon(Icons.movie), text: 'Filmes'),
              Tab(icon: Icon(Icons.tv), text: 'Séries'),
              Tab(icon: Icon(Icons.star), text: 'Top 20'),
            ],
            isScrollable: true,
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
            IconButton(icon: const Icon(Icons.add_link), onPressed: () {}),
          ],
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('📺 Canais ao vivo\n\nToque para carregar', textAlign: TextAlign.center)),            Center(child: Text('🎬 Filmes\n\nEm breve', textAlign: TextAlign.center)),
            Center(child: Text('📺 Séries\n\nEm breve', textAlign: TextAlign.center)),
            Center(child: Text('🔥 Top 20\n\nAssista para aparecer aqui', textAlign: TextAlign.center)),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.favorite),
          onPressed: () {},
          tooltip: 'Favoritos',
        ),
      ),
    );
  }
}

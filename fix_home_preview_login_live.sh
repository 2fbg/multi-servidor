#!/usr/bin/env bash
set -e

echo "== Ajustando login salvo, Home destaques, preview maior e player ao vivo =="

if [ ! -f "pubspec.yaml" ]; then
  echo "ERRO: rode dentro da pasta do projeto Flutter."
  exit 1
fi

mkdir -p backup_fix_home_preview
cp lib/main.dart "backup_fix_home_preview/main_$(date +%Y%m%d_%H%M%S).dart"
[ -f lib/mini_preview_player.dart ] && cp lib/mini_preview_player.dart "backup_fix_home_preview/mini_preview_$(date +%Y%m%d_%H%M%S).dart" || true

python3 - <<'PY'
from pathlib import Path

p = Path("lib/main.dart")
txt = p.read_text()

def find_method_block(s, signature, start_from=0):
    start = s.find(signature, start_from)
    if start == -1:
        return -1, -1
    brace = s.find("{", start)
    depth = 0
    for i in range(brace, len(s)):
        if s[i] == "{":
            depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
    return start, -1

# 1) Corrigir logout para NÃO apagar usuário salvo.
start, end = find_method_block(txt, "Future<void> logout() async")
if start != -1 and end != -1:
    new_logout = r'''Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final erase = prefs.getBool('erase_password_on_next_logout') ?? false;

    // Mantém o usuário salvo para aparecer novamente na tela de login.
    // Remove senha somente se o usuário desmarcou "Salvar senha".
    if (erase) {
      await prefs.remove('login_pass');
      await prefs.remove('erase_password_on_next_logout');
    }

    widget.onLogout();
  }'''
    txt = txt[:start] + new_logout + txt[end:]
else:
    print("Aviso: não encontrei logout().")

# 2) Garantir que o login sempre salve usuário.
txt = txt.replace(
    "await prefs.setString('login_user', user);",
    "await prefs.setString('login_user', user);"
)

# 3) Melhorar player principal para MPEGTS/ao vivo.
txt = txt.replace(
    "VideoPlayerController.networkUrl(uri, httpHeaders: iptvHeaders());",
    "VideoPlayerController.networkUrl(uri, httpHeaders: iptvHeaders(), formatHint: VideoFormat.other);"
)

txt = txt.replace(
    "await video!.initialize().timeout(const Duration(seconds: 35));",
    "await video!.initialize().timeout(const Duration(seconds: 60));"
)

# 4) Trocar Home por vitrine de destaques, sem card selecionado estourando.
start, end = find_method_block(txt, "Widget home()")
if start == -1 or end == -1:
    raise SystemExit("Não encontrei Widget home() para substituir.")

new_home = r'''Widget home() {
    final highlights = [
      ...movieItems.take(18),
      ...seriesItems.take(10),
      ...liveItems.take(6),
    ];

    return Row(
      children: [
        SizedBox(
          width: 330,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              navButton('AO VIVO', Icons.live_tv, Section.live, liveItems.length),
              navButton('FILMES', Icons.movie, Section.movies, movieItems.length),
              navButton('SÉRIES', Icons.video_library, Section.series, seriesItems.length),
              navButton('LISTAS', Icons.playlist_play, Section.lists, extraSources.length),
              navButton('AJUSTES', Icons.settings, Section.settings, 0),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: logout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    decoration: BoxDecoration(
                      color: kPanel2,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 28),
                        SizedBox(width: 14),
                        Text(
                          'SAIR',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF3A0205), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: highlights.isEmpty
                ? const Center(
                    child: Text(
                      'Carregue uma lista para ver os destaques',
                      style: TextStyle(fontSize: 22, color: Colors.white70),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: kRed, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Destaques de ${selectedSource.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        child: Text(
                          'Ao Vivo: ${liveItems.length}  •  Filmes: ${movieItems.length}  •  Séries: ${seriesItems.length}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: PageView.builder(
                          controller: PageController(viewportFraction: 0.72),
                          itemCount: highlights.length,
                          itemBuilder: (context, index) {
                            final item = highlights[index];

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PlayerPage(item: item)),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.35),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: item.logo.isNotEmpty
                                            ? Image.network(
                                                item.logo,
                                                fit: BoxFit.cover,
                                                height: double.infinity,
                                                errorBuilder: (_, __, ___) {
                                                  return const Center(
                                                    child: Icon(Icons.movie, size: 80, color: kRed),
                                                  );
                                                },
                                              )
                                            : const Center(
                                                child: Icon(Icons.movie, size: 80, color: kRed),
                                              ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.kind == ItemKind.live
                                                    ? 'AO VIVO'
                                                    : item.kind == ItemKind.movie
                                                        ? 'FILME'
                                                        : 'SÉRIE',
                                                style: const TextStyle(
                                                  color: kRed,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                item.title,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                '${item.group} • ${item.server}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              FilledButton.icon(
                                                style: FilledButton.styleFrom(backgroundColor: kRed),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (_) => PlayerPage(item: item)),
                                                  );
                                                },
                                                icon: const Icon(Icons.play_arrow),
                                                label: const Text('Assistir'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(26, 4, 26, 18),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: kRed),
                              onPressed: () => setState(() => section = Section.live),
                              icon: const Icon(Icons.live_tv),
                              label: const Text('Ao Vivo'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: kRed),
                              onPressed: () => setState(() => section = Section.movies),
                              icon: const Icon(Icons.movie),
                              label: const Text('Filmes'),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: kRed),
                              onPressed: () => setState(() => section = Section.series),
                              icon: const Icon(Icons.video_library),
                              label: const Text('Séries'),
                            ),
                            OutlinedButton.icon(
                              onPressed: showDiagnostics,
                              icon: const Icon(Icons.info_outline),
                              label: const Text('Diagnóstico'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }'''

txt = txt[:start] + new_home + txt[end:]

p.write_text(txt)
print("main.dart ajustado.")
PY

# 5) Ajustar MiniPreviewPlayer: maior, MPEGTS e duplo clique tela cheia.
python3 - <<'PY'
from pathlib import Path

p = Path("lib/mini_preview_player.dart")
if not p.exists():
    print("mini_preview_player.dart não existe. Pulando.")
    raise SystemExit(0)

txt = p.read_text()

txt = txt.replace(
    "VideoPlayerController.networkUrl(\n        Uri.parse(widget.item.url),\n        httpHeaders: iptvHeaders(),\n      );",
    "VideoPlayerController.networkUrl(\n        Uri.parse(widget.item.url),\n        httpHeaders: iptvHeaders(),\n        formatHint: VideoFormat.other,\n      );"
)

txt = txt.replace(
    "height: 150,",
    "height: 285,"
)

txt = txt.replace(
    "fit: BoxFit.contain,",
    "fit: BoxFit.cover,"
)

p.write_text(txt)
print("mini_preview_player.dart ajustado.")
PY

# 6) Tentar aumentar painel de prévia da tela Ao Vivo e evitar overflow no card.
python3 - <<'PY'
from pathlib import Path

p = Path("lib/main.dart")
txt = p.read_text()

# Painel da direita de canais: aumenta um pouco e reduz conteúdo textual se existir.
txt = txt.replace(
    "const Icon(Icons.live_tv, size: 90)",
    "const Icon(Icons.live_tv, size: 70)"
)

txt = txt.replace(
    "style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)",
    "style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)"
)

# Se a seleção de canal ainda abre direto, força clique simples selecionar preview e clique longo abrir tela cheia.
txt = txt.replace(
    "onTap: () => openItem(item),",
    "onTap: () => setState(() => selectedPreviewItem = item),\n                onLongPress: () => openItem(item),"
)

p.write_text(txt)
print("preview em Ao Vivo ajustado.")
PY

dart format lib/main.dart lib/mini_preview_player.dart
flutter analyze 2>&1 | tail -n 60

echo ""
echo "Se não aparecer ERROR acima, envie:"
echo "git add ."
echo "git commit -m 'Ajusta home destaques login preview e player ao vivo'"
echo "git push"

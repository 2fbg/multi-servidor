#!/usr/bin/env bash
set -e

echo "== Ajuste fino TV Box: home, player, favoritos, bloqueio, preview =="

if [ ! -f "pubspec.yaml" ]; then
  echo "ERRO: rode dentro da pasta do projeto Flutter."
  exit 1
fi

if [ ! -f "lib/tvbox_layout.dart" ]; then
  echo "ERRO: lib/tvbox_layout.dart não encontrado."
  exit 1
fi

mkdir -p backup_ajuste_fino_tvbox
cp lib/main.dart "backup_ajuste_fino_tvbox/main_$(date +%Y%m%d_%H%M%S).dart"
cp lib/tvbox_layout.dart "backup_ajuste_fino_tvbox/tvbox_layout_$(date +%Y%m%d_%H%M%S).dart"
[ -f lib/series_catalog_page.dart ] && cp lib/series_catalog_page.dart "backup_ajuste_fino_tvbox/series_$(date +%Y%m%d_%H%M%S).dart"

python3 - <<'PY'
from pathlib import Path
import re

main = Path("lib/main.dart")
txt = main.read_text()

def find_block(s, signature):
    start = s.find(signature)
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

# 1) Helper: destaques da Home somente Filmes do ano atual / lançamentos.
if "bool isHomeMovieHighlight(StreamItem item)" not in txt:
    insert_pos = txt.find("bool isRestrictedIptvItem(StreamItem item)")
    if insert_pos == -1:
        insert_pos = txt.find("class M3uService")
    helper = r'''
bool isHomeMovieHighlight(StreamItem item) {
  final year = DateTime.now().year.toString();
  final text = '${item.title} ${item.group} ${item.url}'.toLowerCase();

  if (item.kind != ItemKind.movie) return false;
  if (isRestrictedIptvItem(item)) return false;

  return text.contains(year) ||
      text.contains('cinema $year') ||
      text.contains('filmes $year') ||
      text.contains('filme $year') ||
      text.contains('lançamento') ||
      text.contains('lancamento') ||
      text.contains('lançamentos') ||
      text.contains('lancamentos') ||
      text.contains('novidades') ||
      text.contains('adicionados recentemente');
}

'''
    txt = txt[:insert_pos] + helper + txt[insert_pos:]

# 2) Reforço: Ao Vivo não deve pegar filmes/séries.
txt = re.sub(
    r"List<StreamItem> get liveItems => .*?;",
    "List<StreamItem> get liveItems => items.where((e) => e.kind == ItemKind.live && !isProbablyVodGroup(e.group) && !e.url.toLowerCase().contains('/movie/') && !e.url.toLowerCase().contains('/series/')).toList();",
    txt,
)

# 3) Home: highlights só filmes/lançamentos do ano atual.
txt = re.sub(
    r"highlights:\s*movieItems\s*\.where\(\(e\)\s*=>\s*!isRestrictedIptvItem\(e\)\)\s*\.take\(36\)\s*\.toList\(\),",
    "highlights: movieItems.where(isHomeMovieHighlight).take(36).toList(),",
    txt,
)

txt = re.sub(
    r"highlights:\s*\[\s*\.\.\.movieItems\.take\(\d+\),\s*\.\.\.seriesItems\.take\(\d+\),\s*\],",
    "highlights: movieItems.where(isHomeMovieHighlight).take(36).toList(),",
    txt,
    flags=re.S,
)

# 4) Topo: garantir botão Ajustes/configuração.
if "tooltip: 'Ajustes'" not in txt:
    old = """            IconButton(
              tooltip: 'Listas',
              icon: const Icon(Icons.playlist_add),
              onPressed: () => setState(() => section = Section.lists),
            ),"""
    new = old + """
            IconButton(
              tooltip: 'Ajustes',
              icon: const Icon(Icons.settings),
              onPressed: () => setState(() => section = Section.settings),
            ),"""
    if old in txt:
        txt = txt.replace(old, new)

main.write_text(txt)
print("main.dart ajustado.")
PY

python3 - <<'PY'
from pathlib import Path
import re

p = Path("lib/tvbox_layout.dart")
txt = p.read_text()

# 1) Home: diminuir botões grandes para não estourar.
txt = txt.replace("height: 92,", "height: 72,")
txt = txt.replace("size: 44", "size: 34")
txt = txt.replace("fontSize: 30", "fontSize: 24")
txt = txt.replace("fontSize: 34", "fontSize: 28")
txt = txt.replace("width: 440,", "width: 390,")
txt = txt.replace("padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),", "padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),")
txt = txt.replace("const SizedBox(width: 18),", "const SizedBox(width: 12),")

# Reduz espaço vertical dos botões.
txt = txt.replace("padding: const EdgeInsets.only(bottom: 14),", "padding: const EdgeInsets.only(bottom: 8),")

# 2) Home: remover label "LANÇAMENTO / DESTAQUE" ou "LANÇAMENTOS".
txt = re.sub(
    r"""const Text\(\s*'LANÇAMENTO / DESTAQUE',[\s\S]*?\),\s*const SizedBox\(height: 8\),""",
    "",
    txt,
    count=1,
)
txt = re.sub(
    r"""const Text\(\s*'LANÇAMENTOS',[\s\S]*?\),\s*const SizedBox\(height: 8\),""",
    "",
    txt,
    count=1,
)

# Remover botão Assistir interno do card de destaque; o clique no card já abre.
txt = re.sub(
    r"""const SizedBox\(height: 14\),\s*FilledButton\.icon\([\s\S]*?label: const Text\('Assistir'\),\s*\),""",
    "const SizedBox(height: 4),",
    txt,
    count=1,
)

# 3) Prévia Ao Vivo: maior e sem botão visível.
txt = txt.replace("Expanded(\n              flex: 6,", "Expanded(\n              flex: 8,")
txt = txt.replace("Expanded(\n              flex: 3,", "Expanded(\n              flex: 2,")
txt = txt.replace("fit: BoxFit.contain,", "fit: BoxFit.cover,")

# Remove botões da prévia, deixa só estrela discreta e dica pequena.
txt = re.sub(
    r"""Row\(\s*children: \[\s*FilledButton\([\s\S]*?Duplo clique no vídeo para expandir'[\s\S]*?\],\s*\),""",
    """Row(
                      children: [
                        IconButton(
                          tooltip: 'Favorito',
                          onPressed: widget.onFavorite,
                          icon: Icon(
                            widget.isFavorite ? Icons.star : Icons.star_border,
                            color: widget.isFavorite ? Colors.amber : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Duplo toque: tela cheia',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),""",
    txt,
    count=1,
)

# 4) Tirar texto fixo Brilho/Volume do player.
txt = re.sub(
    r"""if \(showHint\)\s*Positioned\(\s*left: 24,[\s\S]*?Brilho: \$\{\(appBrightness \* 100\)\.round\(\)\}%'\),[\s\S]*?\),\s*\),""",
    "",
    txt,
    count=1,
)

txt = re.sub(
    r"""if \(showHint\)\s*Positioned\(\s*right: 24,[\s\S]*?Volume: \$\{\(appVolume \* 100\)\.round\(\)\}%'\),[\s\S]*?\),\s*\),""",
    "",
    txt,
    count=1,
)

# Caso existam apenas labels simples.
txt = txt.replace("child: const Text('Brilho'),", "child: const SizedBox.shrink(),")
txt = txt.replace("child: const Text('Volume'),", "child: const SizedBox.shrink(),")
txt = txt.replace("Text('Brilho')", "const SizedBox.shrink()")
txt = txt.replace("Text('Volume')", "const SizedBox.shrink()")

# 5) Velocidade até 3x no player TV Box.
if "double playbackSpeed = 1.0;" not in txt:
    txt = txt.replace(
        "double appVolume = 1.0;\n  bool showHint = true;",
        "double appVolume = 1.0;\n  double playbackSpeed = 1.0;\n  bool showHint = true;",
    )

if "Future<void> cycleSpeed()" not in txt:
    txt = txt.replace(
        """  void adjustRight(double delta) {
    appVolume = (appVolume - delta / 260).clamp(0.0, 1.0);
    video?.setVolume(appVolume);
    setState(() {});
  }""",
        """  void adjustRight(double delta) {
    appVolume = (appVolume - delta / 260).clamp(0.0, 1.0);
    video?.setVolume(appVolume);
    setState(() {});
  }

  Future<void> cycleSpeed() async {
    final speeds = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0];
    final index = speeds.indexOf(playbackSpeed);
    playbackSpeed = speeds[(index + 1) % speeds.length];
    await video?.setPlaybackSpeed(playbackSpeed);
    if (mounted) setState(() {});
  }""",
    )

if "playbackSpeed.toStringAsFixed" not in txt:
    txt = txt.replace(
        """                    IconButton(
                      icon: Icon(video?.value.isPlaying == true ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (video == null) return;
                        if (video!.value.isPlaying) {
                          video!.pause();
                        } else {
                          video!.play();
                        }
                        setState(() {});
                      },
                    ),""",
        """                    TextButton(
                      onPressed: cycleSpeed,
                      child: Text(
                        '${playbackSpeed.toStringAsFixed(playbackSpeed == playbackSpeed.roundToDouble() ? 0 : 2)}x',
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: Icon(video?.value.isPlaying == true ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (video == null) return;
                        if (video!.value.isPlaying) {
                          video!.pause();
                        } else {
                          video!.play();
                        }
                        setState(() {});
                      },
                    ),""",
    )

# 6) Anti-travamento: timeout menor para preview ao vivo.
txt = txt.replace("await c.initialize().timeout(const Duration(seconds: 35));", "await c.initialize().timeout(const Duration(seconds: 18));")

# 7) Garantir VideoFormat.other no player e preview.
txt = txt.replace(
    """VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url),
        httpHeaders: iptvHeaders(),
      );""",
    """VideoPlayerController.networkUrl(
        Uri.parse(widget.item.url),
        httpHeaders: iptvHeaders(),
        formatHint: VideoFormat.other,
      );""",
)

# 8) Ajustes: bloqueio restrito com PIN se não existir.
if "Bloqueio de conteúdo restrito" not in txt:
    txt = txt.replace(
        "(Icons.lock_outline, 'Controle dos pais', () {}),",
        "(Icons.lock_outline, 'Controle dos pais', () {}),\n      (Icons.security, 'Bloqueio de conteúdo restrito', () => showRestrictedLockDialog(context)),",
    )

if "Future<void> showRestrictedLockDialog" not in txt:
    marker = "  Widget tile(IconData icon, String label, VoidCallback onTap) {"
    dialog = r'''
  Future<void> showRestrictedLockDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('restricted_pin') ?? '';
    final pinCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Bloqueio de conteúdo restrito'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: savedPin.isEmpty ? 'Criar senha/PIN' : 'Digite a senha/PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setBool('restricted_unlocked', false);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Bloquear'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.length < 4) return;

              if (savedPin.isEmpty) {
                await prefs.setString('restricted_pin', pin);
                await prefs.setBool('restricted_unlocked', false);
              } else if (pin == savedPin) {
                await prefs.setBool('restricted_unlocked', true);
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: Text(savedPin.isEmpty ? 'Salvar' : 'Desbloquear'),
          ),
        ],
      ),
    );
  }

'''
    if marker in txt:
        txt = txt.replace(marker, dialog + marker)

p.write_text(txt)
print("tvbox_layout.dart ajustado.")
PY

# Ajustes em filmes/séries: adicionar Continuar assistindo no catálogo genérico.
python3 - <<'PY'
from pathlib import Path

p = Path("lib/main.dart")
txt = p.read_text()

# Garante menu "Continuar assistindo" no CatalogPage para Filmes.
# Não mexe se já existir.
if "Continuar assistindo" not in txt:
    txt = txt.replace(
        "final map = <String, int>{'Todos': widget.items.length};",
        """final map = <String, int>{'Todos': widget.items.length};

    if (widget.mode == CatalogMode.movies || widget.mode == CatalogMode.series) {
      map['Continuar assistindo'] = 0;
    }""",
        1,
    )

p.write_text(txt)
print("Continuar assistindo básico aplicado ao catálogo.")
PY

dart format lib/main.dart lib/tvbox_layout.dart lib/series_catalog_page.dart
flutter analyze 2>&1 | tail -n 120

echo ""
echo "== Validação rápida =="
grep -n "playbackSpeed" lib/tvbox_layout.dart || true
grep -n "3.0" lib/tvbox_layout.dart || true
grep -n "restricted_pin" lib/tvbox_layout.dart || true
grep -n "favorite_live_urls" lib/tvbox_layout.dart || true
grep -n "VideoFormat.other" lib/tvbox_layout.dart || true
grep -n "Bloqueio de conteúdo restrito" lib/tvbox_layout.dart || true
grep -n "isHomeMovieHighlight" lib/main.dart || true

echo ""
echo "Se não apareceu ERROR no analyze, envie:"
echo "git add ."
echo "git commit -m 'Ajuste fino layout home player favoritos e bloqueio'"
echo "git push"

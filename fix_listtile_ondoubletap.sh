#!/usr/bin/env bash
set -e

echo "== Corrigindo erro onDoubleTap em ListTile =="

if [ ! -f "lib/tvbox_layout.dart" ]; then
  echo "ERRO: lib/tvbox_layout.dart não encontrado."
  exit 1
fi

mkdir -p backup_fix_ondoubletap
cp lib/tvbox_layout.dart "backup_fix_ondoubletap/tvbox_layout_$(date +%Y%m%d_%H%M%S).dart"

python3 - <<'PY'
from pathlib import Path

p = Path("lib/tvbox_layout.dart")
txt = p.read_text()

old = r'''                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF332000),
                        leading: Text('${i + 1}', style: const TextStyle(color: Colors.white70)),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isSelected ? Colors.amber : Colors.white),
                        ),
                        subtitle: Text(
                          item.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            favorites.contains(item.url) ? Icons.star : Icons.star_border,
                            color: favorites.contains(item.url) ? Colors.amber : Colors.white54,
                          ),
                          onPressed: () => toggleFavorite(item),
                        ),
                        onTap: () => setState(() => selected = item),
                        onDoubleTap: () => openFullscreen(item),
                        onLongPress: () => openFullscreen(item),
                      );'''

new = r'''                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: () => openFullscreen(item),
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF332000),
                          leading: Text(
                            '${i + 1}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.amber : Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            item.group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              favorites.contains(item.url)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: favorites.contains(item.url)
                                  ? Colors.amber
                                  : Colors.white54,
                            ),
                            onPressed: () => toggleFavorite(item),
                          ),
                          onTap: () => setState(() => selected = item),
                          onLongPress: () => openFullscreen(item),
                        ),
                      );'''

if old not in txt:
    print("Bloco exato não encontrado. Tentando correção simples...")
    txt = txt.replace(
        "                        onDoubleTap: () => openFullscreen(item),\n",
        ""
    )
    print("Removido onDoubleTap direto do ListTile. Duplo toque na prévia continua funcionando.")
else:
    txt = txt.replace(old, new)
    print("ListTile envolvido com GestureDetector para duplo clique.")

p.write_text(txt)
PY

dart format lib/tvbox_layout.dart
flutter analyze 2>&1 | tail -n 80

echo ""
echo "Se não aparecer ERROR acima, envie:"
echo "git add ."
echo "git commit -m 'Corrige onDoubleTap no menu de canais'"
echo "git push"

#!/usr/bin/env bash
set -e

echo "🔧 Corrigindo submenus da aba Séries para agrupar por nome da série..."

python3 - <<'PY'
from pathlib import Path

main = Path("lib/main.dart")
text = main.read_text()

# 1) Substituir _filteredForSection para respeitar nome da série quando estiver na aba Séries.
old_filtered = """  List<Channel> _filteredForSection() {
    var list = _baseForSection();

    if (_selectedGroup != 'Todos') {
      list = list.where((c) => (c.group ?? 'Sem grupo') == _selectedGroup).toList();
    }

    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) => c.title.toLowerCase().contains(query)).toList();
    }

    return list;
  }
"""

new_filtered = """  List<Channel> _filteredForSection() {
    var list = _baseForSection();

    if (_selectedGroup != 'Todos') {
      if (_section == MainSection.series) {
        list = list.where((c) => _seriesName(c.title) == _selectedGroup).toList();
      } else {
        list = list.where((c) => (c.group ?? 'Sem grupo') == _selectedGroup).toList();
      }
    }

    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) {
        final title = c.title.toLowerCase();
        final group = (c.group ?? '').toLowerCase();
        final serie = _seriesName(c.title).toLowerCase();
        return title.contains(query) || group.contains(query) || serie.contains(query);
      }).toList();
    }

    return list;
  }
"""

if old_filtered not in text:
    print("⚠️ Bloco _filteredForSection original não encontrado. Tentando seguir com outros patches.")
else:
    text = text.replace(old_filtered, new_filtered)

# 2) Substituir _groupCounts para, na aba Séries, gerar submenus por nome da série.
old_group = """  Map<String, int> _groupCounts() {
    final source = _baseForSection();
    final counts = <String, int>{};

    counts['Todos'] = source.length;

    for (final channel in source) {
      final group = (channel.group == null || channel.group!.trim().isEmpty)
          ? 'Sem grupo'
          : channel.group!.trim();

      counts[group] = (counts[group] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Todos') return -1;
        if (b.key == 'Todos') return 1;
        return b.value.compareTo(a.value);
      });

    return Map.fromEntries(sorted);
  }
"""

new_group = """  Map<String, int> _groupCounts() {
    final source = _baseForSection();
    final counts = <String, int>{};

    counts['Todos'] = source.length;

    for (final channel in source) {
      String group;

      if (_section == MainSection.series) {
        group = _seriesName(channel.title);
      } else {
        group = (channel.group == null || channel.group!.trim().isEmpty)
            ? 'Sem grupo'
            : channel.group!.trim();
      }

      if (group.trim().isEmpty) group = 'Sem grupo';

      counts[group] = (counts[group] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Todos') return -1;
        if (b.key == 'Todos') return 1;

        if (_section == MainSection.series) {
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
        }

        return b.value.compareTo(a.value);
      });

    return Map.fromEntries(sorted);
  }
"""

if old_group not in text:
    print("⚠️ Bloco _groupCounts original não encontrado. Tentando seguir com inserção manual.")
else:
    text = text.replace(old_group, new_group)

# 3) Inserir função _seriesName antes de _buildTopTabs, se ainda não existir.
if "String _seriesName(String title)" not in text:
    marker = "  Widget _buildTopTabs() {"
    helper = r"""  String _seriesName(String title) {
    var name = title.trim();

    // Remove padrões comuns de episódio:
    // Ex: "13 Reasons Why S04E05" -> "13 Reasons Why"
    // Ex: "Serie - S01 E02" -> "Serie"
    final patterns = <RegExp>[
      RegExp(r'\s*[-_.]?\s*S\d{1,2}\s*E\d{1,3}.*$', caseSensitive: false),
      RegExp(r'\s*[-_.]?\s*S\d{1,2}\s*EP\d{1,3}.*$', caseSensitive: false),
      RegExp(r'\s*[-_.]?\s*TEMP(?:ORADA)?\s*\d{1,2}\s*EP(?:ISODIO)?\s*\d{1,3}.*$', caseSensitive: false),
      RegExp(r'\s*[-_.]?\s*T\d{1,2}\s*E\d{1,3}.*$', caseSensitive: false),
      RegExp(r'\s*[-_.]?\s*\d{1,2}x\d{1,3}.*$', caseSensitive: false),
      RegExp(r'\s*[-_.]?\s*EP(?:ISODIO)?\s*\d{1,3}.*$', caseSensitive: false),
    ];

    for (final p in patterns) {
      name = name.replaceAll(p, '').trim();
    }

    // Remove finalizações comuns que ficam depois do nome.
    name = name
        .replaceAll(RegExp(r'\s+', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s*[-_.]\s*$', caseSensitive: false), '')
        .trim();

    if (name.isEmpty) return title.trim();

    return name;
  }

"""
    if marker in text:
        text = text.replace(marker, helper + marker)
    else:
        print("⚠️ Marcador _buildTopTabs não encontrado. Não foi possível inserir _seriesName.")

# 4) Melhorar título dos chips quando estiver em Séries: texto menor para caber.
old_chip = """                  label: Text('${e.key} (${e.value})'),"""
new_chip = """                  label: Text(
                    '${e.key} (${e.value})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),"""
text = text.replace(old_chip, new_chip)

# 5) Ao entrar em Séries pelo botão Home, limpar grupo corretamente já existente.
# Não precisa mexer se já faz set _selectedGroup = Todos.

main.write_text(text)
print("✅ main.dart atualizado: Séries agora agrupa por nome da série.")
PY

flutter pub get
flutter clean

echo ""
echo "✅ Correção aplicada."
echo ""
echo "Agora rode:"
echo "git add ."
echo "git commit -m \"corrige agrupamento de series por nome\""
echo "git push"

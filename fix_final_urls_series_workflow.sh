#!/usr/bin/env bash
set -e

echo(Icons.search),echo "🚀 Aplicando correção final: URLs, séries, workflow e limpeza..."
                    labelText: 'Buscar séries ou episódios',
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              seasonChips(),
              Expanded(child: episodesGrid()),
            ],
          ),
        ),
      ],
    );
  }
}
EOF

# ============================================================
# 4. Remover pasta digitada errada
# ============================================================
if [ -d "lib/sevices" ]; then
  echo "🧹 Removendo pasta incorreta lib/sevices..."
  rm -rf "lib/sevices"
fi

# ============================================================
# 5. Recriar workflow correto
# ============================================================
mkdir -p .github/workflows

cat > .github/workflows/build-apk.yml <<'EOF'
name: Build APK

on:
  workflow_dispatch:
  push:
    branches:
      - main

jobs:
  build-apk:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.24.5"
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze project
        run: flutter analyze || true

      - name: Build APK
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: multi-servidor-apk
          path: build/app/outputs/flutter-apk/app-release.apk
EOF

# ============================================================
# 6. Evitar subir diagnóstico temporário
# ============================================================
touch .gitignore

grep -qxF "diagnostico_repo.txt" .gitignore || echo "diagnostico_repo.txt" >> .gitignore
grep -qxF "gerar_diagnostico_repo.sh" .gitignore || echo "gerar_diagnostico_repo.sh" >> .gitignore
grep -qxF "*.ipynb_checkpoints" .gitignore || echo "*.ipynb_checkpoints" >> .gitignore

# ============================================================
# 7. Conferências
# ============================================================
echo ""
echo "🔎 Conferindo se ainda existe &amp; em lib:"
grep -R "&amp;" -n lib || true

echo ""
echo "🔎 Conferindo URLs no main.dart:"
grep -n "get.php" lib/main.dart || true

echo ""
echo "🔎 Conferindo workflow:"
ls -la .github/workflows

flutter pub get
flutter clean
flutter analyze || true

echo ""
echo "✅ Correção final aplicada."
echo ""
echo "Agora rode:"
echo "git add ."
echo "git commit -m \"corrige urls series e workflow\""
echo "git push"

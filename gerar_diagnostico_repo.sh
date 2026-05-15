#!/usr/bin/env bash

echo "📋 Gerando diagnóstico do repositório..."

OUT="diagnostico_repo.txt"

{
  echo "=============================="
  echo "DIAGNÓSTICO MULTI SERVIDOR"
  echo "=============================="
  echo ""
  echo "DATA:"
  date
  echo ""

  echo "=============================="
  echo "GIT STATUS"
  echo "=============================="
  git status
  echo ""

  echo "=============================="
  echo "ÚLTIMOS COMMITS"
  echo "=============================="
  git log --oneline -10
  echo ""

  echo "=============================="
  echo "ESTRUTURA DO PROJETO"
  echo "=============================="
  find . -maxdepth 4 -type f | sort | sed 's#^\./##'
  echo ""

  echo "=============================="
  echo "PUBSPEC.YAML"
  echo "=============================="
  cat pubspec.yaml 2>/dev/null || echo "pubspec.yaml não encontrado"
  echo ""

  echo "=============================="
  echo "MAIN.DART"
  echo "=============================="
  cat lib/main.dart 2>/dev/null || echo "lib/main.dart não encontrado"
  echo ""

  echo "=============================="
  echo "SERVERS.DART"
  echo "=============================="
  cat lib/config/servers.dart 2>/dev/null || echo "lib/config/servers.dart não encontrado"
  echo ""

  echo "=============================="
  echo "CHANNEL.DART"
  echo "=============================="
  cat lib/models/channel.dart 2>/dev/null || echo "lib/models/channel.dart não encontrado"
  echo ""

  echo "=============================="
  echo "M3U_PARSER.DART"
  echo "=============================="
  cat lib/services/m3u_parser.dart 2>/dev/null || echo "lib/services/m3u_parser.dart não encontrado"
  echo ""

  echo "=============================="
  echo "STORAGE.DART"
  echo "=============================="
  cat lib/services/storage.dart 2>/dev/null || echo "lib/services/storage.dart não encontrado"
  echo ""

  echo "=============================="
  echo "PLAYER_SCREEN.DART"
  echo "=============================="
  cat lib/screens/player_screen.dart 2>/dev/null || echo "lib/screens/player_screen.dart não encontrado"
  echo ""

  echo "=============================="
  echo "ANDROID MANIFEST"
  echo "=============================="
  cat android/app/src/main/AndroidManifest.xml 2>/dev/null || echo "AndroidManifest.xml não encontrado"
  echo ""

  echo "=============================="
  echo "NETWORK SECURITY CONFIG"
  echo "=============================="
  cat android/app/src/main/res/xml/network_security_config.xml 2>/dev/null || echo "network_security_config.xml não encontrado"
  echo ""

  echo "=============================="
  echo "WORKFLOW BUILD"
  echo "=============================="
  cat .github/workflows/build.yml 2>/dev/null || echo ".github/workflows/build.yml não encontrado"
  echo ""

  echo "=============================="
  echo "FLUTTER ANALYZE"
  echo "=============================="
  flutter analyze || true
  echo ""

} > "$OUT"

echo "✅ Diagnóstico gerado em: $OUT"
echo ""
echo "Agora rode:"
echo "cat diagnostico_repo.txt"

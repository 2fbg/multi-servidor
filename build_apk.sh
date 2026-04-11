#!/bin/bash
set -e

cd /workspaces/multi-servidor

echo "====== Verificando Flutter ======"
flutter --version

echo "====== Obtendo dependências ======"
flutter pub get

echo "====== Construindo APK (release) ======"
flutter build apk --release --split-per-abi

echo "====== APK construído com sucesso ======"
ls -lh build/app/outputs/flutter-apk/

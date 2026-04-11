#!/bin/bash
if [ ! -d "/tmp/flutter" ]; then
  echo "Instalando Flutter..."
  cd /tmp && git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PATH:/tmp/flutter/bin"
echo "Flutter configurado! Versão:"
flutter --version

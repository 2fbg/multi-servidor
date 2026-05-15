#!/usr/bin/env bash
set -e

echo "== Validação dos ajustes Multi Servidor =="
echo ""

check_file() {
  local file="$1"
  if [ -f "$file" ]; then
    echo "OK: arquivo existe: $file"
  else
    echo "FALTA: arquivo não encontrado: $file"
  fi
}

check_text() {
  local label="$1"
  local file="$2"
  local text="$3"

  if grep -q "$text" "$file" 2>/dev/null; then
    echo "OK: $label"
  else
    echo "FALTA: $label"
  fi
}

check_file "lib/main.dart"
check_file "lib/tvbox_layout.dart"
check_file "lib/series_catalog_page.dart"

echo ""
echo "== 1. Tela horizontal =="
check_text "Travamento landscapeLeft" "lib/main.dart" "DeviceOrientation.landscapeLeft"
check_text "Travamento landscapeRight" "lib/main.dart" "DeviceOrientation.landscapeRight"
check_text "Modo imersivo sticky" "lib/main.dart" "SystemUiMode.immersiveSticky"

echo ""
echo "== 2. Layout TV Box novo =="
check_text "part tvbox_layout.dart ligado no main" "lib/main.dart" "part 'tvbox_layout.dart'"
check_text "Home usando TvBoxHomePage" "lib/main.dart" "TvBoxHomePage"
check_text "Ao Vivo usando TvBoxLivePage" "lib/main.dart" "TvBoxLivePage"
check_text "Ajustes usando TvBoxSettingsPage" "lib/main.dart" "TvBoxSettingsPage"
check_text "Player novo TvBoxPlayerPage" "lib/tvbox_layout.dart" "class TvBoxPlayerPage"

echo ""
echo "== 3. Home com destaques/lançamentos =="
check_text "Home recebe highlights" "lib/tvbox_layout.dart" "final List<StreamItem> highlights"
check_text "Texto lançamentos" "lib/tvbox_layout.dart" "LANÇAMENTOS"
check_text "Destaques clicáveis abrem player" "lib/tvbox_layout.dart" "TvBoxPlayerPage(item: item)"

echo ""
echo "== 4. Menu Canais / Ao Vivo =="
check_text "Tela Ao Vivo TV Box" "lib/tvbox_layout.dart" "class TvBoxLivePage"
check_text "Grupos no Ao Vivo" "lib/tvbox_layout.dart" "Map<String, int> get groups"
check_text "Favorito no grupo lateral" "lib/tvbox_layout.dart" "'Favorito'"
check_text "Clique seleciona canal" "lib/tvbox_layout.dart" "onTap: () => setState(() => selected = item)"
check_text "Toque longo abre tela cheia" "lib/tvbox_layout.dart" "onLongPress: () => openFullscreen(item)"
check_text "Duplo toque na prévia" "lib/tvbox_layout.dart" "onDoubleTap: widget.onFullscreen"

echo ""
echo "== 5. Favoritos =="
check_text "Salva favoritos no aparelho" "lib/tvbox_layout.dart" "favorite_live_urls"
check_text "Botão estrela favorito" "lib/tvbox_layout.dart" "Icons.star"
check_text "Toggle favorito" "lib/tvbox_layout.dart" "toggleFavorite"

echo ""
echo "== 6. Séries por temporada =="
check_text "part series_catalog_page.dart ligado no main" "lib/main.dart" "part 'series_catalog_page.dart'"
check_text "Menu Séries usa SeriesCatalogPage" "lib/main.dart" "SeriesCatalogPage"
check_text "Classe SeriesCatalogPage existe" "lib/series_catalog_page.dart" "class SeriesCatalogPage"
check_text "Temporadas" "lib/series_catalog_page.dart" "Temporada"
check_text "Episódios ordenados" "lib/series_catalog_page.dart" "episodeNumber"

echo ""
echo "== 7. Player, velocidade, brilho e volume =="
check_text "Player usa VideoFormat.other" "lib/tvbox_layout.dart" "formatHint: VideoFormat.other"
check_text "Controle de brilho por gesto" "lib/tvbox_layout.dart" "adjustLeft"
check_text "Controle de volume por gesto" "lib/tvbox_layout.dart" "adjustRight"
check_text "Velocidade playbackSpeed" "lib/tvbox_layout.dart" "playbackSpeed"
check_text "Velocidade até 3x" "lib/tvbox_layout.dart" "3.0"
check_text "Botão ciclo de velocidade" "lib/tvbox_layout.dart" "cycleSpeed"

echo ""
echo "== 8. Anti-travamento / timeout =="
check_text "Timeout no player" "lib/tvbox_layout.dart" "timeout(const Duration"
check_text "Timeout preview Ao Vivo" "lib/tvbox_layout.dart" "Timeout ao abrir prévia"
check_text "Tratamento de erro player" "lib/tvbox_layout.dart" "Falha ao abrir o vídeo"

echo ""
echo "== 9. Bloqueio conteúdo restrito/adulto =="
check_text "Helper restrito" "lib/main.dart" "isRestrictedIptvItem"
check_text "PIN restrito" "lib/tvbox_layout.dart" "restricted_pin"
check_text "Tile bloqueio restrito" "lib/tvbox_layout.dart" "Bloqueio de conteúdo restrito"
check_text "Detecta adulto" "lib/main.dart" "adulto"
check_text "Detecta XXX" "lib/main.dart" "xxx"

echo ""
echo "== 10. Classificação Canais / Filmes / Séries =="
check_text "classifyItem existe" "lib/main.dart" "static ItemKind classifyItem"
check_text "Detecta /movie/" "lib/main.dart" "/movie/"
check_text "Detecta /series/" "lib/main.dart" "/series/"
check_text "Remove VOD do Ao Vivo" "lib/main.dart" "isProbablyVodGroup"

echo ""
echo "== 11. Login salvo =="
check_text "Login salva usuário" "lib/main.dart" "setString('login_user'"
check_text "Login salva senha opcional" "lib/main.dart" "save_password"
check_text "Remove senha se não salvar" "lib/main.dart" "erase_password_on_next_logout"

echo ""
echo "== 12. Análise Flutter =="
flutter analyze 2>&1 | tail -n 80

echo ""
echo "== Validação finalizada =="

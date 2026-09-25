# Multi Servidor

Aplicativo Android para organizar fontes de streaming que você já possui, com uma experiência mais rápida e consistente para múltiplos servidores.

## O que mudou

- Home editorial com status real de servidores, itens sincronizados e favoritos.
- Biblioteca com busca global e filtros para ao vivo, filmes e séries.
- Importação e sincronização de playlists M3U por URL.
- Favoritos e histórico persistidos localmente no dispositivo.
- Player integrado com `expo-video`, tela cheia e picture-in-picture.
- Interface escura, acessível e responsiva para celular e TV box.
- Nenhuma fonte de mídia é fornecida pelo aplicativo; o usuário conecta suas próprias playlists autorizadas.

## Stack

Expo SDK 54, React Native 0.81, Expo Router 6, TypeScript, NativeWind, AsyncStorage e expo-video.

## Desenvolvimento

```bash
pnpm install
pnpm dev
```

Para validar o projeto:

```bash
pnpm check
pnpm test
pnpm lint
```

## Uso

Abra **Ajustes**, informe um nome e a URL de uma playlist M3U acessível pela internet. O Multi Servidor baixa e indexa os itens localmente; depois, use a Biblioteca para pesquisar ou o coração para criar favoritos.

## Privacidade e responsabilidade

As fontes e preferências ficam armazenadas localmente no dispositivo. Use somente conteúdos e servidores para os quais você possui autorização.

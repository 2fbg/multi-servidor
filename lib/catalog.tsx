import AsyncStorage from "@react-native-async-storage/async-storage";
import React, { createContext, useContext, useEffect, useMemo, useState } from "react";

export type MediaKind = "live" | "movie" | "series";

export type StreamServer = {
  id: string;
  name: string;
  playlistUrl: string;
  status: "syncing" | "ready" | "error";
  itemCount: number;
  lastSync: string | null;
  error?: string;
};

export type MediaItem = {
  id: string;
  serverId: string;
  title: string;
  url: string;
  group: string;
  logo?: string;
  kind: MediaKind;
};

type CatalogSnapshot = {
  servers: StreamServer[];
  items: MediaItem[];
  favorites: string[];
  history: string[];
};

type CatalogContextValue = CatalogSnapshot & {
  hydrated: boolean;
  addServer: (name: string, playlistUrl: string) => Promise<void>;
  syncServer: (serverId: string) => Promise<void>;
  removeServer: (serverId: string) => Promise<void>;
  toggleFavorite: (mediaId: string) => void;
  markPlayed: (mediaId: string) => void;
  getItem: (mediaId: string) => MediaItem | undefined;
};

const STORAGE_KEY = "multi-servidor.catalog.v1";
const CatalogContext = createContext<CatalogContextValue | null>(null);

function hash(value: string) {
  let result = 0;
  for (let index = 0; index < value.length; index += 1) {
    result = (result << 5) - result + value.charCodeAt(index);
    result |= 0;
  }
  return Math.abs(result).toString(36);
}

function createId(value: string) {
  return `media-${hash(value)}`;
}

function getAttribute(line: string, attribute: string) {
  const match = line.match(new RegExp(`${attribute}="([^"]*)"`, "i"));
  return match?.[1]?.trim() ?? "";
}

function inferKind(title: string, group: string, url: string): MediaKind {
  const value = `${title} ${group} ${url}`.toLocaleLowerCase();
  if (/filme|movie|cinema|vod/.test(value)) return "movie";
  if (/série|serie|series|season|temporada/.test(value)) return "series";
  return "live";
}

export function parseM3U(content: string, serverId: string): MediaItem[] {
  const lines = content.split(/\r?\n/);
  const parsed: MediaItem[] = [];
  let metadata: { title: string; group: string; logo?: string } | null = null;

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;

    if (line.startsWith("#EXTINF")) {
      const commaIndex = line.indexOf(",");
      const fallbackTitle = commaIndex >= 0 ? line.slice(commaIndex + 1).trim() : "Sem título";
      const title = getAttribute(line, "tvg-name") || fallbackTitle || "Sem título";
      const group = getAttribute(line, "group-title") || "Sem categoria";
      const logo = getAttribute(line, "tvg-logo");
      metadata = { title, group, ...(logo ? { logo } : {}) };
      continue;
    }

    if (metadata && !line.startsWith("#")) {
      const item: MediaItem = {
        id: createId(`${serverId}:${line}:${metadata.title}`),
        serverId,
        title: metadata.title,
        url: line,
        group: metadata.group,
        ...(metadata.logo ? { logo: metadata.logo } : {}),
        kind: inferKind(metadata.title, metadata.group, line),
      };
      parsed.push(item);
      metadata = null;
    }
  }

  const unique = new Map<string, MediaItem>();
  for (const item of parsed) unique.set(`${item.title}:${item.url}`, item);
  return Array.from(unique.values());
}

async function fetchPlaylist(url: string, serverId: string) {
  const response = await fetch(url, { headers: { Accept: "application/x-mpegURL,text/plain,*/*" } });
  if (!response.ok) throw new Error(`Não foi possível acessar a playlist (${response.status}).`);
  const items = parseM3U(await response.text(), serverId);
  if (!items.length) throw new Error("A playlist não contém itens M3U reconhecíveis.");
  return items;
}

export function kindLabel(kind: MediaKind) {
  if (kind === "movie") return "Filme";
  if (kind === "series") return "Série";
  return "Ao vivo";
}

export function kindIcon(kind: MediaKind) {
  if (kind === "movie") return "film.fill" as const;
  if (kind === "series") return "tv.fill" as const;
  return "dot.radiowaves.left.and.right" as const;
}

export function normalizeSearch(value: string) {
  return value.trim().toLocaleLowerCase();
}

export function CatalogProvider({ children }: { children: React.ReactNode }) {
  const [snapshot, setSnapshot] = useState<CatalogSnapshot>({ servers: [], items: [], favorites: [], history: [] });
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    let active = true;
    AsyncStorage.getItem(STORAGE_KEY)
      .then((stored) => {
        if (!active) return;
        if (stored) {
          try {
            const parsed = JSON.parse(stored) as Partial<CatalogSnapshot>;
            setSnapshot({
              servers: parsed.servers ?? [],
              items: parsed.items ?? [],
              favorites: parsed.favorites ?? [],
              history: parsed.history ?? [],
            });
          } catch {
            setSnapshot({ servers: [], items: [], favorites: [], history: [] });
          }
        }
        setHydrated(true);
      })
      .catch(() => setHydrated(true));
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (hydrated) AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot)).catch(() => undefined);
  }, [hydrated, snapshot]);

  const value = useMemo<CatalogContextValue>(() => ({
    ...snapshot,
    hydrated,
    addServer: async (name, playlistUrl) => {
      const trimmedUrl = playlistUrl.trim();
      try {
        new URL(trimmedUrl);
      } catch {
        throw new Error("Informe uma URL válida para a playlist.");
      }
      const serverId = `server-${Date.now().toString(36)}`;
      const pending: StreamServer = { id: serverId, name: name.trim() || "Novo servidor", playlistUrl: trimmedUrl, status: "syncing", itemCount: 0, lastSync: null };
      setSnapshot((current) => ({ ...current, servers: [...current.servers, pending] }));
      try {
        const items = await fetchPlaylist(trimmedUrl, serverId);
        setSnapshot((current) => ({
          ...current,
          servers: current.servers.map((server) => server.id === serverId ? { ...server, status: "ready", itemCount: items.length, lastSync: new Date().toISOString(), error: undefined } : server),
          items: [...current.items.filter((item) => item.serverId !== serverId), ...items],
        }));
      } catch (error) {
        const message = error instanceof Error ? error.message : "Não foi possível sincronizar a playlist.";
        setSnapshot((current) => ({ ...current, servers: current.servers.map((server) => server.id === serverId ? { ...server, status: "error", error: message } : server) }));
        throw new Error(message);
      }
    },
    syncServer: async (serverId) => {
      const server = snapshot.servers.find((entry) => entry.id === serverId);
      if (!server) return;
      setSnapshot((current) => ({ ...current, servers: current.servers.map((entry) => entry.id === serverId ? { ...entry, status: "syncing", error: undefined } : entry) }));
      try {
        const items = await fetchPlaylist(server.playlistUrl, serverId);
        setSnapshot((current) => ({
          ...current,
          servers: current.servers.map((entry) => entry.id === serverId ? { ...entry, status: "ready", itemCount: items.length, lastSync: new Date().toISOString(), error: undefined } : entry),
          items: [...current.items.filter((item) => item.serverId !== serverId), ...items],
        }));
      } catch (error) {
        const message = error instanceof Error ? error.message : "Não foi possível sincronizar a playlist.";
        setSnapshot((current) => ({ ...current, servers: current.servers.map((entry) => entry.id === serverId ? { ...entry, status: "error", error: message } : entry) }));
        throw new Error(message);
      }
    },
    removeServer: async (serverId) => {
      setSnapshot((current) => ({
        ...current,
        servers: current.servers.filter((server) => server.id !== serverId),
        items: current.items.filter((item) => item.serverId !== serverId),
        favorites: current.favorites.filter((id) => current.items.some((item) => item.id === id && item.serverId !== serverId)),
        history: current.history.filter((id) => current.items.some((item) => item.id === id && item.serverId !== serverId)),
      }));
    },
    toggleFavorite: (mediaId) => setSnapshot((current) => ({ ...current, favorites: current.favorites.includes(mediaId) ? current.favorites.filter((id) => id !== mediaId) : [mediaId, ...current.favorites] })),
    markPlayed: (mediaId) => setSnapshot((current) => ({ ...current, history: [mediaId, ...current.history.filter((id) => id !== mediaId)].slice(0, 20) })),
    getItem: (mediaId) => snapshot.items.find((item) => item.id === mediaId),
  }), [hydrated, snapshot]);

  return <CatalogContext.Provider value={value}>{children}</CatalogContext.Provider>;
}

export function useCatalog() {
  const context = useContext(CatalogContext);
  if (!context) throw new Error("useCatalog precisa estar dentro de CatalogProvider");
  return context;
}

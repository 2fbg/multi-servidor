import { useRouter } from "expo-router";
import { useMemo, useState } from "react";
import { FlatList, Pressable, Text, TextInput, View } from "react-native";

import { MediaCard } from "@/components/media-card";
import { PageHeader } from "@/components/brand";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { ScreenContainer } from "@/components/screen-container";
import { normalizeSearch, type MediaKind, useCatalog } from "@/lib/catalog";

const filters: { label: string; value: "all" | MediaKind }[] = [
  { label: "Tudo", value: "all" },
  { label: "Ao vivo", value: "live" },
  { label: "Filmes", value: "movie" },
  { label: "Séries", value: "series" },
];

export default function LibraryScreen() {
  const router = useRouter();
  const { items, favorites, toggleFavorite } = useCatalog();
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<(typeof filters)[number]["value"]>("all");
  const normalized = normalizeSearch(query);
  const filtered = useMemo(() => items.filter((item) => {
    const matchesType = filter === "all" || item.kind === filter;
    const matchesQuery = !normalized || `${item.title} ${item.group}`.toLocaleLowerCase().includes(normalized);
    return matchesType && matchesQuery;
  }), [filter, items, normalized]);

  return (
    <ScreenContainer>
      <FlatList
        data={filtered}
        keyExtractor={(item) => item.id}
        numColumns={2}
        columnWrapperStyle={{ gap: 12 }}
        contentContainerStyle={{ padding: 20, paddingBottom: 32, gap: 14 }}
        ListHeaderComponent={<View>
          <PageHeader eyebrow="Catálogo pessoal" title="Biblioteca" />
          <View className="mb-5 flex-row items-center rounded-2xl border border-border bg-surface px-4 py-1">
            <IconSymbol name="magnifyingglass" size={19} color="#8FA8B7" />
            <TextInput value={query} onChangeText={setQuery} placeholder="Buscar título ou categoria" placeholderTextColor="#6D8190" className="ml-3 flex-1 py-3 text-foreground" returnKeyType="search" />
            {query ? <Pressable onPress={() => setQuery("")}><IconSymbol name="xmark.circle.fill" size={18} color="#8FA8B7" /></Pressable> : null}
          </View>
          <View className="mb-6 flex-row gap-2">
            {filters.map((entry) => <Pressable key={entry.value} onPress={() => setFilter(entry.value)} style={({ pressed }) => [{ opacity: pressed ? 0.7 : 1 }]} className={`rounded-full border px-4 py-2 ${filter === entry.value ? "border-primary bg-primary" : "border-border bg-surface"}`}><Text className={`text-xs font-bold ${filter === entry.value ? "text-[#07131D]" : "text-muted"}`}>{entry.label}</Text></Pressable>)}
          </View>
          <Text className="mb-1 text-sm font-semibold text-foreground">{filtered.length} {filtered.length === 1 ? "resultado" : "resultados"}</Text>
        </View>}
        renderItem={({ item }) => <MediaCard item={item} favorite={favorites.includes(item.id)} onPress={() => router.push({ pathname: "/player", params: { id: item.id } })} onToggleFavorite={() => toggleFavorite(item.id)} />}
        ListEmptyComponent={<View className="mt-8 items-center rounded-2xl border border-dashed border-border bg-surface p-6"><View className="mb-4 h-14 w-14 items-center justify-center rounded-2xl bg-primary/15"><IconSymbol name="rectangle.stack.badge.plus" size={26} color="#23C3D9" /></View><Text className="text-center text-base font-semibold text-foreground">Biblioteca vazia</Text><Text className="mt-2 text-center text-sm leading-5 text-muted">Conecte uma playlist M3U em Ajustes para começar.</Text></View>}
      />
    </ScreenContainer>
  );
}

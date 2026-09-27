import { useRouter } from "expo-router";
import { useMemo, useState } from "react";
import { FlatList, Pressable, ScrollView, Text, TextInput, View } from "react-native";

import { MediaCard } from "@/components/media-card";
import { PageHeader } from "@/components/brand";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { ScreenContainer } from "@/components/screen-container";
import { normalizeSearch, type MediaKind, useCatalog } from "@/lib/catalog";

const typeFilters: { label: string; value: "all" | MediaKind }[] = [
  { label: "Tudo", value: "all" },
  { label: "Ao vivo", value: "live" },
  { label: "Filmes", value: "movie" },
  { label: "Séries", value: "series" },
];

function FilterChip({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return <Pressable onPress={onPress} style={({ pressed }) => [{ opacity: pressed ? 0.7 : 1 }]} className={`rounded-full border px-3 py-2 ${active ? "border-primary bg-primary" : "border-border bg-surface"}`}><Text className={`text-xs font-bold ${active ? "text-[#07131D]" : "text-muted"}`}>{label}</Text></Pressable>;
}

export default function LibraryScreen() {
  const router = useRouter();
  const { items, favorites, toggleFavorite } = useCatalog();
  const [query, setQuery] = useState("");
  const [typeFilter, setTypeFilter] = useState<(typeof typeFilters)[number]["value"]>("all");
  const [category, setCategory] = useState("all");
  const [subcategory, setSubcategory] = useState("all");
  const normalized = normalizeSearch(query);

  const categories = useMemo(() => Array.from(new Set(items.map((item) => item.category || item.group || "Sem categoria"))).sort((a, b) => a.localeCompare(b)), [items]);
  const subcategories = useMemo(() => Array.from(new Set(items.filter((item) => category === "all" || (item.category || item.group) === category).map((item) => item.subcategory || "Geral"))).sort((a, b) => a.localeCompare(b)), [category, items]);
  const filtered = useMemo(() => items.filter((item) => {
    const itemCategory = item.category || item.group || "Sem categoria";
    const itemSubcategory = item.subcategory || "Geral";
    const matchesType = typeFilter === "all" || item.kind === typeFilter;
    const matchesCategory = category === "all" || itemCategory === category;
    const matchesSubcategory = subcategory === "all" || itemSubcategory === subcategory;
    const matchesQuery = !normalized || `${item.title} ${itemCategory} ${itemSubcategory} ${item.group}`.toLocaleLowerCase().includes(normalized);
    return matchesType && matchesCategory && matchesSubcategory && matchesQuery;
  }), [category, items, normalized, subcategory, typeFilter]);

  function selectCategory(value: string) {
    setCategory(value);
    setSubcategory("all");
  }

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
          <View className="mb-5 flex-row items-center rounded-2xl border border-border bg-surface px-4 py-1"><IconSymbol name="magnifyingglass" size={19} color="#8FA8B7" /><TextInput value={query} onChangeText={setQuery} placeholder="Buscar título, categoria ou subcategoria" placeholderTextColor="#6D8190" className="ml-3 flex-1 py-3 text-foreground" returnKeyType="search" />{query ? <Pressable onPress={() => setQuery("")}><IconSymbol name="xmark.circle.fill" size={18} color="#8FA8B7" /></Pressable> : null}</View>
          <Text className="mb-2 text-xs font-bold uppercase tracking-wider text-muted">Tipo</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }} className="mb-4">{typeFilters.map((entry) => <FilterChip key={entry.value} label={entry.label} active={typeFilter === entry.value} onPress={() => setTypeFilter(entry.value)} />)}</ScrollView>
          <Text className="mb-2 text-xs font-bold uppercase tracking-wider text-muted">Categorias ({categories.length})</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }} className="mb-4"><FilterChip label="Todas" active={category === "all"} onPress={() => selectCategory("all")} />{categories.map((entry) => <FilterChip key={entry} label={entry} active={category === entry} onPress={() => selectCategory(entry)} />)}</ScrollView>
          {category !== "all" && subcategories.length > 0 ? <><Text className="mb-2 text-xs font-bold uppercase tracking-wider text-muted">Subcategorias</Text><ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }} className="mb-4"><FilterChip label="Todas" active={subcategory === "all"} onPress={() => setSubcategory("all")} />{subcategories.map((entry) => <FilterChip key={entry} label={entry} active={subcategory === entry} onPress={() => setSubcategory(entry)} />)}</ScrollView></> : null}
          <Text className="mb-1 text-sm font-semibold text-foreground">{filtered.length} {filtered.length === 1 ? "resultado" : "resultados"}</Text>
        </View>}
        renderItem={({ item }) => <MediaCard item={item} favorite={favorites.includes(item.id)} onPress={() => router.push({ pathname: "/player", params: { id: item.id } })} onToggleFavorite={() => toggleFavorite(item.id)} />}
        ListEmptyComponent={<View className="mt-8 items-center rounded-2xl border border-dashed border-border bg-surface p-6"><View className="mb-4 h-14 w-14 items-center justify-center rounded-2xl bg-primary/15"><IconSymbol name="rectangle.stack.badge.plus" size={26} color="#23C3D9" /></View><Text className="text-center text-base font-semibold text-foreground">Nenhum item encontrado</Text><Text className="mt-2 text-center text-sm leading-5 text-muted">Importe uma mensagem completa em Ajustes ou altere os filtros de categoria.</Text></View>}
      />
    </ScreenContainer>
  );
}

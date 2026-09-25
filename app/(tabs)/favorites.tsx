import { useRouter } from "expo-router";
import { useMemo } from "react";
import { FlatList, Text, View } from "react-native";

import { MediaCard } from "@/components/media-card";
import { PageHeader } from "@/components/brand";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { ScreenContainer } from "@/components/screen-container";
import { useCatalog } from "@/lib/catalog";

export default function FavoritesScreen() {
  const router = useRouter();
  const { items, favorites, toggleFavorite } = useCatalog();
  const favoriteItems = useMemo(() => favorites.map((id) => items.find((item) => item.id === id)).filter(Boolean), [favorites, items]);

  return (
    <ScreenContainer>
      <FlatList
        data={favoriteItems}
        keyExtractor={(item) => item!.id}
        numColumns={2}
        columnWrapperStyle={{ gap: 12 }}
        contentContainerStyle={{ padding: 20, paddingBottom: 32, gap: 14 }}
        ListHeaderComponent={<View><PageHeader eyebrow="Acesso rápido" title="Favoritos" /><Text className="mb-5 text-sm leading-5 text-muted">Seus canais, filmes e séries salvos para encontrar em um toque.</Text></View>}
        renderItem={({ item }) => item ? <MediaCard item={item} favorite onPress={() => router.push({ pathname: "/player", params: { id: item.id } })} onToggleFavorite={() => toggleFavorite(item.id)} /> : null}
        ListEmptyComponent={<View className="mt-10 items-center rounded-2xl border border-dashed border-border bg-surface p-6"><View className="mb-4 h-14 w-14 items-center justify-center rounded-2xl bg-primary/15"><IconSymbol name="heart.fill" size={25} color="#23C3D9" /></View><Text className="text-center text-base font-semibold text-foreground">Ainda sem favoritos</Text><Text className="mt-2 text-center text-sm leading-5 text-muted">Toque no coração de qualquer item da biblioteca para criar sua seleção.</Text></View>}
      />
    </ScreenContainer>
  );
}

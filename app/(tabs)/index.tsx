import { useRouter } from "expo-router";
import { useMemo } from "react";
import { FlatList, Pressable, Text, View } from "react-native";

import { BrandMark, PageHeader } from "@/components/brand";
import { MediaCard } from "@/components/media-card";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { ScreenContainer } from "@/components/screen-container";
import { useCatalog } from "@/lib/catalog";

export default function HomeScreen() {
  const router = useRouter();
  const { servers, items, favorites, history, hydrated, toggleFavorite } = useCatalog();
  const recentItems = useMemo(() => history.map((id) => items.find((item) => item.id === id)).filter(Boolean).slice(0, 6), [history, items]);
  const liveItems = useMemo(() => items.filter((item) => item.kind === "live").slice(0, 6), [items]);

  return (
    <ScreenContainer edges={["top", "left", "right"]}>
      <FlatList
        data={recentItems.length ? recentItems : liveItems}
        keyExtractor={(item) => item!.id}
        numColumns={2}
        columnWrapperStyle={{ gap: 12 }}
        contentContainerStyle={{ padding: 20, paddingBottom: 32, gap: 14 }}
        ListHeaderComponent={
          <View>
            <View className="mb-7 flex-row items-center justify-between">
              <BrandMark />
              <Pressable onPress={() => router.push("/settings")} style={({ pressed }) => [{ opacity: pressed ? 0.6 : 1 }]} className="h-11 w-11 items-center justify-center rounded-full border border-border bg-surface">
                <IconSymbol name="gearshape.fill" size={20} color="#23C3D9" />
              </Pressable>
            </View>
            <View className="mb-6 rounded-[28px] bg-primary p-5">
              <View className="mb-8 flex-row items-start justify-between">
                <View className="flex-1 pr-5">
                  <Text className="mb-2 text-[11px] font-bold uppercase tracking-[2px] text-[#07131D]/70">Sua central de mídia</Text>
                  <Text className="text-[29px] font-bold leading-8 text-[#07131D]">Tudo em um só lugar.</Text>
                </View>
                <View className="h-12 w-12 items-center justify-center rounded-2xl bg-[#07131D]/10"><IconSymbol name="sparkles" size={24} color="#07131D" /></View>
              </View>
              <Text className="mb-5 max-w-[290px] text-sm leading-5 text-[#07131D]/75">Conecte seus servidores, organize playlists e continue assistindo sem perder o ritmo.</Text>
              <Pressable onPress={() => router.push("/settings")} style={({ pressed }) => [{ opacity: pressed ? 0.8 : 1 }, { backgroundColor: "#07131D", borderRadius: 999, paddingHorizontal: 16, paddingVertical: 12, flexDirection: "row", alignItems: "center", alignSelf: "flex-start" }]}>
                <Text className="mr-2 font-bold text-white">{servers.length ? "Gerenciar fontes" : "Adicionar primeira fonte"}</Text>
                <IconSymbol name="arrow.up.right" size={16} color="#23C3D9" />
              </Pressable>
            </View>
            <View className="mb-6 flex-row gap-3">
              <View className="flex-1 rounded-2xl border border-border bg-surface p-4"><Text className="text-2xl font-bold text-foreground">{hydrated ? servers.length : "—"}</Text><Text className="mt-1 text-xs text-muted">servidores</Text></View>
              <View className="flex-1 rounded-2xl border border-border bg-surface p-4"><Text className="text-2xl font-bold text-foreground">{hydrated ? items.length : "—"}</Text><Text className="mt-1 text-xs text-muted">itens sincronizados</Text></View>
              <View className="flex-1 rounded-2xl border border-border bg-surface p-4"><Text className="text-2xl font-bold text-foreground">{hydrated ? favorites.length : "—"}</Text><Text className="mt-1 text-xs text-muted">favoritos</Text></View>
            </View>
            <Pressable onPress={() => router.push("/library")} style={({ pressed }) => [{ opacity: pressed ? 0.8 : 1 }]} className="mb-7 flex-row items-center rounded-2xl border border-border bg-surface px-4 py-3">
              <IconSymbol name="magnifyingglass" size={19} color="#8FA8B7" />
              <Text className="ml-3 flex-1 text-sm text-muted">Buscar na sua biblioteca</Text>
              <IconSymbol name="chevron.right" size={18} color="#8FA8B7" />
            </Pressable>
            <PageHeader eyebrow={recentItems.length ? "Retome de onde parou" : "Quando você adicionar fontes"} title={recentItems.length ? "Continuar assistindo" : "Sua programação"} />
            {!servers.length ? <View className="mb-2 rounded-2xl border border-dashed border-border bg-surface/60 p-5"><Text className="text-base font-semibold text-foreground">Nenhuma fonte conectada</Text><Text className="mt-2 text-sm leading-5 text-muted">Adicione uma URL M3U em Ajustes para preencher sua biblioteca com conteúdo real.</Text></View> : null}
          </View>
        }
        renderItem={({ item }) => item ? <MediaCard item={item} compact favorite={favorites.includes(item.id)} onPress={() => router.push({ pathname: "/player", params: { id: item.id } })} onToggleFavorite={() => toggleFavorite(item.id)} /> : null}
        ListEmptyComponent={servers.length ? <View className="rounded-2xl border border-border bg-surface p-5"><Text className="font-semibold text-foreground">Playlist sincronizando</Text><Text className="mt-1 text-sm leading-5 text-muted">Assim que os itens estiverem prontos, eles aparecerão aqui.</Text></View> : null}
        ListFooterComponent={<View className="mt-5"><Text className="text-xs leading-5 text-muted">{servers.length ? "Os conteúdos são carregados diretamente das suas fontes. O Multi Servidor não fornece canais ou mídia." : "Privacidade em primeiro lugar: suas fontes e preferências ficam salvas localmente neste dispositivo."}</Text></View>}
      />
    </ScreenContainer>
  );
}

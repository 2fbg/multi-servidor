import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect } from "react";
import { ActivityIndicator, Pressable, Text, View } from "react-native";
import { useEvent } from "expo";
import { VideoView, useVideoPlayer } from "expo-video";

import { IconSymbol } from "@/components/ui/icon-symbol";
import { ScreenContainer } from "@/components/screen-container";
import { kindLabel, useCatalog } from "@/lib/catalog";

export default function PlayerScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { getItem, favorites, toggleFavorite, markPlayed } = useCatalog();
  const item = id ? getItem(id) : undefined;
  const player = useVideoPlayer(null);
  const { status } = useEvent(player, "statusChange", { status: player.status });
  const { isPlaying } = useEvent(player, "playingChange", { isPlaying: player.playing });

  useEffect(() => {
    if (!item) return;
    player.replace(item.url);
    player.play();
    markPlayed(item.id);
  }, [item, markPlayed, player]);

  if (!item) {
    return <ScreenContainer edges={["top", "bottom", "left", "right"]}><View className="flex-1 items-center justify-center p-6"><Text className="text-lg font-bold text-foreground">Conteúdo não encontrado</Text><Pressable onPress={() => router.back()} className="mt-5 rounded-xl bg-primary px-5 py-3"><Text className="font-bold text-[#07131D]">Voltar</Text></Pressable></View></ScreenContainer>;
  }

  return (
    <ScreenContainer edges={["top", "bottom", "left", "right"]} containerClassName="bg-[#02080D]">
      <View className="flex-1">
        <View className="flex-row items-center justify-between px-5 pb-4 pt-3"><Pressable onPress={() => router.back()} style={({ pressed }) => [{ opacity: pressed ? 0.6 : 1 }]} className="h-10 w-10 items-center justify-center rounded-full bg-white/10"><IconSymbol name="chevron.left" size={22} color="#FFFFFF" /></Pressable><Text className="max-w-[220px] text-center text-sm font-semibold text-white" numberOfLines={1}>{item.title}</Text><Pressable onPress={() => toggleFavorite(item.id)} style={({ pressed }) => [{ opacity: pressed ? 0.6 : 1 }]} className="h-10 w-10 items-center justify-center rounded-full bg-white/10"><IconSymbol name={favorites.includes(item.id) ? "heart.fill" : "heart"} size={18} color={favorites.includes(item.id) ? "#23C3D9" : "#FFFFFF"} /></Pressable></View>
        <View className="relative aspect-video w-full overflow-hidden bg-black">
          <VideoView player={player} style={{ width: "100%", height: "100%" }} contentFit="contain" allowsFullscreen allowsPictureInPicture />
          {status === "loading" ? <View className="absolute inset-0 items-center justify-center bg-black/35"><ActivityIndicator color="#23C3D9" size="large" /><Text className="mt-3 text-sm text-white">Carregando transmissão...</Text></View> : null}
          {status === "error" ? <View className="absolute inset-0 items-center justify-center bg-black/70 p-6"><IconSymbol name="exclamationmark.triangle" size={28} color="#FF929A" /><Text className="mt-3 text-center text-sm leading-5 text-white">Esta fonte não respondeu. Tente atualizar a playlist ou escolher outro item.</Text></View> : null}
        </View>
        <View className="flex-1 px-5 pt-6"><View className="mb-7"><Text className="mb-2 text-[11px] font-bold uppercase tracking-[2px] text-primary">{kindLabel(item.kind)} · {item.group}</Text><Text className="text-2xl font-bold text-white">{item.title}</Text></View><View className="flex-row items-center gap-3"><Pressable onPress={() => isPlaying ? player.pause() : player.play()} style={({ pressed }) => [{ opacity: pressed ? 0.7 : 1 }]} className="flex-1 flex-row items-center justify-center rounded-xl bg-primary px-4 py-3"><IconSymbol name={isPlaying ? "pause.fill" : "play.fill"} size={17} color="#07131D" /><Text className="ml-2 font-bold text-[#07131D]">{isPlaying ? "Pausar" : "Reproduzir"}</Text></Pressable><Pressable onPress={() => player.replace(item.url)} style={({ pressed }) => [{ opacity: pressed ? 0.7 : 1 }]} className="h-12 w-12 items-center justify-center rounded-xl border border-white/15 bg-white/5"><IconSymbol name="arrow.clockwise" size={18} color="#FFFFFF" /></Pressable></View><View className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-4"><Text className="text-xs leading-5 text-[#8FA8B7]">A reprodução usa diretamente a URL da sua playlist. A disponibilidade e o formato do stream dependem do servidor de origem.</Text></View></View>
      </View>
    </ScreenContainer>
  );
}

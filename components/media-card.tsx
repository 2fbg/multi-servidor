import { Image, Pressable, Text, View } from "react-native";

import { IconSymbol } from "@/components/ui/icon-symbol";
import { kindIcon, kindLabel, type MediaItem } from "@/lib/catalog";

const coverColors = ["#123B4C", "#21324C", "#3C294A", "#1E4A47"];

export function MediaCard({ item, favorite, onPress, onToggleFavorite, compact = false }: { item: MediaItem; favorite: boolean; onPress: () => void; onToggleFavorite: () => void; compact?: boolean }) {
  const color = coverColors[item.title.length % coverColors.length];
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [{ opacity: pressed ? 0.78 : 1 }, compact ? { width: 174 } : undefined]}>
      <View className="overflow-hidden rounded-2xl border border-border bg-surface">
        <View className={compact ? "h-24" : "h-36"} style={{ backgroundColor: color }}>
          {item.logo ? <Image source={{ uri: item.logo }} className="h-full w-full" resizeMode="contain" /> : null}
          <View className="absolute inset-0 items-center justify-center opacity-25">
            <IconSymbol name={kindIcon(item.kind)} size={44} color="#FFFFFF" />
          </View>
          <View className="absolute bottom-2 left-2 rounded-md bg-black/50 px-2 py-1">
            <Text className="text-[10px] font-bold uppercase tracking-wider text-white">{kindLabel(item.kind)}</Text>
          </View>
          <Pressable onPress={onToggleFavorite} style={({ pressed }) => [{ opacity: pressed ? 0.55 : 1 }]} className="absolute right-2 top-2 h-8 w-8 items-center justify-center rounded-full bg-black/45">
            <IconSymbol name={favorite ? "heart.fill" : "heart"} size={16} color={favorite ? "#23C3D9" : "#FFFFFF"} />
          </Pressable>
        </View>
        <View className="p-3">
          <Text numberOfLines={1} className="font-semibold text-foreground">{item.title}</Text>
          <Text numberOfLines={1} className="mt-1 text-xs text-muted">{item.group}</Text>
        </View>
      </View>
    </Pressable>
  );
}

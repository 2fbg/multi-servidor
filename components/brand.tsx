import { Text, View } from "react-native";

import { IconSymbol } from "@/components/ui/icon-symbol";

export function BrandMark({ compact = false }: { compact?: boolean }) {
  return (
    <View className="flex-row items-center gap-3">
      <View className="h-11 w-11 items-center justify-center rounded-2xl bg-primary">
        <IconSymbol name="play.fill" size={20} color="#07131D" />
      </View>
      {!compact && (
        <View>
          <Text className="text-lg font-bold tracking-tight text-foreground">MULTI</Text>
          <Text className="-mt-1 text-[10px] font-semibold tracking-[3px] text-primary">SERVIDOR</Text>
        </View>
      )}
    </View>
  );
}

export function PageHeader({ eyebrow, title, action }: { eyebrow?: string; title: string; action?: React.ReactNode }) {
  return (
    <View className="mb-5 flex-row items-end justify-between">
      <View className="flex-1">
        {eyebrow ? <Text className="mb-1 text-[11px] font-bold uppercase tracking-[2px] text-primary">{eyebrow}</Text> : null}
        <Text className="text-[30px] font-bold leading-9 text-foreground">{title}</Text>
      </View>
      {action}
    </View>
  );
}

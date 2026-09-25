import MaterialIcons from "@expo/vector-icons/MaterialIcons";
import { SymbolWeight, SymbolViewProps } from "expo-symbols";
import { ComponentProps } from "react";
import { OpaqueColorValue, type StyleProp, type TextStyle } from "react-native";

type IconMapping = Record<SymbolViewProps["name"], ComponentProps<typeof MaterialIcons>["name"]>;
type IconSymbolName = keyof typeof MAPPING;

const MAPPING = {
  "house.fill": "home",
  "rectangle.stack.fill": "view-module",
  "heart.fill": "favorite",
  heart: "favorite-border",
  "slider.horizontal.3": "tune",
  "gearshape.fill": "settings",
  "play.fill": "play-arrow",
  "pause.fill": "pause",
  "sparkles": "auto-awesome",
  "arrow.up.right": "north-east",
  "arrow.right": "arrow-forward",
  "chevron.right": "chevron-right",
  "chevron.left": "chevron-left",
  "magnifyingglass": "search",
  "xmark.circle.fill": "cancel",
  plus: "add",
  "rectangle.stack.badge.plus": "library-add",
  "film.fill": "movie",
  "tv.fill": "tv",
  "dot.radiowaves.left.and.right": "live-tv",
  "server.rack": "dns",
  "arrow.clockwise": "refresh",
  trash: "delete-outline",
  "exclamationmark.triangle": "warning-amber",
} as IconMapping;

export function IconSymbol({ name, size = 24, color, style }: { name: IconSymbolName; size?: number; color: string | OpaqueColorValue; style?: StyleProp<TextStyle>; weight?: SymbolWeight }) {
  return <MaterialIcons color={color} size={size} name={MAPPING[name]} style={style} />;
}

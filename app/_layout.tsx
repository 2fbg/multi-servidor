import "@/global.css";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";

import { CatalogProvider } from "@/lib/catalog";
import { ThemeProvider } from "@/lib/theme-provider";

export default function RootLayout() {
  return (
    <CatalogProvider>
      <ThemeProvider>
        <StatusBar style="light" />
        <Stack screenOptions={{ headerShown: false, animation: "fade" }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="player" options={{ presentation: "modal", animation: "slide_from_bottom" }} />
        </Stack>
      </ThemeProvider>
    </CatalogProvider>
  );
}

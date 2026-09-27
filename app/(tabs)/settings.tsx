import { useState } from "react";
import { ActivityIndicator, Alert, Pressable, ScrollView, Text, TextInput, View } from "react-native";

import { BrandMark, PageHeader } from "@/components/brand";
import { IconSymbol } from "@/components/ui/icon-symbol";
import { ScreenContainer } from "@/components/screen-container";
import { useCatalog } from "@/lib/catalog";

export default function SettingsScreen() {
  const { servers, addServer, addServersFromText, syncServer, removeServer } = useCatalog();
  const [name, setName] = useState("");
  const [playlistUrl, setPlaylistUrl] = useState("");
  const [bulkText, setBulkText] = useState("");
  const [saving, setSaving] = useState(false);
  const [bulkSaving, setBulkSaving] = useState(false);
  const [feedback, setFeedback] = useState<{ type: "success" | "error"; message: string } | null>(null);

  async function handleAdd() {
    setFeedback(null);
    if (!playlistUrl.trim()) {
      setFeedback({ type: "error", message: "Cole a URL da sua playlist M3U para continuar." });
      return;
    }
    setSaving(true);
    try {
      await addServer(name, playlistUrl);
      setName("");
      setPlaylistUrl("");
      setFeedback({ type: "success", message: "Servidor conectado e playlist sincronizada." });
    } catch (error) {
      setFeedback({ type: "error", message: error instanceof Error ? error.message : "Não foi possível conectar este servidor." });
    } finally {
      setSaving(false);
    }
  }

  async function handleBulkAdd() {
    setFeedback(null);
    if (!bulkText.trim()) {
      setFeedback({ type: "error", message: "Cole a mensagem ou as URLs das listas no campo acima." });
      return;
    }
    setBulkSaving(true);
    try {
      const result = await addServersFromText(bulkText);
      setBulkText("");
      const summary = `${result.added} de ${result.found} listas importadas.${result.failed.length ? ` Falhas: ${result.failed.map((entry) => entry.name).join(", ")}.` : ""}`;
      setFeedback({ type: result.failed.length ? "error" : "success", message: summary });
    } catch (error) {
      setFeedback({ type: "error", message: error instanceof Error ? error.message : "Não foi possível extrair as listas." });
    } finally {
      setBulkSaving(false);
    }
  }

  function confirmRemove(serverId: string, serverName: string) {
    Alert.alert("Remover servidor?", `A playlist de ${serverName} e os itens associados serão removidos deste dispositivo.`, [{ text: "Cancelar", style: "cancel" }, { text: "Remover", style: "destructive", onPress: () => removeServer(serverId) }]);
  }

  return (
    <ScreenContainer>
      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 36 }} keyboardShouldPersistTaps="handled">
        <View className="mb-7 flex-row items-center justify-between"><BrandMark compact /><Text className="text-xs font-semibold uppercase tracking-[2px] text-muted">Configurações</Text></View>
        <PageHeader eyebrow="Suas fontes" title="Ajustes" />
        <View className="mb-7 rounded-3xl border border-primary/30 bg-primary/5 p-5">
          <View className="mb-4 flex-row items-center"><View className="mr-3 h-10 w-10 items-center justify-center rounded-xl bg-primary/15"><IconSymbol name="rectangle.stack.badge.plus" size={20} color="#23C3D9" /></View><View className="flex-1"><Text className="text-base font-bold text-foreground">Importar várias listas</Text><Text className="mt-1 text-xs leading-5 text-muted">Cole a mensagem completa do painel. O app encontra automaticamente todos os links M3U/get.php.</Text></View></View>
          <TextInput value={bulkText} onChangeText={setBulkText} placeholder="Cole aqui o texto completo com as listas..." placeholderTextColor="#6D8190" multiline numberOfLines={8} textAlignVertical="top" autoCapitalize="none" autoCorrect={false} className="min-h-[150px] rounded-xl border border-border bg-background px-4 py-3 text-sm leading-5 text-foreground" />
          <Pressable disabled={bulkSaving} onPress={handleBulkAdd} style={({ pressed }) => [{ opacity: pressed || bulkSaving ? 0.75 : 1 }]} className="mt-4 flex-row items-center justify-center rounded-xl bg-primary px-4 py-3"><Text className="font-bold text-[#07131D]">{bulkSaving ? "Importando todas..." : "Extrair e importar listas"}</Text>{bulkSaving ? <ActivityIndicator size="small" color="#07131D" className="ml-2" /> : <IconSymbol name="arrow.down.circle" size={17} color="#07131D" style={{ marginLeft: 8 }} />}</Pressable>
        </View>
        <View className="mb-7 rounded-3xl border border-border bg-surface p-5">
          <View className="mb-5 flex-row items-center"><View className="mr-3 h-10 w-10 items-center justify-center rounded-xl bg-primary/15"><IconSymbol name="plus" size={20} color="#23C3D9" /></View><View><Text className="text-base font-bold text-foreground">Adicionar uma lista</Text><Text className="mt-1 text-xs text-muted">Importe uma playlist M3U por URL</Text></View></View>
          <Text className="mb-2 text-xs font-bold uppercase tracking-wider text-muted">Nome da fonte</Text>
          <TextInput value={name} onChangeText={setName} placeholder="Ex.: Minha TV" placeholderTextColor="#6D8190" className="mb-4 rounded-xl border border-border bg-background px-4 py-3 text-foreground" />
          <Text className="mb-2 text-xs font-bold uppercase tracking-wider text-muted">URL da playlist M3U</Text>
          <TextInput value={playlistUrl} onChangeText={setPlaylistUrl} placeholder="https://.../get.php?..." placeholderTextColor="#6D8190" autoCapitalize="none" autoCorrect={false} keyboardType="url" className="rounded-xl border border-border bg-background px-4 py-3 text-foreground" />
          <Text className="mt-3 text-xs leading-5 text-muted">Aceita links HTTP/HTTPS com get.php, m3u, m3u8 ou playlist.</Text>
          <Pressable disabled={saving} onPress={handleAdd} style={({ pressed }) => [{ opacity: pressed || saving ? 0.75 : 1 }]} className="mt-5 flex-row items-center justify-center rounded-xl border border-border bg-background px-4 py-3"><Text className="font-bold text-foreground">{saving ? "Sincronizando..." : "Conectar uma fonte"}</Text>{saving ? <ActivityIndicator size="small" color="#23C3D9" className="ml-2" /> : <IconSymbol name="arrow.right" size={17} color="#23C3D9" style={{ marginLeft: 8 }} />}</Pressable>
        </View>
        {feedback ? <View className={`mb-5 rounded-xl border p-3 ${feedback.type === "success" ? "border-success/40 bg-success/10" : "border-error/40 bg-error/10"}`}><Text className={`text-sm leading-5 ${feedback.type === "success" ? "text-success" : "text-error"}`}>{feedback.message}</Text></View> : null}
        <View className="mb-7 flex-row items-center justify-between"><Text className="text-lg font-bold text-foreground">Servidores conectados</Text><Text className="text-sm font-semibold text-primary">{servers.length}</Text></View>
        {servers.length ? servers.map((server) => <View key={server.id} className="mb-3 rounded-2xl border border-border bg-surface p-4"><View className="flex-row items-start"><View className="mr-3 h-10 w-10 items-center justify-center rounded-xl bg-background"><IconSymbol name="server.rack" size={20} color="#23C3D9" /></View><View className="flex-1"><Text numberOfLines={1} className="font-bold text-foreground">{server.name}</Text><Text numberOfLines={1} className="mt-1 text-xs text-muted">{server.playlistUrl}</Text><View className="mt-3 flex-row items-center"><View className={`mr-2 h-2 w-2 rounded-full ${server.status === "ready" ? "bg-success" : server.status === "error" ? "bg-error" : "bg-warning"}`} /><Text className="text-xs text-muted">{server.status === "ready" ? `${server.itemCount} itens disponíveis` : server.status === "syncing" ? "Sincronizando playlist" : server.error || "Erro na sincronização"}</Text></View></View></View><View className="mt-4 flex-row justify-end gap-2"><Pressable onPress={() => syncServer(server.id).catch(() => undefined)} style={({ pressed }) => [{ opacity: pressed ? 0.6 : 1 }]} className="flex-row items-center rounded-lg border border-border px-3 py-2"><IconSymbol name="arrow.clockwise" size={15} color="#23C3D9" /><Text className="ml-2 text-xs font-semibold text-foreground">Atualizar</Text></Pressable><Pressable onPress={() => confirmRemove(server.id, server.name)} style={({ pressed }) => [{ opacity: pressed ? 0.6 : 1 }]} className="flex-row items-center rounded-lg border border-error/30 px-3 py-2"><IconSymbol name="trash" size={15} color="#FF929A" /><Text className="ml-2 text-xs font-semibold text-error">Remover</Text></Pressable></View></View>) : <View className="rounded-2xl border border-dashed border-border p-5"><Text className="text-sm leading-5 text-muted">Nenhum servidor configurado. Cole uma mensagem completa acima para importar várias listas de uma vez.</Text></View>}
        <View className="mt-5 rounded-2xl bg-background p-4"><Text className="mb-2 text-sm font-bold text-foreground">Sobre o Multi Servidor</Text><Text className="text-xs leading-5 text-muted">Um player independente para organizar fontes que você já possui. Use apenas conteúdos e fontes para os quais você tem autorização.</Text></View>
      </ScrollView>
    </ScreenContainer>
  );
}

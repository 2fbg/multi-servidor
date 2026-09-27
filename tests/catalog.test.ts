import { describe, expect, it } from "vitest";

import { extractPlaylistSources, kindLabel, parseM3U } from "../lib/catalog";

describe("extractPlaylistSources", () => {
  it("extracts every M3U/get.php playlist from a pasted message", () => {
    const message = [
      "*🔵 Link VLOG(M3U):* http://vlog.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts",
      "*⚪ Link LUB TV (M3U):* http://lub.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts",
      "*🔴 Link CINELON21 (M3U):* http://cinelon.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts",
      "*🟠 Link TANNIX (M3U):* http://tannix.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts",
      "*🔵 Link CB6000 (M3U):* http://cb.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts",
      "*🟣 Link MK21 TV (M3U):* http://mk21.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts",
      "https://example.com/app.apk",
      "https://example.com/carregar-playlist",
    ].join("\n");

    expect(extractPlaylistSources(message)).toEqual([
      { name: "Link VLOG", url: "http://vlog.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts" },
      { name: "Link LUB TV", url: "http://lub.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts" },
      { name: "Link CINELON21", url: "http://cinelon.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts" },
      { name: "Link TANNIX", url: "http://tannix.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts" },
      { name: "Link CB6000", url: "http://cb.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts" },
      { name: "Link MK21 TV", url: "http://mk21.test/get.php?username=u&password=p&type=m3u_plus&output=mpegts" },
    ]);
  });
});

describe("parseM3U", () => {
  it("converts EXTINF entries into unique media items", () => {
    const playlist = [
      "#EXTM3U",
      '#EXTINF:-1 tvg-name="News 24" group-title="Canais | Brasil",News 24',
      "https://example.com/news.m3u8",
      '#EXTINF:-1 group-title="Filmes/ Ação",Cinema Session',
      "https://example.com/movie.mp4",
      '#EXTINF:-1 group-title="Filmes/ Ação",Cinema Session',
      "https://example.com/movie.mp4",
    ].join("\n");

    const items = parseM3U(playlist, "server-1");

    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ title: "News 24", group: "Canais | Brasil", category: "Canais", subcategory: "Brasil", kind: "live", serverId: "server-1" });
    expect(items[1]).toMatchObject({ title: "Cinema Session", category: "Filmes", subcategory: "Ação", kind: "movie" });
  });

  it("ignores comments and incomplete entries", () => {
    const items = parseM3U("#EXTM3U\n#EXTVLCOPT:http-referrer=https://example.com\n", "server-1");
    expect(items).toEqual([]);
  });
});

describe("kindLabel", () => {
  it("returns the Portuguese label for each media kind", () => {
    expect(kindLabel("live")).toBe("Ao vivo");
    expect(kindLabel("movie")).toBe("Filme");
    expect(kindLabel("series")).toBe("Série");
  });
});

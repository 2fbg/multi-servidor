import { describe, expect, it } from "vitest";

import { kindLabel, parseM3U } from "../lib/catalog";

describe("parseM3U", () => {
  it("converts EXTINF entries into unique media items", () => {
    const playlist = [
      "#EXTM3U",
      '#EXTINF:-1 tvg-name="News 24" group-title="Ao Vivo",News 24',
      "https://example.com/news.m3u8",
      '#EXTINF:-1 group-title="Filmes",Cinema Session',
      "https://example.com/movie.mp4",
      '#EXTINF:-1 group-title="Filmes",Cinema Session',
      "https://example.com/movie.mp4",
    ].join("\n");

    const items = parseM3U(playlist, "server-1");

    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ title: "News 24", group: "Ao Vivo", kind: "live", serverId: "server-1" });
    expect(items[1]).toMatchObject({ title: "Cinema Session", kind: "movie" });
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

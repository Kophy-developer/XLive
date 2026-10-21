import { config } from "../config";

export type GiphyGif = {
  id: string;
  title: string;
  previewUrl: string;
  url: string;
};

type GiphyImage = { url?: string };
type GiphyItem = {
  id?: string;
  title?: string;
  images?: {
    preview_gif?: GiphyImage;
    fixed_width_small?: GiphyImage;
    fixed_height_small?: GiphyImage;
    downsized?: GiphyImage;
    original?: GiphyImage;
    fixed_height?: GiphyImage;
  };
};

function parseItem(item: GiphyItem): GiphyGif | null {
  const images = item.images;
  const url = String(images?.downsized?.url || images?.fixed_height?.url || images?.original?.url || "").trim();
  const previewUrl = String(
    images?.fixed_width_small?.url || images?.preview_gif?.url || images?.fixed_height_small?.url || url
  ).trim();
  const id = String(item.id || "").trim();
  if (!id || !url) return null;
  return { id, title: String(item.title || "GIF"), previewUrl, url };
}

async function giphyGet(path: string, params: Record<string, string>) {
  const key = config.giphyApiKey;
  if (!key) throw new Error("Giphy is not configured.");
  const qs = new URLSearchParams({ api_key: key, rating: "pg-13", limit: "24", ...params });
  const res = await fetch(`https://api.giphy.com/v1/gifs/${path}?${qs}`);
  const body = (await res.json().catch(() => ({}))) as { data?: GiphyItem[]; message?: string };
  if (!res.ok) throw new Error(body.message || "Could not load GIFs.");
  return (body.data || []).map(parseItem).filter((g): g is GiphyGif => Boolean(g));
}

export async function searchGiphy(query: string) {
  const q = query.trim();
  if (!q) return listTrendingGiphy();
  return giphyGet("search", { q });
}

export async function listTrendingGiphy() {
  return giphyGet("trending", {});
}

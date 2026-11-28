export const config = {
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://xlive-app-bcqre.ondigitalocean.app",
  wsUrl: process.env.NEXT_PUBLIC_WS_URL ?? "https://xlive-app-bcqre.ondigitalocean.app",
  cloudinaryCloud: process.env.NEXT_PUBLIC_CLOUDINARY_CLOUD ?? "dlfzn6m9q",
  giphyApiKey: process.env.NEXT_PUBLIC_GIPHY_API_KEY ?? "UQsln13lcUzYUqvYeRUmj8BdLvFgPRl2",
} as const;

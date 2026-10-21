export const config = {
  authBaseUrl: process.env.NEXT_PUBLIC_AUTH_BASE_URL ?? "https://creative.flowfly.dev/dev",
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL ?? "https://store-x-live.4tqepo.easypanel.host",
  wsUrl: process.env.NEXT_PUBLIC_WS_URL ?? "https://store-x-live.4tqepo.easypanel.host",
  cloudinaryCloud: process.env.NEXT_PUBLIC_CLOUDINARY_CLOUD ?? "dlfzn6m9q",
  giphyApiKey: process.env.NEXT_PUBLIC_GIPHY_API_KEY ?? "UQsln13lcUzYUqvYeRUmj8BdLvFgPRl2",
} as const;

export const BACKEND_BASE_URL =
  import.meta.env.VITE_BACKEND_BASE_URL?.replace(/\/$/, '') ?? 'http://localhost:8000'

export const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL?.trim() ?? ''
export const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim() ?? ''
export const GOOGLE_AUTH_REDIRECT_TO = 'https://truth-filtering-engine-web.vercel.app/'

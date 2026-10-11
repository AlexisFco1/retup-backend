// ═══════════════════════════════════════════════════════════════════
// CONFIGURACIÓN GENERAL DEL DASHBOARD
// ═══════════════════════════════════════════════════════════════════

/** URL del backend (sin /api). Sale de .env.development o .env.production */
export const API_URL: string =
  import.meta.env.VITE_API_URL ?? 'http://localhost:5000';
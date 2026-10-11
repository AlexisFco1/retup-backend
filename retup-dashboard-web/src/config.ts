export const API_URL: string =
  import.meta.env.VITE_API_URL ?? 'http://localhost:5000';

/**
 * Correo de soporte de RetUp (botón "Ayuda" de la cabecera).
 * Si la empresa del usuario tiene uno propio en company_settings, se usa ese.
 * ⚠️ PROVISIONAL: cambiar por el correo real de soporte.
 */
export const SOPORTE_EMAIL_POR_DEFECTO = 'soporte@retup.com';
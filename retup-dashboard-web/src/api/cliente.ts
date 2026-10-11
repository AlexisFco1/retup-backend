// ═══════════════════════════════════════════════════════════════════
// CLIENTE DEL BACKEND
// Única puerta del dashboard para hablar con server.js.
// - Añade la URL base y /api
// - Pone el token y lo renueva antes de que caduque
// - Si la sesión deja de ser válida, la cierra (vuelve al login)
// ═══════════════════════════════════════════════════════════════════
import { API_URL } from '../config';
import { useSesion } from '../auth/sesion';

/** Error del backend con su código HTTP (0 = sin conexión) */
export class ErrorApi extends Error {
  estado: number;

  constructor(mensaje: string, estado: number) {
    super(mensaje);
    this.name = 'ErrorApi';
    this.estado = estado;
  }
}

/** Si al token le queda menos de esto (segundos), se renueva antes de usarlo */
const MARGEN_RENOVACION_SEGUNDOS = 60;

/** Evita lanzar varias renovaciones a la vez si varias pantallas piden datos juntas */
let renovacionEnCurso: Promise<string | null> | null = null;

type CuerpoRespuesta = { error?: string; [clave: string]: unknown };

async function leerCuerpo(respuesta: Response): Promise<CuerpoRespuesta | null> {
  try {
    return (await respuesta.json()) as CuerpoRespuesta;
  } catch {
    return null;
  }
}

/**
 * ¿La sesión dejó de ser válida?
 * Tu middleware responde 401 "Token requerido" o 403 "Token inválido".
 * OJO: el 403 "No tienes acceso a esta sección" es de permisos, NO de sesión.
 */
function esSesionInvalida(estado: number, cuerpo: CuerpoRespuesta | null): boolean {
  return estado === 401 || (estado === 403 && cuerpo?.error === 'Token inválido');
}

/** Pide un token nuevo con el refresh_token. Devuelve el token o null. */
async function renovarToken(): Promise<string | null> {
  const sesion = useSesion.getState().sesion;
  if (!sesion) return null;

  if (!renovacionEnCurso) {
    renovacionEnCurso = (async () => {
      try {
        const respuesta = await fetch(`${API_URL}/api/dashboard/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: sesion.refreshToken }),
        });

        if (!respuesta.ok) {
          // El refresh_token ya no sirve: hay que volver a iniciar sesión
          useSesion.getState().cerrarSesion();
          return null;
        }

        const datos = (await respuesta.json()) as {
          token: string;
          refresh_token: string;
          expires_at: number;
        };
        useSesion.getState().actualizarTokens(datos.token, datos.refresh_token, datos.expires_at);
        return datos.token;
      } catch {
        // Sin conexión: NO cerramos la sesión, puede ser algo momentáneo
        return null;
      } finally {
        renovacionEnCurso = null;
      }
    })();
  }

  return renovacionEnCurso;
}

/** Devuelve un token que no esté a punto de caducar (renovándolo si hace falta) */
async function tokenVigente(): Promise<string | null> {
  const sesion = useSesion.getState().sesion;
  if (!sesion) return null;

  const ahoraSegundos = Date.now() / 1000;
  if (sesion.expiraEn - ahoraSegundos > MARGEN_RENOVACION_SEGUNDOS) {
    return sesion.token;
  }
  return renovarToken();
}

interface OpcionesPeticion {
  metodo?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  cuerpo?: unknown;
  /** false solo para el login (todavía no hay token) */
  conToken?: boolean;
}

/**
 * Hace una petición al backend.
 * @param ruta Ruta SIN /api. Ej: '/dashboard/me'
 * @returns El JSON de la respuesta, con el tipo que indiques en <T>
 */
export async function apiFetch<T>(ruta: string, opciones: OpcionesPeticion = {}): Promise<T> {
  const { metodo = 'GET', cuerpo, conToken = true } = opciones;

  const enviar = async (token: string | null): Promise<Response> => {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;

    try {
      return await fetch(`${API_URL}/api${ruta}`, {
        method: metodo,
        headers,
        body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
      });
    } catch {
      throw new ErrorApi('No se pudo conectar con el servidor. Revisa tu conexión.', 0);
    }
  };

  let respuesta = await enviar(conToken ? await tokenVigente() : null);
  let datos = await leerCuerpo(respuesta);

  // Token caducado o inválido: renovar UNA vez y reintentar
  if (conToken && esSesionInvalida(respuesta.status, datos)) {
    const tokenNuevo = await renovarToken();
    if (tokenNuevo) {
      respuesta = await enviar(tokenNuevo);
      datos = await leerCuerpo(respuesta);
    }
    if (esSesionInvalida(respuesta.status, datos)) {
      useSesion.getState().cerrarSesion();
      throw new ErrorApi('Tu sesión ha caducado. Vuelve a iniciar sesión.', 401);
    }
  }

  if (!respuesta.ok) {
    throw new ErrorApi(datos?.error ?? `Error ${respuesta.status} del servidor`, respuesta.status);
  }

  return datos as T;
}
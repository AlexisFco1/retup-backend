// ═══════════════════════════════════════════════════════════════════
// SESIÓN DEL DASHBOARD
// Guarda el token, su renovación y el perfil del usuario conectado.
// Se conserva en el navegador (localStorage) para sobrevivir a un F5.
// ═══════════════════════════════════════════════════════════════════
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

/** Niveles de acceso (iguales a la tabla dashboard_access) */
export type NivelAcceso = 'retup' | 'rrhh_gerencia' | 'jefatura' | 'mantenimiento';

/** Una pantalla del menú, ej. { clave: 'mapa-calor', titulo: 'Mapa de calor' } */
export interface PantallaMenu {
  clave: string;
  titulo: string;
}

/** Un bloque del menú por nivel, ej. "RRHH · Gerencia" con sus pantallas */
export interface SeccionMenu {
  nivel: NivelAcceso;
  etiqueta: string;
  pantallas: PantallaMenu[];
}

/** Lo que devuelve el backend en /api/dashboard/me y en el login */
export interface PerfilDashboard {
  usuario: {
    id: string;
    email: string;
    nombre: string | null;
    iniciales: string;
    cargo: string | null;
  };
  empresa: { id: string; name: string } | null;
  niveles: NivelAcceso[];
  equipos_a_cargo: { id: string; name: string; department_id: string }[];
  soporte_email: string | null;
  menu: SeccionMenu[];
}

/** Todo lo que se guarda de una sesión iniciada */
export interface DatosSesion {
  token: string;
  refreshToken: string;
  /** Momento en que caduca el token, en segundos desde 1970 (formato de Supabase) */
  expiraEn: number;
  perfil: PerfilDashboard;
}

interface EstadoSesion {
  sesion: DatosSesion | null;
  iniciarSesion: (datos: DatosSesion) => void;
  actualizarTokens: (token: string, refreshToken: string, expiraEn: number) => void;
  actualizarPerfil: (perfil: PerfilDashboard) => void;
  cerrarSesion: () => void;
}

export const useSesion = create<EstadoSesion>()(
  persist(
    (set) => ({
      sesion: null,

      iniciarSesion: (datos) => set({ sesion: datos }),

      actualizarTokens: (token, refreshToken, expiraEn) =>
        set((estado) =>
          estado.sesion
            ? { sesion: { ...estado.sesion, token, refreshToken, expiraEn } }
            : estado,
        ),

      actualizarPerfil: (perfil) =>
        set((estado) =>
          estado.sesion ? { sesion: { ...estado.sesion, perfil } } : estado,
        ),

      cerrarSesion: () => set({ sesion: null }),
    }),
    {
      // Nombre con el que se guarda en el navegador
      name: 'retup-dashboard-sesion',
    },
  ),
);
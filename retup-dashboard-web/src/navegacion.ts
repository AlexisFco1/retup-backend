// ═══════════════════════════════════════════════════════════════════
// MAPA DE NAVEGACIÓN
// Cada pantalla tiene una URL:  /<prefijo del nivel>/<clave de la pantalla>
// La clave y el título de cada pantalla los envía el backend en el menú.
// ═══════════════════════════════════════════════════════════════════
import type { NivelAcceso, PantallaMenu, PerfilDashboard, SeccionMenu } from './auth/sesion';

/** Prefijo de URL de cada nivel */
export const PREFIJO_POR_NIVEL: Record<NivelAcceso, string> = {
  retup: '/retup',
  rrhh_gerencia: '/rrhh',
  jefatura: '/jefatura',
  mantenimiento: '/mantenimiento',
};

/** URL completa de una pantalla. Ej: rutaPantalla('rrhh_gerencia', 'mapa-calor') -> '/rrhh/mapa-calor' */
export function rutaPantalla(nivel: NivelAcceso, clave: string): string {
  return `${PREFIJO_POR_NIVEL[nivel]}/${clave}`;
}

/** Primera pantalla del primer nivel del usuario (a donde se aterriza al entrar) */
export function rutaInicial(perfil: PerfilDashboard): string | null {
  const primeraSeccion = perfil.menu[0];
  const primeraPantalla = primeraSeccion?.pantallas[0];
  if (!primeraSeccion || !primeraPantalla) return null;
  return rutaPantalla(primeraSeccion.nivel, primeraPantalla.clave);
}

/** Pantalla que corresponde a una URL, buscando SOLO en el menú del usuario */
export interface PantallaEncontrada {
  seccion: SeccionMenu;
  pantalla: PantallaMenu;
}

export function buscarPantalla(
  perfil: PerfilDashboard,
  ruta: string,
): PantallaEncontrada | null {
  for (const seccion of perfil.menu) {
    for (const pantalla of seccion.pantallas) {
      if (rutaPantalla(seccion.nivel, pantalla.clave) === ruta) {
        return { seccion, pantalla };
      }
    }
  }
  return null;
}
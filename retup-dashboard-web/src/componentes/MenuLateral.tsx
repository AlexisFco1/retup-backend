// ═══════════════════════════════════════════════════════════════════
// MENÚ LATERAL
// Un bloque desplegable por nivel de acceso del usuario.
// La pantalla actual se resalta (NavLink sabe si su URL está activa).
// ═══════════════════════════════════════════════════════════════════
import { useState } from 'react';
import { NavLink, useLocation } from 'react-router';
import { useSesion } from '../auth/sesion';
import type { NivelAcceso } from '../auth/sesion';
import { rutaPantalla } from '../navegacion';
import './MenuLateral.css';

export default function MenuLateral() {
  const sesion = useSesion((estado) => estado.sesion);
  const ubicacion = useLocation();

  // Bloques que el usuario abrió a mano
  const [abiertos, setAbiertos] = useState<Set<NivelAcceso>>(new Set());

  if (!sesion) return null;
  const { menu } = sesion.perfil;

  function alternar(nivel: NivelAcceso) {
    setAbiertos((anteriores) => {
      const nuevos = new Set(anteriores);
      if (nuevos.has(nivel)) nuevos.delete(nivel);
      else nuevos.add(nivel);
      return nuevos;
    });
  }

  return (
    <nav className="menu" aria-label="Menú principal">
      {menu.map((seccion) => {
        // ¿La pantalla actual pertenece a este bloque?
        const contieneActual = seccion.pantallas.some(
          (pantalla) => rutaPantalla(seccion.nivel, pantalla.clave) === ubicacion.pathname,
        );
        // Se ve abierto si el usuario lo abrió o si contiene la pantalla actual
        const abierto = abiertos.has(seccion.nivel) || contieneActual;

        return (
          <div key={seccion.nivel} className="menu__seccion">
            <button
              type="button"
              className={`menu__nivel${contieneActual ? ' menu__nivel--actual' : ''}`}
              onClick={() => alternar(seccion.nivel)}
              aria-expanded={abierto}
            >
              <span>{seccion.etiqueta}</span>
              <span className="menu__flecha" aria-hidden="true">
                {abierto ? '▾' : '▸'}
              </span>
            </button>

            {abierto && (
              <ul className="menu__pantallas">
                {seccion.pantallas.map((pantalla) => (
                  <li key={pantalla.clave}>
                    <NavLink
                      to={rutaPantalla(seccion.nivel, pantalla.clave)}
                      className={({ isActive }) =>
                        `menu__enlace${isActive ? ' menu__enlace--activo' : ''}`
                      }
                    >
                      {pantalla.titulo}
                    </NavLink>
                  </li>
                ))}
              </ul>
            )}
          </div>
        );
      })}
    </nav>
  );
}
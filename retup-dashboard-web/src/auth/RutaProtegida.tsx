// ═══════════════════════════════════════════════════════════════════
// GUARDIANES DE RUTAS
// Se usan en App.tsx envolviendo grupos de rutas.
// <Outlet /> = "aquí se pinta la pantalla que corresponda a la URL"
// ═══════════════════════════════════════════════════════════════════
import { Navigate, Outlet, useLocation } from 'react-router';
import { useSesion } from './sesion';

/** Solo deja pasar si HAY sesión. Si no, manda al login. */
export function RutaProtegida() {
  const sesion = useSesion((estado) => estado.sesion);
  const ubicacion = useLocation();

  if (!sesion) {
    // Recordamos a dónde quería ir (lo usaremos más adelante)
    return <Navigate to="/login" replace state={{ desde: ubicacion.pathname }} />;
  }

  return <Outlet />;
}

/** Solo deja pasar si NO hay sesión (ej. el login). Si ya hay, manda al inicio. */
export function SoloSinSesion() {
  const sesion = useSesion((estado) => estado.sesion);

  if (sesion) {
    return <Navigate to="/" replace />;
  }

  return <Outlet />;
}
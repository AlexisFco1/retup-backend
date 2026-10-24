// ═══════════════════════════════════════════════════════════════════
// MARCO DEL DASHBOARD
// Cabecera arriba · menú a la izquierda · filtros + pantalla a la derecha.
// <Outlet /> = aquí se pinta la pantalla que corresponda a la URL.
// ═══════════════════════════════════════════════════════════════════
import { useEffect } from 'react';
import { Outlet, useLocation } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '../api/cliente';
import { useSesion } from '../auth/sesion';
import type { PerfilDashboard } from '../auth/sesion';
import Cabecera from './Cabecera';
import MenuLateral from './MenuLateral';
import BarraFiltros from './BarraFiltros';
import './Marco.css';

interface RespuestaMe {
  success: boolean;
  perfil: PerfilDashboard;
}

/**
 * Pantallas que NO usan los filtros globales (periodo, frecuencia, comparar):
 * muestran el estado actual, no datos de un periodo. Ahí no se pinta la barra.
 * (Los filtros elegidos se conservan para cuando se vuelva a otra pantalla.)
 */
const RUTAS_SIN_FILTROS = ['/mantenimiento', '/rrhh/exportar'];

function usaFiltros(ruta: string): boolean {
  return !RUTAS_SIN_FILTROS.some((prefijo) => ruta === prefijo || ruta.startsWith(`${prefijo}/`));
}

export default function Marco() {
  const actualizarPerfil = useSesion((estado) => estado.actualizarPerfil);
  const { pathname } = useLocation();

  // Al entrar, se pide el perfil actualizado (por si cambiaron sus niveles o su menú)
  const consultaPerfil = useQuery({
    queryKey: ['dashboard', 'me'],
    queryFn: () => apiFetch<RespuestaMe>('/dashboard/me'),
    staleTime: 5 * 60_000, // se considera vigente 5 minutos
  });

  useEffect(() => {
    if (consultaPerfil.data?.perfil) {
      actualizarPerfil(consultaPerfil.data.perfil);
    }
  }, [consultaPerfil.data, actualizarPerfil]);

  return (
    <div className="marco">
      <Cabecera />
      <div className="marco__cuerpo">
        <MenuLateral />
        <div className="marco__contenido">
                    {usaFiltros(pathname) && <BarraFiltros />}
          <main className="marco__pagina">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}
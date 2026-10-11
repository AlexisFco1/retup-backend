// ═══════════════════════════════════════════════════════════════════
// MARCO DEL DASHBOARD
// Cabecera arriba · menú a la izquierda · filtros + pantalla a la derecha.
// <Outlet /> = aquí se pinta la pantalla que corresponda a la URL.
// ═══════════════════════════════════════════════════════════════════
import { useEffect } from 'react';
import { Outlet } from 'react-router';
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

export default function Marco() {
  const actualizarPerfil = useSesion((estado) => estado.actualizarPerfil);

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
          <BarraFiltros />
          <main className="marco__pagina">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}
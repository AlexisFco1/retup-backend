// ═══════════════════════════════════════════════════════════════════
// CABECERA DEL DASHBOARD (visible en todas las pantallas)
// Logo · empresa · hora de actualización · configuración · ayuda ·
// usuario conectado (iniciales, nombre, cargo) · salir
// ═══════════════════════════════════════════════════════════════════
import { useState } from 'react';
import { useIsFetching, useQueryClient } from '@tanstack/react-query';
import { useSesion } from '../auth/sesion';
import { SOPORTE_EMAIL_POR_DEFECTO } from '../config';
import './Cabecera.css';

export default function Cabecera() {
  const sesion = useSesion((estado) => estado.sesion);
  const cerrarSesion = useSesion((estado) => estado.cerrarSesion);
  const clienteConsultas = useQueryClient();
  const consultasEnCurso = useIsFetching();
  const [configAbierta, setConfigAbierta] = useState(false);

  if (!sesion) return null;
  const { perfil } = sesion;

  // Hora del dato más reciente recibido del backend.
  // useIsFetching hace que la cabecera se vuelva a pintar al terminar cada carga.
  const ultimaActualizacion = Math.max(
    0,
    ...clienteConsultas
      .getQueryCache()
      .getAll()
      .map((consulta) => consulta.state.dataUpdatedAt),
  );

  const textoActualizacion =
    consultasEnCurso > 0
      ? 'Actualizando…'
      : ultimaActualizacion > 0
        ? `Datos actualizados a las ${new Date(ultimaActualizacion).toLocaleTimeString('es-ES', {
            hour: '2-digit',
            minute: '2-digit',
          })}`
        : 'Sin datos cargados';

  const correoSoporte = perfil.soporte_email ?? SOPORTE_EMAIL_POR_DEFECTO;
  const enlaceAyuda =
    `mailto:${correoSoporte}` +
    `?subject=${encodeURIComponent('Ayuda con el Dashboard RetUp')}` +
    `&body=${encodeURIComponent(
      `Usuario: ${perfil.usuario.email}\nEmpresa: ${perfil.empresa?.name ?? 'RetUp'}\n\nDescribe tu consulta:\n`,
    )}`;

  return (
    <header className="cabecera">
      {/* ── Marca y empresa ── */}
      <div className="cabecera__marca">
        <img className="cabecera__icono" src="/icono-retup.png" alt="" />
        <span className="cabecera__logo">
          Ret<span>Up</span>
        </span>
        <span className="cabecera__empresa">{perfil.empresa?.name ?? 'Todas las empresas'}</span>
      </div>

      {/* ── Acciones y usuario ── */}
      <div className="cabecera__acciones">
        <div className="cabecera__actualizacion">
          <span>{textoActualizacion}</span>
          <button
            type="button"
            className="cabecera__boton-icono"
            onClick={() => clienteConsultas.invalidateQueries()}
            disabled={consultasEnCurso > 0}
            title="Volver a cargar los datos"
            aria-label="Volver a cargar los datos"
          >
            ↻
          </button>
        </div>

        <div className="cabecera__config">
          <button
            type="button"
            className="cabecera__boton-icono"
            onClick={() => setConfigAbierta((abierta) => !abierta)}
            title="Configuración"
            aria-label="Configuración"
            aria-expanded={configAbierta}
          >
            ⚙
          </button>
          {configAbierta && (
            <div className="cabecera__panel-config" role="dialog" aria-label="Configuración">
              <strong>Configuración</strong>
              <p>Próximamente podrás ajustar:</p>
              <ul>
                <li>Idioma</li>
                <li>Accesos de visualización</li>
                <li>Frecuencia de actualización</li>
              </ul>
            </div>
          )}
        </div>

        <a className="cabecera__ayuda" href={enlaceAyuda}>
          ? Ayuda
        </a>

        <div className="cabecera__usuario">
          <div className="cabecera__avatar" aria-hidden="true">
            {perfil.usuario.iniciales}
          </div>
          <div className="cabecera__datos-usuario">
            <span className="cabecera__nombre">{perfil.usuario.nombre ?? perfil.usuario.email}</span>
            <span className="cabecera__cargo">{perfil.usuario.cargo ?? 'Sin cargo'}</span>
          </div>
        </div>

        <button type="button" className="cabecera__salir" onClick={cerrarSesion}>
          Salir
        </button>
      </div>
    </header>
  );
}
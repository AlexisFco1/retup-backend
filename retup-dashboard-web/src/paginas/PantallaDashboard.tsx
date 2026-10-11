// ═══════════════════════════════════════════════════════════════════
// PANTALLA GENÉRICA "EN CONSTRUCCIÓN"
// Se usa para cualquier URL /<nivel>/<pantalla> hasta que exista la real.
// Solo se muestra si la pantalla pertenece al menú del usuario.
// ═══════════════════════════════════════════════════════════════════
import type { CSSProperties } from 'react';
import { Link, useLocation } from 'react-router';
import { useSesion } from '../auth/sesion';
import { buscarPantalla, rutaInicial } from '../navegacion';
import { fechaLegible, useFiltros } from '../filtros/filtros';

const TEXTO_FRECUENCIA = { dia: 'por día', semana: 'por semana', mes: 'por mes' };
const TEXTO_COMPARACION = {
  ninguna: 'sin comparación',
  periodo_anterior: 'con el periodo anterior',
  anio_anterior: 'con el mismo periodo del año anterior',
};

export default function PantallaDashboard() {
  const sesion = useSesion((estado) => estado.sesion);
  const ubicacion = useLocation();
  const filtros = useFiltros();

  if (!sesion) return null;

  const encontrada = buscarPantalla(sesion.perfil, ubicacion.pathname);

  // La URL existe, pero NO pertenece al menú de este usuario
  if (!encontrada) {
    const inicio = rutaInicial(sesion.perfil) ?? '/';
    return (
      <section style={estilos.tarjeta}>
        <h1 style={estilos.titulo}>No tienes acceso a esta pantalla</h1>
        <p style={estilos.suave}>
          Esta sección no forma parte de tus permisos. Si crees que es un error, usa el botón
          «Ayuda» de la cabecera.
        </p>
        <Link to={inicio} style={estilos.enlace}>
          ← Volver a mi inicio
        </Link>
      </section>
    );
  }

  return (
    <div>
      <p style={estilos.miga}>{encontrada.seccion.etiqueta}</p>
      <h1 style={estilos.titulo}>{encontrada.pantalla.titulo}</h1>

      <section style={estilos.tarjeta}>
        <p style={{ margin: 0, fontWeight: 600 }}>🚧 Pantalla en construcción</p>
        <p style={estilos.suave}>
          Aquí irán los indicadores, tablas y gráficos de esta sección. Todos responderán a los
          filtros de arriba.
        </p>
        <p style={estilos.filtrosActivos}>
          Filtros activos: del <strong>{fechaLegible(filtros.desde)}</strong> al{' '}
          <strong>{fechaLegible(filtros.hasta)}</strong>, {TEXTO_FRECUENCIA[filtros.frecuencia]},{' '}
          {TEXTO_COMPARACION[filtros.comparacion]}.
        </p>
      </section>
    </div>
  );
}

const estilos: Record<string, CSSProperties> = {
  miga: {
    margin: 0,
    fontSize: 13,
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: 0.4,
    color: 'var(--rt-texto-suave)',
  },
  titulo: { margin: '4px 0 20px', fontSize: 26, color: 'var(--rt-indigo)' },
  tarjeta: {
    padding: 28,
    background: 'var(--rt-superficie)',
    borderRadius: 'var(--rt-radio)',
    boxShadow: 'var(--rt-sombra)',
  },
  suave: { margin: '8px 0 0', color: 'var(--rt-texto-suave)', lineHeight: 1.6 },
  filtrosActivos: {
    margin: '16px 0 0',
    padding: '10px 14px',
    fontSize: 14,
    background: 'var(--rt-fondo)',
    borderRadius: 8,
  },
  enlace: {
    display: 'inline-block',
    marginTop: 16,
    fontWeight: 600,
    color: 'var(--rt-indigo)',
  },
};